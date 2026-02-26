import Foundation

/// XP 与等级计算（纯函数）
/// 所有方法均为无状态纯函数，便于测试和复用
enum GhostTwinXP {
    static let xpForLevel0 = 2_000
    static let xpPerLevel = 10_000
    static let maxLevel = 10

    /// 根据总 XP 计算等级 (0~10)
    /// Lv.0: 0~1999, Lv.1: 2000~11999, ..., Lv.10: 92000+
    static func calculateLevel(totalXP: Int) -> Int {
        if totalXP < xpForLevel0 { return 0 }
        let remaining = totalXP - xpForLevel0
        return min(remaining / xpPerLevel + 1, maxLevel)
    }

    /// 当前等级内的 XP（每级从 0 开始）
    /// Lv.0: 返回 totalXP
    /// Lv.1~9: (totalXP - 2000) % 10000
    /// Lv.10: totalXP - 2000 - 90000
    static func currentLevelXP(totalXP: Int) -> Int {
        if totalXP < xpForLevel0 { return totalXP }
        let level = calculateLevel(totalXP: totalXP)
        if level >= maxLevel {
            return totalXP - xpForLevel0 - (maxLevel - 1) * xpPerLevel
        }
        return (totalXP - xpForLevel0) % xpPerLevel
    }

    /// 当前等级的升级所需 XP
    static func xpNeededForCurrentLevel(level: Int) -> Int {
        level == 0 ? xpForLevel0 : xpPerLevel
    }

    /// 检查是否升级，返回 (是否升级, 旧等级, 新等级)
    static func checkLevelUp(oldXP: Int, newXP: Int) -> (leveledUp: Bool, oldLevel: Int, newLevel: Int) {
        let oldLevel = calculateLevel(totalXP: oldXP)
        let newLevel = calculateLevel(totalXP: newXP)
        return (newLevel > oldLevel, oldLevel, newLevel)
    }

    /// 统一校准 XP 奖励
    static let calibrationXPReward = 300

    /// 语音输入 XP 奖励（1 字符 = 1 XP）
    /// 正常说话也能积累 XP，10000 字即可升一级
    static func speechXP(characterCount: Int) -> Int {
        max(characterCount, 0)
    }
}
