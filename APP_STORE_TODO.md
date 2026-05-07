# App Store Readiness TODO

This file tracks what remains before publishing `OpenSevenZip Explorer` through
TestFlight and the Mac App Store. The GitHub build can keep broader backend
discovery, but the App Store build must stay sandboxed and must not execute
arbitrary user-selected or PATH-discovered tools.

## Current Engineering Status

- Done: App Store bundle identifier uses lowercase reverse-DNS casing:
  `com.maicrohard.opensevenzip-explorer`.
- Done: App Store build disables external backend discovery at compile time.
- Done: App Store package bundles only the official `7zz` helper.
- Done: Bundled `7zz` is packaged at `Contents/MacOS/7zz`.
- Done: `BackendLocator` resolves the bundled helper from `Contents/MacOS/7zz`.
- Done: Helper signing uses sandbox inheritance entitlements.
- Done: Self-tests and GUI smoke tests cover App Store backend behavior.
- Done: Release docs include App Store metadata placeholders and sandbox checks.

## Automatic Verification Commands

Run these from the repository root before handing a build to a human tester:

```sh
make test
make test-appstore
make package-appstore
make verify-architectures
codesign --verify --deep --strict --verbose=2 "dist/OpenSevenZip Explorer.app"
codesign --display --entitlements :- "dist/OpenSevenZip Explorer.app"
codesign --display --entitlements :- "dist/OpenSevenZip Explorer.app/Contents/MacOS/7zz"
```

Expected results:

- All tests pass.
- `lipo -info` reports both `x86_64` and `arm64` for the app executable.
- If bundled `Resources/7zz` is present locally, `lipo -info` also reports both
  `x86_64` and `arm64` for `Contents/MacOS/7zz`.
- The app entitlement output includes App Sandbox.
- The helper entitlement output includes App Sandbox and inherit.
- The App Store build does not show temporary backend import or PATH discovery.

## Human Setup: Apple Developer Account

1. Join or access the Apple Developer Program.
2. Confirm access to App Store Connect for the target organization.
3. Record the Apple Developer Team ID in a private release note or CI secret.
4. Do not commit certificates, provisioning profiles, API keys, or private IDs
   unless the repository has an approved secret-management process.

## Human Setup: Bundle ID

1. Open Apple Developer Certificates, Identifiers & Profiles.
2. Register a macOS App ID for:
   `com.maicrohard.opensevenzip-explorer`
3. Enable only capabilities required by the app.
4. Keep App Sandbox enabled.
5. Do not enable network, automation, file-system, or device capabilities unless
   the app has a concrete feature that requires them and the reason is
   documented for App Review.

## Human Setup: Certificates And Profiles

1. Create or obtain an Apple Distribution certificate.
2. Create a Mac App Store provisioning profile for
   `com.maicrohard.opensevenzip-explorer`.
3. Install the certificate and provisioning profile on the release Mac or CI
   runner.
4. Update the release packaging command or CI environment with the correct
   signing identity and provisioning profile.
5. Build a signed App Store package and verify it locally before upload.

## Human Setup: App Store Connect Record

1. Create a new macOS app in App Store Connect.
2. Use the app name `OpenSevenZip Explorer`.
3. Select bundle ID `com.maicrohard.opensevenzip-explorer`.
4. Set the SKU to a stable internal identifier, for example:
   `opensevenzip-explorer-macos`.
5. Choose the primary category. Recommended starting point:
   `Utilities`.
6. Add support URL and marketing URL.
7. Add copyright owner text.

## Human Setup: App Metadata

Prepare and enter the following App Store metadata:

- App name: `OpenSevenZip Explorer`
- Subtitle: concise archive-manager description.
- Description: explain archive browsing, extraction, creation, testing, and the
  bundled 7-Zip backend without implying affiliation with 7-Zip.
- Keywords: include archive-related search terms, but avoid trademark stuffing.
- Category: `Utilities`, unless a better category is chosen by the publisher.
- Support URL: a public page or GitHub Issues page.
- Marketing URL: project site or GitHub repository.
- Review notes: mention that the app bundles the official 7-Zip command-line
  helper and does not execute arbitrary external tools in the App Store build.

## Human Setup: Privacy Labels

Answer App Store privacy questions based on the final product behavior:

1. Confirm whether the app collects any data.
2. Confirm whether diagnostics, analytics, crash logs, or telemetry are added.
3. Confirm whether archive filenames, paths, or file contents ever leave the
   user device.
