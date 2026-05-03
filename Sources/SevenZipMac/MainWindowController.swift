import AppKit

@MainActor
final class MainWindowController: NSWindowController {
    private let pathField = NSTextField(labelWithString: "No archive open")
    private let statusField = NSTextField(labelWithString: "Detecting backend...")
    private let progress = NSProgressIndicator()
    private let tableView = ArchiveTableView()
    private let scrollView = NSScrollView()

    private var backend: SevenZipBackend?
    private var archiveURL: URL?
    private var archivePassword: String?
    private var currentDirectoryURL: URL?
    private var allEntries: [ArchiveEntry] = []
    private var currentPath = ""
    private var visibleEntries: [ArchiveEntry] = []
    private var activeSortDescriptors: [NSSortDescriptor] = [NSSortDescriptor(key: "name", ascending: true)]
    private var previewDirectories: [URL] = []
    private static let archiveExtensions: Set<String> = ["7z", "zip", "rar", "tar", "gz", "tgz", "bz2", "xz", "zst", "cab", "iso", "dmg"]

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
        window.delegate = self
        window.toolbar = makeToolbar()
        installMainMenu()

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
        tableView.dropTarget = self
        tableView.menu = makeContextMenu()
        tableView.registerForDraggedTypes([.fileURL])

        addColumn("name", title: "Name", width: 390)
        addColumn("size", title: "Size", width: 110)
        addColumn("packed", title: "Packed", width: 110)
        addColumn("modified", title: "Modified", width: 180)
        addColumn("attributes", title: "Attr", width: 80)
        addColumn("encrypted", title: "Encrypted", width: 90)
        tableView.sortDescriptors = activeSortDescriptors

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
    }

    private func addColumn(_ identifier: String, title: String, width: CGFloat) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title
        column.width = width
        column.sortDescriptorPrototype = NSSortDescriptor(key: identifier, ascending: true)
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

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit 7-Zip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileItem = NSMenuItem()
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        fileItem.submenu = fileMenu
        addMenuItem("Open Archive...", action: #selector(openArchivePanel), key: "o", modifiers: [.command], to: fileMenu)
        addMenuItem("Add Files...", action: #selector(addFiles), key: "n", modifiers: [.command], to: fileMenu)
        fileMenu.addItem(.separator())
        addMenuItem("Extract...", action: #selector(extractSelected), key: "e", modifiers: [.command], to: fileMenu)
        addMenuItem("Test Archive", action: #selector(testArchive), key: "t", modifiers: [.command], to: fileMenu)
        addMenuItem("Archive Password...", action: #selector(askPasswordAndReload), key: "l", modifiers: [.command], to: fileMenu)

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu
        addMenuItem("Rename", action: #selector(renameSelected), key: "\r", modifiers: [], to: editMenu)
        addMenuItem("Delete", action: #selector(deleteSelected), key: "\u{8}", modifiers: [], to: editMenu)

        let navigateItem = NSMenuItem()
        mainMenu.addItem(navigateItem)
        let navigateMenu = NSMenu(title: "Navigate")
        navigateItem.submenu = navigateMenu
        addMenuItem("Open Selected", action: #selector(openSelectedEntry), key: "\r", modifiers: [.command], to: navigateMenu)
        addMenuItem("Up", action: #selector(goUp), key: String(UnicodeScalar(NSUpArrowFunctionKey)!), modifiers: [.command], to: navigateMenu)

        let settingsItem = NSMenuItem()
        mainMenu.addItem(settingsItem)
        let settingsMenu = NSMenu(title: "Settings")
        settingsItem.submenu = settingsMenu
        addMenuItem("Backend...", action: #selector(showBackendSettings), key: ",", modifiers: [.command], to: settingsMenu)

        NSApp.mainMenu = mainMenu
    }

    @discardableResult
    private func addMenuItem(
        _ title: String,
        action: Selector,
        key: String,
        modifiers: NSEvent.ModifierFlags,
        to menu: NSMenu
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        menu.addItem(item)
        return item
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu(title: "Archive")
        addMenuItem("Open", action: #selector(openSelectedEntry), key: "", modifiers: [], to: menu)
        addMenuItem("Extract...", action: #selector(extractSelected), key: "", modifiers: [], to: menu)
        addMenuItem("Rename...", action: #selector(renameSelected), key: "", modifiers: [], to: menu)
        addMenuItem("Delete", action: #selector(deleteSelected), key: "", modifiers: [], to: menu)
        menu.addItem(.separator())
        addMenuItem("Test Archive", action: #selector(testArchive), key: "", modifiers: [], to: menu)
        addMenuItem("Password...", action: #selector(askPasswordAndReload), key: "", modifiers: [], to: menu)
        addMenuItem("Backend...", action: #selector(showBackendSettings), key: "", modifiers: [], to: menu)
        return menu
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
                archivePassword = password
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
        guard archiveURL != nil else {
            tableView.reloadData()
            return
        }

        let children = allEntries.filter { entry in
            if currentPath.isEmpty {
                return entry.parentPath.isEmpty
            }
            return entry.parentPath == currentPath
        }

        visibleEntries = sortedEntries(children)
        pathField.stringValue = archiveURL.map { "\($0.path)\(currentPath.isEmpty ? "" : " / \(currentPath)")" } ?? "No archive open"
        tableView.reloadData()
    }

    private func sortedEntries(_ entries: [ArchiveEntry]) -> [ArchiveEntry] {
        let descriptors = activeSortDescriptors.isEmpty ? [NSSortDescriptor(key: "name", ascending: true)] : activeSortDescriptors
        return entries.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
            for descriptor in descriptors {
                let result = compare(lhs, rhs, using: descriptor)
                if result != .orderedSame {
                    return descriptor.ascending ? result == .orderedAscending : result == .orderedDescending
                }
            }
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func compare(_ lhs: ArchiveEntry, _ rhs: ArchiveEntry, using descriptor: NSSortDescriptor) -> ComparisonResult {
        switch descriptor.key {
        case "size":
            return compareOptional(lhs.size, rhs.size)
        case "packed":
            return compareOptional(lhs.packedSize, rhs.packedSize)
        case "modified":
            return compareOptional(lhs.modified, rhs.modified)
        case "attributes":
            return (lhs.attributes ?? "").localizedStandardCompare(rhs.attributes ?? "")
        case "encrypted":
            return compareBool(lhs.encrypted, rhs.encrypted)
        default:
            return lhs.name.localizedStandardCompare(rhs.name)
        }
    }

    private func compareOptional<T: Comparable>(_ lhs: T?, _ rhs: T?) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            if lhs == rhs { return .orderedSame }
            return lhs < rhs ? .orderedAscending : .orderedDescending
        case (nil, nil):
            return .orderedSame
        case (nil, _?):
            return .orderedAscending
        case (_?, nil):
            return .orderedDescending
        }
    }

    private func compareBool(_ lhs: Bool, _ rhs: Bool) -> ComparisonResult {
        if lhs == rhs { return .orderedSame }
        return lhs ? .orderedDescending : .orderedAscending
    }

    private func showDirectory(_ url: URL) {
        archiveURL = nil
        archivePassword = nil
        currentDirectoryURL = url
        allEntries = []
        currentPath = ""

        do {
            let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey]
            let urls = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsPackageDescendants]
            )

            let entries = urls.compactMap { itemURL in
                let values = try? itemURL.resourceValues(forKeys: keys)
                let isDirectory = values?.isDirectory == true
                return ArchiveEntry(
                    path: itemURL.path,
                    size: isDirectory ? nil : Int64(values?.fileSize ?? 0),
                    packedSize: nil,
                    modified: values?.contentModificationDate,
                    attributes: isDirectory ? "D" : "A",
                    encrypted: false,
                    isDirectory: isDirectory
                )
            }
            visibleEntries = sortedEntries(entries)

            pathField.stringValue = url.path
            tableView.reloadData()
            setBusy(false, message: "\(visibleEntries.count) items in \(url.path)")
        } catch {
            visibleEntries = []
            pathField.stringValue = url.path
            tableView.reloadData()
            setBusy(false, message: "Cannot open folder")
            Dialogs.showError(error, in: window)
        }
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

    @objc func openArchivePanel() {
        let panel = NSOpenPanel()
        panel.title = "Open Archive"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openArchive(at: url)
    }

    func openArchive(at url: URL) {
        currentDirectoryURL = nil
        archivePassword = nil
        archiveURL = url
        reloadArchive()
    }

    @objc func askPasswordAndReload() {
        guard archiveURL != nil else {
            Dialogs.showError(AppError.noArchiveSelected, in: window)
            return
        }
        if let password = Dialogs.askPassword(message: "Archive password", in: window) {
            reloadArchive(password: password)
        }
    }

    @objc func extractSelected() {
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
        guard let options = Dialogs.askExtractOptions(destination: destination, defaultPassword: archivePassword, in: window) else { return }
        if options.password?.isEmpty == false {
            archivePassword = options.password
        }

        Task {
            do {
                setBusy(true, message: "Extracting...")
                try await backend.extract(
                    archive: archiveURL,
                    entries: entries,
                    destination: options.destination,
                    password: options.password,
                    overwrite: options.overwrite
                )
                setBusy(false, message: "Extracted to \(options.destination.path)")
                if options.openDestination {
                    NSWorkspace.shared.activateFileViewerSelecting([options.destination])
                }
            } catch {
                setBusy(false, message: "Extract failed")
                Dialogs.showError(error, in: window)
            }
        }
    }

    @objc func addFiles() {
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
        guard let options = Dialogs.askAddOptions(archive: archive, in: window) else { return }

        Task {
            do {
                setBusy(true, message: "Creating \(options.archive.lastPathComponent)...")
                try await backend.add(
                    items: openPanel.urls,
                    archive: options.archive,
                    format: options.format,
                    level: options.level,
                    password: options.password,
                    encryptHeaders: options.encryptHeaders
                )
                currentDirectoryURL = nil
                archivePassword = options.password
                archiveURL = options.archive
                allEntries = try await backend.list(archive: options.archive, password: options.password)
                refreshVisibleEntries()
                setBusy(false, message: "Created \(options.archive.lastPathComponent)")
            } catch {
                setBusy(false, message: "Add failed")
                Dialogs.showError(error, in: window)
            }
        }
    }

    @objc func testArchive() {
        guard let backend, let archiveURL else {
            Dialogs.showError(archiveURL == nil ? AppError.noArchiveSelected : AppError.noBackend, in: window)
            return
        }
        let password = passwordForOperation(message: "Test password")
        guard password != nil || archivePassword != nil else { return }
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

    @objc func deleteSelected() {
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
                allEntries = try await backend.list(archive: archiveURL, password: archivePassword)
                refreshVisibleEntries()
                setBusy(false, message: "Deleted \(entries.count) entries")
            } catch {
                setBusy(false, message: "Delete failed")
                Dialogs.showError(error, in: window)
            }
        }
    }

    @objc func renameSelected() {
        guard let backend, let archiveURL else {
            Dialogs.showError(archiveURL == nil ? AppError.noArchiveSelected : AppError.noBackend, in: window)
            return
        }
        let entries = selectedEntries()
        guard entries.count == 1, let entry = entries.first else { return }

        let alert = NSAlert()
        alert.messageText = "Rename Entry"
        alert.informativeText = entry.path
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 520, height: 24))
        field.stringValue = entry.path
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let newPath = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newPath.isEmpty, newPath != entry.path else { return }

        Task {
            do {
                setBusy(true, message: "Renaming \(entry.name)...")
                try await backend.rename(archive: archiveURL, entry: entry, to: newPath)
                allEntries = try await backend.list(archive: archiveURL, password: archivePassword)
                refreshVisibleEntries()
                setBusy(false, message: "Renamed \(entry.name)")
            } catch {
                setBusy(false, message: "Rename failed")
                Dialogs.showError(error, in: window)
            }
        }
    }

    @objc func showBackendSettings() {
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
        report["registeredDragTypes"] = tableView.registeredDraggedTypes.map(\.rawValue)
        report["hasDropTarget"] = tableView.dropTarget != nil
        report["previewDirectoryCount"] = previewDirectories.count
        report["mainMenuItems"] = NSApp.mainMenu?.items.compactMap { item in
            item.submenu?.items.map(\.title)
        } ?? []
        report["contextMenuItems"] = tableView.menu?.items.map(\.title) ?? []
        report["pathText"] = pathField.stringValue
        report["statusText"] = statusField.stringValue
        report["tableColumnCount"] = tableView.tableColumns.count
        report["tableColumns"] = tableView.tableColumns.map(\.title)
        report["sortDescriptors"] = tableView.sortDescriptors.map { descriptor in
            [
                "key": descriptor.key ?? "",
                "ascending": descriptor.ascending
            ]
        }
        report["visibleEntryCount"] = visibleEntries.count
        report["backendName"] = backend?.info.name ?? ""
        report["backendPath"] = backend?.info.executableURL.path ?? ""
        report["backendVersion"] = backend?.info.version ?? ""
        report["archivePath"] = archiveURL?.path ?? ""
        report["directoryPath"] = currentDirectoryURL?.path ?? ""
        report["allEntryCount"] = allEntries.count
        report["visibleEntryNames"] = visibleEntries.map(\.name)
        report["visibleEntryPaths"] = visibleEntries.map(\.path)
        return report
    }

    func smokeTestOpenArchive(_ url: URL, password: String? = nil) async throws {
        guard let backend else {
            throw AppError.noBackend
        }

        archiveURL = url
        currentDirectoryURL = nil
        archivePassword = password
        setBusy(true, message: "Listing \(url.lastPathComponent)...")
        allEntries = try await backend.list(archive: url, password: password)
        currentPath = ""
        refreshVisibleEntries()
        setBusy(false, message: "\(allEntries.count) entries loaded from \(url.lastPathComponent)")
    }

    func smokeTestNavigate(to path: String) throws {
        let normalized = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard allEntries.contains(where: { entry in
            entry.isDirectory && entry.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == normalized
        }) else {
            throw NSError(
                domain: "SevenZipMacSmokeTest",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Archive folder not found: \(path)"]
            )
        }

        currentPath = normalized
        refreshVisibleEntries()
    }

    func smokeTestGoUp() {
        goUp()
    }

    func smokeTestSort(column: String, ascending: Bool) {
        let descriptor = NSSortDescriptor(key: column, ascending: ascending)
        tableView.sortDescriptors = [descriptor]
        activeSortDescriptors = [descriptor]
        if archiveURL == nil, let currentDirectoryURL {
            showDirectory(currentDirectoryURL)
        } else {
            refreshVisibleEntries()
        }
    }

    @objc func openSelectedEntry() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0 && row < visibleEntries.count else { return }
        let entry = visibleEntries[row]

        if archiveURL == nil {
            openFileSystemEntry(entry)
        } else if entry.isDirectory {
            currentPath = entry.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            refreshVisibleEntries()
        } else {
            preview(entry)
        }
    }

    @objc func goUp() {
        if currentPath.isEmpty, let archiveURL {
            showDirectory(archiveURL.deletingLastPathComponent())
            return
        }

        if archiveURL == nil, let currentDirectoryURL {
            let parent = currentDirectoryURL.deletingLastPathComponent()
            if parent.path != currentDirectoryURL.path {
                showDirectory(parent)
            }
            return
        }

        if let slash = currentPath.lastIndex(of: "/") {
            currentPath = String(currentPath[..<slash])
        } else {
            currentPath = ""
        }
        refreshVisibleEntries()
    }

    private func openFileSystemEntry(_ entry: ArchiveEntry) {
        let url = URL(fileURLWithPath: entry.path)
        if entry.isDirectory {
            showDirectory(url)
        } else if Self.archiveExtensions.contains(url.pathExtension.lowercased()) {
            openArchive(at: url)
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    private func passwordForOperation(message: String) -> String? {
        if let archivePassword {
            return archivePassword
        }
        let password = Dialogs.askPassword(message: message, defaultValue: archivePassword, in: window)
        if password?.isEmpty == false {
            archivePassword = password
        }
        return password
    }

    func handleDroppedFileURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        if archiveURL != nil {
            addDroppedItems(urls)
            return
        }

        if let archive = urls.first(where: { Self.archiveExtensions.contains($0.pathExtension.lowercased()) }) {
            openArchive(at: archive)
        } else if urls.count == 1, urls[0].hasDirectoryPath {
            showDirectory(urls[0])
        }
    }

    private func addDroppedItems(_ urls: [URL]) {
        guard let backend, let archiveURL else { return }

        Task {
            do {
                setBusy(true, message: "Adding \(urls.count) item\(urls.count == 1 ? "" : "s")...")
                try await backend.add(
                    items: urls,
                    archive: archiveURL,
                    format: archiveURL.pathExtension.isEmpty ? "7z" : archiveURL.pathExtension,
                    level: 5,
                    password: archivePassword,
                    encryptHeaders: archivePassword?.isEmpty == false
                )
                allEntries = try await backend.list(archive: archiveURL, password: archivePassword)
                refreshVisibleEntries()
                setBusy(false, message: "Added \(urls.count) item\(urls.count == 1 ? "" : "s")")
            } catch {
                setBusy(false, message: "Drop add failed")
                Dialogs.showError(error, in: window)
            }
        }
    }

    private func preview(_ entry: ArchiveEntry) {
        guard let backend, let archiveURL else { return }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("SevenZipMacPreview", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        Task {
            do {
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                previewDirectories.append(destination)
                setBusy(true, message: "Extracting preview...")
                try await backend.extract(archive: archiveURL, entries: [entry], destination: destination, password: archivePassword, overwrite: true)
                setBusy(false, message: "Opened \(entry.name)")
                NSWorkspace.shared.open(destination.appendingPathComponent(entry.path))
            } catch {
                setBusy(false, message: "Preview failed")
                Dialogs.showError(error, in: window)
            }
        }
    }

    private func cleanupPreviewDirectories() {
        let directories = previewDirectories
        previewDirectories.removeAll()
        for directory in directories {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

extension MainWindowController: NSTableViewDataSource, NSTableViewDelegate {
    nonisolated func numberOfRows(in tableView: NSTableView) -> Int {
        MainActor.assumeIsolated { visibleEntries.count }
    }

    nonisolated func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        return MainActor.assumeIsolated {
            activeSortDescriptors = tableView.sortDescriptors
            if archiveURL == nil, let currentDirectoryURL {
                showDirectory(currentDirectoryURL)
            } else {
                refreshVisibleEntries()
            }
        }
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

extension MainWindowController: NSMenuItemValidation {
    nonisolated func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let action = menuItem.action
        return MainActor.assumeIsolated {
            switch action {
            case #selector(openArchivePanel), #selector(showBackendSettings):
                return true
            case #selector(addFiles):
                return backend != nil
            case #selector(openSelectedEntry):
                return tableView.selectedRowIndexes.count == 1
            case #selector(goUp):
                if archiveURL != nil { return true }
                guard let currentDirectoryURL else { return false }
                return currentDirectoryURL.deletingLastPathComponent().path != currentDirectoryURL.path
            case #selector(extractSelected):
                return backend != nil && archiveURL != nil
            case #selector(testArchive), #selector(askPasswordAndReload):
                return backend != nil && archiveURL != nil
            case #selector(renameSelected):
                return backend != nil && archiveURL != nil && tableView.selectedRowIndexes.count == 1
            case #selector(deleteSelected):
                return backend != nil && archiveURL != nil && !tableView.selectedRowIndexes.isEmpty
            default:
                return true
            }
        }
    }
}

extension MainWindowController: NSWindowDelegate {
    nonisolated func windowWillClose(_ notification: Notification) {
        MainActor.assumeIsolated {
            cleanupPreviewDirectories()
        }
    }
}

extension MainWindowController: NSToolbarDelegate {
    nonisolated func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.openArchive, .addFiles, .extract, .testArchive, .renameEntry, .deleteEntry, .password, .backendSettings, .flexibleSpace]
    }

    nonisolated func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.openArchive, .addFiles, .extract, .testArchive, .renameEntry, .deleteEntry, .flexibleSpace, .password, .backendSettings]
    }

    nonisolated func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        MainActor.assumeIsolated {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            switch itemIdentifier {
            case .openArchive:
                configure(item, label: "Open", image: "folder", action: #selector(openArchivePanel))
            case .addFiles:
                configure(item, label: "Add", image: "plus.square", action: #selector(addFiles))
            case .extract:
                configure(item, label: "Extract", image: "arrow.down.doc", action: #selector(extractSelected))
            case .testArchive:
                configure(item, label: "Test", image: "checkmark.seal", action: #selector(testArchive))
            case .renameEntry:
                configure(item, label: "Rename", image: "pencil", action: #selector(renameSelected))
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
    static let renameEntry = NSToolbarItem.Identifier("RenameEntry")
    static let deleteEntry = NSToolbarItem.Identifier("DeleteEntry")
    static let password = NSToolbarItem.Identifier("Password")
    static let backendSettings = NSToolbarItem.Identifier("BackendSettings")
}

private final class ArchiveTableView: NSTableView {
    weak var dropTarget: MainWindowController?

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: point)
        if clickedRow >= 0, !selectedRowIndexes.contains(clickedRow) {
            selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
        }
        return super.menu(for: event)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        fileURLs(from: sender.draggingPasteboard).isEmpty ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = fileURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        dropTarget?.handleDroppedFileURLs(urls)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty else {
            super.keyDown(with: event)
            return
        }

        switch event.charactersIgnoringModifiers {
        case "\r", "\u{3}":
            if let doubleAction, let target {
                NSApp.sendAction(doubleAction, to: target, from: self)
            } else {
                super.keyDown(with: event)
            }
        case "\u{7F}", "\u{8}":
            if let target {
                NSApp.sendAction(#selector(MainWindowController.deleteSelected), to: target, from: self)
            } else {
                super.keyDown(with: event)
            }
        default:
            super.keyDown(with: event)
        }
    }

    private func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let classes = [NSURL.self]
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        return pasteboard.readObjects(forClasses: classes, options: options) as? [URL] ?? []
    }
}
