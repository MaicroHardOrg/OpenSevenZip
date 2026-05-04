import Foundation

typealias BackendProgress = @Sendable (_ line: String) -> Void

protocol SevenZipBackend: Sendable {
    var info: BackendInfo { get }
    var capabilities: BackendCapabilities { get }
    func list(archive: URL, password: String?, progress: BackendProgress?) async throws -> [ArchiveEntry]
    func extract(archive: URL, entries: [ArchiveEntry], destination: URL, password: String?, overwrite: Bool, progress: BackendProgress?) async throws
    func add(items: [URL], options: Dialogs.AddOptions, progress: BackendProgress?) async throws
    func test(archive: URL, password: String?, progress: BackendProgress?) async throws
    func delete(archive: URL, entries: [ArchiveEntry], progress: BackendProgress?) async throws
    func rename(archive: URL, entry: ArchiveEntry, to newPath: String, progress: BackendProgress?) async throws
}

extension SevenZipBackend {
    var capabilities: BackendCapabilities {
        info.capabilities
    }

    func list(archive: URL, password: String?) async throws -> [ArchiveEntry] {
        try await list(archive: archive, password: password, progress: nil)
    }

    func extract(archive: URL, entries: [ArchiveEntry], destination: URL, password: String?, overwrite: Bool) async throws {
        try await extract(archive: archive, entries: entries, destination: destination, password: password, overwrite: overwrite, progress: nil)
    }

    func add(items: [URL], options: Dialogs.AddOptions) async throws {
        try await add(items: items, options: options, progress: nil)
    }

    func test(archive: URL, password: String?) async throws {
        try await test(archive: archive, password: password, progress: nil)
    }

    func delete(archive: URL, entries: [ArchiveEntry]) async throws {
        try await delete(archive: archive, entries: entries, progress: nil)
    }

    func rename(archive: URL, entry: ArchiveEntry, to newPath: String) async throws {
        try await rename(archive: archive, entry: entry, to: newPath, progress: nil)
    }
}

final class CommandLineSevenZipBackend: SevenZipBackend, @unchecked Sendable {
    let info: BackendInfo

    init(info: BackendInfo) {
        self.info = info
    }

    func list(archive: URL, password: String?, progress: BackendProgress?) async throws -> [ArchiveEntry] {
        let result = try await run(SevenZipCommandBuilder.list(archive: archive, password: password), operation: .list, progress: progress)
        return SevenZipParser.parseTechnicalList(result.output)
    }

    func extract(archive: URL, entries: [ArchiveEntry], destination: URL, password: String?, overwrite: Bool, progress: BackendProgress?) async throws {
        let args = SevenZipCommandBuilder.extract(archive: archive, entries: entries, destination: destination, password: password, overwrite: overwrite)
        _ = try await run(args, operation: .extract, progress: progress)
    }

    func add(items: [URL], options: Dialogs.AddOptions, progress: BackendProgress?) async throws {
        let args = SevenZipCommandBuilder.add(items: items, options: options)
        _ = try await run(args, operation: .add, progress: progress)
    }

    func test(archive: URL, password: String?, progress: BackendProgress?) async throws {
        _ = try await run(SevenZipCommandBuilder.test(archive: archive, password: password), operation: .test, progress: progress)
    }

    func delete(archive: URL, entries: [ArchiveEntry], progress: BackendProgress?) async throws {
        _ = try await run(SevenZipCommandBuilder.delete(archive: archive, entries: entries), operation: .delete, progress: progress)
    }

    func rename(archive: URL, entry: ArchiveEntry, to newPath: String, progress: BackendProgress?) async throws {
        _ = try await run(SevenZipCommandBuilder.rename(archive: archive, entry: entry, to: newPath), operation: .rename, progress: progress)
    }

