import AppKit

@MainActor
final class MainWindowController: NSWindowController {
    private let pathField = NSTextField(labelWithString: "No archive open")
    private let statusField = NSTextField(labelWithString: "Detecting backend...")
    private let progress = NSProgressIndicator()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()

    private var backend: SevenZipBackend?
    private var archiveURL: URL?
    private var allEntries: [ArchiveEntry] = []
    private var currentPath = ""
    private var visibleEntries: [ArchiveEntry] = []

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "7-Zip"
        window.minSize = NSSize(width: 760, height: 420)
        window.backgroundColor = .windowBackgroundColor
        self.init(window: window)
        setupWindow()
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }

    private func setupWindow() {
        guard let window else { return }
        window.center()
        window.toolbar = makeToolbar()

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 0
        root.translatesAutoresizingMaskIntoConstraints = false
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let pathBar = NSStackView()
        pathBar.orientation = .horizontal
        pathBar.spacing = 8
        pathBar.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        pathBar.wantsLayer = true
        pathBar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let upButton = NSButton(title: "Up", target: self, action: #selector(goUp))
        upButton.bezelStyle = .rounded
        pathField.lineBreakMode = .byTruncatingMiddle
        pathBar.addArrangedSubview(upButton)
        pathBar.addArrangedSubview(pathField)

        setupTable()
        setupStatusBar()

        root.addArrangedSubview(pathBar)
        root.addArrangedSubview(scrollView)
        root.addArrangedSubview(statusContainer())

        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        window.contentView = contentView
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            root.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            root.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])

        Task { await detectBackend() }
    }

    private func setupTable() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.doubleAction = #selector(openSelectedEntry)
        tableView.target = self

        addColumn("name", title: "Name", width: 390)
        addColumn("size", title: "Size", width: 110)
        addColumn("packed", title: "Packed", width: 110)
        addColumn("modified", title: "Modified", width: 180)
        addColumn("attributes", title: "Attr", width: 80)
        addColumn("encrypted", title: "Encrypted", width: 90)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
    }

    private func addColumn(_ identifier: String, title: String, width: CGFloat) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title
        column.width = width
        tableView.addTableColumn(column)
    }

    private func setupStatusBar() {
        progress.style = .spinning
        progress.controlSize = .small
        progress.isDisplayedWhenStopped = false
        statusField.lineBreakMode = .byTruncatingMiddle
    }

    private func statusContainer() -> NSView {
        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 8
        container.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        container.addArrangedSubview(progress)
        container.addArrangedSubview(statusField)
        return container
    }

    private func makeToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.displayMode = .iconAndLabel
        toolbar.delegate = self
        return toolbar
    }

    private func detectBackend() async {
        setBusy(true, message: "Detecting backend...")
        backend = await BackendLocator.defaultBackend()
        setBusy(false, message: backend.map { "\($0.info.name): \($0.info.version)" } ?? AppError.noBackend.description)
    }

    private func reloadArchive(password: String? = nil) {
        guard let backend else {
            Dialogs.showError(AppError.noBackend, in: window)
            return
        }
        guard let archiveURL else {
            Dialogs.showError(AppError.noArchiveSelected, in: window)
            return
        }

        Task {
            do {
                setBusy(true, message: "Listing \(archiveURL.lastPathComponent)...")
                allEntries = try await backend.list(archive: archiveURL, password: password)
                currentPath = ""
                refreshVisibleEntries()
                setBusy(false, message: "\(allEntries.count) entries loaded from \(archiveURL.lastPathComponent)")
            } catch {
                setBusy(false, message: "List failed")
                Dialogs.showError(error, in: window)
            }
        }
    }

    private func refreshVisibleEntries() {
        let children = allEntries.filter { entry in
            if currentPath.isEmpty {
                return entry.parentPath.isEmpty
            }
            return entry.parentPath == currentPath
        }.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory && !$1.isDirectory }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }

        visibleEntries = children
        pathField.stringValue = archiveURL.map { "\($0.path)\(currentPath.isEmpty ? "" : " / \(currentPath)")" } ?? "No archive open"
        tableView.reloadData()
    }

    private func selectedEntries() -> [ArchiveEntry] {
        tableView.selectedRowIndexes.compactMap { index in
            guard index >= 0 && index < visibleEntries.count else { return nil }
            return visibleEntries[index]
        }
    }

    private func setBusy(_ busy: Bool, message: String) {
        statusField.stringValue = message
        busy ? progress.startAnimation(nil) : progress.stopAnimation(nil)
    }

    @objc private func openArchive() {
        let panel = NSOpenPanel()
        panel.title = "Open Archive"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        archiveURL = url
        reloadArchive()
    }

    @objc private func askPasswordAndReload() {
        guard archiveURL != nil else {
            Dialogs.showError(AppError.noArchiveSelected, in: window)
            return
        }
        if let password = Dialogs.askPassword(message: "Archive password", in: window) {
            reloadArchive(password: password)
        }
    }

    @objc private func extractSelected() {
        guard let backend, let archiveURL else {
            Dialogs.showError(archiveURL == nil ? AppError.noArchiveSelected : AppError.noBackend, in: window)
            return
        }

        let panel = NSOpenPanel()
        panel.title = "Extract To"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        let entries = selectedEntries()
        let password = Dialogs.askPassword(message: "Extract password", in: window)

        Task {
            do {
                setBusy(true, message: "Extracting...")
                try await backend.extract(archive: archiveURL, entries: entries, destination: destination, password: password, overwrite: true)
                setBusy(false, message: "Extracted to \(destination.path)")
                NSWorkspace.shared.activateFileViewerSelecting([destination])
            } catch {
                setBusy(false, message: "Extract failed")
                Dialogs.showError(error, in: window)
            }
        }
    }

    @objc private func addFiles() {
        guard let backend else {
            Dialogs.showError(AppError.noBackend, in: window)
            return
        }

        let openPanel = NSOpenPanel()
        openPanel.title = "Choose Files To Add"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = true
        guard openPanel.runModal() == .OK, !openPanel.urls.isEmpty else { return }

        let savePanel = NSSavePanel()
        savePanel.title = "Create Archive"
        savePanel.nameFieldStringValue = "Archive.7z"
        guard savePanel.runModal() == .OK, let archive = savePanel.url else { return }

        let password = Dialogs.askPassword(message: "Archive password", in: window)
        Task {
            do {
                setBusy(true, message: "Creating \(archive.lastPathComponent)...")
                try await backend.add(items: openPanel.urls, archive: archive, format: archive.pathExtension.isEmpty ? "7z" : archive.pathExtension, level: 5, password: password, encryptHeaders: true)
                archiveURL = archive
                allEntries = try await backend.list(archive: archive, password: password)
                refreshVisibleEntries()
                setBusy(false, message: "Created \(archive.lastPathComponent)")
            } catch {
                setBusy(false, message: "Add failed")
                Dialogs.showError(error, in: window)
            }
        }
    }

    @objc private func testArchive() {
        guard let backend, let archiveURL else {
            Dialogs.showError(archiveURL == nil ? AppError.noArchiveSelected : AppError.noBackend, in: window)
            return
        }
        let password = Dialogs.askPassword(message: "Test password", in: window)
        Task {
            do {
                setBusy(true, message: "Testing \(archiveURL.lastPathComponent)...")
                try await backend.test(archive: archiveURL, password: password)
                setBusy(false, message: "Test passed")
                Dialogs.showInfo("Archive test passed", detail: archiveURL.path, in: window)
            } catch {
                setBusy(false, message: "Test failed")
                Dialogs.showError(error, in: window)
            }
        }
    }

    @objc private func deleteSelected() {
        guard let backend, let archiveURL else {
            Dialogs.showError(archiveURL == nil ? AppError.noArchiveSelected : AppError.noBackend, in: window)
            return
        }
        let entries = selectedEntries()
        guard !entries.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "Delete selected entries?"
        alert.informativeText = entries.map(\.path).joined(separator: "\n")
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        Task {
            do {
                setBusy(true, message: "Deleting...")
                try await backend.delete(archive: archiveURL, entries: entries)
                allEntries = try await backend.list(archive: archiveURL, password: nil)
                refreshVisibleEntries()
                setBusy(false, message: "Deleted \(entries.count) entries")
            } catch {
                setBusy(false, message: "Delete failed")
                Dialogs.showError(error, in: window)
            }
        }
    }

    @objc private func showBackendSettings() {
        var pathValue = BackendLocator.customBackendPath

        while true {
            let alert = NSAlert()
            alert.messageText = "Backend Settings"
            alert.informativeText = backend.map {
                "Current: \($0.info.name)\n\($0.info.executableURL.path)\n\n\($0.info.version)"
            } ?? "No active backend"
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Choose...")
            alert.addButton(withTitle: "Reset")
            alert.addButton(withTitle: "Cancel")

            let stack = NSStackView()
            stack.orientation = .vertical
            stack.spacing = 8
            stack.translatesAutoresizingMaskIntoConstraints = false

            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 520, height: 24))
            field.placeholderString = "Custom backend path, for example /usr/local/bin/7z"
            field.stringValue = pathValue

            let candidates = NSTextField(labelWithString: backendCandidateSummary())
            candidates.lineBreakMode = .byWordWrapping
            candidates.maximumNumberOfLines = 0

            stack.addArrangedSubview(field)
            stack.addArrangedSubview(candidates)
            alert.accessoryView = stack
            NSLayoutConstraint.activate([
                stack.widthAnchor.constraint(equalToConstant: 560)
            ])

            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                BackendLocator.setCustomBackendPath(field.stringValue)
                Task { await detectBackend() }
                return
            case .alertSecondButtonReturn:
                let panel = NSOpenPanel()
                panel.title = "Choose 7-Zip Backend"
                panel.canChooseFiles = true
                panel.canChooseDirectories = false
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    pathValue = url.path
                }
            case .alertThirdButtonReturn:
                BackendLocator.resetCustomBackendPath()
                Task { await detectBackend() }
                return
            default:
                return
            }
        }
    }

    private func backendCandidateSummary() -> String {
        BackendLocator.candidates().map { candidate in
            let exists = FileManager.default.isExecutableFile(atPath: candidate.url.path) ? "available" : "missing"
            return "\(candidate.name): \(candidate.url.path) (\(exists))"
        }.joined(separator: "\n")
    }

    func smokeTestSnapshot() -> [String: Any] {
        let frame = window?.frame ?? .zero
        let windowFrame: [String: CGFloat] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.width,
            "height": frame.height
        ]

        var report: [String: Any] = [:]
        report["windowTitle"] = window?.title ?? ""
        report["windowIsVisible"] = window?.isVisible ?? false
        report["windowFrame"] = windowFrame
        report["toolbarItems"] = window?.toolbar?.items.map(\.label) ?? []
        report["pathText"] = pathField.stringValue
        report["statusText"] = statusField.stringValue
        report["tableColumnCount"] = tableView.tableColumns.count
        report["tableColumns"] = tableView.tableColumns.map(\.title)
        report["visibleEntryCount"] = visibleEntries.count
        report["backendName"] = backend?.info.name ?? ""
        report["backendPath"] = backend?.info.executableURL.path ?? ""
        report["backendVersion"] = backend?.info.version ?? ""
        return report
    }

    @objc private func openSelectedEntry() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0 && row < visibleEntries.count else { return }
        let entry = visibleEntries[row]

        if entry.isDirectory {
            currentPath = entry.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            refreshVisibleEntries()
        } else {
            preview(entry)
        }
    }

    @objc private func goUp() {
        guard !currentPath.isEmpty else { return }
        if let slash = currentPath.lastIndex(of: "/") {
            currentPath = String(currentPath[..<slash])
        } else {
            currentPath = ""
        }
        refreshVisibleEntries()
    }

    private func preview(_ entry: ArchiveEntry) {
        guard let backend, let archiveURL else { return }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("SevenZipMacPreview", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        Task {
            do {
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                setBusy(true, message: "Extracting preview...")
                try await backend.extract(archive: archiveURL, entries: [entry], destination: destination, password: nil, overwrite: true)
                setBusy(false, message: "Opened \(entry.name)")
                NSWorkspace.shared.open(destination.appendingPathComponent(entry.path))
            } catch {
                setBusy(false, message: "Preview failed")
                Dialogs.showError(error, in: window)
            }
        }
    }
}

