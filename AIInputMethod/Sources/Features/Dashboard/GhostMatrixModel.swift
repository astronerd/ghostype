//
//  GhostMatrixModel.swift
//  AIInputMethod
//
//  Ghost Twin 点阵数据模型
//  管理 160×120 像素点的状态和点亮顺序
//  Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5
//

import AppKit
import Foundation

// MARK: - Ghost Matrix Model

/// Ghost Twin 点阵数据模型
/// 管理 19,200 个像素点的 Ghost Logo 掩码和点亮序列
/// Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5
class GhostMatrixModel {
    
    // MARK: - Constants
    
    /// 点阵列数
    static let cols = 160
    
    /// 点阵行数
    static let rows = 120
    
    /// 总像素数 (160 × 120 = 19,200)
    static let totalPixels = cols * rows
    
    // MARK: - UserDefaults Keys
    
    private enum CacheKey {
        static let activationOrder = "ghostTwin.activationOrder"
    }
    
    // MARK: - Properties
    
    /// Ghost Logo 掩码：true = Logo 像素，false = 背景像素
    /// 长度为 19,200，按行优先存储 (row * cols + col)
    /// Validates: Requirements 5.1
    private(set) var ghostMask: [Bool]
    
    /// 当前级别的点亮序列（Fisher-Yates 洗牌后的索引数组）
    /// 长度为 19,200，包含 0..<19200 的随机排列
    /// Validates: Requirements 5.2
    private(set) var activationOrder: [Int]
    
    // MARK: - Initialization
    
    /// 初始化 GhostMatrixModel
    /// 自动加载 ghostMask 和尝试恢复 activationOrder
    init() {
        // 初始化为空数组，稍后加载
        self.ghostMask = [Bool](repeating: false, count: Self.totalPixels)
        self.activationOrder = []
        
        // 加载 Ghost Logo 掩码
        loadMaskFromSVG()
        
        // 尝试从 UserDefaults 恢复 activationOrder
        if !loadActivationOrder() {
            // 如果没有缓存，生成新的随机序列
            shuffleActivationOrder(seed: nil)
        }
    }
    
    /// 用于测试的初始化方法
    /// - Parameters:
    ///   - ghostMask: 自定义的 Ghost Logo 掩码
    ///   - activationOrder: 自定义的点亮序列
    init(ghostMask: [Bool], activationOrder: [Int]) {
        self.ghostMask = ghostMask
        self.activationOrder = activationOrder
    }
    
    // MARK: - Mask Loading
    
    /// 从 SVG 文件加载 Ghost Logo 掩码
    /// 将 SVG 渲染为 160×120 位图，采样每个像素判断是否属于 Ghost Logo
    /// Validates: Requirements 5.5
    func loadMaskFromSVG() {
        // 尝试从 Bundle 加载 ghostmask.svg
        guard let svgURL = Bundle.main.url(forResource: "ghostmask", withExtension: "svg"),
              let image = NSImage(contentsOf: svgURL) else {
            print("[GhostMatrixModel] ⚠️ Failed to load ghostmask.svg, using empty mask")
            ghostMask = [Bool](repeating: false, count: Self.totalPixels)
            return
        }
        
        // 创建 160×120 的位图表示
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Self.cols,
            pixelsHigh: Self.rows,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            print("[GhostMatrixModel] ⚠️ Failed to create bitmap, using empty mask")
            ghostMask = [Bool](repeating: false, count: Self.totalPixels)
            return
        }
        
        // 保存当前图形上下文
        NSGraphicsContext.saveGraphicsState()
        
        // 设置位图为当前绘图上下文
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        
        // 先填充黑色背景（确保透明区域为黑色）
        NSColor.black.setFill()
        NSRect(x: 0, y: 0, width: CGFloat(Self.cols), height: CGFloat(Self.rows)).fill()
        
