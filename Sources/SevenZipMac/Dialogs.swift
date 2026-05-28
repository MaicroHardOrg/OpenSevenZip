import AppKit

@MainActor
enum Dialogs {
    struct ExtractOptions: Sendable {
        var destination: URL
        var password: String?
        var overwrite: Bool
        var openDestination: Bool
    }

    struct AddOptions: Sendable {
        var archive: URL
        var format: String
        var level: Int
        var password: String?
        var encryptHeaders: Bool
        var volumeSize: String
        var includePatterns: String
        var excludePatterns: String
    }

    static func showError(_ error: Error, in window: NSWindow?) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = L10n.string("app.operationFailed")
        alert.informativeText = String(describing: error)
        alert.addButton(withTitle: L10n.string("button.ok"))
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    static func showInfo(_ message: String, detail: String = "", in window: NSWindow?) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: L10n.string("button.ok"))
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    static func askPassword(message: String, defaultValue: String? = nil, in window: NSWindow?) -> String? {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = L10n.string("password.blankHint")
        alert.addButton(withTitle: L10n.string("button.continue"))
        alert.addButton(withTitle: L10n.string("button.cancel"))

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = L10n.string("password.label")
        field.stringValue = defaultValue ?? ""
        alert.accessoryView = field

        let response: NSApplication.ModalResponse
        if let window {
            response = alert.runSheetModal(for: window)
        } else {
            response = alert.runModal()
        }
        return response == .alertFirstButtonReturn ? field.stringValue : nil
    }

    static func askExtractOptions(destination: URL, defaultPassword: String?, in window: NSWindow?) -> ExtractOptions? {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 280),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = L10n.string("extract.title")
        panel.isReleasedWhenClosed = false

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        root.translatesAutoresizingMaskIntoConstraints = false

        let destinationLabel = wrappingLabel(destination.path, width: 560)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 26))
        passwordField.placeholderString = L10n.string("password.label")
        passwordField.stringValue = defaultPassword ?? ""

        let overwriteButton = NSButton(checkboxWithTitle: L10n.string("extract.overwrite"), target: nil, action: nil)
        overwriteButton.lineBreakMode = .byTruncatingTail
        overwriteButton.state = .on

        let openDestinationButton = NSButton(checkboxWithTitle: L10n.string("extract.showDestination"), target: nil, action: nil)
        openDestinationButton.lineBreakMode = .byTruncatingTail
        openDestinationButton.state = .on

        stack.addArrangedSubview(formRow(label: L10n.string("password.label"), control: passwordField))
        stack.addArrangedSubview(overwriteButton)
        stack.addArrangedSubview(openDestinationButton)

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false
        let spacer = NSView()
        let cancelButton = NSButton(title: L10n.string("button.cancel"), target: nil, action: nil)
        let extractButton = NSButton(title: L10n.string("toolbar.extract"), target: nil, action: nil)
        let cancelTarget = ModalButtonTarget(response: .cancel)
        let extractTarget = ModalButtonTarget(response: .OK)
        for (button, target) in [(cancelButton, cancelTarget), (extractButton, extractTarget)] {
            button.bezelStyle = .rounded
            button.target = target
            button.action = #selector(ModalButtonTarget.closeModal(_:))
        }
        cancelButton.keyEquivalent = "\u{1b}"
        extractButton.keyEquivalent = "\r"
        buttons.addArrangedSubview(cancelButton)
        buttons.addArrangedSubview(spacer)
        buttons.addArrangedSubview(extractButton)

        root.addArrangedSubview(destinationLabel)
        root.addArrangedSubview(stack)
        root.addArrangedSubview(buttons)

        let contentView = NSView()
        panel.contentView = contentView
        contentView.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stack.widthAnchor.constraint(equalToConstant: 560),
            spacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 360)
        ])

        if let window {
            panel.centerRelative(to: window)
        } else {
            panel.center()
        }
        panel.makeKeyAndOrderFront(nil)
        let response = NSApp.runModal(for: panel)
        panel.orderOut(nil)
        _ = [cancelTarget, extractTarget]

        guard response == .OK else { return nil }
        return ExtractOptions(
            destination: destination,
            password: passwordField.stringValue,
            overwrite: overwriteButton.state == .on,
            openDestination: openDestinationButton.state == .on
        )
    }

    static func askAddOptions(archive: URL, availableFormats: [String], in window: NSWindow?) -> AddOptions? {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 430),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = L10n.string("add.createPanel")
        panel.isReleasedWhenClosed = false

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        root.translatesAutoresizingMaskIntoConstraints = false

        let formatPopup = NSPopUpButton(frame: .zero)
        let formats = availableFormats.isEmpty ? ["7z"] : availableFormats
        formatPopup.addItems(withTitles: formats)
        let extensionFormat = archive.pathExtension.lowercased()
        formatPopup.selectItem(withTitle: formats.contains(extensionFormat) ? extensionFormat : formats[0])

        let levelPopup = NSPopUpButton(frame: .zero)
        let levels = [
            "\(L10n.string("add.method.store")) (0)",
            "\(L10n.string("add.method.fastest")) (1)",
            "\(L10n.string("add.method.fast")) (3)",
            "\(L10n.string("add.method.normal")) (5)",
            "\(L10n.string("add.method.maximum")) (7)",
            "\(L10n.string("add.method.ultra")) (9)"
        ]
        levelPopup.addItems(withTitles: levels)
        levelPopup.selectItem(withTitle: "\(L10n.string("add.method.normal")) (5)")

        let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        passwordField.placeholderString = L10n.string("password.label")

        let encryptHeadersButton = NSButton(checkboxWithTitle: L10n.string("add.encryptFileNamesSupported"), target: nil, action: nil)
        encryptHeadersButton.state = .on

        let volumeField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        volumeField.placeholderString = L10n.string("add.splitPlaceholder")

        let includeField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        includeField.placeholderString = L10n.string("add.includePlaceholder")

        let excludeField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        excludeField.placeholderString = L10n.string("add.excludePlaceholder")

        let pathLabel = wrappingLabel(archive.path, width: 560)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(formRow(label: L10n.string("add.archiveFormat"), control: formatPopup))
        stack.addArrangedSubview(formRow(label: L10n.string("add.compressionLevel"), control: levelPopup))
        stack.addArrangedSubview(formRow(label: L10n.string("password.label"), control: passwordField))
        stack.addArrangedSubview(formRow(label: "", control: encryptHeadersButton))
        stack.addArrangedSubview(formRow(label: L10n.string("split.toVolumesBytes"), control: volumeField))
        stack.addArrangedSubview(formRow(label: L10n.string("add.include"), control: includeField))
        stack.addArrangedSubview(formRow(label: L10n.string("add.exclude"), control: excludeField))

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false
        let spacer = NSView()
        let createButton = NSButton(title: L10n.string("button.create"), target: nil, action: nil)
        createButton.bezelStyle = .rounded
        createButton.keyEquivalent = "\r"
        let cancelButton = NSButton(title: L10n.string("button.cancel"), target: nil, action: nil)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        let createTarget = ModalButtonTarget(response: .OK)
        let cancelTarget = ModalButtonTarget(response: .cancel)
        createButton.target = createTarget
        createButton.action = #selector(ModalButtonTarget.closeModal(_:))
        cancelButton.target = cancelTarget
        cancelButton.action = #selector(ModalButtonTarget.closeModal(_:))
        buttons.addArrangedSubview(spacer)
        buttons.addArrangedSubview(cancelButton)
        buttons.addArrangedSubview(createButton)

        root.addArrangedSubview(pathLabel)
        root.addArrangedSubview(stack)
        root.addArrangedSubview(buttons)

        let contentView = NSView()
        panel.contentView = contentView
        contentView.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stack.widthAnchor.constraint(equalToConstant: 640),
            spacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 320)
        ])

        if let window {
            panel.centerRelative(to: window)
        } else {
            panel.center()
        }
        panel.makeKeyAndOrderFront(nil)
        let response = NSApp.runModal(for: panel)
        panel.orderOut(nil)
        _ = createTarget
        _ = cancelTarget

        guard response == .OK else { return nil }
        let selectedLevel = levelPopup.titleOfSelectedItem.flatMap { title -> Int? in
            guard let open = title.lastIndex(of: "("), let close = title.lastIndex(of: ")") else { return nil }
            return Int(title[title.index(after: open)..<close])
        } ?? 5

        return AddOptions(
            archive: archive,
            format: formatPopup.titleOfSelectedItem ?? "7z",
            level: selectedLevel,
            password: passwordField.stringValue,
            encryptHeaders: encryptHeadersButton.state == .on,
            volumeSize: volumeField.stringValue,
            includePatterns: includeField.stringValue,
            excludePatterns: excludeField.stringValue
        )
    }

    private static func formRow(label title: String, control: NSView) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: title)
        label.alignment = .right
        label.lineBreakMode = .byTruncatingTail
        row.addArrangedSubview(label)
        row.addArrangedSubview(control)

        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(equalToConstant: 170),
            control.widthAnchor.constraint(equalToConstant: 360)
        ])
        return row
    }

    private static func wrappingLabel(_ text: String, width: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.lineBreakMode = .byTruncatingMiddle
        label.maximumNumberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: width).isActive = true
        return label
    }
}

@MainActor
final class ModalButtonTarget: NSObject {
    private let response: NSApplication.ModalResponse

    init(response: NSApplication.ModalResponse) {
        self.response = response
    }

    @objc func closeModal(_ sender: Any?) {
        NSApp.stopModal(withCode: response)
        if let view = sender as? NSView {
            view.window?.orderOut(nil)
        }
    }
}

extension NSWindow {
    func centerRelative(to parent: NSWindow) {
        let parentFrame = parent.frame
        let x = parentFrame.midX - frame.width / 2
        let y = parentFrame.midY - frame.height / 2
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private extension NSAlert {
    func runSheetModal(for window: NSWindow) -> NSApplication.ModalResponse {
        var response: NSApplication.ModalResponse = .abort
        let semaphore = DispatchSemaphore(value: 0)
        beginSheetModal(for: window) {
            response = $0
            semaphore.signal()
        }
        while semaphore.wait(timeout: .now()) != .success {
            RunLoop.current.run(mode: .modalPanel, before: Date(timeIntervalSinceNow: 0.05))
        }
        return response
    }
}
