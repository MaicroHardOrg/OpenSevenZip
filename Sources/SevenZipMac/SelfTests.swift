import Foundation

enum SelfTests {
    static func run() throws {
        try parseTechnicalListWithFoldersFilesAndEncryption()
        try parserFlushesFinalEntryWithoutTrailingBlankLine()
        try parserDropsSyntheticDotEntry()
        try parserSynthesizesMissingDirectories()
        try smokeConfigurationParsesArguments()
        try smokeConfigurationRequiresReportPath()
        try commandBuilderPreservesPathsPasswordsAndSelections()
        try commandBuilderHandlesOverwriteModesAndHeaderEncryption()
        try backendCandidatesUseExpectedPriority()
        print("Self-tests passed")
    }

    private static func parseTechnicalListWithFoldersFilesAndEncryption() throws {
        let text = """
        Path = src
        Size = 0
        Packed Size = 0
        Modified = 2026-05-04 00:12:03.1234567
        Attributes = D drwxr-xr-x
        Encrypted = -

        Path = src/alpha.txt
        Size = 6
        Packed Size = 10
        Modified = 2026-05-04 00:13:04
        Attributes = A -rw-r--r--
        Encrypted = +

        """

        let entries = SevenZipParser.parseTechnicalList(text)

        try expect(entries.count == 2, "expected two entries")
        try expect(entries[0].path == "src", "folder path")
        try expect(entries[0].isDirectory, "folder flag")
        try expect(!entries[0].encrypted, "folder encryption flag")
        try expect(entries[1].name == "alpha.txt", "file name")
        try expect(entries[1].parentPath == "src", "file parent")
        try expect(entries[1].size == 6, "file size")
        try expect(entries[1].packedSize == 10, "packed size")
        try expect(entries[1].encrypted, "file encryption flag")
        try expect(!entries[1].isDirectory, "file directory flag")
    }

    private static func parserFlushesFinalEntryWithoutTrailingBlankLine() throws {
        let text = """
        Path = file.txt
        Size = 4
        Attributes = A
        Encrypted = -
        """

        let entries = SevenZipParser.parseTechnicalList(text)

        try expect(entries.count == 1, "final entry flush")
        try expect(entries[0].path == "file.txt", "final entry path")
        try expect(entries[0].size == 4, "final entry size")
    }

    private static func parserDropsSyntheticDotEntry() throws {
        let text = """
        Path = .
        Size = 0

        Path = real.txt
        Size = 1

        """

        let entries = SevenZipParser.parseTechnicalList(text)

        try expect(entries.map(\.path) == ["real.txt"], "drop dot entry")
    }

    private static func parserSynthesizesMissingDirectories() throws {
        let text = """
        Path = ProjectA/src/chapter-one.txt
        Folder = -
        Size = 22287
        Packed Size = 7541
        Modified = 2025-11-12 06:39:14
        Attributes = -rw-r--r--
        Encrypted = -

        Path = Archive Samples/Batch 11/assets/diagram.txt
        Folder = -
        Size = 10
        Packed Size = 5
        Modified = 2025-11-12 06:39:20
        Attributes = -rw-r--r--
        Encrypted = -

        """

        let entries = SevenZipParser.parseTechnicalList(text)
        let paths = Set(entries.map(\.path))

        try expect(paths.contains("ProjectA"), "synthesized first-level directory")
        try expect(paths.contains("ProjectA/src"), "synthesized nested directory")
        try expect(paths.contains("Archive Samples"), "synthesized archive samples directory")
        try expect(paths.contains("Archive Samples/Batch 11"), "synthesized directory with space")
        try expect(paths.contains("Archive Samples/Batch 11/assets"), "synthesized deep directory")
        try expect(entries.first { $0.path == "ProjectA" }?.isDirectory == true, "synthesized directory flag")
        try expect(entries.filter(\.isDirectory).count == 5, "synthesized directory count")
    }

