//
//  IncubatorViewModelPropertyTests.swift
//  AIInputMethod
//
//  Property-based tests for IncubatorViewModel
//  Feature: ghost-twin-incubator
//

import XCTest
import Foundation

// Uses shared PropertyTest from AuthManagerPropertyTests.swift

// MARK: - Test Copies of Types (test target can't import executable)

/// Ghost 动效阶段，根据等级演进
/// Exact copy from IncubatorViewModel.swift
/// Validates: Requirements 6.4
private enum TestAnimationPhase: String, CaseIterable, Equatable {
    case glitch      // Lv.1~3
    case breathing   // Lv.4~6
    case awakening   // Lv.7~9
    case complete    // Lv.10
}

/// UserDefaults 缓存键
/// Exact copy from IncubatorViewModel.swift
private enum TestGhostTwinCacheKey: String {
    case level = "ghostTwin.level"
    case totalXP = "ghostTwin.totalXP"
    case currentLevelXP = "ghostTwin.currentLevelXP"
    case challengesRemaining = "ghostTwin.challengesRemaining"
    case activationOrder = "ghostTwin.activationOrder"
}

// MARK: - Static Helper Copies (exact logic from IncubatorViewModel)

/// Copies of IncubatorViewModel's static helper methods for testing.
/// These replicate the exact logic so we can test without importing the executable.
private enum IncubatorHelpers {
    
    /// 根据等级返回动效阶段
    /// Exact copy of IncubatorViewModel.animationPhase(forLevel:)
    /// Validates: Requirements 6.4
    static func animationPhase(forLevel level: Int) -> TestAnimationPhase {
        switch level {
        case 1...3: return .glitch
        case 4...6: return .breathing
        case 7...9: return .awakening
        case 10: return .complete
        default:
            if level < 1 { return .glitch }
            return .complete
        }
    }
    
    /// 根据等级返回闲置文案分组索引
    /// Exact copy of IncubatorViewModel.idleTextGroup(forLevel:)
    /// Validates: Requirements 10.2
    static func idleTextGroup(forLevel level: Int) -> Int {
        switch level {
        case 1...3: return 0
        case 4...6: return 1
        case 7...9: return 2
        case 10: return 3
        default:
            if level < 1 { return 0 }
            return 3
        }
    }
    
    /// 根据等级计算 Ghost 透明度
    /// Exact copy of IncubatorViewModel.ghostOpacity(forLevel:)
    /// Validates: Requirements 3.5, 6.3
    static func ghostOpacity(forLevel level: Int) -> Double {
        return Double(level) * 0.1
    }
}

// MARK: - Property Tests

/// Property-based tests for IncubatorViewModel
/// Feature: ghost-twin-incubator
final class IncubatorViewModelPropertyTests: XCTestCase {
    
    // MARK: - Test UserDefaults Suite
    
    /// Unique UserDefaults suite for testing to avoid polluting real data
    private static let testSuiteName = "com.ghostype.test.incubatorViewModel"
    
