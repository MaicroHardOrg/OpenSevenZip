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

    static func add(items: [URL], options: Dialogs.AddOptions) -> [String] {
        var args = ["a", "-t\(options.format)", "-mx=\(options.level)", options.archive.path]
        appendPassword(options.password, to: &args)
        if options.encryptHeaders, options.password?.isEmpty == false {
            args.append("-mhe=on")
        }
        if !options.volumeSize.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args.append("-v\(options.volumeSize.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        appendPatternSwitches(options.includePatterns, prefix: "-i!", to: &args)
        appendPatternSwitches(options.excludePatterns, prefix: "-x!", to: &args)
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

    private static func appendPatternSwitches(_ patterns: String, prefix: String, to args: inout [String]) {
        let separators = CharacterSet(charactersIn: "\n,")
        let values = patterns.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        args.append(contentsOf: values.map { "\(prefix)\($0)" })
    }
}