    private static func smokeConfigurationParsesArguments() throws {
        let configuration = SmokeTest.configuration(from: [
            "SevenZipMac",
            "--gui-smoke-report",
            "/tmp/report.json",
            "--gui-smoke-archive",
            "/tmp/archive.7z",
            "--gui-smoke-navigate",
            "src/docs",
            "--gui-smoke-password",
            "secret",
            "--gui-smoke-up",
            "2",
            "--gui-smoke-sort",
            "size",
            "--gui-smoke-sort-desc"
        ])

        try expect(configuration?.reportURL.path == "/tmp/report.json", "smoke report path")
        try expect(configuration?.archiveURL?.path == "/tmp/archive.7z", "smoke archive path")
        try expect(configuration?.navigationPath == "src/docs", "smoke navigation path")
        try expect(configuration?.password == "secret", "smoke password")
        try expect(configuration?.upCount == 2, "smoke up count")
        try expect(configuration?.sortColumn == "size", "smoke sort column")
        try expect(configuration?.sortAscending == false, "smoke sort direction")
    }

    private static func smokeConfigurationRequiresReportPath() throws {
        let configuration = SmokeTest.configuration(from: ["SevenZipMac", "--gui-smoke-archive", "/tmp/archive.7z"])
        try expect(configuration == nil, "smoke configuration requires report")
    }

    private static func commandBuilderPreservesPathsPasswordsAndSelections() throws {
        let archive = URL(fileURLWithPath: "/tmp/Seven Zip Smoke/archive with space.7z")
        let destination = URL(fileURLWithPath: "/tmp/Seven Zip Smoke/out folder")
        let entries = [
            ArchiveEntry(path: "src/docs/beta file.txt", size: 5, packedSize: 9, modified: nil, attributes: "A", encrypted: true, isDirectory: false),
            ArchiveEntry(path: "unicodé/名前.txt", size: 8, packedSize: 12, modified: nil, attributes: "A", encrypted: false, isDirectory: false)
        ]

        try expect(
            SevenZipCommandBuilder.list(archive: archive, password: "secret") == ["l", "-slt", "-ba", archive.path, "-psecret"],
            "list command arguments"
        )
        try expect(
            SevenZipCommandBuilder.extract(archive: archive, entries: entries, destination: destination, password: "secret", overwrite: true) == [
                "x",
                archive.path,
                "-o\(destination.path)",
                "-y",
                "-psecret",
                "src/docs/beta file.txt",
                "unicodé/名前.txt"
            ],
            "extract command preserves selected paths"
        )
        try expect(
            SevenZipCommandBuilder.delete(archive: archive, entries: entries) == ["d", archive.path, "src/docs/beta file.txt", "unicodé/名前.txt"],
            "delete command preserves selected paths"
        )
        try expect(
            SevenZipCommandBuilder.rename(archive: archive, entry: entries[0], to: "src/docs/renamed file.txt") == [
                "rn",
                archive.path,
                "src/docs/beta file.txt",
                "src/docs/renamed file.txt"
            ],
            "rename command preserves old and new paths"
        )
    }

