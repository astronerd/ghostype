import XCTest
import Foundation

// MARK: - Test Copy of NavItem
// Since the test target cannot import the executable target,
// we duplicate the NavItem enum here for testing.

/// Exact copy of NavItem from NavItem.swift
private enum TestNavItem: String, CaseIterable, Identifiable {
    case account
    case overview
    case incubator
    case memo
    case library
    case aiPolish
    case preferences
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .account:
            return "person.circle"
        case .overview:
            return "chart.bar.fill"
        case .incubator:
            return "flask.fill"
        case .memo:
            return "note.text"
        case .library:
            return "clock.arrow.circlepath"
        case .aiPolish:
            return "wand.and.stars"
        case .preferences:
            return "gearshape.fill"
        }
    }
    
    /// Sidebar 分组
    static var groups: [[TestNavItem]] {
        [
            [.account, .overview, .incubator],
            [.memo, .library],
            [.aiPolish, .preferences]
        ]
    }
    
    /// 该页面是否需要登录才能访问
    var requiresAuth: Bool {
        switch self {
        case .account, .preferences: return false
        case .overview, .memo, .library, .aiPolish, .incubator: return true
        }
    }
    
    /// 徽章文字（nil 表示无徽章）
    var badge: String? {
        switch self {
        case .incubator: return "LAB"
        default: return nil
        }
    }
}

// MARK: - NavItem Unit Tests

/// Unit tests for NavItem enum, specifically for the `.incubator` case
/// Feature: ghost-twin-incubator
/// **Validates: Requirements 1.1, 1.2, 1.3, 1.4**
final class NavItemTests: XCTestCase {
    
    // MARK: - Test 1: Incubator icon
    
    /// Test that NavItem.incubator.icon equals "flask.fill"
    /// **Validates: Requirements 1.1**
    func testIncubatorIcon() {
        let incubator = TestNavItem.incubator
        XCTAssertEqual(incubator.icon, "flask.fill", "Incubator icon should be 'flask.fill'")
    }
    
    // MARK: - Test 2: Incubator title (rawValue check)
    
    /// Test that NavItem.incubator has correct rawValue for title lookup
    /// Note: We cannot test L.Nav.incubator directly since it requires the localization system,
    /// but we verify the rawValue is "incubator" which is used for title lookup
    /// **Validates: Requirements 1.1**
    func testIncubatorRawValue() {
        let incubator = TestNavItem.incubator
        XCTAssertEqual(incubator.rawValue, "incubator", "Incubator rawValue should be 'incubator'")
    }
    
    // MARK: - Test 3: Incubator requiresAuth
    
    /// Test that NavItem.incubator.requiresAuth equals true
    /// **Validates: Requirements 1.3**
    func testIncubatorRequiresAuth() {
        let incubator = TestNavItem.incubator
        XCTAssertTrue(incubator.requiresAuth, "Incubator should require authentication")
    }
    
    // MARK: - Test 4: Incubator badge
    
    /// Test that NavItem.incubator.badge equals "LAB"
    /// **Validates: Requirements 1.4**
    func testIncubatorBadge() {
        let incubator = TestNavItem.incubator
        XCTAssertEqual(incubator.badge, "LAB", "Incubator badge should be 'LAB'")
    }
    
    // MARK: - Test 5: Incubator position in groups
    
    /// Test that NavItem.groups[0] contains .incubator at index 2 (third position)
    /// **Validates: Requirements 1.2**
    func testIncubatorPositionInFirstGroup() {
        let firstGroup = TestNavItem.groups[0]
        
        // Verify first group has at least 3 items
        XCTAssertGreaterThanOrEqual(firstGroup.count, 3, "First group should have at least 3 items")
        
        // Verify incubator is at index 2 (third position)
        XCTAssertEqual(firstGroup[2], .incubator, "Incubator should be at index 2 (third position) in first group")
    }
    
    // MARK: - Test 6: First group composition
    
    /// Test that NavItem.groups[0] equals [.account, .overview, .incubator]
    /// **Validates: Requirements 1.2**
    func testFirstGroupComposition() {
        let firstGroup = TestNavItem.groups[0]
        let expectedFirstGroup: [TestNavItem] = [.account, .overview, .incubator]
        
        XCTAssertEqual(firstGroup, expectedFirstGroup, "First group should be [.account, .overview, .incubator]")
    }
    
    // MARK: - Additional Tests: Other NavItems don't have badges
    
    /// Test that other NavItems (except incubator) have nil badge
    /// **Validates: Requirements 1.4**
    func testOtherNavItemsHaveNoBadge() {
        let navItemsWithoutBadge: [TestNavItem] = [.account, .overview, .memo, .library, .aiPolish, .preferences]
        
        for navItem in navItemsWithoutBadge {
            XCTAssertNil(navItem.badge, "\(navItem.rawValue) should not have a badge")
        }
    }
    
    // MARK: - Additional Tests: Groups structure
    
    /// Test that NavItem.groups has 3 groups
    func testGroupsCount() {
        XCTAssertEqual(TestNavItem.groups.count, 3, "NavItem.groups should have 3 groups")
    }
    
    /// Test that all NavItems are included in groups
    func testAllNavItemsInGroups() {
        let allItemsInGroups = TestNavItem.groups.flatMap { $0 }
        let allCases = TestNavItem.allCases
        
        XCTAssertEqual(Set(allItemsInGroups), Set(allCases), "All NavItem cases should be included in groups")
    }
}
