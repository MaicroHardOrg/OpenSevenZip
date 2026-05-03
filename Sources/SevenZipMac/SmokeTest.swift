import AppKit

enum SmokeTest {
    struct Configuration {
        var reportURL: URL
        var archiveURL: URL?
    }

    static func configuration(from arguments: [String]) -> Configuration? {
        guard let reportURL = reportURL(from: arguments) else { return nil }
        return Configuration(reportURL: reportURL, archiveURL: archiveURL(from: arguments))
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
