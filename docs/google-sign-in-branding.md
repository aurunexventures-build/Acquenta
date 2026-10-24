# Acquenta Google sign-in domain

Verified 20 October 2026: Firebase project display name is Acquenta, and acquenta.aurunex.com is an authorized Firebase Auth domain. The Firebase project ID remains metcue09; existing accounts stay in that project.

To replace metcue09.firebaseapp.com in the Google popup:

1. In Google Cloud > Google Auth Platform > Clients, open web client 1084823977938-hcnoc1ev007mia9svj74qal4e7m09vnf.apps.googleusercontent.com in project metcue09.
2. Add https://acquenta.aurunex.com/__/auth/handler to Authorized redirect URIs, preserving existing entries. Check Branding uses Acquenta and the aurunex.com authorized domain.
3. Deploy the prepared /__/auth/* reverse proxy. Verify /__/auth/iframe and /__/auth/handler serve the Firebase auth helper, not the app shell.
4. Build with --dart-define=ACQUENTA_AUTH_DOMAIN=acquenta.aurunex.com, deploy, and test Google popup completion with a new account.

The build retains the working Firebase auth domain until the redirect URI is registered. Changing only authDomain prematurely breaks Google sign-in.

References: https://firebase.google.com/docs/auth/web/google-signin#customizing-the-redirect-domain-for-google-sign-in and https://firebase.google.com/docs/auth/web/redirect-best-practices#proxy-requests
