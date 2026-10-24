import Flutter
import UIKit
import UserNotifications
import Contacts
import ContactsUI
import MultipeerConnectivity
import CryptoKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, CNContactViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
  private var nearbyBridge: AcquentaNearbyBridge?
  private var contactResult: FlutterResult?
  private var contactsChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    nearbyBridge = AcquentaNearbyBridge(messenger: engineBridge.applicationRegistrar.messenger())
    contactsChannel = FlutterMethodChannel(name: "acquenta/contacts", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    contactsChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "saveContact" else { result(FlutterMethodNotImplemented); return }
      guard let self = self, self.contactResult == nil,
            let args = call.arguments as? [String: Any], let text = args["vcard"] as? String,
            let data = text.data(using: .utf8) else {
        result(FlutterError(code: "CONTACT_UNAVAILABLE", message: "A contact editor is already open or the card is invalid.", details: nil)); return
      }
      do {
        guard let contact = try CNContactVCardSerialization.contacts(with: data).first else { throw NSError(domain: "Acquenta", code: 1) }
        guard var presenter = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows }).first(where: { $0.isKeyWindow })?.rootViewController else { throw NSError(domain: "Acquenta", code: 2) }
        while let presented = presenter.presentedViewController { presenter = presented }
        let editor = CNContactViewController(forNewContact: contact)
        editor.delegate = self
        let navigation = UINavigationController(rootViewController: editor)
        self.contactResult = result
        presenter.present(navigation, animated: true)
        navigation.presentationController?.delegate = self
      } catch { result(FlutterError(code: "CONTACT_EXPORT_FAILED", message: "Could not open the contact editor.", details: nil)) }
    }
  }
  func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
    viewController.dismiss(animated: true)
    let result = contactResult; contactResult = nil; result?(contact != nil)
  }
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    let result = contactResult; contactResult = nil; result?(false)
  }
}


