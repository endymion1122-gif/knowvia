import Foundation

struct AppSettings: Codable, Equatable {
    var providerName: String
    var apiEndpoint: String
    var modelName: String
    var demoModeEnabled: Bool

    init(
        providerName: String = "OpenAI",
        apiEndpoint: String = "https://api.openai.com/v1/chat/completions",
        modelName: String = "gpt-4o-mini",
        demoModeEnabled: Bool = true
    ) {
        self.providerName = providerName
        self.apiEndpoint = apiEndpoint
        self.modelName = modelName
        self.demoModeEnabled = demoModeEnabled
    }

    static let defaults = AppSettings(
        providerName: "OpenAI",
        apiEndpoint: "https://api.openai.com/v1/chat/completions",
        modelName: "gpt-4o-mini",
        demoModeEnabled: true
    )

    static let defaultProviderName = defaults.providerName
    static let defaultAPIEndpoint = defaults.apiEndpoint
    static let defaultModelName = defaults.modelName

    static let deepSeekProviderName = "DeepSeek"
    static let deepSeekAPIEndpoint = "https://api.deepseek.com/chat/completions"
    static let deepSeekDefaultModelName = "deepseek-v4-flash"

    static let deepSeekPreset = AppSettings(
        providerName: deepSeekProviderName,
        apiEndpoint: deepSeekAPIEndpoint,
        modelName: deepSeekDefaultModelName,
        demoModeEnabled: false
    )
}

enum AppSettingsStore {
    static let providerNameKey = "ai.providerName"
    static let apiEndpointKey = "ai.apiEndpoint"
    static let modelNameKey = "ai.modelName"
    static let demoModeEnabledKey = "ai.demoModeEnabled"

    static func load(defaults: UserDefaults = .standard) -> AppSettings {
        AppSettingsPreferences(defaults: defaults).settings
    }
}

struct AppSettingsPreferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var settings: AppSettings {
        get {
            AppSettings(
                providerName: defaults.string(forKey: AppSettingsStore.providerNameKey)
                    ?? AppSettings.defaultProviderName,
                apiEndpoint: defaults.string(forKey: AppSettingsStore.apiEndpointKey)
                    ?? AppSettings.defaultAPIEndpoint,
                modelName: defaults.string(forKey: AppSettingsStore.modelNameKey)
                    ?? AppSettings.defaultModelName,
                demoModeEnabled: defaults.object(forKey: AppSettingsStore.demoModeEnabledKey) as? Bool
                    ?? true
            )
        }
        nonmutating set {
            defaults.set(newValue.providerName, forKey: AppSettingsStore.providerNameKey)
            defaults.set(newValue.apiEndpoint, forKey: AppSettingsStore.apiEndpointKey)
            defaults.set(newValue.modelName, forKey: AppSettingsStore.modelNameKey)
            defaults.set(newValue.demoModeEnabled, forKey: AppSettingsStore.demoModeEnabledKey)
        }
    }
}
