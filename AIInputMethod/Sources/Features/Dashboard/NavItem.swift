import Foundation

// MARK: - NavItem

/// 导航项枚举
/// 定义 Dashboard Sidebar 中的导航选项
enum NavItem: String, CaseIterable, Identifiable {
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
    
    /// 本地化标题
    var title: String {
        switch self {
        case .account:
            return L.Nav.account
        case .overview:
            return L.Nav.overview
        case .incubator:
            return L.Nav.incubator
        case .memo:
            return L.Nav.memo
        case .library:
            return L.Nav.library
        case .aiPolish:
            return L.Nav.aiPolish
        case .preferences:
            return L.Nav.preferences
        }
    }
    
    /// Sidebar 分组
    static var groups: [[NavItem]] {
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
