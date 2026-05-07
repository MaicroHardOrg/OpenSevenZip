# Distribution Checklist

## Mac App Store and TestFlight

- Build with `make build-backend-universal` and `make package-appstore`.
- Confirm `lipo -info "dist/OpenSevenZip Explorer.app/Contents/MacOS/SevenZipMac"` reports `x86_64 arm64`.
- Confirm `lipo -info "dist/OpenSevenZip Explorer.app/Contents/MacOS/7zz"` reports `x86_64 arm64`.
- Sign with App Store distribution identities and provisioning instead of the default ad-hoc identity.
- Confirm the app entitlement includes App Sandbox and user-selected file read/write access.
- Confirm the bundled `7zz` helper entitlement includes sandbox inheritance.
- Upload first to App Store Connect TestFlight and pass Beta App Review.
- Test with internal testers, then external testers, before public App Store release.
- Complete privacy labels, support URL, beta review notes, screenshots, category, and encryption export compliance.
- Prepare App Store metadata placeholders before upload: app description, subtitle, keywords, support URL, marketing URL, review notes, beta feedback email, privacy labels, screenshots, and encryption export compliance.
- Complete manual sandbox workflow testing:
  - open archive through file picker
  - extract to chosen folder
  - add files through file picker
  - drag/drop archive and files

The App Store/TestFlight build intentionally disables PATH discovery and user-imported executables. It uses only the bundled reviewed `7zz` backend.

## GitHub

- Build with `make build-backend-universal` and `make dmg-github`.
- The GitHub bundle is `dist/OpenSevenZip Explorer-gh.app`, so it does not overwrite the App Store/TestFlight bundle.
- The GitHub DMG is `dist/OpenSevenZip-Explorer-gh.dmg`.
- `Resources/7zz` is ignored by git. Release automation must build it from the adjacent 7-Zip source tree or provide it as a trusted release input before running `make dmg-github`.
- Sign with a Developer ID Application identity.
- Enable hardened runtime during signing.
- Notarize with `xcrun notarytool`.
- Staple with `xcrun stapler`.
- Publish a `.dmg` or `.zip`, checksum, release notes, and source attribution.

The GitHub build allows bundled, host PATH-discovered, fallback host-path, and user-imported temporary 7-Zip executables.
