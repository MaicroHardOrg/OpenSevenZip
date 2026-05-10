# Localization TODO

Translations marked `new-unchecked` are app-specific strings that were not directly verified against upstream 7-Zip language files. A human fluent in each language should review them before release.

## Implementation Status

Implemented:

- Added JSON string tables in `Resources/Localizations/` for `en`, `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, and `ru`.
- Added `Sources/SevenZipMac/Localization.swift` with supported-language detection, user default storage, fallback to English, and validation helpers.
- Updated packaging in `Makefile` so app bundles copy `Resources/Localizations`.
- Wired localized strings into `AppConfiguration.swift`, `Models.swift`, `Dialogs.swift`, and the main menu, toolbar, context menu, table headers, archive actions, backend settings, App Store backend settings, alerts, and operation statuses in `MainWindowController.swift`.
- Added `Tools > Options...` with a System Default / language selector and a button to open Backend Settings.
- Kept Backend Settings directly available under `Tools` and from the toolbar/context menu.
- Added localization self-tests for JSON key coverage, language resolution, and English lookup.
- Updated `Resources/ThirdPartyNotices.txt` to disclose use/alignment with official 7-Zip language resources.

Verification completed:

- `make test`
- `make test-appstore`
- `make package-github`
- `git diff --check`

Remaining engineering follow-up:

- Run an interactive GUI smoke pass after packaging to inspect longer translated strings in the Options, Add, Extract, and Backend Settings windows.
- Consider replacing the remaining few intentionally technical English-only diagnostics in smoke-test error paths if those ever become user-visible.
- Optionally update `README.md` and `README_CN.md` to mention multi-language support.

## Source Summary

- `upstream`: string came from official 7-Zip 26.01 `Lang/*.txt` or `en.ttt`.
- `new-unchecked`: string was newly written for OpenSevenZip Explorer behavior.
- Initial review languages: `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.

## New Unchecked Keys

- `add.chooseFiles`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `add.createPanel`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `add.created`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `add.creating`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `add.encryptFileNamesSupported`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `add.exclude`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `add.excludePlaceholder`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `add.failed`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `add.include`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `add.includePlaceholder`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `add.splitPlaceholder`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `app.backendUnavailable`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `app.chooseAvailableBackend`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `app.detectingBackend`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `app.licenseUnavailable`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `app.licensesTitle`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `app.noArchiveOpen`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `app.operationFailed`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `app.storeBackendCandidate`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `app.storeBackendHeading`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `app.storePolicyNotice`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `button.create`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `delete.deletedEntries`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `delete.selectedEntries`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `error.invalidArchive`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `error.noArchive`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `error.noBackend`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `error.noBackendAppStore`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `error.unsupported`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `error.unsupportedGithub`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `extract.destinationPanel`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `extract.done`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `extract.failed`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `extract.overwrite`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `extract.showDestination`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `extract.to`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `folder.cannotOpen`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `folder.items`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `list.failed`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `list.listing`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `list.loaded`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `menu.archivePassword`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `menu.licenses`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `menu.openSelected`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `menu.quit`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `operation.cancelled`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `operation.cancelling`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.applyLanguage`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.available`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.backend`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.backendHeading`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.backendSettings`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.choose`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.chooseExecutable7z`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.chooseTemporaryBackend`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.currentLanguage`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.detectedBackends`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.formats`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.none`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.notAvailable`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.notFound`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.resetBundle`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.selectLanguage`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.status`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.systemDefault`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.temporaryBackendUnavailable`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.temporaryExecutable`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.temporaryPlaceholder`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.unknownVersion`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.useSelected`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `options.useTemporary`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `password.archivePassword`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `password.blankHint`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `preview.extracting`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `preview.failed`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `preview.opened`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `rename.done`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `rename.entry`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `rename.failed`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `rename.renaming`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `test.failed`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
- `test.passed`: review translations in `zh-Hans`, `ja`, `ko`, `fr`, `de`, `es`, `ru`.
