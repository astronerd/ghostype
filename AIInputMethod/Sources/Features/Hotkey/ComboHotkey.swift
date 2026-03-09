import Foundation

// MARK: - Combo Hotkey

/// 组合快捷键，由两个独立的键（key1 和 key2）组成
/// 每个键可以是修饰键或普通键，用户通过两个独立的录制框分别录制
/// 有序对比较：(key1, key2) 作为唯一标识，key1 和 key2 的顺序由用户录制顺序决定
struct ComboHotkey: Codable, Equatable, Hashable {
    let key1: UInt16  // 第一个键的 keyCode
    let key2: UInt16  // 第二个键的 keyCode
}
