import Foundation

enum SevenZipParser {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static func parseTechnicalList(_ text: String) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        var current: [String: String] = [:]

        func flush() {
            guard let path = current["Path"], !path.isEmpty else {
                current.removeAll()
                return
            }

            let attributes = current["Attributes"]
            let folderValue = current["Folder"]?.lowercased()
            let encryptedValue = current["Encrypted"]?.lowercased()
            let isDirectory = folderValue == "+" || attributes?.contains("D") == true || path.hasSuffix("/")

            entries.append(
                ArchiveEntry(
                    path: path,
                    size: parseInt64(current["Size"]),
                    packedSize: parseInt64(current["Packed Size"]),
                    modified: parseDate(current["Modified"]),
                    attributes: attributes,
                    encrypted: encryptedValue == "+",
                    isDirectory: isDirectory
                )
            )
            current.removeAll()
        }

        for line in text.components(separatedBy: .newlines) {
            if line.isEmpty {
                flush()
                continue
            }

            guard let separator = line.firstIndex(of: "=") else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespaces)
            let valueStart = line.index(after: separator)
            let value = line[valueStart...].trimmingCharacters(in: .whitespaces)
            current[String(key)] = String(value)
        }

        flush()
        return entriesWithSyntheticDirectories(from: entries.filter { $0.path != "." })
    }

    private static func entriesWithSyntheticDirectories(from entries: [ArchiveEntry]) -> [ArchiveEntry] {
        var existingPaths = Set(entries.map { normalizedPath($0.path) })
        var syntheticDirectories: [ArchiveEntry] = []

        for entry in entries {
            let path = normalizedPath(entry.path)
            let components = path.split(separator: "/").map(String.init)
            guard components.count > 1 else { continue }

            var directoryParts: [String] = []
            for component in components.dropLast() {
                directoryParts.append(component)
                let directoryPath = directoryParts.joined(separator: "/")
                guard !existingPaths.contains(directoryPath) else { continue }
                existingPaths.insert(directoryPath)
                syntheticDirectories.append(
                    ArchiveEntry(
                        path: directoryPath,
                        size: nil,
                        packedSize: nil,
                        modified: entry.modified,
                        attributes: "D",
                        encrypted: false,
                        isDirectory: true
                    )
                )
            }
        }

        return entries + syntheticDirectories
    }

    private static func normalizedPath(_ path: String) -> String {
        path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func parseInt64(_ value: String?) -> Int64? {
        guard let value, !value.isEmpty else { return nil }
        return Int64(value)
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value, value.count >= 19 else { return nil }
        let prefix = String(value.prefix(19))
        return dateFormatter.date(from: prefix)
    }
}
