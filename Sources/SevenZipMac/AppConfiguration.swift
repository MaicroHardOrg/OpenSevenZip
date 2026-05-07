import Foundation

enum AppConfiguration {
    static let productName = "OpenSevenZip Explorer"

    #if APP_STORE
    static let distributionName = "App Store"
    static let allowsExternalBackends = false
    static let appStorePolicyNotice = "The Mac App Store build uses only the bundled backend. Apple policy disallows running arbitrary external executables; the GitHub build supports host and imported backends."
    #else
    static let distributionName = "GitHub"
    static let allowsExternalBackends = true
    static let appStorePolicyNotice = ""
    #endif
}
