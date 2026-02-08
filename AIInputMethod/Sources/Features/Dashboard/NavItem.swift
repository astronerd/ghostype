import Foundation

// MARK: - NavItem

/// 导航项枚举
/// 定义 Dashboard Sidebar 中的导航选项
/// - overview: 概览页，显示今日统计和数据可视化
/// - memo: 随心记，Flomo 风格便签展示
/// - library: 历史库，管理语音输入记录
/// - preferences: 偏好设置，配置应用选项
enum NavItem: String, CaseIterable, Identifiable {
    case overview = "概览"
    case memo = "随心记"      // NEW - 随心记页面
    case library = "历史库"
    case aiPolish = "AI 润色"  // NEW - AI 润色页面
    case preferences = "偏好设置"
    
    // MARK: - Identifiable
    
    /// 唯一标识符，使用 rawValue（中文标签）
    var id: String { rawValue }
    
    // MARK: - Properties
    
    /// SF Symbol 图标名称
    /// 返回与导航项对应的系统图标
    var icon: String {
        switch self {
        case .overview:
            return "chart.bar.fill"
        case .memo:
            return "note.text"           // NEW - 随心记图标
        case .library:
            return "clock.arrow.circlepath"
        case .aiPolish:
            return "wand.and.stars"      // NEW - AI 润色图标
        case .preferences:
            return "gearshape.fill"
        }
    }
    
    /// 导航项标题（中文标签）
    /// 与 rawValue 相同，提供语义化访问
    var title: String {
        return rawValue
    }
}
