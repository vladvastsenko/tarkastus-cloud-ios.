# iPhone test checklist

Generate the Xcode project with xcodegen generate on a Mac. Open TarkastusCloud.xcodeproj, select the TarkastusCloud target, configure Signing & Capabilities with your Apple development team, and select a connected iPhone. Use the matching iOS Firebase configuration and Google OAuth URL scheme before testing cloud sign-in. Do not commit signing secrets.

- Fresh installation: language selection and switching through all nine languages.
- Offline: create both report types, save, reopen, restart, and export PDFs.
- PDF: verify language independently of UI, customer and inspector details, material categories, result, long text, 9/4 photo layout, missing photos, signature and page numbering.
- Test camera, photo picker and Face ID on a physical device.
- Test Firebase registration, verification, password reset and account deletion using a disposable account.
- Test Drive sync, backup and restore with a disposable shared folder; verify existing reports are preserved.
- Confirm a successful simulator CI build before device testing. A simulator build is not a signed IPA or proof of device behavior.

## Configure real cloud services

Register the iOS app with bundle ID `fi.vladi.tarkastuscloud` in Firebase, enable email/password and Google sign-in, download the iOS GoogleService-Info.plist (not Android google-services.json), and run `python3 scripts/configure_ios.py /path/to/GoogleService-Info.plist`. Then run `xcodegen generate --spec project.local.yml`. Enable Drive API and configure OAuth consent/test users in the corresponding Google Cloud project. Configure signing in Xcode. Local configuration is ignored by Git.

## GitHub Actions configuration

In repository Settings → Secrets and variables → Actions, create repository secret `FIREBASE_IOS_PLIST` with the complete raw XML contents of the downloaded iOS plist. Do not use HTML-escaped XML or Markdown backslashes. The simulator workflow uses it when available; otherwise it builds the offline variant. The workflow does not upload the configured app or print the plist. A signed device build still requires Apple signing credentials.

## Device build

Run `bash scripts/fetch_android_icon.sh` on macOS before project generation. CI fetches the exact Android artwork at a pinned commit and verifies its Git object hash before conversion. If the original repository is not accessible, provide the original JPG to `scripts/import_android_icon.sh` instead. In Actions, manually run the workflow with `device_build` enabled for an unsigned iphoneos compile check. This is not an installable IPA. For installation on a personal iPhone, open the generated project on a Mac, select your Apple team under Signing & Capabilities and run on the paired iPhone. Do not upload signing keys or configured app bundles to a public workflow.
