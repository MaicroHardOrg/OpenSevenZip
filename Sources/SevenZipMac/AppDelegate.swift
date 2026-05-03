import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?
    private let smokeReportURL = SmokeTest.reportURL(from: CommandLine.arguments)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        showMainWindow()
        scheduleSmokeTestIfNeeded()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc func showMainWindow() {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        mainWindowController?.showWindow(nil)
    }

    private func scheduleSmokeTestIfNeeded() {
        guard let smokeReportURL else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, let mainWindowController = self.mainWindowController else {
                NSApp.terminate(nil)
                return
            }

            do {
                try SmokeTest.writeReport(for: mainWindowController, to: smokeReportURL)
            } catch {
                let failureURL = smokeReportURL.deletingPathExtension().appendingPathExtension("error.txt")
                try? String(describing: error).write(to: failureURL, atomically: true, encoding: .utf8)
            }
            NSApp.terminate(nil)
        }
    }
}