    @discardableResult
    private func run(_ arguments: [String], operation: ArchiveOperation, progress: BackendProgress?) async throws -> ProcessResult {
        let info = self.info
        return try await ProcessRunner.run(
            executableURL: info.executableURL,
            arguments: arguments,
            outputHandler: progress,
            failure: { exitCode, output, errorOutput in
                SevenZipFailure(operation: operation, backend: info, exitCode: exitCode, output: output, errorOutput: errorOutput)
            }
        )
    }
}

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
        candidateList(customBackendPath: customBackendPath, resourceURL: Bundle.main.resourceURL)
    }

    static func candidateList(customBackendPath: String, resourceURL: URL?) -> [(name: String, url: URL, capabilities: BackendCapabilities)] {
        let fullCapabilities: BackendCapabilities = [.list, .extract, .add, .test, .delete, .rename]
        var values: [(String, URL, BackendCapabilities)] = []

        if !customBackendPath.isEmpty {
            values.append(("Custom 7-Zip", URL(fileURLWithPath: customBackendPath), fullCapabilities))
        }

        if let resourceURL {
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
        outputHandler: BackendProgress? = nil,
        failure: @escaping @Sendable (_ exitCode: Int32, _ output: String, _ errorOutput: String) -> any Error
    ) async throws -> ProcessResult {
        let state = ProcessRunState()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard state.setContinuation(continuation) else { return }

                let process = Process()
                process.executableURL = executableURL
                process.arguments = arguments

                let stdout = Pipe()
                let stderr = Pipe()
                let output = ProcessOutputAccumulator(outputHandler: outputHandler)
                process.standardOutput = stdout
                process.standardError = stderr
                stdout.fileHandleForReading.readabilityHandler = { fileHandle in
                    output.append(fileHandle.availableData, isErrorOutput: false)
                }
                stderr.fileHandleForReading.readabilityHandler = { fileHandle in
                    output.append(fileHandle.availableData, isErrorOutput: true)
                }

                process.terminationHandler = { process in
                    stdout.fileHandleForReading.readabilityHandler = nil
                    stderr.fileHandleForReading.readabilityHandler = nil
                    output.append(stdout.fileHandleForReading.readDataToEndOfFile(), isErrorOutput: false)
                    output.append(stderr.fileHandleForReading.readDataToEndOfFile(), isErrorOutput: true)
                    let result = ProcessResult(exitCode: process.terminationStatus, output: output.standardOutput, errorOutput: output.errorOutput)

                    if process.terminationStatus == 0 {
                        state.resume(returning: result)
                    } else if state.isCancelled {
                        state.resume(throwing: CancellationError())
                    } else {
                        state.resume(throwing: failure(process.terminationStatus, result.output, result.errorOutput))
                    }
                }

                guard state.setProcess(process) else { return }
                do {
                    try process.run()
                } catch {
                    state.resume(throwing: error)
                }
            }
        } onCancel: {
            state.cancel()
        }
    }
}

private final class ProcessOutputAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var outputData = Data()
    private var errorData = Data()
    private let outputHandler: BackendProgress?

    var standardOutput: String {
        string(isErrorOutput: false)
    }

    var errorOutput: String {
        string(isErrorOutput: true)
    }

    init(outputHandler: BackendProgress?) {
        self.outputHandler = outputHandler
    }

    func append(_ data: Data, isErrorOutput: Bool) {
        guard !data.isEmpty else { return }
        lock.lock()
        if isErrorOutput {
            errorData.append(data)
        } else {
            outputData.append(data)
        }
        lock.unlock()

        guard let outputHandler, let text = String(data: data, encoding: .utf8) else { return }
        for line in Self.statusLines(from: text) {
            outputHandler(line)
        }
    }

    private func string(isErrorOutput: Bool) -> String {
        lock.lock()
        let copy = isErrorOutput ? errorData : outputData
        lock.unlock()
        return String(data: copy, encoding: .utf8) ?? ""
    }

    private static func statusLines(from text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: "\r\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private final class ProcessRunState: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<ProcessResult, any Error>?
    private var process: Process?
    private(set) var isCancelled = false

    func setContinuation(_ continuation: CheckedContinuation<ProcessResult, any Error>) -> Bool {
        lock.lock()
        if isCancelled {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }

    func setProcess(_ process: Process) -> Bool {
        lock.lock()
        let shouldRun = !isCancelled
        if shouldRun {
            self.process = process
        }
        let continuation = shouldRun ? nil : self.continuation
        if !shouldRun {
            self.continuation = nil
        }
        lock.unlock()

        if !shouldRun {
            continuation?.resume(throwing: CancellationError())
        }
        return shouldRun
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let process = self.process
        let continuation = process == nil ? self.continuation : nil
        if process == nil {
            self.continuation = nil
        }
        lock.unlock()

        if let process, process.isRunning {
            process.terminate()
        } else {
            continuation?.resume(throwing: CancellationError())
        }
    }

    func resume(returning result: ProcessResult) {
        complete(.success(result))
    }

    func resume(throwing error: any Error) {
        complete(.failure(error))
    }

    private func complete(_ result: Result<ProcessResult, any Error>) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()

        switch result {
        case .success(let processResult):
            continuation.resume(returning: processResult)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