/// Foreground, consent-based iPhone exchange. No account identifiers are advertised.
private final class AcquentaNearbyBridge: NSObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
  private let channel: FlutterMethodChannel
  private let service = "acquenta-card"
  private var peer: MCPeerID?
  private var session: MCSession?
  private var advertiser: MCNearbyServiceAdvertiser?
  private var browser: MCNearbyServiceBrowser?
  private var found: [String: MCPeerID] = [:]
  private var invitation: ((Bool, MCSession?) -> Void)?
  private var pendingPeer: MCPeerID?
  private var connectedPeer: MCPeerID?
  private var privateKey: Curve25519.KeyAgreement.PrivateKey?
  private var remotePublic: Data?
  private var key: SymmetricKey?
  private var mode = ""
  private var localConfirmed = false, remoteConfirmed = false, cardSent = false, cardReceived = false, completed = false
  private var deadline: Timer?
  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "acquenta/nearby", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(FlutterError(code: "CLOSED", message: "Nearby sharing closed.", details: nil)); return }
      do {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "available": result(true)
        case "start":
          guard let mode = args["mode"] as? String, ["send", "receive"].contains(mode) else { throw self.failure() }
          self.start(mode); result(self.peer?.displayName)
        case "invite":
          guard self.mode == "send", self.connectedPeer == nil, self.pendingPeer == nil, let id = args["id"] as? String,
                let peer = self.found[id], let session = self.session else { throw self.failure() }
          self.pendingPeer = peer
          self.browser?.invitePeer(peer, to: session, withContext: Data("acquenta-v1".utf8), timeout: 30)
          self.emit("connecting"); result(nil)
        case "accept":
          guard let invitation = self.invitation else { throw self.failure() }
          self.invitation = nil
          let accept = args["accept"] as? Bool == true
          invitation(accept, accept ? self.session : nil)
          if !accept { self.pendingPeer = nil }
          result(nil)
        case "confirm":
          guard self.key != nil, !self.localConfirmed else { throw self.failure() }
          self.localConfirmed = true
          try self.seal(["kind": "confirm"]); self.ready(); result(nil)
        case "send":
          guard self.mode == "send", self.localConfirmed, self.remoteConfirmed, !self.cardSent,
                let card = args["card"] as? String, card.utf8.count <= 30000,
                card.hasPrefix("BEGIN:VCARD"), card.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("END:VCARD") else { throw self.failure() }
          try self.seal(["kind": "card", "card": card]); self.cardSent = true; self.emit("sent"); result(nil)
        case "saved":
          guard self.mode == "receive", self.cardReceived, !self.completed else { throw self.failure() }
          try self.seal(["kind": "saved"]); self.completed = true; self.deadline?.invalidate(); result(nil)
        case "decline":
          if self.key != nil { try? self.seal(["kind": "declined"]) }
          self.emit("declined"); result(nil)
        case "stop": self.stop(); result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      } catch { result(FlutterError(code: "NEARBY_FAILED", message: "Nearby sharing could not continue. Retry or use the offline QR.", details: nil)) }
    }
    NotificationCenter.default.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
  }
  deinit { NotificationCenter.default.removeObserver(self) }
  private func failure() -> NSError { NSError(domain: "AcquentaNearby", code: 1) }
  private func emit(_ type: String, _ fields: [String: Any] = [:]) {
    channel.invokeMethod("event", arguments: fields.merging(["type": type]) { _, new in new })
  }
  private func start(_ value: String) {
    stop()
    mode = value
    let local = MCPeerID(displayName: "Acquenta " + String(UUID().uuidString.prefix(4)))
    peer = local; privateKey = Curve25519.KeyAgreement.PrivateKey()
    let connection = MCSession(peer: local, securityIdentity: nil, encryptionPreference: .required)
    session = connection; connection.delegate = self
    if value == "receive" {
      advertiser = MCNearbyServiceAdvertiser(peer: local, discoveryInfo: ["v": "1"], serviceType: service)
      advertiser?.delegate = self; advertiser?.startAdvertisingPeer()
    } else {
      browser = MCNearbyServiceBrowser(peer: local, serviceType: service)
      browser?.delegate = self; browser?.startBrowsingForPeers()
    }
    deadline = Timer.scheduledTimer(withTimeInterval: 180, repeats: false) { [weak self] _ in
      guard let self = self else { return }; self.emit("timeout"); self.stop()
    }
  }
  private func stop() {
    deadline?.invalidate(); deadline = nil
    advertiser?.stopAdvertisingPeer(); browser?.stopBrowsingForPeers()
    advertiser?.delegate = nil; browser?.delegate = nil; advertiser = nil; browser = nil
    invitation?(false, nil); invitation = nil
    session?.delegate = nil; session?.disconnect(); session = nil
    pendingPeer = nil; connectedPeer = nil; peer = nil; found.removeAll()
    privateKey = nil; remotePublic = nil; key = nil; mode = ""
    localConfirmed = false; remoteConfirmed = false; cardSent = false; cardReceived = false; completed = false
  }
  @objc private func background() { emit("paused"); stop() }
  private func packet(_ object: [String: Any]) throws {
    guard let session = session, let target = connectedPeer else { throw failure() }
    try session.send(JSONSerialization.data(withJSONObject: object), toPeers: [target], with: .reliable)
  }
  private func seal(_ object: [String: Any]) throws {
    guard let key = key else { throw failure() }
    let box = try AES.GCM.seal(JSONSerialization.data(withJSONObject: object), using: key)
    guard let bytes = box.combined else { throw failure() }
    try packet(["kind": "sealed", "data": bytes.base64EncodedString()])
  }
  private func ready() {
    if localConfirmed && remoteConfirmed { emit("ready") }
  }
  func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, session === self.session else { return }
      if state == .connected {
        guard self.connectedPeer == nil, self.pendingPeer == peerID else { self.emit("error"); self.stop(); return }
        self.connectedPeer = peerID; self.browser?.stopBrowsingForPeers(); self.advertiser?.stopAdvertisingPeer()
        do { try self.packet(["kind": "hello", "v": 1, "mode": self.mode, "public": self.privateKey!.publicKey.rawRepresentation.base64EncodedString()]) }
        catch { self.emit("error"); self.stop() }
      } else if state == .notConnected && self.pendingPeer == peerID {
        self.emit(self.completed ? "closed" : "disconnected"); self.stop()
      }
    }
  }
  func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, session === self.session, peerID == self.connectedPeer else { return }
      do {
        guard data.count <= 65536, let message = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw self.failure() }
        if message["kind"] as? String == "hello" {
          guard self.key == nil, message["v"] as? Int == 1, let role = message["mode"] as? String,
                ["send", "receive"].contains(role), role != self.mode,
                let encoded = message["public"] as? String, let raw = Data(base64Encoded: encoded), raw.count == 32, let own = self.privateKey else { throw self.failure() }
          let remote = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: raw)
          let secret = try own.sharedSecretFromKeyAgreement(with: remote)
          let first = own.publicKey.rawRepresentation
          let context = first.lexicographicallyPrecedes(raw) ? first + raw : raw + first
          let key = secret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data("Acquenta nearby v1".utf8), sharedInfo: context, outputByteCount: 32)
          self.key = key; self.remotePublic = raw
          let hash = key.withUnsafeBytes { SHA256.hash(data: Data($0) + Data("verification".utf8)) }
          let number = hash.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) } % 1000000
          self.emit("verification", ["code": String(format: "%06u", number), "name": peerID.displayName])
        } else {
          guard message["kind"] as? String == "sealed", let encoded = message["data"] as? String,
                let bytes = Data(base64Encoded: encoded), let key = self.key,
                let payload = try JSONSerialization.jsonObject(with: AES.GCM.open(AES.GCM.SealedBox(combined: bytes), using: key)) as? [String: Any] else { throw self.failure() }
          switch payload["kind"] as? String {
          case "confirm": self.remoteConfirmed = true; self.ready()
          case "card":
            guard self.mode == "receive", self.localConfirmed, self.remoteConfirmed, !self.cardReceived,
                  let card = payload["card"] as? String, card.utf8.count <= 30000,
                  card.hasPrefix("BEGIN:VCARD"), card.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("END:VCARD") else { throw self.failure() }
            self.cardReceived = true; self.emit("card", ["card": card])
          case "saved":
            guard self.mode == "send", self.cardSent, self.localConfirmed, self.remoteConfirmed, !self.completed else { throw self.failure() }
            self.completed = true; self.deadline?.invalidate(); self.emit("saved")
          case "declined": self.emit("declined"); self.stop()
          default: throw self.failure()
          }
        }
      } catch { self.emit("error"); self.stop() }
    }
  }
  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, advertiser === self.advertiser, self.invitation == nil, self.pendingPeer == nil,
            context == Data("acquenta-v1".utf8) else { invitationHandler(false, nil); return }
      self.pendingPeer = peerID; self.invitation = invitationHandler
      self.emit("incoming", ["name": peerID.displayName])
    }
  }
  func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, browser === self.browser, info?["v"] == "1" else { return }
      let id = self.found.first(where: { $0.value == peerID })?.key ?? UUID().uuidString
      self.found[id] = peerID; self.emit("found", ["id": id, "name": peerID.displayName])
    }
  }
  func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, browser === self.browser, let id = self.found.first(where: { $0.value == peerID })?.key else { return }
      self.found.removeValue(forKey: id); self.emit("lost", ["id": id])
    }
  }
  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) { DispatchQueue.main.async { [weak self] in guard let self, advertiser === self.advertiser else { return }; self.emit("error"); self.stop() } }
  func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) { DispatchQueue.main.async { [weak self] in guard let self, browser === self.browser else { return }; self.emit("error"); self.stop() } }
  func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { stream.close() }
  func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { progress.cancel() }
  func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { if let url = localURL { try? FileManager.default.removeItem(at: url) } }
}
