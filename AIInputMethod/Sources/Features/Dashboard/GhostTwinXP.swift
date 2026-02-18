import Foundation

/// XP 与等级计算（纯函数）
/// 所有方法均为无状态纯函数，便于测试和复用
enum GhostTwinXP {
    static let xpPerLevel = 10_000
    static let maxLevel = 10

    /// 根据总 XP 计算等级 (1~10)
    /// 公式: min(totalXP / 10000 + 1, 10)
    static func calculateLevel(totalXP: Int) -> Int {
        min(totalXP / xpPerLevel + 1, maxLevel)
    }

    /// 当前等级内的 XP
    /// 未满级: totalXP % 10000
    /// 满级: totalXP - 90000
    static func currentLevelXP(totalXP: Int) -> Int {
        let level = calculateLevel(totalXP: totalXP)
        if level >= maxLevel { return totalXP - (maxLevel - 1) * xpPerLevel }
        return totalXP % xpPerLevel
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
