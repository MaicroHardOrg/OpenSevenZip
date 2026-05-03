import AppKit

if CommandLine.arguments.contains("--self-test") {
    do {
        try SelfTests.run()
        exit(0)
    } catch {
        fputs("Self-tests failed: \(error)\n", stderr)
        exit(1)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
