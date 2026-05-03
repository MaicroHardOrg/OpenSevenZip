import Foundation

enum SevenZipCommandBuilder {
    static func list(archive: URL, password: String?) -> [String] {
        var args = ["l", "-slt", "-ba", archive.path]
        appendPassword(password, to: &args)
        return args
    }

    static func extract(archive: URL, entries: [ArchiveEntry], destination: URL, password: String?, overwrite: Bool) -> [String] {
        var args = ["x", archive.path, "-o\(destination.path)", overwrite ? "-y" : "-aos"]
        appendPassword(password, to: &args)
        args.append(contentsOf: entries.map(\.path))
        return args
    }

    static func add(items: [URL], archive: URL, format: String, level: Int, password: String?, encryptHeaders: Bool) -> [String] {
        var args = ["a", "-t\(format)", "-mx=\(level)", archive.path]
        appendPassword(password, to: &args)
        if encryptHeaders, password?.isEmpty == false {
            args.append("-mhe=on")
        }
        args.append(contentsOf: items.map(\.path))
        return args
    }

    static func test(archive: URL, password: String?) -> [String] {
        var args = ["t", archive.path]
        appendPassword(password, to: &args)
        return args
    }

    static func delete(archive: URL, entries: [ArchiveEntry]) -> [String] {
        var args = ["d", archive.path]
        args.append(contentsOf: entries.map(\.path))
        return args
    }

    static func rename(archive: URL, entry: ArchiveEntry, to newPath: String) -> [String] {
        ["rn", archive.path, entry.path, newPath]
    }

    private static func appendPassword(_ password: String?, to args: inout [String]) {
        if let password, !password.isEmpty {
            args.append("-p\(password)")
        }
    }
}
