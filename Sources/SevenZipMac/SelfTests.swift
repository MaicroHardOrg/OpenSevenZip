import Foundation

enum SelfTests {
    static func run() throws {
        try parseTechnicalListWithFoldersFilesAndEncryption()
        try parserFlushesFinalEntryWithoutTrailingBlankLine()
        try parserDropsSyntheticDotEntry()
        try smokeConfigurationParsesArguments()
        try smokeConfigurationRequiresReportPath()
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

    private static func smokeConfigurationParsesArguments() throws {
        let configuration = SmokeTest.configuration(from: [
            "SevenZipMac",
            "--gui-smoke-report",
            "/tmp/report.json",
            "--gui-smoke-archive",
            "/tmp/archive.7z",
            "--gui-smoke-navigate",
            "src/docs"
        ])

        try expect(configuration?.reportURL.path == "/tmp/report.json", "smoke report path")
        try expect(configuration?.archiveURL?.path == "/tmp/archive.7z", "smoke archive path")
        try expect(configuration?.navigationPath == "src/docs", "smoke navigation path")
    }

    private static func smokeConfigurationRequiresReportPath() throws {
        let configuration = SmokeTest.configuration(from: ["SevenZipMac", "--gui-smoke-archive", "/tmp/archive.7z"])
        try expect(configuration == nil, "smoke configuration requires report")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw NSError(domain: "SevenZipMacSelfTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}