        // 将 SVG 缩放绘制到 160×120
        let targetSize = NSSize(width: Self.cols, height: Self.rows)
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1.0
        )
        
        // 恢复图形上下文
        NSGraphicsContext.restoreGraphicsState()
        
        // 采样每个像素，判断是否属于 Ghost Logo
        // SVG 中白色 (#FEFEFE) 路径为 Ghost 轮廓，黑色为细节（眼睛等）
        // 亮度 > 0.5 的像素视为 Ghost Logo 的一部分
        var mask = [Bool](repeating: false, count: Self.totalPixels)
        for row in 0..<Self.rows {
            for col in 0..<Self.cols {
                let index = row * Self.cols + col
                if let color = bitmap.colorAt(x: col, y: row) {
                    // 获取亮度分量
                    let brightness = color.brightnessComponent
                    mask[index] = brightness > 0.5
                } else {
                    mask[index] = false
                }
            }
        }
        
        ghostMask = mask
        
        // 统计 Ghost Logo 像素数量
        let ghostPixelCount = mask.filter { $0 }.count
        print("[GhostMatrixModel] ✅ Loaded ghostMask from SVG, ghost pixels: \(ghostPixelCount)")
    }
    
    // MARK: - Shuffle Algorithm
    
    /// Fisher-Yates 洗牌算法生成新的 activationOrder
    /// 生成 0..<19200 的随机排列，决定像素点亮的先后顺序
    /// - Parameter seed: 随机种子（nil 使用系统随机）
    /// Validates: Requirements 5.2
    func shuffleActivationOrder(seed: UInt64?) {
        // 初始化为顺序数组 [0, 1, 2, ..., 19199]
        var order = Array(0..<Self.totalPixels)
        
        // 创建随机数生成器
        var rng: RandomNumberGenerator
        if let seed = seed {
            rng = SeededRandomNumberGenerator(seed: seed)
        } else {
            rng = SystemRandomNumberGenerator()
        }
        
        // Fisher-Yates 洗牌算法
        // 从最后一个元素开始，随机选择一个位置与之交换
        for i in stride(from: Self.totalPixels - 1, through: 1, by: -1) {
            let j = Int.random(in: 0...i, using: &rng)
            order.swapAt(i, j)
        }
        
        activationOrder = order
        print("[GhostMatrixModel] 🔀 Shuffled activationOrder with seed: \(seed?.description ?? "random")")
    }
    
    // MARK: - Active Pixels Calculation
    
    /// 根据当前字数计算需要点亮的像素索引集合
    /// 每字点亮约 2 个像素（wordCount × 19200 / 10000）
    /// - Parameter wordCount: 当前等级内的字数 (0...10000)
    /// - Returns: 需要点亮的像素索引集合
    /// Validates: Requirements 5.3
    func getActivePixels(wordCount: Int) -> Set<Int> {
        // 计算需要点亮的像素数量
        // 公式：pixelCount = wordCount * 19200 / 10000
        // 约每字点亮 1.92 个像素
        let count = min(wordCount * Self.totalPixels / 10_000, Self.totalPixels)
        
        // 确保 count 不超过 activationOrder 的长度
        guard count > 0, !activationOrder.isEmpty else {
            return Set()
        }
        
        let actualCount = min(count, activationOrder.count)
        return Set(activationOrder.prefix(actualCount))
    }
    
    // MARK: - Pixel Query
    
    /// 判断某个像素索引是否属于 Ghost Logo
    /// - Parameter index: 像素索引 (0..<19200)
    /// - Returns: true 表示该像素属于 Ghost Logo
    func isGhostPixel(_ index: Int) -> Bool {
        guard index >= 0, index < ghostMask.count else {
            return false
        }
        return ghostMask[index]
    }
    
    /// 将像素索引转换为行列坐标
    /// - Parameter index: 像素索引 (0..<19200)
    /// - Returns: (row, col) 坐标元组
    func indexToCoordinate(_ index: Int) -> (row: Int, col: Int) {
        let row = index / Self.cols
        let col = index % Self.cols
        return (row, col)
    }
    
    /// 将行列坐标转换为像素索引
    /// - Parameters:
    ///   - row: 行号 (0..<120)
    ///   - col: 列号 (0..<160)
    /// - Returns: 像素索引
    func coordinateToIndex(row: Int, col: Int) -> Int {
        return row * Self.cols + col
    }
    
    // MARK: - Persistence
    
    /// 持久化 activationOrder 到 UserDefaults
    /// Validates: Requirements 5.4
    func saveActivationOrder() {
        // 将 Int 数组转换为 Data 存储（比 JSON 更高效）
        let data = activationOrder.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
        UserDefaults.standard.set(data, forKey: CacheKey.activationOrder)
        print("[GhostMatrixModel] 💾 Saved activationOrder to UserDefaults (\(activationOrder.count) elements)")
    }
    
    /// 从 UserDefaults 加载 activationOrder
    /// - Returns: 加载成功返回 true，失败返回 false
    /// Validates: Requirements 5.4
    @discardableResult
    func loadActivationOrder() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: CacheKey.activationOrder) else {
            print("[GhostMatrixModel] ℹ️ No cached activationOrder found")
            return false
        }
        
        // 验证数据长度
        let expectedSize = Self.totalPixels * MemoryLayout<Int>.size
        guard data.count == expectedSize else {
            print("[GhostMatrixModel] ⚠️ Cached activationOrder has invalid size: \(data.count) (expected \(expectedSize))")
            return false
        }
        
        // 将 Data 转换回 Int 数组
        let order = data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Int.self))
        }
        
        // 验证是否为有效排列
        guard isValidPermutation(order) else {
            print("[GhostMatrixModel] ⚠️ Cached activationOrder is not a valid permutation")
            return false
        }
        
        activationOrder = order
        print("[GhostMatrixModel] ✅ Loaded activationOrder from UserDefaults (\(order.count) elements)")
        return true
    }
    
    /// 清除缓存的 activationOrder
    func clearActivationOrderCache() {
        UserDefaults.standard.removeObject(forKey: CacheKey.activationOrder)
        print("[GhostMatrixModel] 🗑️ Cleared activationOrder cache")
    }
    
    // MARK: - Validation
    
    /// 验证数组是否为 0..<totalPixels 的有效排列
    /// - Parameter order: 待验证的数组
    /// - Returns: 是否为有效排列
    func isValidPermutation(_ order: [Int]) -> Bool {
        // 检查长度
        guard order.count == Self.totalPixels else {
            return false
        }
        
        // 检查是否包含所有 0..<totalPixels 的元素（无重复）
        let set = Set(order)
        guard set.count == Self.totalPixels else {
            return false
        }
        
        // 检查所有元素是否在有效范围内
        for element in order {
            guard element >= 0, element < Self.totalPixels else {
                return false
            }
        }
        
        return true
    }
}

