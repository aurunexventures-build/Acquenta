# Mobile-first authentication

Firebase project: `metcue09`. Authentication stays in Firebase; wallet records,
photos and semantic recall stay on the existing Cloudflare backend.

- The welcome page offers Google, email/password sign-in, account creation,
  password reset and local-only access. Existing Firebase sessions restore at launch.
- Native Android uses the official `google_sign_in` package and a Firebase ID token.
  Web uses Firebase's Google popup, without initializing the native Google plugin.
- The account button opens the same auth page; signed-in users can sign out there.
- Account changes clear provider state before loading the new user's local wallet.
  Local cards are claimed by the first signed-in account once. Subsequent accounts
  use separate local records and onboarding state; the Worker verifies the Firebase
  token and scopes cloud records by UID.
- Passwords and Google tokens are handled by Firebase/Google SDKs, not stored in
  preferences or sent to Cloudflare as credentials. Cloudflare gets Firebase ID tokens.

## Configuration verified on 17 October 2026

Email/password and Google are enabled in Firebase. Existing authorized domains were
preserved, and `127.0.0.1` was added for the local preview. Android's current debug
signing SHA-1 is registered, and `android/app/google-services.json` was refreshed
from Firebase with both Android and web OAuth clients. Release APKs currently use
that existing development signing key; a future production key needs its own SHA.

On 18 October 2026, the existing MetCue project received an iOS Firebase app for
`com.aurunex.contactCardBuilder`. Explicit iOS FirebaseOptions and the matching
Google client ID / callback URL scheme are configured. The unsigned iOS device
build succeeds. Native iOS login and installation remain unverified until a trusted
iPhone and Apple development signing identity are available.

## Validation

Widget tests cover 360/390px phones, keyboard insets, Google-button dispatch,
email validation, unmodified passwords, registration, reset feedback, failure
messages, local access, sign-out and isolation of two accounts. Existing wallet,
recall, QR and sync tests remain in the suite. Browser screenshots verify the
actual phone and desktop welcome page. Completing a real Google/account login
requires the account owner; mock tests do not establish an end-to-end SSO session.


## Native installation check — 18 October 2026

The latest debug APK was installed with `adb install -r` on the connected
Samsung SM-G990E (R5CT114D6SR), preserving app data. The activity launched and
its process remained running. `flutter build ios --debug --no-codesign --no-pub`
completed and produced `build/ios/iphoneos/Runner.app`. This is unsigned and cannot
be installed until Apple development signing is configured. No iPhone or valid
code-signing identity was detected during this check. No backend deployment was
performed; recent history/reminder fields need the matching backend before
cross-device cloud behavior can be verified.


## Signed iPhone installation — 18 October 2026

Developer Mode was enabled and the iPhone 14 Pro was paired. Xcode automatic
signing with the AuruNex Ventures Personal Team successfully built the current
Release configuration. The signed app at
`build/ios-device/Build/Products/Release-iphoneos/Runner.app` was installed on the
phone using `devicectl`. Initial launch required trusting the developer profile on the iPhone. After the
user confirmed trust, `devicectl` successfully launched the installed app. The development provisioning profile
expires on 25 October 2026 at 08:03 UTC; rebuild/reinstall is needed after expiry.
This is a development installation, not an App Store/TestFlight distribution.


## iOS startup lifecycle repair

After developer trust was approved, launch initially succeeded at the OS level
but the app immediately exited with SIGTRAP. The iPhone crash report identified
`UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption` on iOS 27.
Migrated AppDelegate to FlutterImplicitEngineDelegate, moved plugin registration
to didInitializeImplicitFlutterEngine, and added the standard FlutterSceneDelegate
scene manifest. This follows https://docs.flutter.dev/release/breaking-changes/uiscenedelegate.
The signed Release rebuild succeeded and was reinstalled without deleting app
data. The next verification attempt was blocked by the phone screen lock;
the user then confirmed MetCue opened. A subsequent device process query
confirmed Runner.app remained running after the repair.
