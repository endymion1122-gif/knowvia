import Foundation
import XCTest
@testable import Knowvia

final class ResearchParticipationTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        let suiteName = "ResearchParticipationTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDefaultsToUndecided() {
        let preferences = ResearchParticipationPreferences(defaults: defaults)

        XCTAssertEqual(preferences.status, .undecided)
    }

    func testPersistsParticipationChoiceLocally() {
        var preferences = ResearchParticipationPreferences(defaults: defaults)

        preferences.status = .participating

        XCTAssertEqual(preferences.status, .participating)
        XCTAssertEqual(
            defaults.string(forKey: ResearchParticipationPreferences.statusKey),
            ResearchParticipationStatus.participating.rawValue
        )
    }

    func testCanAcknowledgeIntroWithoutChoosingParticipation() {
        var preferences = ResearchParticipationPreferences(defaults: defaults)

        preferences.hasSeenIntro = true

        XCTAssertTrue(preferences.hasSeenIntro)
        XCTAssertEqual(preferences.status, .undecided)
        XCTAssertTrue(
            defaults.bool(forKey: ResearchParticipationPreferences.introSeenKey)
        )
    }
}