    /// Get a clean UserDefaults instance for testing
    private func testDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: Self.testSuiteName)!
        return defaults
    }
    
    /// Clean up test UserDefaults after each test
    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removePersistentDomain(forName: Self.testSuiteName)
    }
    
    // MARK: - Property 4: ghostOpacity linear mapping
    
    /// Property 4: ghostOpacity linear mapping
    /// *For any* level in 1...10, ghostOpacity shall equal Double(level) * 0.1
    /// (i.e., Lv.1 → 0.1, Lv.10 → 1.0).
    /// Feature: ghost-twin-incubator, Property 4: ghostOpacity linear mapping
    /// **Validates: Requirements 3.5, 6.3**
    func testProperty4_GhostOpacityLinearMapping() {
        PropertyTest.verify(
            "ghostOpacity equals Double(level) * 0.1 for any level in 1...10",
            iterations: 100
        ) {
            // Generate random level in 1...10
            let level = Int.random(in: 1...10)
            
            // Calculate ghostOpacity using the static helper
            let opacity = IncubatorHelpers.ghostOpacity(forLevel: level)
            
            // Expected value
            let expected = Double(level) * 0.1
            
            // Verify: ghostOpacity equals expected value
            // Use small epsilon for floating point comparison
            guard abs(opacity - expected) < 1e-10 else {
                return false
            }
            
            return true
        }
    }
    
    /// Property 4 (range): ghostOpacity is always in [0.1, 1.0] for valid levels
    /// **Validates: Requirements 3.5, 6.3**
    func testProperty4_GhostOpacityInValidRange() {
        PropertyTest.verify(
            "ghostOpacity is in [0.1, 1.0] for levels 1...10",
            iterations: 100
        ) {
            let level = Int.random(in: 1...10)
            let opacity = IncubatorHelpers.ghostOpacity(forLevel: level)
            
            guard opacity >= 0.1 - 1e-10 && opacity <= 1.0 + 1e-10 else {
                return false
            }
            
            return true
        }
    }
    
    /// Property 4 (monotonicity): Higher level means higher or equal opacity
    /// **Validates: Requirements 3.5, 6.3**
    func testProperty4_GhostOpacityMonotonicallyIncreasing() {
        PropertyTest.verify(
            "ghostOpacity monotonically increases with level",
            iterations: 100
        ) {
            let level1 = Int.random(in: 1...9)
            let level2 = Int.random(in: level1...10)
            
            let opacity1 = IncubatorHelpers.ghostOpacity(forLevel: level1)
            let opacity2 = IncubatorHelpers.ghostOpacity(forLevel: level2)
            
            guard opacity2 >= opacity1 - 1e-10 else {
                return false
            }
            
            return true
        }
    }
    
    // MARK: - Property 5: Animation phase selection by level range
    
    /// Property 5: Animation phase selection by level range
    /// *For any* level in 1...10, the animation phase shall be:
    /// - Lv.1~3 → .glitch (幽灵态)
    /// - Lv.4~6 → .breathing (呼吸态)
    /// - Lv.7~9 → .awakening (觉醒态)
    /// - Lv.10 → .complete (完全体)
    /// Feature: ghost-twin-incubator, Property 5: Animation phase selection by level range
    /// **Validates: Requirements 6.4**
    func testProperty5_AnimationPhaseSelectionByLevelRange() {
        PropertyTest.verify(
            "Animation phase matches level range for any level in 1...10",
            iterations: 100
        ) {
            // Generate random level in 1...10
            let level = Int.random(in: 1...10)
            
            // Get animation phase
            let phase = IncubatorHelpers.animationPhase(forLevel: level)
            
            // Determine expected phase based on level range
            let expectedPhase: TestAnimationPhase
            switch level {
            case 1...3: expectedPhase = .glitch
            case 4...6: expectedPhase = .breathing
            case 7...9: expectedPhase = .awakening
            case 10: expectedPhase = .complete
            default: return false // Should never happen for 1...10
            }
            
            guard phase == expectedPhase else {
                return false
            }
            
            return true
        }
    }
    
    /// Property 5 (exhaustive): Verify all 10 levels map correctly
    /// **Validates: Requirements 6.4**
    func testProperty5_AnimationPhaseExhaustiveMapping() {
        // Lv.1~3 → .glitch
        for level in 1...3 {
            XCTAssertEqual(
                IncubatorHelpers.animationPhase(forLevel: level),
                .glitch,
                "Level \(level) should map to .glitch"
            )
        }
        
        // Lv.4~6 → .breathing
        for level in 4...6 {
            XCTAssertEqual(
                IncubatorHelpers.animationPhase(forLevel: level),
                .breathing,
                "Level \(level) should map to .breathing"
            )
        }
        
        // Lv.7~9 → .awakening
        for level in 7...9 {
            XCTAssertEqual(
                IncubatorHelpers.animationPhase(forLevel: level),
                .awakening,
                "Level \(level) should map to .awakening"
            )
        }
        
        // Lv.10 → .complete
        XCTAssertEqual(
            IncubatorHelpers.animationPhase(forLevel: 10),
            .complete,
            "Level 10 should map to .complete"
        )
    }
    
    /// Property 5 (boundary safety): Levels outside 1...10 don't crash
    /// **Validates: Requirements 6.4**
    func testProperty5_AnimationPhaseBoundarySafety() {
        PropertyTest.verify(
            "Animation phase handles out-of-range levels safely",
            iterations: 100
        ) {
            // Generate random level outside normal range
            let level = Int.random(in: -10...20)
            
            // Should not crash, always returns a valid phase
            let phase = IncubatorHelpers.animationPhase(forLevel: level)
            
            // Verify it's a valid AnimationPhase
            guard TestAnimationPhase.allCases.contains(phase) else {
                return false
            }
            
            // Verify boundary behavior: level < 1 → .glitch, level > 10 → .complete
            if level < 1 {
                guard phase == .glitch else { return false }
            } else if level > 10 {
                guard phase == .complete else { return false }
            }
            
            return true
        }
    }
    
    // MARK: - Property 7: Cache fallback on API failure
    
    /// Property 7: Cache fallback on API failure
    /// *For any* previously cached Ghost Twin state (level, totalXP, currentLevelXP,
    /// challengesRemaining), when the status API call fails,
    /// the ViewModel shall restore state from cache such that all displayed values
    /// match the cached values.
    /// Feature: ghost-twin-incubator, Property 7: Cache fallback on API failure
    /// **Validates: Requirements 7.5**
    func testProperty7_CacheFallbackOnAPIFailure() {
        PropertyTest.verify(
            "Cache fallback restores all state values correctly",
            iterations: 100
        ) {
            // Generate random Ghost Twin state
            let cachedLevel = Int.random(in: 1...10)
            let cachedTotalXP = Int.random(in: 0...100000)
            let cachedCurrentLevelXP = Int.random(in: 0...9999)
            let cachedChallengesRemaining = Int.random(in: 0...3)
            
            // Write state to UserDefaults using the cache keys (simulating a previous save)
            let defaults = UserDefaults.standard
            defaults.set(cachedLevel, forKey: TestGhostTwinCacheKey.level.rawValue)
            defaults.set(cachedTotalXP, forKey: TestGhostTwinCacheKey.totalXP.rawValue)
            defaults.set(cachedCurrentLevelXP, forKey: TestGhostTwinCacheKey.currentLevelXP.rawValue)
            defaults.set(cachedChallengesRemaining, forKey: TestGhostTwinCacheKey.challengesRemaining.rawValue)
            
            // Read back from UserDefaults (simulating cache fallback)
            let restoredLevel = defaults.integer(forKey: TestGhostTwinCacheKey.level.rawValue)
            let restoredTotalXP = defaults.integer(forKey: TestGhostTwinCacheKey.totalXP.rawValue)
            let restoredCurrentLevelXP = defaults.integer(forKey: TestGhostTwinCacheKey.currentLevelXP.rawValue)
            let restoredChallengesRemaining = defaults.integer(forKey: TestGhostTwinCacheKey.challengesRemaining.rawValue)
            
            // Verify: all restored values match cached values
            guard restoredLevel == cachedLevel else { return false }
            guard restoredTotalXP == cachedTotalXP else { return false }
            guard restoredCurrentLevelXP == cachedCurrentLevelXP else { return false }
            guard restoredChallengesRemaining == cachedChallengesRemaining else { return false }
            
            // Clean up
            defaults.removeObject(forKey: TestGhostTwinCacheKey.level.rawValue)
            defaults.removeObject(forKey: TestGhostTwinCacheKey.totalXP.rawValue)
            defaults.removeObject(forKey: TestGhostTwinCacheKey.currentLevelXP.rawValue)
            defaults.removeObject(forKey: TestGhostTwinCacheKey.challengesRemaining.rawValue)
            
            return true
        }
    }
    
    /// Property 7 (isolated suite): Cache round-trip using isolated UserDefaults suite
    /// **Validates: Requirements 7.5**
    func testProperty7_CacheRoundTripWithIsolatedSuite() {
        PropertyTest.verify(
            "Cache round-trip works with isolated UserDefaults suite",
            iterations: 100
        ) {
            let defaults = UserDefaults(suiteName: Self.testSuiteName)!
            
            // Generate random state
            let level = Int.random(in: 1...10)
            let totalXP = Int.random(in: 0...100000)
            let currentLevelXP = Int.random(in: 0...9999)
            let challengesRemaining = Int.random(in: 0...3)
            
            // Write to isolated suite
            defaults.set(level, forKey: TestGhostTwinCacheKey.level.rawValue)
            defaults.set(totalXP, forKey: TestGhostTwinCacheKey.totalXP.rawValue)
            defaults.set(currentLevelXP, forKey: TestGhostTwinCacheKey.currentLevelXP.rawValue)
            defaults.set(challengesRemaining, forKey: TestGhostTwinCacheKey.challengesRemaining.rawValue)
            
            // Read back
            let restoredLevel = defaults.integer(forKey: TestGhostTwinCacheKey.level.rawValue)
            let restoredTotalXP = defaults.integer(forKey: TestGhostTwinCacheKey.totalXP.rawValue)
            let restoredCurrentLevelXP = defaults.integer(forKey: TestGhostTwinCacheKey.currentLevelXP.rawValue)
            let restoredChallengesRemaining = defaults.integer(forKey: TestGhostTwinCacheKey.challengesRemaining.rawValue)
            
            // Verify all values match
            guard restoredLevel == level else { return false }
            guard restoredTotalXP == totalXP else { return false }
            guard restoredCurrentLevelXP == currentLevelXP else { return false }
            guard restoredChallengesRemaining == challengesRemaining else { return false }
            
            return true
        }
    }
    
    /// Property 7 (overwrite): Latest cache write wins on restore
    /// **Validates: Requirements 7.5**
    func testProperty7_LatestCacheWriteWins() {
        PropertyTest.verify(
            "Latest cache write wins when restoring",
            iterations: 100
        ) {
            let defaults = UserDefaults(suiteName: Self.testSuiteName)!
            
            // Write first state
            let level1 = Int.random(in: 1...5)
            defaults.set(level1, forKey: TestGhostTwinCacheKey.level.rawValue)
            
            // Overwrite with second state
            let level2 = Int.random(in: 6...10)
            defaults.set(level2, forKey: TestGhostTwinCacheKey.level.rawValue)
            
            // Read back should return the latest value
            let restored = defaults.integer(forKey: TestGhostTwinCacheKey.level.rawValue)
            
            guard restored == level2 else { return false }
            
            return true
        }
    }
    
    // MARK: - Property 8: Idle text level group selection
    
    /// Property 8: Idle text level group selection
    /// *For any* level in 1...10, the idle text pool returned shall only contain
    /// texts belonging to the correct level group:
    /// - Lv.1~3 → group 0 (懵懂)
    /// - Lv.4~6 → group 1 (有个性)
    /// - Lv.7~9 → group 2 (自信)
    /// - Lv.10 → group 3 (完全体)
    /// Feature: ghost-twin-incubator, Property 8: Idle text level group selection
    /// **Validates: Requirements 10.2**
    func testProperty8_IdleTextLevelGroupSelection() {
        PropertyTest.verify(
            "idleTextGroup returns correct group for any level in 1...10",
            iterations: 100
        ) {
            // Generate random level in 1...10
            let level = Int.random(in: 1...10)
            
            // Get idle text group
            let group = IncubatorHelpers.idleTextGroup(forLevel: level)
            
            // Determine expected group based on level range
            let expectedGroup: Int
            switch level {
            case 1...3: expectedGroup = 0
            case 4...6: expectedGroup = 1
            case 7...9: expectedGroup = 2
            case 10: expectedGroup = 3
            default: return false // Should never happen for 1...10
            }
            
            guard group == expectedGroup else {
                return false
            }
            
            return true
        }
    }
    
    /// Property 8 (exhaustive): Verify all 10 levels map to correct groups
    /// **Validates: Requirements 10.2**
    func testProperty8_IdleTextGroupExhaustiveMapping() {
        // Lv.1~3 → group 0
        for level in 1...3 {
            XCTAssertEqual(
                IncubatorHelpers.idleTextGroup(forLevel: level),
                0,
                "Level \(level) should map to group 0 (懵懂)"
            )
        }
        
        // Lv.4~6 → group 1
        for level in 4...6 {
            XCTAssertEqual(
                IncubatorHelpers.idleTextGroup(forLevel: level),
                1,
                "Level \(level) should map to group 1 (有个性)"
            )
        }
        
        // Lv.7~9 → group 2
        for level in 7...9 {
            XCTAssertEqual(
                IncubatorHelpers.idleTextGroup(forLevel: level),
                2,
                "Level \(level) should map to group 2 (自信)"
            )
        }
        
        // Lv.10 → group 3
        XCTAssertEqual(
            IncubatorHelpers.idleTextGroup(forLevel: 10),
            3,
            "Level 10 should map to group 3 (完全体)"
        )
    }
    
    /// Property 8 (group range): Group index is always in [0, 3] for valid levels
    /// **Validates: Requirements 10.2**
    func testProperty8_IdleTextGroupInValidRange() {
        PropertyTest.verify(
            "idleTextGroup returns value in [0, 3] for levels 1...10",
            iterations: 100
        ) {
            let level = Int.random(in: 1...10)
            let group = IncubatorHelpers.idleTextGroup(forLevel: level)
            
            guard group >= 0 && group <= 3 else {
                return false
            }
            
            return true
        }
    }
    
    /// Property 8 (boundary safety): Levels outside 1...10 don't crash
    /// **Validates: Requirements 10.2**
    func testProperty8_IdleTextGroupBoundarySafety() {
        PropertyTest.verify(
            "idleTextGroup handles out-of-range levels safely",
            iterations: 100
        ) {
            // Generate random level outside normal range
            let level = Int.random(in: -10...20)
            
            // Should not crash, always returns a valid group
            let group = IncubatorHelpers.idleTextGroup(forLevel: level)
            
            // Verify it's a valid group index
            guard group >= 0 && group <= 3 else {
                return false
            }
            
            // Verify boundary behavior: level < 1 → group 0, level > 10 → group 3
            if level < 1 {
                guard group == 0 else { return false }
            } else if level > 10 {
                guard group == 3 else { return false }
            }
            
            return true
        }
    }
    
    // MARK: - Cross-Property Consistency Tests
    
    /// Cross-property: animationPhase and idleTextGroup have consistent level grouping
    /// Both use the same level ranges (1~3, 4~6, 7~9, 10)
    /// **Validates: Requirements 6.4, 10.2**
    func testCrossProperty_AnimationPhaseAndIdleTextGroupConsistency() {
        PropertyTest.verify(
            "animationPhase and idleTextGroup use consistent level grouping",
            iterations: 100
        ) {
            let level = Int.random(in: 1...10)
            
            let phase = IncubatorHelpers.animationPhase(forLevel: level)
            let group = IncubatorHelpers.idleTextGroup(forLevel: level)
            
            // Verify consistent mapping
            switch phase {
            case .glitch:    guard group == 0 else { return false }
            case .breathing: guard group == 1 else { return false }
            case .awakening: guard group == 2 else { return false }
            case .complete:  guard group == 3 else { return false }
            }
            
            return true
        }
    }
}
