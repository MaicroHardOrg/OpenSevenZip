import AppKit

@MainActor
enum Dialogs {
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

    static func askPassword(message: String, in window: NSWindow?) -> String? {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = "Leave blank if the archive is not encrypted."
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = "Password"
        alert.accessoryView = field

        let response: NSApplication.ModalResponse
        if let window {
            response = alert.runSheetModal(for: window)
        } else {
            response = alert.runModal()
        }
        return response == .alertFirstButtonReturn ? field.stringValue : nil
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
