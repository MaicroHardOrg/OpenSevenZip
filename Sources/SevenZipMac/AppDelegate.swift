import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?
    private let smokeConfiguration = SmokeTest.configuration(from: CommandLine.arguments)
    private var pendingArchiveURL: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        showMainWindow()
        openLaunchArchiveIfNeeded()
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

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard let filename = filenames.first else { return }
        let url = URL(fileURLWithPath: filename)
        if mainWindowController == nil {
            pendingArchiveURL = url
            showMainWindow()
        }
        mainWindowController?.openArchive(at: url)
        sender.reply(toOpenOrPrint: .success)
    }

    private func openLaunchArchiveIfNeeded() {
        if let pendingArchiveURL {
            mainWindowController?.openArchive(at: pendingArchiveURL)
            self.pendingArchiveURL = nil
            return
        }

        guard smokeConfiguration == nil, let url = launchArchiveURL(from: CommandLine.arguments) else { return }
        mainWindowController?.openArchive(at: url)
    }

    private func launchArchiveURL(from arguments: [String]) -> URL? {
        var skipNext = false
        for argument in arguments.dropFirst() {
            if skipNext {
                skipNext = false
                continue
            }
            if argument == "--gui-smoke-report" || argument == "--gui-smoke-archive" {
                skipNext = true
                continue
            }
            if argument.hasPrefix("-") {
                continue
            }
            return URL(fileURLWithPath: argument)
        }
        return nil
    }

    private func scheduleSmokeTestIfNeeded() {
        guard let smokeConfiguration else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, let mainWindowController = self.mainWindowController else {
                NSApp.terminate(nil)
                return
            }

            Task { @MainActor in
                do {
                    if let archiveURL = smokeConfiguration.archiveURL {
                        try await mainWindowController.smokeTestOpenArchive(archiveURL)
                    }
                    if let navigationPath = smokeConfiguration.navigationPath {
                        try mainWindowController.smokeTestNavigate(to: navigationPath)
                    }
                    try SmokeTest.writeReport(for: mainWindowController, to: smokeConfiguration.reportURL)
                } catch {
                    let failureURL = smokeConfiguration.reportURL.deletingPathExtension().appendingPathExtension("error.txt")
                    try? String(describing: error).write(to: failureURL, atomically: true, encoding: .utf8)
                }
                NSApp.terminate(nil)
            }
        }
    }
}
