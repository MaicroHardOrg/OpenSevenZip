import Foundation

struct ArchiveEntry: Equatable, Sendable {
    var path: String
    var size: Int64?
    var packedSize: Int64?
    var modified: Date?
    var attributes: String?
    var encrypted: Bool
    var isDirectory: Bool

    var name: String {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed.split(separator: "/").last.map(String.init) ?? path
    }

    var parentPath: String {
        let normalized = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let slash = normalized.lastIndex(of: "/") else { return "" }
        return String(normalized[..<slash])
    }
}

struct BackendCapabilities: OptionSet, Sendable {
    let rawValue: Int

    static let list = BackendCapabilities(rawValue: 1 << 0)
    static let extract = BackendCapabilities(rawValue: 1 << 1)
    static let add = BackendCapabilities(rawValue: 1 << 2)
    static let test = BackendCapabilities(rawValue: 1 << 3)
    static let delete = BackendCapabilities(rawValue: 1 << 4)
    static let rename = BackendCapabilities(rawValue: 1 << 5)

    var labels: [String] {
        [
            (.list, L10n.string("view.list")),
            (.extract, L10n.string("toolbar.extract")),
            (.add, L10n.string("toolbar.add")),
            (.test, L10n.string("toolbar.test")),
            (.delete, L10n.string("action.delete")),
            (.rename, L10n.string("action.rename"))
        ].compactMap { capability, label in
            contains(capability) ? label : nil
        }
    }
}

struct BackendInfo: Equatable, Sendable {
    var name: String
    var executableURL: URL
    var version: String
    var capabilities: BackendCapabilities

    var supportedCreateFormats: [String] {
        guard capabilities.contains(.add) else { return [] }
        if name.localizedCaseInsensitiveContains("7zr") {
            return ["7z"]
        }
        return ["7z", "zip", "tar"]
    }
}

enum ArchiveOperation: Sendable {
    case list
    case extract
    case add
    case test
    case delete
    case rename

    var description: String {
        switch self {
        case .list: L10n.string("view.list").lowercased()
        case .extract: L10n.string("toolbar.extract").lowercased()
        case .add: L10n.string("toolbar.add").lowercased()
        case .test: L10n.string("toolbar.test").lowercased()
        case .delete: L10n.string("action.delete").lowercased()
        case .rename: L10n.string("action.rename").lowercased()
        }
    }
}

struct SevenZipFailure: Error, CustomStringConvertible, Sendable {
    var operation: ArchiveOperation
    var backend: BackendInfo
    var exitCode: Int32
    var output: String
    var errorOutput: String

    var description: String {
        let details = errorOutput.isEmpty ? output : errorOutput
        return """
        \(backend.name) failed to \(operation.description) archive.
        Executable: \(backend.executableURL.path)
        Exit code: \(exitCode)

        \(details.trimmingCharacters(in: .whitespacesAndNewlines))
        """
    }
}

enum AppError: Error, CustomStringConvertible, Sendable {
    case noBackend
    case noArchiveSelected
    case invalidArchive(URL)
    case unsupportedOperation(String, String)

    var description: String {
        switch self {
        case .noBackend:
            #if APP_STORE
            L10n.format("error.noBackendAppStore", AppConfiguration.productName)
            #else
            L10n.string("error.noBackend")
            #endif
        case .noArchiveSelected:
            L10n.string("error.noArchive")
        case .invalidArchive(let url):
            L10n.format("error.invalidArchive", url.path)
        case .unsupportedOperation(let operation, let backend):
            #if APP_STORE
            L10n.format("error.unsupported", backend, operation)
            #else
            L10n.format("error.unsupportedGithub", backend, operation)
            #endif
        }
    }
}
