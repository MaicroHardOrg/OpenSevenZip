import AppKit

@MainActor
final class MainWindowController: NSWindowController {
    private let pathField = NSTextField(labelWithString: "No archive open")
    private let statusField = NSTextField(labelWithString: "Detecting backend...")
    private let progress = NSProgressIndicator()
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
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
    private var currentOperationTask: Task<Void, Never>?
    private var currentOperationID: UUID?
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
        cancelButton.target = self
        cancelButton.action = #selector(cancelCurrentOperation)
        cancelButton.bezelStyle = .rounded
        cancelButton.isHidden = true
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
        container.addArrangedSubview(cancelButton)
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

        runOperation(startMessage: "Listing \(archiveURL.lastPathComponent)...", failureMessage: "List failed") { [self] progress in
            allEntries = try await backend.list(archive: archiveURL, password: password, progress: progress)
            archivePassword = password
            currentPath = ""
            refreshVisibleEntries()
            return "\(allEntries.count) entries loaded from \(archiveURL.lastPathComponent)"
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
        cancelButton.isHidden = !(busy && currentOperationTask != nil)
    }

    private func runOperation(
        startMessage: String,
        failureMessage: String,
        operation: @escaping @MainActor (_ progress: @escaping BackendProgress) async throws -> String
    ) {
        currentOperationTask?.cancel()
        let operationID = UUID()
        currentOperationID = operationID
        let task = Task { @MainActor in
            guard currentOperationID == operationID else { return }
            setBusy(true, message: startMessage)
            let progress: BackendProgress = { [weak self] line in
                Task { @MainActor in
                    self?.updateOperationProgress(operationID, line: line)
                }
            }
            do {
                let successMessage = try await operation(progress)
                finishOperation(operationID, message: successMessage)
            } catch is CancellationError {
                finishOperation(operationID, message: "Cancelled")
            } catch {
                guard finishOperation(operationID, message: failureMessage) else { return }
                Dialogs.showError(error, in: window)
            }
        }
        currentOperationTask = task
        setBusy(true, message: startMessage)
    }

    private func updateOperationProgress(_ operationID: UUID, line: String) {
        guard currentOperationID == operationID else { return }
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        statusField.stringValue = trimmed
    }

    @discardableResult
    private func finishOperation(_ operationID: UUID, message: String) -> Bool {
        guard currentOperationID == operationID else { return false }
        currentOperationTask = nil
        currentOperationID = nil
        setBusy(false, message: message)
        return true
    }

