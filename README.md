# 7-Zip for macOS

Native macOS/AppKit GUI for 7-Zip archive workflows. The app is built with Swift Package Manager and wraps command-line 7-Zip backends:

- Bundled official 7-Zip for macOS (`7zz`), built from the sibling `../7zip` source checkout.
- Installed p7zip tools (`/usr/local/bin/7z`, `/usr/local/bin/7za`, `/usr/local/bin/7zr`) as fallback backends.

## Build

```bash
make build-backend
make build
```

`make build-backend` compiles the official 7-Zip `Alone2` target and copies the generated `7zz` into `Resources/7zz`. The binary is ignored by git and bundled into the app during `make build`.

## Test

```bash
make test
```

The self-test target runs parser, backend command-construction, backend-priority, and smoke-argument checks without requiring XCTest. GUI smoke reports can be run from the built app with `--gui-smoke-report`, optionally combined with `--gui-smoke-archive`, `--gui-smoke-navigate`, and `--gui-smoke-password`.

## Run

```bash
make run
```

The app bundle is written to:

```text
dist/7-Zip.app
```

You can also open an archive directly:

```bash
open dist/7-Zip.app --args /path/to/archive.7z
```

## Current Features

- Open archives from the app, Finder/Open With, or a launch argument.
- Open an archive and list entries using `7z l -slt`.
- Navigate folders inside archives, and use Up at archive root to browse the archive's parent folder.
- Sort archive and folder listings by clicking table column headers.
- Use table context menus and keyboard shortcuts for common open, extract, rename, delete, test, password, and backend actions.
- Drag files onto an open archive to add them, or drag an archive/folder into the listing to open it.
- Add files/folders to a new archive.
- Configure add format/compression/password options when creating an archive.
- Extract selected entries or the whole archive with overwrite, password, and reveal-destination options.
- Cancel long-running list, add, extract, test, delete, rename, and preview operations.
- Test archive integrity.
- Delete selected archive entries where the backend supports it.
- Rename a selected archive entry where the backend supports it.
- Password prompts for listing, extracting, testing, and creating encrypted archives.
- Backend settings with persisted custom executable path, reset-to-autodetect, and candidate detection.
- Packaged `.app` bundle with a 7-Zip icon resource and local ad-hoc signature.

## Notes

This is an initial native port, not a Win32 UI compatibility layer. The UI follows the core 7-Zip File Manager workflows while using macOS controls and a backend abstraction over official 7-Zip/p7zip command-line tools.
