# OpenSevenZip Explorer Native macOS GUI Port

## Summary
Build a Swift Package Manager macOS 14+ app in this standalone `7zip-mac-app` repository. The app is a native AppKit file-manager style archive utility under the trademark-safe name **OpenSevenZip Explorer**, backed by command-line 7-Zip engines instead of attempting to compile Win32 UI code.

## Key Changes
- Scaffold `7zip-mac-app` as a Swift/AppKit app with:
  - Main browser window: path bar, toolbar, file/archive table, status bar.
  - Archive actions: Open, Add, Extract, Test, Delete, Rename where backend support allows.
  - Dialogs modeled after 7-Zip workflows: add/compress options, extract destination/options, password prompt, operation progress, error details.
- Add backend abstraction:
  - `SevenZipBackend` protocol with `list`, `extract`, `add`, `test`, `delete`, and `capabilities`.
  - Official backend: bundled `7zz` built from `7zip/CPP/7zip/Bundles/Alone2`.
  - p7zip backend: autodetect `/usr/local/bin/7z`, `/usr/local/bin/7za`, `/usr/local/bin/7zr`, plus user-configurable path.
  - Default priority: bundled official `7zz`, then p7zip `7z`, then `7za`, then `7zr`.
- Add parser layer for backend output:
  - Prefer machine-stable list parsing using `7z l -slt`.
  - Normalize archive entries into a shared Swift model: path, size, packed size, modified date, attributes, encrypted flag, directory flag.
  - Convert backend exit codes and stderr into user-facing operation errors.
- Add packaging/build support:
  - `Makefile` targets for GitHub and App Store/TestFlight variants.
  - `build-backend-universal` compiles official macOS `7zz` for x86_64 and arm64, then combines them with `lipo`.
- App bundle includes distribution-specific `Info.plist`, entitlements, third-party notices, icon resource, and local codesigning defaults.

## Current Status
- Implemented native AppKit archive browser, toolbar workflows, backend selection, direct archive opening, and in-archive navigation.
- Implemented parent-folder browsing so Up from an archive root exits the archive and shows its containing folder.
- Implemented sortable table columns for archive and folder listings.
- Implemented table context menus and keyboard shortcuts for common archive actions.
- Implemented drag-and-drop opening/adding, add options, extract options, session password reuse, and preview temp cleanup.
- Implemented cancellable long-running backend operations with a status-bar Cancel button that terminates the active 7-Zip process.
- Implemented live backend output updates in the status bar for long-running operations.
- Implemented advanced add options for split volumes plus include/exclude patterns.
- Implemented backend capability exposure, command validation, settings details, and capability-based create-format choices.
- Implemented app bundle icon packaging from the checked-in 7-Zip file-manager icon asset.
- Implemented bundled official `7zz` support plus p7zip/custom backend detection.
- Implemented Open, Add, Extract, Test, Delete, Rename, Password, and Backend toolbar workflows.
- Added app-owned self-tests for parser and smoke argument behavior via `make test`.
- Added GUI smoke reporting that captures the rendered window from inside the app for CLI-based verification on a non-headless Mac.
- Added command-construction and backend-priority self-tests covering spaces, Unicode paths, selected entries, passwords, overwrite modes, encrypted-header flags, and p7zip fallback order.
- Verified real archive create/list/test/selected-extract flows with bundled official `7zz` and installed p7zip `7z`; verified encrypted archive listing with correct and wrong passwords.
- Added dual distribution builds from the same source tree:
  - GitHub build keeps bundled, PATH-discovered, fallback host-path, and temporary imported executable backends.
  - App Store/TestFlight build compiles with `APP_STORE`, enables sandbox entitlements, and exposes only the bundled reviewed backend.
- Added license/attribution notice bundling and Help menu access.
- Verified universal app and bundled backend slices for x86_64 and arm64.

## Behavior Details
- Opening an archive loads table rows via `list`; double-clicking folders navigates inside the archive, double-clicking files extracts to a temporary preview location and opens with Finder default app.
- Extract supports selected entries or whole archive, destination picker, overwrite mode, password, and "open destination after extract."
- Add/compress supports selected filesystem items, archive path, format selection based on backend capabilities, compression level, encryption password, and header encryption when supported.
- GitHub backend settings window shows selected backend, detected version, executable path, capabilities, selectable candidates, and temporary executable import.
- App Store/TestFlight backend settings window shows bundled backend status and a policy notice that external executable support is only available in the GitHub build.
- Long-running operations run asynchronously with cancellable progress UI. If exact progress is not available from backend output, show indeterminate progress plus current backend output line.

## Test Plan
- Build tests:
  - `make build-backend-universal` produces universal bundled `7zz`.
  - `make package-github` produces a universal GitHub `.app`.
  - `make package-appstore` produces a universal App Store/TestFlight `.app`.
  - `make verify-architectures` confirms app and backend contain x86_64 and arm64 slices.
- Backend tests:
  - Done: parse `7z l -slt` output from official `7zz` and p7zip-style output.
  - Done: verify backend priority and fallback order for custom, bundled `7zz`, and p7zip binaries.
  - Done: verify App Store candidate list contains only bundled `7zz` when compiled with `APP_STORE`.
  - Done: verify command construction for spaces, Unicode paths, selected entries, passwords, overwrite mode, and encrypted headers.
- Integration scenarios:
  - Done: create `.7z` and `.zip`, list contents, extract selected files, rename an entry, and test archive integrity.
  - Done: open password-protected archives with the correct password and handle wrong password errors.
  - Done: confirm p7zip at `/usr/local/bin/7z`, `/usr/local/bin/7za`, and `/usr/local/bin/7zr` is detected on this machine.
- UI acceptance:
  - Main window remains responsive during operations.
  - Errors include backend name, command action, exit code, and readable stderr.
  - File/archive table handles nested folders, empty archives, large archives, and Unicode filenames.

## Assumptions
- `voice-input-src` provided build harness conventions only; implementation now lives in the standalone `7zip-mac-app` repo.
- The first version is a native macOS 7-Zip file-manager experience, not a pixel-perfect Win32 clone.
- Official 7-Zip is bundled as `7zz`; p7zip is supported by autodetection/configuration, not bundled.
- GitHub public release still requires Developer ID signing, notarization, stapling, and release packaging.
- App Store/TestFlight release still requires App Store signing/provisioning, App Store Connect metadata, beta review, and final review.