// MARK: - Seeded Random Number Generator

/// 带种子的随机数生成器，用于可重复的测试
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        // 使用 xorshift64 算法
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - GhostMatrixModel Extension for Testing

extension GhostMatrixModel {
    
    /// 创建用于测试的 GhostMatrixModel 实例
    /// - Parameters:
    ///   - ghostPixelIndices: Ghost Logo 像素的索引集合
    ///   - seed: 随机种子
    /// - Returns: 配置好的 GhostMatrixModel 实例
    static func forTesting(
        ghostPixelIndices: Set<Int> = [],
        seed: UInt64 = 12345
    ) -> GhostMatrixModel {
        var mask = [Bool](repeating: false, count: totalPixels)
        for index in ghostPixelIndices {
            if index >= 0, index < totalPixels {
                mask[index] = true
            }
        }
        
        let model = GhostMatrixModel(ghostMask: mask, activationOrder: [])
        model.shuffleActivationOrder(seed: seed)
        return model
    }
    
    /// 创建带有预设 activationOrder 的测试实例
    /// - Parameters:
    ///   - ghostMask: Ghost Logo 掩码
    ///   - activationOrder: 点亮序列
    /// - Returns: 配置好的 GhostMatrixModel 实例
    static func forTestingWithOrder(
        ghostMask: [Bool],
        activationOrder: [Int]
    ) -> GhostMatrixModel {
        return GhostMatrixModel(ghostMask: ghostMask, activationOrder: activationOrder)
    }
}
