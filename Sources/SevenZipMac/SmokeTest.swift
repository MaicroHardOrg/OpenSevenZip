import AppKit

enum SmokeTest {
    struct Configuration {
        var reportURL: URL
        var archiveURL: URL?
        var navigationPath: String?
        var password: String?
        var upCount: Int
        var sortColumn: String?
        var sortAscending: Bool
    }

    static func configuration(from arguments: [String]) -> Configuration? {
        guard let reportURL = reportURL(from: arguments) else { return nil }
        return Configuration(
            reportURL: reportURL,
            archiveURL: archiveURL(from: arguments),
            navigationPath: navigationPath(from: arguments),
            password: password(from: arguments),
            upCount: upCount(from: arguments),
            sortColumn: sortColumn(from: arguments),
            sortAscending: sortAscending(from: arguments)
        )
    }

    static func reportURL(from arguments: [String]) -> URL? {
        guard let index = arguments.firstIndex(of: "--gui-smoke-report") else { return nil }
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else { return nil }
        return URL(fileURLWithPath: arguments[valueIndex])
    }

    static func archiveURL(from arguments: [String]) -> URL? {
        guard let index = arguments.firstIndex(of: "--gui-smoke-archive") else { return nil }
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else { return nil }
        return URL(fileURLWithPath: arguments[valueIndex])
    }

    static func navigationPath(from arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: "--gui-smoke-navigate") else { return nil }
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else { return nil }
        return arguments[valueIndex]
    }

    static func password(from arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: "--gui-smoke-password") else { return nil }
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else { return nil }
        return arguments[valueIndex]
    }

    static func upCount(from arguments: [String]) -> Int {
        guard let index = arguments.firstIndex(of: "--gui-smoke-up") else { return 0 }
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else { return 0 }
        return Int(arguments[valueIndex]) ?? 0
    }

    static func sortColumn(from arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: "--gui-smoke-sort") else { return nil }
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else { return nil }
        return arguments[valueIndex]
    }

    static func sortAscending(from arguments: [String]) -> Bool {
        !arguments.contains("--gui-smoke-sort-desc")
    }

    @MainActor
    static func writeReport(for controller: MainWindowController, to reportURL: URL) throws {
        let imageURL = reportURL.deletingPathExtension().appendingPathExtension("png")
        let snapshot = controller.smokeTestSnapshot()
        let imageInfo = try captureWindow(controller.window, to: imageURL)

        var report = snapshot
        report["screenshotPath"] = imageURL.path
        report["screenshotWidth"] = imageInfo.width
        report["screenshotHeight"] = imageInfo.height
        report["screenshotBytes"] = imageInfo.bytes

        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: reportURL, options: .atomic)
    }

    @MainActor
    private static func captureWindow(_ window: NSWindow?, to url: URL) throws -> (width: Int, height: Int, bytes: Int) {
        guard let view = window?.contentView else {
            throw NSError(domain: "SevenZipMacSmokeTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "No window content view"])
        }

        view.layoutSubtreeIfNeeded()
        let bounds = view.bounds
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            throw NSError(domain: "SevenZipMacSmokeTest", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not allocate bitmap"])
        }

        view.cacheDisplay(in: bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "SevenZipMacSmokeTest", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
        }

        try data.write(to: url, options: .atomic)
        return (bitmap.pixelsWide, bitmap.pixelsHigh, data.count)
    }
}