    @objc private func cancelCurrentOperation() {
        currentOperationTask?.cancel()
        setBusy(true, message: "Cancelling...")
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
        guard backend.capabilities.contains(.extract) else {
            Dialogs.showError(AppError.unsupportedOperation("extract", backend.info.name), in: window)
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

        runOperation(startMessage: "Extracting...", failureMessage: "Extract failed") { progress in
            try await backend.extract(
                archive: archiveURL,
                entries: entries,
                destination: options.destination,
                password: options.password,
                overwrite: options.overwrite,
                progress: progress
            )
            if options.openDestination {
                NSWorkspace.shared.activateFileViewerSelecting([options.destination])
            }
            return "Extracted to \(options.destination.path)"
        }
    }

    @objc func addFiles() {
        guard let backend else {
            Dialogs.showError(AppError.noBackend, in: window)
            return
        }
        guard backend.capabilities.contains(.add) else {
            Dialogs.showError(AppError.unsupportedOperation("add", backend.info.name), in: window)
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
        guard let options = Dialogs.askAddOptions(archive: archive, availableFormats: backend.info.supportedCreateFormats, in: window) else { return }

        runOperation(startMessage: "Creating \(options.archive.lastPathComponent)...", failureMessage: "Add failed") { [self] progress in
            try await backend.add(items: openPanel.urls, options: options, progress: progress)
            currentDirectoryURL = nil
            archivePassword = options.password
            archiveURL = options.archive
            allEntries = try await backend.list(archive: options.archive, password: options.password, progress: progress)
            refreshVisibleEntries()
            return "Created \(options.archive.lastPathComponent)"
        }
    }

    @objc func testArchive() {
        guard let backend, let archiveURL else {
            Dialogs.showError(archiveURL == nil ? AppError.noArchiveSelected : AppError.noBackend, in: window)
            return
        }
        guard backend.capabilities.contains(.test) else {
            Dialogs.showError(AppError.unsupportedOperation("test", backend.info.name), in: window)
            return
        }
        let password = passwordForOperation(message: "Test password")
        guard password != nil || archivePassword != nil else { return }
        runOperation(startMessage: "Testing \(archiveURL.lastPathComponent)...", failureMessage: "Test failed") { [self] progress in
            try await backend.test(archive: archiveURL, password: password, progress: progress)
            Dialogs.showInfo("Archive test passed", detail: archiveURL.path, in: window)
            return "Test passed"
        }
    }

    @objc func deleteSelected() {
        guard let backend, let archiveURL else {
            Dialogs.showError(archiveURL == nil ? AppError.noArchiveSelected : AppError.noBackend, in: window)
            return
        }
        guard backend.capabilities.contains(.delete) else {
            Dialogs.showError(AppError.unsupportedOperation("delete", backend.info.name), in: window)
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

        runOperation(startMessage: "Deleting...", failureMessage: "Delete failed") { [self] progress in
            try await backend.delete(archive: archiveURL, entries: entries, progress: progress)
            allEntries = try await backend.list(archive: archiveURL, password: archivePassword, progress: progress)
            refreshVisibleEntries()
            return "Deleted \(entries.count) entries"
        }
    }

    @objc func renameSelected() {
        guard let backend, let archiveURL else {
            Dialogs.showError(archiveURL == nil ? AppError.noArchiveSelected : AppError.noBackend, in: window)
            return
        }
        guard backend.capabilities.contains(.rename) else {
            Dialogs.showError(AppError.unsupportedOperation("rename", backend.info.name), in: window)
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

        runOperation(startMessage: "Renaming \(entry.name)...", failureMessage: "Rename failed") { [self] progress in
            try await backend.rename(archive: archiveURL, entry: entry, to: newPath, progress: progress)
            allEntries = try await backend.list(archive: archiveURL, password: archivePassword, progress: progress)
            refreshVisibleEntries()
            return "Renamed \(entry.name)"
        }
    }

    @objc func showBackendSettings() {
        var pathValue = BackendLocator.customBackendPath
        let chooseResponse = NSApplication.ModalResponse(rawValue: 1001)
        let resetResponse = NSApplication.ModalResponse(rawValue: 1002)

        while true {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            panel.title = "Backend Settings"
            panel.isReleasedWhenClosed = false

            let stack = NSStackView()
            stack.orientation = .vertical
            stack.spacing = 12
            stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
            stack.translatesAutoresizingMaskIntoConstraints = false

            let heading = NSTextField(labelWithString: "Choose or reset the 7-Zip command-line backend.")
            heading.font = .boldSystemFont(ofSize: NSFont.systemFontSize)

            let currentBackend = wrappingSettingsLabel(backendSettingsSummary(), width: 660)

            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 520, height: 24))
            field.placeholderString = "Custom backend path, for example /usr/local/bin/7z"
            field.stringValue = pathValue

            let candidates = NSTextView()
            candidates.string = backendCandidateSummary()
            candidates.isEditable = false
            candidates.isSelectable = true
            candidates.drawsBackground = false
            candidates.textContainerInset = NSSize(width: 6, height: 6)
            candidates.textContainer?.widthTracksTextView = true

            let scrollView = NSScrollView()
            scrollView.hasVerticalScroller = true
            scrollView.borderType = .bezelBorder
            scrollView.documentView = candidates
            scrollView.translatesAutoresizingMaskIntoConstraints = false

            let buttons = NSStackView()
            buttons.orientation = .horizontal
            buttons.spacing = 10
            buttons.alignment = .centerY
            buttons.translatesAutoresizingMaskIntoConstraints = false
            let spacer = NSView()
            let saveButton = NSButton(title: "Save", target: nil, action: nil)
            let chooseButton = NSButton(title: "Choose...", target: nil, action: nil)
            let resetButton = NSButton(title: "Reset", target: nil, action: nil)
            let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
            let saveTarget = ModalButtonTarget(response: .OK)
            let chooseTarget = ModalButtonTarget(response: chooseResponse)
            let resetTarget = ModalButtonTarget(response: resetResponse)
            let cancelTarget = ModalButtonTarget(response: .cancel)
            for (button, target) in [
                (saveButton, saveTarget),
                (chooseButton, chooseTarget),
                (resetButton, resetTarget),
                (cancelButton, cancelTarget)
            ] {
                button.bezelStyle = .rounded
                button.target = target
                button.action = #selector(ModalButtonTarget.closeModal(_:))
            }
            saveButton.keyEquivalent = "\r"
            cancelButton.keyEquivalent = "\u{1b}"
            buttons.addArrangedSubview(spacer)
            buttons.addArrangedSubview(resetButton)
            buttons.addArrangedSubview(chooseButton)
            buttons.addArrangedSubview(cancelButton)
            buttons.addArrangedSubview(saveButton)

            stack.addArrangedSubview(heading)
            stack.addArrangedSubview(currentBackend)
            stack.addArrangedSubview(field)
            stack.addArrangedSubview(scrollView)
            stack.addArrangedSubview(buttons)

            let contentView = NSView()
            panel.contentView = contentView
            contentView.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                stack.topAnchor.constraint(equalTo: contentView.topAnchor),
                stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                field.widthAnchor.constraint(equalToConstant: 660),
                scrollView.widthAnchor.constraint(equalToConstant: 660),
                scrollView.heightAnchor.constraint(equalToConstant: 220),
                spacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 260)
            ])

            if let window {
                panel.centerRelative(to: window)
            } else {
                panel.center()
            }
            panel.makeKeyAndOrderFront(nil)
            let response = NSApp.runModal(for: panel)
            panel.orderOut(nil)
            _ = [saveTarget, chooseTarget, resetTarget, cancelTarget]

            switch response {
            case .OK:
                BackendLocator.setCustomBackendPath(field.stringValue)
                Task { await detectBackend() }
                return
            case chooseResponse:
                let panel = NSOpenPanel()
                panel.title = "Choose 7-Zip Backend"
                panel.canChooseFiles = true
                panel.canChooseDirectories = false
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    pathValue = url.path
                }
            case resetResponse:
                BackendLocator.resetCustomBackendPath()
                Task { await detectBackend() }
                return
            default:
                return
            }
        }
    }

    private func backendSettingsSummary() -> String {
        guard let backend else { return "Current: No active backend" }
        return """
        Current: \(backend.info.name)
        \(backend.info.executableURL.path)
        \(backend.info.version)
        Capabilities: \(capabilitySummary(backend.info.capabilities))
        Create formats: \(backend.info.supportedCreateFormats.joined(separator: ", "))
        """
    }

    private func backendCandidateSummary() -> String {
        BackendLocator.candidates().map { candidate in
            let exists = FileManager.default.isExecutableFile(atPath: candidate.url.path) ? "available" : "missing"
            let info = BackendInfo(name: candidate.name, executableURL: candidate.url, version: "", capabilities: candidate.capabilities)
            return "\(candidate.name): \(candidate.url.path) (\(exists), \(capabilitySummary(candidate.capabilities)), formats: \(info.supportedCreateFormats.joined(separator: ", ")))"
        }.joined(separator: "\n")
    }

    private func capabilitySummary(_ capabilities: BackendCapabilities) -> String {
        let labels = capabilities.labels
        return labels.isEmpty ? "None" : labels.joined(separator: ", ")
    }

    private func wrappingSettingsLabel(_ text: String, width: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.widthAnchor.constraint(equalToConstant: width).isActive = true
        return label
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
        report["hasCancelButton"] = cancelButton.superview != nil
        report["cancelButtonHidden"] = cancelButton.isHidden
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
        report["backendCapabilities"] = backend?.capabilities.labels ?? []
        report["backendCreateFormats"] = backend?.info.supportedCreateFormats ?? []
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
        guard backend.capabilities.contains(.add) else {
            Dialogs.showError(AppError.unsupportedOperation("add", backend.info.name), in: window)
            return
        }

        runOperation(
            startMessage: "Adding \(urls.count) item\(urls.count == 1 ? "" : "s")...",
            failureMessage: "Drop add failed"
        ) { [self] progress in
            let options = Dialogs.AddOptions(
                archive: archiveURL,
                format: archiveURL.pathExtension.isEmpty ? "7z" : archiveURL.pathExtension,
                level: 5,
                password: archivePassword,
                encryptHeaders: archivePassword?.isEmpty == false,
                volumeSize: "",
                includePatterns: "",
                excludePatterns: ""
            )
            try await backend.add(items: urls, options: options, progress: progress)
            allEntries = try await backend.list(archive: archiveURL, password: archivePassword, progress: progress)
            refreshVisibleEntries()
            return "Added \(urls.count) item\(urls.count == 1 ? "" : "s")"
        }
    }

    private func preview(_ entry: ArchiveEntry) {
        guard let backend, let archiveURL else { return }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("SevenZipMacPreview", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        runOperation(startMessage: "Extracting preview...", failureMessage: "Preview failed") { [self] progress in
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            previewDirectories.append(destination)
            try await backend.extract(archive: archiveURL, entries: [entry], destination: destination, password: archivePassword, overwrite: true, progress: progress)
            NSWorkspace.shared.open(destination.appendingPathComponent(entry.path))
            return "Opened \(entry.name)"
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
                return backend?.capabilities.contains(.add) == true
            case #selector(openSelectedEntry):
                return tableView.selectedRowIndexes.count == 1
            case #selector(goUp):
                if archiveURL != nil { return true }
                guard let currentDirectoryURL else { return false }
                return currentDirectoryURL.deletingLastPathComponent().path != currentDirectoryURL.path
            case #selector(extractSelected):
                return backend?.capabilities.contains(.extract) == true && archiveURL != nil
            case #selector(askPasswordAndReload):
                return backend?.capabilities.contains(.list) == true && archiveURL != nil
            case #selector(testArchive):
                return backend?.capabilities.contains(.test) == true && archiveURL != nil
            case #selector(renameSelected):
                return backend?.capabilities.contains(.rename) == true && archiveURL != nil && tableView.selectedRowIndexes.count == 1
            case #selector(deleteSelected):
                return backend?.capabilities.contains(.delete) == true && archiveURL != nil && !tableView.selectedRowIndexes.isEmpty
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
