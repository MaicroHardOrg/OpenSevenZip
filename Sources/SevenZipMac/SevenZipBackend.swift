import Foundation

protocol SevenZipBackend: Sendable {
    var info: BackendInfo { get }
    func list(archive: URL, password: String?) async throws -> [ArchiveEntry]
    func extract(archive: URL, entries: [ArchiveEntry], destination: URL, password: String?, overwrite: Bool) async throws
    func add(items: [URL], archive: URL, format: String, level: Int, password: String?, encryptHeaders: Bool) async throws
    func test(archive: URL, password: String?) async throws
    func delete(archive: URL, entries: [ArchiveEntry]) async throws
}

final class CommandLineSevenZipBackend: SevenZipBackend, @unchecked Sendable {
    let info: BackendInfo

    init(info: BackendInfo) {
        self.info = info
    }

    func list(archive: URL, password: String?) async throws -> [ArchiveEntry] {
        var args = ["l", "-slt", "-ba", archive.path]
        appendPassword(password, to: &args)
        let result = try await run(args, operation: .list)
        return SevenZipParser.parseTechnicalList(result.output)
    }

    func extract(archive: URL, entries: [ArchiveEntry], destination: URL, password: String?, overwrite: Bool) async throws {
        var args = ["x", archive.path, "-o\(destination.path)", overwrite ? "-y" : "-aos"]
        appendPassword(password, to: &args)
        args.append(contentsOf: entries.map(\.path))
        _ = try await run(args, operation: .extract)
    }

    func add(items: [URL], archive: URL, format: String, level: Int, password: String?, encryptHeaders: Bool) async throws {
        var args = ["a", "-t\(format)", "-mx=\(level)", archive.path]
        appendPassword(password, to: &args)
        if encryptHeaders, password?.isEmpty == false {
            args.append("-mhe=on")
        }
        args.append(contentsOf: items.map(\.path))
        _ = try await run(args, operation: .add)
    }

    func test(archive: URL, password: String?) async throws {
        var args = ["t", archive.path]
        appendPassword(password, to: &args)
        _ = try await run(args, operation: .test)
    }

    func delete(archive: URL, entries: [ArchiveEntry]) async throws {
        var args = ["d", archive.path]
        args.append(contentsOf: entries.map(\.path))
        _ = try await run(args, operation: .delete)
    }

    private func appendPassword(_ password: String?, to args: inout [String]) {
        if let password, !password.isEmpty {
            args.append("-p\(password)")
        }
    }

    @discardableResult
    private func run(_ arguments: [String], operation: ArchiveOperation) async throws -> ProcessResult {
        let info = self.info
        return try await ProcessRunner.run(
            executableURL: info.executableURL,
            arguments: arguments,
            failure: { exitCode, output, errorOutput in
                SevenZipFailure(operation: operation, backend: info, exitCode: exitCode, output: output, errorOutput: errorOutput)
            }
        )
    }
}

@MainActor
enum BackendLocator {
    private static let customBackendPathKey = "CustomBackendPath"

    static var customBackendPath: String {
        UserDefaults.standard.string(forKey: customBackendPathKey) ?? ""
    }

    static func setCustomBackendPath(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            resetCustomBackendPath()
        } else {
            UserDefaults.standard.set(trimmed, forKey: customBackendPathKey)
        }
    }

    static func resetCustomBackendPath() {
        UserDefaults.standard.removeObject(forKey: customBackendPathKey)
    }

    static func defaultBackend() async -> SevenZipBackend? {
        for candidate in candidates() {
            guard FileManager.default.isExecutableFile(atPath: candidate.url.path) else { continue }
            let version = await versionString(for: candidate.url) ?? "Unknown version"
            let info = BackendInfo(
                name: candidate.name,
                executableURL: candidate.url,
                version: version,
                capabilities: candidate.capabilities
            )
            return CommandLineSevenZipBackend(info: info)
        }
        return nil
    }

    static func candidates() -> [(name: String, url: URL, capabilities: BackendCapabilities)] {
        var values: [(String, URL, BackendCapabilities)] = []
        let fullCapabilities: BackendCapabilities = [.list, .extract, .add, .test, .delete]

        if !customBackendPath.isEmpty {
            values.append(("Custom 7-Zip", URL(fileURLWithPath: customBackendPath), fullCapabilities))
        }

        if let resourceURL = Bundle.main.resourceURL {
            values.append(("Official 7-Zip", resourceURL.appendingPathComponent("7zz"), fullCapabilities))
        }

        values.append(contentsOf: [
            ("p7zip 7z", URL(fileURLWithPath: "/usr/local/bin/7z"), fullCapabilities),
            ("p7zip 7za", URL(fileURLWithPath: "/usr/local/bin/7za"), fullCapabilities),
            ("p7zip 7zr", URL(fileURLWithPath: "/usr/local/bin/7zr"), fullCapabilities)
        ])

        return values
    }

    private static func versionString(for executableURL: URL) async -> String? {
        do {
            let result = try await ProcessRunner.run(executableURL: executableURL, arguments: [], failure: { exitCode, output, errorOutput in
                ProcessRunFailure(exitCode: exitCode, output: output, errorOutput: errorOutput)
            })
            return result.output.components(separatedBy: .newlines).first { $0.contains("7-Zip") }
        } catch {
            return nil
        }
    }
}

struct ProcessResult: Sendable {
    var exitCode: Int32
    var output: String
    var errorOutput: String
}

struct ProcessRunFailure: Error, Sendable {
    var exitCode: Int32
    var output: String
    var errorOutput: String
}

enum ProcessRunner {
    static func run(
        executableURL: URL,
        arguments: [String],
        failure: @escaping @Sendable (_ exitCode: Int32, _ output: String, _ errorOutput: String) -> any Error
    ) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            process.terminationHandler = { process in
                let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let errorOutput = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let result = ProcessResult(exitCode: process.terminationStatus, output: output, errorOutput: errorOutput)

                if process.terminationStatus == 0 {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: failure(process.terminationStatus, output, errorOutput))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
