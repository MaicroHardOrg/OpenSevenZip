# App Store Readiness TODO

## Can Be Automatically Fixed

- Done: Change App Store bundle ID casing to lowercase: `com.maicrohard.opensevenzip-explorer`.
- Done: Move bundled `7zz` from `Contents/Resources/7zz` to `Contents/MacOS/7zz`.
- Done: Update `BackendLocator` to find bundled `7zz` in the new helper location.
- Done: Ensure helper signing still uses sandbox + inherit entitlements.
- Done: Update smoke tests for new helper path.
- Done: Add release checklist entries for TestFlight/App Store.
- Done: Add App Store metadata placeholders in docs: privacy labels, screenshots, support URL, review notes.
- Done: Add a sandbox workflow test checklist for open/add/extract/drag-drop.
- Done: Rebuild and verify:
  - `make package-appstore`
  - `codesign --display --entitlements`
  - `lipo -info`
  - App Store-flavored GUI smoke

## Needs Human Assistance

- Apple Developer Team ID and App Store Connect access.
- Final App Store bundle ID registration.
- Apple Distribution certificate and provisioning profile.
- TestFlight app record creation.
- Privacy labels answers.
- Encryption export compliance answers.
- Support URL and marketing URL decisions.
- App Store screenshots.
- App Store description, subtitle, keywords, category, and review notes.
- Manual sandbox workflow testing on a real user account:
  - open archive through file picker
  - extract to chosen folder
  - add files through file picker
  - drag/drop archive and files
- Legal/trademark review for `OpenSevenZip Explorer`, 7-Zip references, icon usage, and bundled 7-Zip license attribution.
