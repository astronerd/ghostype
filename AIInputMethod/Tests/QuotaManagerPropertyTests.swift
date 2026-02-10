import XCTest
import Foundation

// MARK: - Testable Copies of Production Types
// Since the test target cannot import the executable target,
// we duplicate the relevant structs/logic here for testing.

// MARK: - ProfileResponse (Test Copy)

/// Exact copy of ProfileResponse from GhostypeModels.swift
private struct TestProfileResponse: Codable {
    let subscription: SubscriptionInfo
    let usage: UsageInfo

    struct SubscriptionInfo: Codable {
        let plan: String              // "free" | "pro"
        let status: String?           // "active" | "canceled" | nil
        let is_lifetime_vip: Bool
        let current_period_end: String?
    }

    struct UsageInfo: Codable {
        let used: Int                 // 本周已用字符数
        let limit: Int                // 字符上限（-1 表示无限）
        let reset_at: String          // 下次重置时间
    }
}

// MARK: - TestableQuotaManager

/// A testable version of QuotaManager that replicates the exact logic
/// from QuotaManager.swift without requiring @Observable or singleton.
private class TestableQuotaManager {

    // MARK: - Properties

    private(set) var usedCharacters: Int = 0
    private(set) var limitCharacters: Int = 0
    private(set) var resetAt: Date? = nil
    private(set) var plan: String = "free"
    private(set) var isLifetimeVip: Bool = false

    // MARK: - Computed Properties

    /// 额度是否无限制（limit == -1）
    var isUnlimited: Bool {
        return limitCharacters == -1
    }

    /// 已使用百分比 (0.0 - 1.0)
    /// 无限制用户始终返回 0.0
    var usedPercentage: Double {
        guard !isUnlimited else { return 0.0 }
        guard limitCharacters > 0 else { return 0.0 }
        let percentage = Double(usedCharacters) / Double(limitCharacters)
        return min(max(percentage, 0.0), 1.0)
    }

    // MARK: - Update from ProfileResponse

    /// Exact same logic as QuotaManager.update(from:)
    func update(from response: TestProfileResponse) {
        self.usedCharacters = response.usage.used
        self.limitCharacters = response.usage.limit
        self.plan = response.subscription.plan
        self.isLifetimeVip = response.subscription.is_lifetime_vip

        // Parse ISO 8601 reset_at
        self.resetAt = Self.parseISO8601(response.usage.reset_at)
    }

    // MARK: - Private Helpers

    private static func parseISO8601(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
}

// MARK: - Random Generators for QuotaManager Tests

private struct QuotaTestGenerators {

    /// Generate a random plan string
    static func randomPlan() -> String {
        let plans = ["free", "pro"]
        return plans.randomElement()!
    }

    /// Generate a random subscription status
    static func randomStatus() -> String? {
        let statuses: [String?] = ["active", "canceled", nil]
        return statuses.randomElement()!
    }

    /// Generate a random used character count (non-negative)
    static func randomUsed() -> Int {
        return Int.random(in: 0...100000)
    }

    /// Generate a random limit: -1 (unlimited), 0, or positive
    static func randomLimit() -> Int {
        let choices: [() -> Int] = [
            { -1 },                          // unlimited (pro)
            { 0 },                           // edge case: zero limit
            { Int.random(in: 1...100000) }   // normal finite limit
        ]
        return choices.randomElement()!()
    }

    /// Generate a random limit for free users (positive)
    static func randomFreeLimit() -> Int {
        return Int.random(in: 1...100000)
    }

    /// Generate a random ISO 8601 date string
    static func randomResetAt() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let futureDate = Date().addingTimeInterval(TimeInterval(Int.random(in: 3600...604800)))
        return formatter.string(from: futureDate)
    }

    /// Generate a random current_period_end (may be nil)
    static func randomCurrentPeriodEnd() -> String? {
        if Bool.random() {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            let futureDate = Date().addingTimeInterval(TimeInterval(Int.random(in: 86400...2592000)))
            return formatter.string(from: futureDate)
        }
        return nil
    }

    /// Generate a complete random ProfileResponse
    static func randomProfileResponse() -> TestProfileResponse {
        let plan = randomPlan()
        let limit = plan == "pro" ? -1 : randomFreeLimit()
        return TestProfileResponse(
            subscription: TestProfileResponse.SubscriptionInfo(
                plan: plan,
                status: randomStatus(),
                is_lifetime_vip: plan == "pro" ? Bool.random() : false,
                current_period_end: randomCurrentPeriodEnd()
            ),
            usage: TestProfileResponse.UsageInfo(
                used: randomUsed(),
                limit: limit,
                reset_at: randomResetAt()
            )
        )
    }

    /// Generate a fully random ProfileResponse (any combination of used/limit)
    static func randomArbitraryProfileResponse() -> TestProfileResponse {
        let plan = randomPlan()
        return TestProfileResponse(
            subscription: TestProfileResponse.SubscriptionInfo(
                plan: plan,
                status: randomStatus(),
                is_lifetime_vip: Bool.random(),
                current_period_end: randomCurrentPeriodEnd()
            ),
            usage: TestProfileResponse.UsageInfo(
                used: randomUsed(),
                limit: randomLimit(),
                reset_at: randomResetAt()
            )
        )
    }
}

