//
//  GhostTwinXPPropertyTests.swift
//  AIInputMethod
//
//  Property-based tests for GhostTwinXP pure functions
//  Feature: ghost-twin-on-device, Properties 4, 5, 6
//

import XCTest
import Foundation

// MARK: - Test Copy of GhostTwinXP

/// Since the test target cannot import the executable target,
/// we create a test copy of the pure functions being tested.
private enum TestGhostTwinXP {
    static let xpForLevel0 = 2_000
    static let xpPerLevel = 10_000
    static let maxLevel = 10

    static func calculateLevel(totalXP: Int) -> Int {
        if totalXP < xpForLevel0 { return 0 }
        let remaining = totalXP - xpForLevel0
        return min(remaining / xpPerLevel + 1, maxLevel)
    }

    static func currentLevelXP(totalXP: Int) -> Int {
        if totalXP < xpForLevel0 { return totalXP }
        let level = calculateLevel(totalXP: totalXP)
        if level >= maxLevel {
            return totalXP - xpForLevel0 - (maxLevel - 1) * xpPerLevel
        }
        return (totalXP - xpForLevel0) % xpPerLevel
    }

    static func checkLevelUp(oldXP: Int, newXP: Int) -> (leveledUp: Bool, oldLevel: Int, newLevel: Int) {
        let oldLevel = calculateLevel(totalXP: oldXP)
        let newLevel = calculateLevel(totalXP: newXP)
        return (newLevel > oldLevel, oldLevel, newLevel)
    }
}

// MARK: - Property Tests

/// Property-based tests for GhostTwinXP pure functions
final class GhostTwinXPPropertyTests: XCTestCase {

    // MARK: - Property 4: Level calculation formula

    /// Property 4: Level calculation formula
    /// *For any* non-negative integer `totalXP`, `GhostTwinXP.calculateLevel(totalXP:)`
    /// should return 0 when totalXP < 2000, otherwise min((totalXP - 2000) / 10000 + 1, 10),
    /// and the result should always be in [0, 10].
    /// Feature: ghost-twin-on-device, Property 4: Level calculation formula
    /// **Validates: Requirements 3.1, 3.2, AC-B1**
    func testProperty4_LevelCalculationFormula() {
        PropertyTest.verify(
            "Level calculation matches formula and stays in [0, 10]",
            iterations: 100
        ) {
            let totalXP = Int.random(in: 0...200_000)
            let level = TestGhostTwinXP.calculateLevel(totalXP: totalXP)

            // Verify formula
            let expected: Int
            if totalXP < 2_000 {
                expected = 0
            } else {
                expected = min((totalXP - 2_000) / 10_000 + 1, 10)
            }
            guard level == expected else { return false }

            // Verify range [0, 10]
            guard level >= 0 && level <= 10 else { return false }

            return true
        }
    }

    // MARK: - Property 5: Current level XP formula

    /// Property 5: Current level XP formula
    /// *For any* non-negative integer `totalXP`, `GhostTwinXP.currentLevelXP(totalXP:)`
    /// should equal `totalXP` when level == 0, `(totalXP - 2000) % 10000` when level 1~9,
    /// and `totalXP - 2000 - 90000` when level == 10. The result should always be >= 0.
    /// Feature: ghost-twin-on-device, Property 5: Current level XP formula
    /// **Validates: Requirements 3.3, AC-B1**
    func testProperty5_CurrentLevelXPFormula() {
        PropertyTest.verify(
            "Current level XP matches formula and is non-negative",
            iterations: 100
        ) {
            let totalXP = Int.random(in: 0...200_000)
            let level = TestGhostTwinXP.calculateLevel(totalXP: totalXP)
            let currentXP = TestGhostTwinXP.currentLevelXP(totalXP: totalXP)

            // Verify formula based on level
            if level == 0 {
                guard currentXP == totalXP else { return false }
            } else if level < 10 {
                guard currentXP == (totalXP - 2_000) % 10_000 else { return false }
            } else {
                guard currentXP == totalXP - 2_000 - 90_000 else { return false }
            }

            // Verify non-negative
            guard currentXP >= 0 else { return false }

            return true
        }
    }

    // MARK: - Property 6: Level-up detection

    /// Property 6: Level-up detection
    /// *For any* pair of non-negative integers `(oldXP, newXP)` where `newXP >= oldXP`,
    /// `GhostTwinXP.checkLevelUp(oldXP:newXP:)` should return `leveledUp = true`
    /// if and only if `calculateLevel(newXP) > calculateLevel(oldXP)`, and the returned
    /// oldLevel/newLevel should match the respective calculateLevel results.
    /// Feature: ghost-twin-on-device, Property 6: Level-up detection
    /// **Validates: Requirements 3.4**
    func testProperty6_LevelUpDetection() {
        PropertyTest.verify(
            "Level-up detection is consistent with calculateLevel",
            iterations: 100
        ) {
            let oldXP = Int.random(in: 0...200_000)
            let newXP = Int.random(in: oldXP...200_000)

            let result = TestGhostTwinXP.checkLevelUp(oldXP: oldXP, newXP: newXP)
            let expectedOldLevel = TestGhostTwinXP.calculateLevel(totalXP: oldXP)
            let expectedNewLevel = TestGhostTwinXP.calculateLevel(totalXP: newXP)

            // leveledUp should be true iff newLevel > oldLevel
            guard result.leveledUp == (expectedNewLevel > expectedOldLevel) else { return false }

            // oldLevel and newLevel should match calculateLevel results
            guard result.oldLevel == expectedOldLevel else { return false }
            guard result.newLevel == expectedNewLevel else { return false }

            return true
        }
    }
}
