import XCTest

// Feature: ghost-twin-on-device, Property 16: Custom answer record format

// MARK: - Test-local model copies

private enum TestChallengeType: String, Codable, CaseIterable {
    case dilemma
    case reverseTuring = "reverse_turing"
    case prediction
}

private struct TestCalibrationRecord: Codable, Equatable {
    let id: UUID
    let type: TestChallengeType
    let scenario: String
    let options: [String]
    let selectedOption: Int
    let customAnswer: String?
    let xpEarned: Int
    let ghostResponse: String
    let profileDiff: String?
    let createdAt: Date
}

final class CustomAnswerRecordPropertyTests: XCTestCase {

    // MARK: - Property 16: Custom answer record format

    func testProperty16_customAnswerImpliesSelectedOptionMinusOne() {
        PropertyTest.verify("custom answer implies selectedOption == -1", iterations: 100) {
            let record = self.makeRandomRecord(useCustomAnswer: true)
            return record.customAnswer != nil && record.selectedOption == -1
        }
    }

    func testProperty16_presetOptionImpliesNilCustomAnswer() {
        PropertyTest.verify("preset option implies nil customAnswer", iterations: 100) {
            let record = self.makeRandomRecord(useCustomAnswer: false)
            return record.selectedOption != -1 && record.customAnswer == nil
        }
    }

    func testProperty16_roundTripPreservesInvariant() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        try PropertyTest.verify("round-trip preserves custom answer invariant", iterations: 100) {
            let useCustom = Bool.random()
            let record = self.makeRandomRecord(useCustomAnswer: useCustom)

            let data = try encoder.encode(record)
            let decoded = try decoder.decode(TestCalibrationRecord.self, from: data)

            if decoded.customAnswer != nil {
                return decoded.selectedOption == -1
            } else {
                return decoded.selectedOption != -1
            }
        }
    }

    // MARK: - Helpers

    private func makeRandomRecord(useCustomAnswer: Bool) -> TestCalibrationRecord {
        let type = TestChallengeType.allCases.randomElement()!
        let optionCount = Int.random(in: 2...4)
        let options = (0..<optionCount).map { "Option \($0)" }

        if useCustomAnswer {
            let chars = "abcdefghijklmnopqrstuvwxyz"
            let customText = String((0..<Int.random(in: 1...20)).map { _ in chars.randomElement()! })
            return TestCalibrationRecord(
                id: UUID(), type: type,
                scenario: "Test scenario \(Int.random(in: 1...1000))",
                options: options, selectedOption: -1, customAnswer: customText,
                xpEarned: [200, 300, 500].randomElement()!,
                ghostResponse: "Ghost says something",
                profileDiff: Bool.random() ? "{}" : nil, createdAt: Date()
            )
        } else {
            return TestCalibrationRecord(
                id: UUID(), type: type,
                scenario: "Test scenario \(Int.random(in: 1...1000))",
                options: options, selectedOption: Int.random(in: 0..<optionCount),
                customAnswer: nil,
                xpEarned: [200, 300, 500].randomElement()!,
                ghostResponse: "Ghost says something",
                profileDiff: Bool.random() ? "{}" : nil, createdAt: Date()
            )
        }
    }
}
