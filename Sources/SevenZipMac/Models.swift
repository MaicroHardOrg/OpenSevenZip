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
            (.list, "List"),
            (.extract, "Extract"),
            (.add, "Add"),
            (.test, "Test"),
            (.delete, "Delete"),
            (.rename, "Rename")
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
        case .list: "list"
        case .extract: "extract"
        case .add: "add"
        case .test: "test"
        case .delete: "delete"
        case .rename: "rename"
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
            "No bundled 7-Zip backend was found. Reinstall \(AppConfiguration.productName) or contact support."
            #else
            "No 7-Zip backend was found. Build the bundled official 7zz backend or install p7zip."
            #endif
        case .noArchiveSelected:
            "No archive is open."
        case .invalidArchive(let url):
            "The selected item is not an archive: \(url.path)"
        case .unsupportedOperation(let operation, let backend):
            #if APP_STORE
            "\(backend) does not support \(operation)."
            #else
            "\(backend) does not support \(operation). Choose another 7-Zip backend in Backend Settings."
            #endif
        }
    }
}
