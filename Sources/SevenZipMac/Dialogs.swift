import AppKit

@MainActor
enum Dialogs {
    struct ExtractOptions {
        var destination: URL
        var password: String?
        var overwrite: Bool
        var openDestination: Bool
    }

    struct AddOptions {
        var archive: URL
        var format: String
        var level: Int
        var password: String?
        var encryptHeaders: Bool
    }

    static func showError(_ error: Error, in window: NSWindow?) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "7-Zip operation failed"
        alert.informativeText = String(describing: error)
        alert.addButton(withTitle: "OK")
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
        alert.addButton(withTitle: "OK")
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    static func askPassword(message: String, defaultValue: String? = nil, in window: NSWindow?) -> String? {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = "Leave blank if the archive is not encrypted."
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = "Password"
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
        let alert = NSAlert()
        alert.messageText = "Extract Options"
        alert.informativeText = destination.path
        alert.addButton(withTitle: "Extract")
        alert.addButton(withTitle: "Cancel")

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        passwordField.placeholderString = "Password"
        passwordField.stringValue = defaultPassword ?? ""

        let overwriteButton = NSButton(checkboxWithTitle: "Overwrite existing files", target: nil, action: nil)
        overwriteButton.state = .on

        let openDestinationButton = NSButton(checkboxWithTitle: "Show destination after extraction", target: nil, action: nil)
        openDestinationButton.state = .on

        stack.addArrangedSubview(passwordField)
        stack.addArrangedSubview(overwriteButton)
        stack.addArrangedSubview(openDestinationButton)
        alert.accessoryView = stack
        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(equalToConstant: 380)
        ])

        let response: NSApplication.ModalResponse
        if let window {
            response = alert.runSheetModal(for: window)
        } else {
            response = alert.runModal()
        }

        guard response == .alertFirstButtonReturn else { return nil }
        return ExtractOptions(
            destination: destination,
            password: passwordField.stringValue,
            overwrite: overwriteButton.state == .on,
            openDestination: openDestinationButton.state == .on
        )
    }

    static func askAddOptions(archive: URL, in window: NSWindow?) -> AddOptions? {
        let alert = NSAlert()
        alert.messageText = "Archive Options"
        alert.informativeText = archive.path
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let stack = NSGridView()
        stack.rowSpacing = 8
        stack.columnSpacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let formatPopup = NSPopUpButton(frame: .zero)
        let formats = ["7z", "zip", "tar"]
        formatPopup.addItems(withTitles: formats)
        let extensionFormat = archive.pathExtension.lowercased()
        formatPopup.selectItem(withTitle: formats.contains(extensionFormat) ? extensionFormat : "7z")

        let levelPopup = NSPopUpButton(frame: .zero)
        let levels = ["Store (0)", "Fastest (1)", "Fast (3)", "Normal (5)", "Maximum (7)", "Ultra (9)"]
        levelPopup.addItems(withTitles: levels)
        levelPopup.selectItem(withTitle: "Normal (5)")

        let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        passwordField.placeholderString = "Password"

        let encryptHeadersButton = NSButton(checkboxWithTitle: "Encrypt file names when supported", target: nil, action: nil)
        encryptHeadersButton.state = .on

        stack.addRow(with: [NSTextField(labelWithString: "Format"), formatPopup])
        stack.addRow(with: [NSTextField(labelWithString: "Compression"), levelPopup])
        stack.addRow(with: [NSTextField(labelWithString: "Password"), passwordField])
        stack.addRow(with: [NSView(), encryptHeadersButton])
        alert.accessoryView = stack
        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(equalToConstant: 420)
        ])

        let response: NSApplication.ModalResponse
        if let window {
            response = alert.runSheetModal(for: window)
        } else {
            response = alert.runModal()
        }

        guard response == .alertFirstButtonReturn else { return nil }
        let selectedLevel = levelPopup.titleOfSelectedItem.flatMap { title -> Int? in
            guard let open = title.lastIndex(of: "("), let close = title.lastIndex(of: ")") else { return nil }
            return Int(title[title.index(after: open)..<close])
        } ?? 5

        return AddOptions(
            archive: archive,
            format: formatPopup.titleOfSelectedItem ?? "7z",
            level: selectedLevel,
            password: passwordField.stringValue,
            encryptHeaders: encryptHeadersButton.state == .on
        )
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
