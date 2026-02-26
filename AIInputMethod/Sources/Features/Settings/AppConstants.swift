import Foundation
import AppKit

// MARK: - App Constants

/// 集中管理所有魔法数字
/// 替代散落在代码各处的硬编码常量
enum AppConstants {

    // MARK: - AI 处理

    enum AI {
        /// 润色阈值默认值（字符数）
        static let defaultPolishThreshold = 20
        /// LLM 聊天请求超时（秒）
        static let llmTimeout: TimeInterval = 30
        /// 用户配置查询超时（秒）
        static let profileTimeout: TimeInterval = 10
    }

    // MARK: - 快捷键

    enum Hotkey {
        /// 修饰键防抖时间（毫秒）
        static let modifierDebounceMs: Double = 300
        /// 权限重试间隔（秒）
        static let permissionRetryInterval: TimeInterval = 2
    }

    // MARK: - Overlay 动画

    enum Overlay {
        /// 提交后消失延迟（秒）
        static let commitDismissDelay: TimeInterval = 0.2
        /// 备忘录消失延迟（秒）
        static let memoDismissDelay: TimeInterval = 1.8
        /// 语音超时等待（秒）
        static let speechTimeoutSeconds: TimeInterval = 3.0
        /// 登录提示消失延迟（秒）
        static let loginRequiredDismissDelay: TimeInterval = 2.0
    }

    // MARK: - 语音识别

    enum Speech {
        /// 录音开始时的占位符（内部 sentinel，不会显示给用户）
        static let listeningSentinel = "__listening__"
    }

    // MARK: - 文本插入

    enum TextInsertion {
        /// 剪贴板粘贴延迟（秒）
        static let clipboardPasteDelay: TimeInterval = 1.0
        /// 按键释放延迟（秒）
        static let keyUpDelay: TimeInterval = 0.05
        /// 自动回车延迟（秒）
        static let autoEnterDelay: TimeInterval = 0.2
        /// 剪贴板恢复：最小等待时间（秒）— 粘贴后至少等这么久再开始检查
        static let clipboardRestoreMinDelay: TimeInterval = 0.5
        /// 剪贴板恢复：轮询间隔（秒）
        static let clipboardRestorePollInterval: TimeInterval = 0.05
        /// 剪贴板恢复：最大超时（秒）— 超过这个时间强制恢复
        static let clipboardRestoreMaxTimeout: TimeInterval = 3.0
    }

    // MARK: - 窗口尺寸

    enum Window {
        /// 引导窗口尺寸
        static let onboardingSize = NSSize(width: 480, height: 520)
        /// Dashboard 最小尺寸
        static let dashboardMinSize = NSSize(width: 900, height: 600)
        /// Dashboard 默认尺寸
        static let dashboardDefaultSize = NSSize(width: 1000, height: 700)
        /// 测试窗口尺寸
        static let testWindowSize = NSSize(width: 400, height: 480)
    }
}
