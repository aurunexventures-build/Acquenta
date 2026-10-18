import Flutter
import UIKit
import UserNotifications
import Contacts
import ContactsUI

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, CNContactViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
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