    private static func commandBuilderHandlesOverwriteModesAndHeaderEncryption() throws {
        let archive = URL(fileURLWithPath: "/tmp/test.zip")
        let destination = URL(fileURLWithPath: "/tmp/out")
        let item = URL(fileURLWithPath: "/tmp/input folder/file.txt")

        try expect(
            SevenZipCommandBuilder.extract(archive: archive, entries: [], destination: destination, password: nil, overwrite: false) == [
                "x",
                archive.path,
                "-o\(destination.path)",
                "-aos"
            ],
            "extract command no-overwrite mode"
        )
        let encryptedOptions = Dialogs.AddOptions(
            archive: archive,
            format: "zip",
            level: 7,
            password: "secret",
            encryptHeaders: true,
            volumeSize: "",
            includePatterns: "",
            excludePatterns: ""
        )
        try expect(
            SevenZipCommandBuilder.add(items: [item], options: encryptedOptions) == [
                "a",
                "-tzip",
                "-mx=7",
                archive.path,
                "-psecret",
                "-mhe=on",
                item.path
            ],
            "add command encrypted headers"
        )
        let advancedOptions = Dialogs.AddOptions(
            archive: archive,
            format: "7z",
            level: 9,
            password: nil,
            encryptHeaders: false,
            volumeSize: "100m",
            includePatterns: "*.txt, docs/*",
            excludePatterns: "*.tmp\n.DS_Store"
        )
        try expect(
            SevenZipCommandBuilder.add(items: [item], options: advancedOptions) == [
                "a",
                "-t7z",
                "-mx=9",
                archive.path,
                "-v100m",
                "-i!*.txt",
                "-i!docs/*",
                "-x!*.tmp",
                "-x!.DS_Store",
                item.path
            ],
            "add command split volumes and include exclude filters"
        )
        let emptyPasswordOptions = Dialogs.AddOptions(
            archive: archive,
            format: "zip",
            level: 1,
            password: "",
            encryptHeaders: true,
            volumeSize: "",
            includePatterns: "",
            excludePatterns: ""
        )
        try expect(
            SevenZipCommandBuilder.add(items: [item], options: emptyPasswordOptions) == [
                "a",
                "-tzip",
                "-mx=1",
                archive.path,
                item.path
            ],
            "add command skips empty password and header encryption"
        )
    }

    private static func backendCandidatesUseExpectedPriority() throws {
        let candidates = BackendLocator.candidateList(
            customBackendPath: "/opt/local/bin/7zz-custom",
            resourceURL: URL(fileURLWithPath: "/Applications/7-Zip.app/Contents/Resources"),
            pathEnvironment: "/tmp/no-7zip-bin"
        )

        try expect(
            candidates.map(\.name).prefix(5) == ["Temporary external 7-Zip", "Bundled official 7zz", "Host /usr/local/bin/7z", "Host /usr/local/bin/7za", "Host /usr/local/bin/7zr"],
            "backend candidate priority"
        )
        try expect(candidates[0].url.path == "/opt/local/bin/7zz-custom", "temporary external backend path")
        try expect(candidates[1].url.path == "/Applications/7-Zip.app/Contents/Resources/7zz", "official backend resource path")
        try expect(candidates.allSatisfy { $0.capabilities.contains([.list, .extract, .add, .test, .delete, .rename]) }, "backend capabilities")
        let officialInfo = BackendInfo(name: candidates[1].name, executableURL: candidates[1].url, version: "", capabilities: candidates[1].capabilities)
        try expect(officialInfo.supportedCreateFormats == ["7z", "zip", "tar"], "official create formats")

        let fallbackOnly = BackendLocator.candidateList(customBackendPath: "", resourceURL: nil, pathEnvironment: "/tmp/no-7zip-bin")
        try expect(fallbackOnly.map(\.name).prefix(3) == ["Host /usr/local/bin/7z", "Host /usr/local/bin/7za", "Host /usr/local/bin/7zr"], "p7zip fallback priority")
        let sevenZr = fallbackOnly[2]
        let sevenZrInfo = BackendInfo(name: sevenZr.name, executableURL: sevenZr.url, version: "", capabilities: sevenZr.capabilities)
        try expect(sevenZrInfo.supportedCreateFormats == ["7z"], "7zr create formats")
        let pathCandidates = BackendLocator.candidateList(
            customBackendPath: "",
            resourceURL: nil,
            pathEnvironment: "/usr/local/bin:/opt/homebrew/bin:/usr/local/bin"
        )
        let pathCandidateNames = pathCandidates.map(\.name)
        if FileManager.default.isExecutableFile(atPath: "/usr/local/bin/7z") {
            try expect(pathCandidateNames.first == "Host PATH 7z", "PATH 7z appears before fallback and dedupes fallback")
            try expect(pathCandidates.filter { $0.url.path == "/usr/local/bin/7z" }.count == 1, "dedupe PATH and fallback 7z")
        }
        try expect(BackendCapabilities([.list, .add, .test]).labels == ["List", "Add", "Test"], "capability labels")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw NSError(domain: "SevenZipMacSelfTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}
