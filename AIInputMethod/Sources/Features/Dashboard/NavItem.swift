import Foundation

// MARK: - NavItem

/// 导航项枚举
/// 定义 Dashboard Sidebar 中的导航选项
enum NavItem: String, CaseIterable, Identifiable {
    case account
    case overview
    case incubator
    case skills
    case memo
    case memoSync
    case library
    case aiPolish
    case debugData
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
        case .skills:
            return "sparkles"
        case .memo:
            return "note.text"
        case .memoSync:
            return "arrow.triangle.2.circlepath"
        case .library:
            return "clock.arrow.circlepath"
        case .aiPolish:
            return "wand.and.stars"
        case .debugData:
            return "ladybug"
        case .preferences:
            return "gearshape.fill"
        }
    }
    
    /// 本地化标题
    var title: String {
        switch self {
        case .account:
            return L.Nav.account
        case .overview:
            return L.Nav.overview
        case .incubator:
            return L.Nav.incubator
        case .skills:
            return L.Nav.skills
        case .memo:
            return L.Nav.memo
        case .memoSync:
            return L.MemoSync.title
        case .library:
            return L.Nav.library
        case .aiPolish:
            return L.Nav.aiPolish
        case .debugData:
            return "Debug Data"
        case .preferences:
            return L.Nav.preferences
        }
    }
    
    /// Sidebar 分组
    static var groups: [[NavItem]] {
        [
            [.account, .overview, .incubator],
            [.skills, .memo, .memoSync, .library],
            [.aiPolish, .debugData, .preferences]
        ]
    }
    
    /// 该页面是否需要登录才能访问
    var requiresAuth: Bool {
        switch self {
        case .account, .preferences: return false
        case .overview, .memo, .memoSync, .library, .aiPolish, .incubator, .skills, .debugData: return true
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