// MARK: - Property Tests

/// Property-based tests for QuotaManager
/// Feature: api-online-auth, Property 8: QuotaManager 状态与 ProfileResponse 一致
/// **Validates: Requirements 7.2, 7.3, 7.4, 7.5**
final class QuotaManagerPropertyTests: XCTestCase {

    private var quotaManager: TestableQuotaManager!

    override func setUp() {
        super.setUp()
        quotaManager = TestableQuotaManager()
    }

    override func tearDown() {
        quotaManager = nil
        super.tearDown()
    }

    // MARK: - Property 8: QuotaManager 状态与 ProfileResponse 一致

    /// Feature: api-online-auth, Property 8: QuotaManager 状态与 ProfileResponse 一致
    /// For any valid ProfileResponse, after QuotaManager.update(from:),
    /// usedCharacters should equal usage.used, limitCharacters should equal usage.limit,
    /// and isUnlimited should equal (usage.limit == -1).
    /// **Validates: Requirements 7.2, 7.3, 7.4, 7.5**
    func testProperty8_UsedCharactersMatchesProfileResponse() {
        PropertyTest.verify(
            "After update(from:), usedCharacters equals response.usage.used",
            iterations: 100
        ) { [self] in
            quotaManager = TestableQuotaManager()
            let response = QuotaTestGenerators.randomArbitraryProfileResponse()

            quotaManager.update(from: response)

            guard quotaManager.usedCharacters == response.usage.used else { return false }
            return true
        }
    }

    /// **Validates: Requirements 7.2, 7.3**
    func testProperty8_LimitCharactersMatchesProfileResponse() {
        PropertyTest.verify(
            "After update(from:), limitCharacters equals response.usage.limit",
            iterations: 100
        ) { [self] in
            quotaManager = TestableQuotaManager()
            let response = QuotaTestGenerators.randomArbitraryProfileResponse()

            quotaManager.update(from: response)

            guard quotaManager.limitCharacters == response.usage.limit else { return false }
            return true
        }
    }

    /// **Validates: Requirements 7.3**
    func testProperty8_IsUnlimitedMatchesNegativeOneLimit() {
        PropertyTest.verify(
            "After update(from:), isUnlimited equals (usage.limit == -1)",
            iterations: 100
        ) { [self] in
            quotaManager = TestableQuotaManager()
            let response = QuotaTestGenerators.randomArbitraryProfileResponse()

            quotaManager.update(from: response)

            let expectedUnlimited = (response.usage.limit == -1)
            guard quotaManager.isUnlimited == expectedUnlimited else { return false }
            return true
        }
    }

    /// **Validates: Requirements 7.2, 7.3, 7.4**
    func testProperty8_PlanMatchesProfileResponse() {
        PropertyTest.verify(
            "After update(from:), plan equals response.subscription.plan",
            iterations: 100
        ) { [self] in
            quotaManager = TestableQuotaManager()
            let response = QuotaTestGenerators.randomArbitraryProfileResponse()

            quotaManager.update(from: response)

            guard quotaManager.plan == response.subscription.plan else { return false }
            return true
        }
    }

    /// **Validates: Requirements 7.2**
    func testProperty8_IsLifetimeVipMatchesProfileResponse() {
        PropertyTest.verify(
            "After update(from:), isLifetimeVip equals response.subscription.is_lifetime_vip",
            iterations: 100
        ) { [self] in
            quotaManager = TestableQuotaManager()
            let response = QuotaTestGenerators.randomArbitraryProfileResponse()

            quotaManager.update(from: response)

            guard quotaManager.isLifetimeVip == response.subscription.is_lifetime_vip else { return false }
            return true
        }
    }

    /// Combined: All QuotaManager properties match ProfileResponse after update
    /// **Validates: Requirements 7.2, 7.3, 7.4, 7.5**
    func testProperty8_AllPropertiesMatchAfterUpdate() {
        PropertyTest.verify(
            "After update(from:), all QuotaManager properties match ProfileResponse",
            iterations: 100
        ) { [self] in
            quotaManager = TestableQuotaManager()
            let response = QuotaTestGenerators.randomArbitraryProfileResponse()

            quotaManager.update(from: response)

            // usedCharacters == usage.used
            guard quotaManager.usedCharacters == response.usage.used else { return false }

            // limitCharacters == usage.limit
            guard quotaManager.limitCharacters == response.usage.limit else { return false }

            // isUnlimited == (usage.limit == -1)
            let expectedUnlimited = (response.usage.limit == -1)
            guard quotaManager.isUnlimited == expectedUnlimited else { return false }

            // plan == subscription.plan
            guard quotaManager.plan == response.subscription.plan else { return false }

            // isLifetimeVip == subscription.is_lifetime_vip
            guard quotaManager.isLifetimeVip == response.subscription.is_lifetime_vip else { return false }

            return true
        }
    }

    // MARK: - usedPercentage Property Tests