extension MainWindowController: NSTableViewDataSource, NSTableViewDelegate {
    nonisolated func numberOfRows(in tableView: NSTableView) -> Int {
        MainActor.assumeIsolated { visibleEntries.count }
    }

    nonisolated func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        MainActor.assumeIsolated {
            guard row >= 0 && row < visibleEntries.count, let tableColumn else { return nil }
            let entry = visibleEntries[row]
            let identifier = tableColumn.identifier
            let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
            cell.identifier = identifier

            let field: NSTextField
            if let existing = cell.textField {
                field = existing
            } else {
                field = NSTextField(labelWithString: "")
                field.lineBreakMode = .byTruncatingMiddle
                field.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(field)
                cell.textField = field
                NSLayoutConstraint.activate([
                    field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                    field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                    field.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
            }

            switch identifier.rawValue {
            case "name":
                field.stringValue = entry.isDirectory ? "\(entry.name)/" : entry.name
            case "size":
                field.stringValue = entry.isDirectory ? "" : DisplayFormatters.bytes(entry.size)
            case "packed":
                field.stringValue = DisplayFormatters.bytes(entry.packedSize)
            case "modified":
                field.stringValue = DisplayFormatters.date(entry.modified)
            case "attributes":
                field.stringValue = entry.attributes ?? ""
            case "encrypted":
                field.stringValue = entry.encrypted ? "Yes" : ""
            default:
                field.stringValue = ""
            }
            return cell
        }
    }
}

extension MainWindowController: NSToolbarDelegate {
    nonisolated func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.openArchive, .addFiles, .extract, .testArchive, .deleteEntry, .password, .backendSettings, .flexibleSpace]
    }

    nonisolated func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.openArchive, .addFiles, .extract, .testArchive, .deleteEntry, .flexibleSpace, .password, .backendSettings]
    }

    nonisolated func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        MainActor.assumeIsolated {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            switch itemIdentifier {
            case .openArchive:
                configure(item, label: "Open", image: "folder", action: #selector(openArchive))
            case .addFiles:
                configure(item, label: "Add", image: "plus.square", action: #selector(addFiles))
            case .extract:
                configure(item, label: "Extract", image: "arrow.down.doc", action: #selector(extractSelected))
            case .testArchive:
                configure(item, label: "Test", image: "checkmark.seal", action: #selector(testArchive))
            case .deleteEntry:
                configure(item, label: "Delete", image: "trash", action: #selector(deleteSelected))
            case .password:
                configure(item, label: "Password", image: "lock", action: #selector(askPasswordAndReload))
            case .backendSettings:
                configure(item, label: "Backend", image: "gearshape", action: #selector(showBackendSettings))
            default:
                return nil
            }
            return item
        }
    }

    private func configure(_ item: NSToolbarItem, label: String, image: String, action: Selector) {
        item.label = label
        item.paletteLabel = label
        item.toolTip = label
        item.image = NSImage(systemSymbolName: image, accessibilityDescription: label)
        item.target = self
        item.action = action
    }
}

private extension NSToolbarItem.Identifier {
    static let openArchive = NSToolbarItem.Identifier("OpenArchive")
    static let addFiles = NSToolbarItem.Identifier("AddFiles")
    static let extract = NSToolbarItem.Identifier("Extract")
    static let testArchive = NSToolbarItem.Identifier("TestArchive")
    static let deleteEntry = NSToolbarItem.Identifier("DeleteEntry")
    static let password = NSToolbarItem.Identifier("Password")
    static let backendSettings = NSToolbarItem.Identifier("BackendSettings")
}
