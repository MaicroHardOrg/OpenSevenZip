import Foundation

enum AppConfiguration {
    static let productName = "OpenSevenZip Explorer"

    #if APP_STORE
    static let distributionName = "App Store"
    static let allowsExternalBackends = false
    static var appStorePolicyNotice: String {
        L10n.string("app.storePolicyNotice")
    }
    #else
    static let distributionName = "GitHub"
    static let allowsExternalBackends = true
    static let appStorePolicyNotice = ""
    #endif
}