    /// For unlimited users (limit == -1), usedPercentage should always be 0.0
    /// **Validates: Requirements 7.3, 7.4**
    func testProperty8_UsedPercentageZeroForUnlimited() {
        PropertyTest.verify(
            "For unlimited users (limit == -1), usedPercentage is 0.0",
            iterations: 100
        ) { [self] in
            quotaManager = TestableQuotaManager()
            let used = QuotaTestGenerators.randomUsed()
            let response = TestProfileResponse(
                subscription: TestProfileResponse.SubscriptionInfo(
                    plan: "pro",
                    status: "active",
                    is_lifetime_vip: Bool.random(),
                    current_period_end: nil
                ),
                usage: TestProfileResponse.UsageInfo(
                    used: used,
                    limit: -1,
                    reset_at: QuotaTestGenerators.randomResetAt()
                )
            )

            quotaManager.update(from: response)

            guard quotaManager.usedPercentage == 0.0 else { return false }
            return true
        }
    }

    /// For finite limits, usedPercentage should be clamped to [0.0, 1.0]
    /// **Validates: Requirements 7.4**
    func testProperty8_UsedPercentageClampedForFiniteLimits() {
        PropertyTest.verify(
            "For finite limits, usedPercentage is clamped to [0.0, 1.0]",
            iterations: 100
        ) { [self] in
            quotaManager = TestableQuotaManager()
            let used = Int.random(in: 0...200000)
            let limit = Int.random(in: 1...100000)
            let response = TestProfileResponse(
                subscription: TestProfileResponse.SubscriptionInfo(
                    plan: "free",
                    status: "active",
                    is_lifetime_vip: false,
                    current_period_end: nil
                ),
                usage: TestProfileResponse.UsageInfo(
                    used: used,
                    limit: limit,
                    reset_at: QuotaTestGenerators.randomResetAt()
                )
            )

            quotaManager.update(from: response)

            guard quotaManager.usedPercentage >= 0.0 else { return false }
            guard quotaManager.usedPercentage <= 1.0 else { return false }
            return true
        }
    }

    /// For finite limits with used < limit, usedPercentage should equal used/limit
    /// **Validates: Requirements 7.4**
    func testProperty8_UsedPercentageCorrectForNormalUsage() {
        PropertyTest.verify(
            "For used < limit, usedPercentage equals Double(used)/Double(limit)",
            iterations: 100
        ) { [self] in
            quotaManager = TestableQuotaManager()
            let limit = Int.random(in: 1...100000)
            let used = Int.random(in: 0..<limit)
            let response = TestProfileResponse(
                subscription: TestProfileResponse.SubscriptionInfo(
                    plan: "free",
                    status: "active",
                    is_lifetime_vip: false,
                    current_period_end: nil
                ),
                usage: TestProfileResponse.UsageInfo(
                    used: used,
                    limit: limit,
                    reset_at: QuotaTestGenerators.randomResetAt()
                )
            )

            quotaManager.update(from: response)

            let expected = Double(used) / Double(limit)
            guard abs(quotaManager.usedPercentage - expected) < 0.0001 else { return false }
            return true
        }
    }

    /// Edge case: limit == 0 should result in usedPercentage == 0.0
    /// **Validates: Requirements 7.4**
    func testProperty8_UsedPercentageZeroForZeroLimit() {
        PropertyTest.verify(
            "For limit == 0, usedPercentage is 0.0",
            iterations: 100
        ) { [self] in
            quotaManager = TestableQuotaManager()
            let used = QuotaTestGenerators.randomUsed()
            let response = TestProfileResponse(
                subscription: TestProfileResponse.SubscriptionInfo(
                    plan: "free",
                    status: "active",
                    is_lifetime_vip: false,
                    current_period_end: nil
                ),
                usage: TestProfileResponse.UsageInfo(
                    used: used,
                    limit: 0,
                    reset_at: QuotaTestGenerators.randomResetAt()
                )
            )

            quotaManager.update(from: response)

            guard quotaManager.usedPercentage == 0.0 else { return false }
            return true
        }
    }

    /// Edge case: used > limit should clamp usedPercentage to 1.0
    /// **Validates: Requirements 7.4**
    func testProperty8_UsedPercentageClampsWhenOverLimit() {
        PropertyTest.verify(
            "For used > limit (finite), usedPercentage is clamped to 1.0",
            iterations: 100
        ) { [self] in
            quotaManager = TestableQuotaManager()
            let limit = Int.random(in: 1...50000)
            let used = limit + Int.random(in: 1...50000) // used > limit
            let response = TestProfileResponse(
                subscription: TestProfileResponse.SubscriptionInfo(
                    plan: "free",
                    status: "active",
                    is_lifetime_vip: false,
                    current_period_end: nil
                ),
                usage: TestProfileResponse.UsageInfo(
                    used: used,
                    limit: limit,
                    reset_at: QuotaTestGenerators.randomResetAt()
                )
            )

            quotaManager.update(from: response)

            guard quotaManager.usedPercentage == 1.0 else { return false }
            return true
        }
    }
}
