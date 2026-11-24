# iPhone test checklist

Generate the Xcode project with xcodegen generate on a Mac. Open TarkastusCloud.xcodeproj, select the TarkastusCloud target, configure Signing & Capabilities with your Apple development team, and select a connected iPhone. Use the matching iOS Firebase configuration and Google OAuth URL scheme before testing cloud sign-in. Do not commit signing secrets.

- Fresh installation: language selection and switching through all nine languages.
- Offline: create both report types, save, reopen, restart, and export PDFs.
- PDF: verify language independently of UI, customer and inspector details, material categories, result, long text, 9/4 photo layout, missing photos, signature and page numbering.
- Test camera, photo picker and Face ID on a physical device.
- Test Firebase registration, verification, password reset and account deletion using a disposable account.
- Test Drive sync, backup and restore with a disposable shared folder; verify existing reports are preserved.
- Confirm a successful simulator CI build before device testing. A simulator build is not a signed IPA or proof of device behavior.
