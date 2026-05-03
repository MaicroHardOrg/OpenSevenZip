# Native macOS 7-Zip GUI Port

## Summary
Build a new Swift Package Manager macOS 14+ app in `voice-input-src`, using the README-described harness style: Makefile-driven build/run/install/clean, signed `.app` bundle output, and no Electron/Tauri dependency. The app will be a native AppKit file-manager style port of 7-Zip File Manager workflows, backed by command-line 7-Zip engines instead of attempting to compile Win32 UI code.

## Key Changes
- Scaffold `voice-input-src` as a Swift/AppKit app with:
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
  - `Makefile` targets: `build`, `run`, `install`, `clean`, `build-backend`.
  - `build-backend` compiles official macOS `7zz` from the checked-in `7zip` source and copies it into app resources.
  - App bundle includes `Info.plist`, icon placeholder derived from existing 7-Zip assets where licensing permits, and local codesigning.

## Behavior Details
- Opening an archive loads table rows via `list`; double-clicking folders navigates inside the archive, double-clicking files extracts to a temporary preview location and opens with Finder default app.
- Extract supports selected entries or whole archive, destination picker, overwrite mode, password, and "open destination after extract."
- Add/compress supports selected filesystem items, archive path, format selection based on backend capabilities, compression level, encryption password, and header encryption when supported.
- Backend settings window shows selected backend, detected version, executable path, capabilities, and lets the user override the path or reset to autodetect.
- Long-running operations run asynchronously with cancellable progress UI. If exact progress is not available from backend output, show indeterminate progress plus current log line.

## Test Plan
- Build tests:
  - `make build-backend` produces bundled `7zz`.
  - `make build` produces a signed `.app`.
  - `make run` launches the app.
- Backend tests:
  - Parse `7z l -slt` output from official `7zz` and p7zip.
  - Verify backend priority and fallback when `7zz` or p7zip binaries are missing.
  - Verify command construction for spaces, Unicode paths, selected entries, and passwords.
- Integration scenarios:
  - Create `.7z` and `.zip`, list contents, extract all, extract selected files, test archive integrity.
  - Open password-protected archives and handle wrong password errors.
  - Confirm p7zip at `/usr/local/bin/7z` is detected on this machine.
- UI acceptance:
  - Main window remains responsive during operations.
  - Errors include backend name, command action, exit code, and readable stderr.
  - File/archive table handles nested folders, empty archives, large archives, and Unicode filenames.

## Assumptions
- `voice-input-src` has no reusable app source locally, so implementation will create the SwiftPM/AppKit harness there using the README's build conventions.
- The first version is a native macOS 7-Zip file-manager experience, not a pixel-perfect Win32 clone.
- Official 7-Zip is bundled as `7zz`; p7zip is supported by autodetection/configuration, not bundled.
- Target output is a locally signed macOS app, not a notarized public release.
