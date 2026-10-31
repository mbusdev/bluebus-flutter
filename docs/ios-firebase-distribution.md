# iOS test builds with `/build-ios`

Comment `/build-ios` on a pull request, and GitHub Actions builds that PR as a signed ad-hoc
`.ipa`, uploads it to Firebase App Distribution, and replies on the PR with an install link.
Testers open the link on their iPhone and install that exact PR's build.

Files:

- `.github/workflows/ios-build-firebase.yaml`: the `/build-ios` command
- `ios/fastlane/Fastfile`: signing, build and upload
- `ios/Gemfile`, `ios/fastlane/Pluginfile`: fastlane and its Firebase App Distribution plugin

Device UDIDs are kept out of the repo. They're registered in the Apple Developer portal, and
each build's ad-hoc profile includes every device registered there.

## One-time setup

Needs Admin on Apple team `4LLPM7NY5C`, Owner or Editor on the Firebase project, and admin on
the GitHub repo.

### 1. Apple Developer

1. **Distribution certificate.** On the Mac that does App Store releases, open Keychain Access →
   *My Certificates*, right-click the **Apple Distribution** certificate for the team →
   *Export* → save as `dist.p12` with a password. Export only works on the Mac that holds the
   certificate's private key (it shows an expand arrow with a key under it). Ad-hoc builds use
   the same certificate as App Store releases, so reusing it is fine. Then:
   `base64 -i dist.p12 | pbcopy`
2. **App Store Connect API key.** App Store Connect → *Users and Access* → *Integrations* →
   *App Store Connect API* → *Team Keys* → generate a key with **Admin** access (it regenerates
   the ad-hoc profile). Download the `.p8` (only possible once) and note
   the **Key ID** and **Issuer ID**. Then: `base64 -i AuthKey_XXXX.p8 | pbcopy`
3. **Push capability.** Check that the App ID `com.ishankumar.maizebus` has Push Notifications
   enabled. It should already, since the app uses Firebase Messaging.

### 2. Firebase (the project the app already uses)

1. Firebase console → *Release & Monitor* → *App Distribution* → pick the iOS app →
   *Get started*.
2. *Testers & Groups* → *Add group* named `testers` (its alias is then `testers`, which is what
   the workflow sends builds to) and add tester emails.
3. *Project settings* → *General* → the iOS app → copy the **App ID** (`1:…:ios:…`).
4. Google Cloud console for the same project → *IAM & Admin* → *Service Accounts* → create one
   with the role **Firebase App Distribution Admin** → *Keys* → add a JSON key.

### 3. GitHub (repo → Settings → Secrets and variables → Actions)

| Secret | Value |
|---|---|
| `IOS_DIST_CERT_P12_BASE64` | base64 of `dist.p12` |
| `IOS_DIST_CERT_PASSWORD` | the `.p12` export password |
| `ASC_KEY_ID` | API key ID |
| `ASC_ISSUER_ID` | API issuer ID |
| `ASC_KEY_P8_BASE64` | base64 of the `.p8` |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | contents of the service account JSON key |
| `GMAPS_API_KEY` | iOS Google Maps key |
| `FIREBASE_OPTIONS_DART` | contents of `lib/firebase_options.dart` |
| `GOOGLE_SERVICE_INFO_PLIST_BASE64` | base64 of `ios/Runner/GoogleService-Info.plist` |

| Variable | Value |
|---|---|
| `FIREBASE_IOS_APP_ID` | the Firebase iOS App ID from step 2.3 |
| `FIREBASE_TESTER_GROUPS` | optional, comma-separated group aliases (default `testers`) |

### 4. Merge into `main`

GitHub runs comment-triggered workflows from the default branch only, so `/build-ios` starts
working once these files are on `main`.

## Adding a tester

1. Add their email to the `testers` group in Firebase. They open the invite email on their
   iPhone in Safari, accept it, and follow the prompt to register the device. That installs a
   small profile that sends the device's UDID to Firebase.
2. In Firebase → *App Distribution* → *Testers & Groups*, click **Export Apple UDIDs**.
3. In the Apple Developer portal → *Certificates, Identifiers & Profiles* → *Devices* → **+**,
   choose *Register Multiple Devices* and upload that file. A single device can also be entered
   by hand.
4. The next `/build-ios` includes the device. Earlier builds won't install on it.

Apple allows 100 iPhones per membership year, and removed devices still count until renewal.

## Using it

Comment `/build-ios` on a PR. The bot reacts 🚀, then about 15–25 minutes later replies with
the build number and install link. Release notes in Firebase show the PR number, branch and
commit. A new `/build-ios` on the same PR cancels the one in progress.

## Security notes

- Only users with write access to the repo can trigger a build; anyone else gets a refusal reply.
- The build runs the PR's code with the signing secrets available. Review PRs from forks before
  commenting `/build-ios` on them.
- The commit is pinned when the command is posted, so pushes during the build aren't picked up.

## Costs

Each build uses a macOS runner for roughly 15–25 minutes. That's free for public repos; for
private repos macOS minutes count 10x against the Actions quota.

## Not yet verified

This was written without a Mac, so the first real run may need small fixes. Things to watch:

- `ios/Gemfile.lock` doesn't exist yet. Running `bundle lock` in `ios/` on a Mac and committing
  the result pins fastlane's version.
- The Fastfile sets `aps-environment` to `production` in the CI copy of the entitlements, since
  ad-hoc builds use production push. The checked-in file is unchanged.
- If the PR comment has no install link, the Firebase plugin returned the release in a shape the
  Fastfile doesn't expect; testers still get the Firebase email.