4. If no telemetry or network upload exists, the expected privacy position is
   that the app does not collect user data.
5. Recheck this answer if future versions add update checks, crash reporting,
   cloud sync, analytics, or remote license checks.

## Human Setup: Export Compliance

Answer Apple export-compliance prompts:

1. Confirm whether the app uses encryption beyond Apple's operating-system APIs
   and the bundled 7-Zip functionality.
2. Confirm whether archive encryption creation or extraction is exposed in the
   UI for the submitted version.
3. If archive encryption is supported, review Apple's current export-compliance
   questions carefully and keep the final answers with release records.
4. A developer or publisher must make the final legal/compliance decision.

## Human Setup: Screenshots

Create screenshots on a clean macOS account:

1. Main archive browser window with a public dummy archive.
2. Extraction destination flow.
3. Add/create archive flow.
4. Test archive result window.
5. Settings window showing App Store-safe backend behavior.

Screenshot rules:

- Use only public or generated dummy archives.
- Do not show private filenames, user paths, emails, real documents, or secrets.
- Use the App Store build, not the GitHub build.
- Ensure the UI is large enough that all text is readable and non-overlapping.

## Human Legal Review

Before submission, a human publisher should review:

- Whether `OpenSevenZip Explorer` is acceptable as a trademark-safe name.
- Whether every reference to 7-Zip clearly describes compatibility or bundled
  backend use without implying endorsement.
- Whether `Resources/ThirdPartyNotices.txt` includes the correct 7-Zip license
  and attribution text for the bundled binary.
- Whether the icon, screenshots, README, and App Store text avoid restricted
  trademark or copyrighted assets.
- Whether the source repository and packaged app include required license files.

## Manual Sandbox Workflow Test

Run these tests on a normal user account using the App Store build:

1. Open a public `.7z` archive through the file picker.
2. Open a public `.zip` archive through the file picker.
3. Browse nested folders inside an archive.
4. Press Up from an archive subfolder and confirm it moves to the parent folder.
5. Press Up at `/` and confirm it remains `/`.
6. Extract selected files to a user-chosen folder.
7. Extract all files to a user-chosen folder.
8. Create a new archive from files selected through the file picker.
9. Add files to an existing archive through the file picker.
10. Test an archive and confirm the result window does not crash.
11. Drag and drop an archive onto the app.
12. Confirm Settings does not expose PATH discovery or arbitrary backend import.
13. Confirm the backend list shows only the bundled App Store-safe backend.
14. Quit and reopen the app, then repeat one archive open and one extraction.

Use only public dummy archives for this test. Record macOS version, CPU
architecture, app version, and any failure details.

## TestFlight Checklist

1. Build the App Store variant with the final signing identity and provisioning
   profile.
2. Upload the signed build to App Store Connect.
3. Wait for Apple processing to complete.
4. Add internal testers first.
5. Ask testers to run the Manual Sandbox Workflow Test above.
6. Fix any crash, layout, sandbox, or backend-selection issue before external
   TestFlight.
7. Add external testers only after internal testing passes.
8. Keep release notes focused on user-visible behavior.

## App Review Submission Checklist

1. Confirm the submitted binary is the App Store variant, not the GitHub variant.
2. Confirm the app name is `OpenSevenZip Explorer`.
3. Confirm the bundle ID is `com.maicrohard.opensevenzip-explorer`.
4. Confirm arbitrary external backend import is unavailable.
5. Confirm PATH backend discovery is unavailable.
6. Confirm the bundled helper is signed and sandbox-inheriting.
7. Confirm privacy labels match actual behavior.
8. Confirm export-compliance answers are complete.
9. Confirm support URL works without login.
10. Confirm screenshots show only public dummy archives.
11. Confirm review notes explain bundled `7zz` behavior.
12. Submit for review.

## Remaining Human-Assisted Items

- Apple Developer Team ID and App Store Connect access.
- Final bundle ID registration in Apple's developer portal.
- Apple Distribution certificate.
- Mac App Store provisioning profile.
- App Store Connect app record.
- TestFlight upload and tester management.
- Privacy-label answers.
- Export-compliance answers.
- Support URL and marketing URL decisions.
- App Store screenshots.
- Final App Store description, subtitle, keywords, category, and review notes.
- Manual sandbox workflow testing on real Intel and Apple Silicon Macs.
- Legal/trademark/license review.
