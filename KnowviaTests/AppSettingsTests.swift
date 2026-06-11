import Foundation
import XCTest
@testable import Knowvia

final class AppSettingsTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testUsesOpenAIDefaultsWhenNoSettingsWereSaved() {
        let preferences = AppSettingsPreferences(defaults: defaults)

        XCTAssertEqual(preferences.settings, AppSettings())
        XCTAssertTrue(preferences.settings.demoModeEnabled)
    }

    func testPersistsOnlyNonSecretAIConfiguration() throws {
        let preferences = AppSettingsPreferences(defaults: defaults)
        let settings = AppSettings(
            providerName: "Compatible Provider",
            apiEndpoint: "https://example.com/v1/chat/completions",
            modelName: "example-model"
        )

        preferences.settings = settings

        XCTAssertEqual(preferences.settings, settings)
        let storedValues = String(describing: defaults.dictionaryRepresentation())
        XCTAssertFalse(storedValues.localizedCaseInsensitiveContains("apiKey"))
        XCTAssertNil(defaults.object(forKey: "ai.apiKey"))
    }

    func testCanDisableDemoModeForRealAPIIntegration() {
        let preferences = AppSettingsPreferences(defaults: defaults)
        var settings = preferences.settings

        settings.demoModeEnabled = false
        preferences.settings = settings

        XCTAssertFalse(preferences.settings.demoModeEnabled)
        XCTAssertEqual(
            defaults.object(forKey: AppSettingsStore.demoModeEnabledKey) as? Bool,
            false
        )
    }

    func testProvidesDeepSeekPresetForLocalRealAPIUse() {
        let preset = AppSettings.deepSeekPreset

        XCTAssertEqual(preset.providerName, "DeepSeek")
        XCTAssertEqual(preset.apiEndpoint, "https://api.deepseek.com/chat/completions")
        XCTAssertEqual(preset.modelName, "deepseek-v4-flash")
        XCTAssertFalse(preset.demoModeEnabled)
    }
}
