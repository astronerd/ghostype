//
//  GhostMatrixModelPropertyTests.swift
//  AIInputMethod
//
//  Property-based tests for GhostMatrixModel
//  Feature: ghost-twin-incubator
//

import XCTest
import Foundation

// MARK: - Lightweight Property-Based Testing Helper

/// A simple property-based testing engine that generates random inputs
/// and checks that a property holds for all of them.
/// Inspired by QuickCheck/SwiftCheck but self-contained.
private struct PropertyTest {
    
    /// Run a property test with the given number of iterations.
    /// - Parameters:
    ///   - name: Description of the property being tested
    ///   - iterations: Number of random inputs to test (default 100)
    ///   - property: A closure that returns true if the property holds
    /// - Throws: XCTFail if any iteration fails
    static func verify(
        _ name: String,
        iterations: Int = 100,
        file: StaticString = #file,
        line: UInt = #line,
        property: () throws -> Bool
    ) rethrows {
        for i in 0..<iterations {
            let result = try property()
            if !result {
                XCTFail("Property '\(name)' failed on iteration \(i + 1)", file: file, line: line)
                return
            }
        }
    }
}

// MARK: - Seeded Random Number Generator (Test Copy)

/// 带种子的随机数生成器，用于可重复的测试
/// Exact copy from GhostMatrixModel.swift
private struct SeededRandomNumberGenerator: RandomNumberGenerator {
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

// MARK: - TestGhostMatrixModel (Test Copy)

/// A testable copy of GhostMatrixModel that replicates the exact logic
/// from GhostMatrixModel.swift without requiring AppKit or Bundle resources.
/// Since the test target cannot import the executable target,
/// we duplicate the relevant logic here for testing.
private class TestGhostMatrixModel {
    
    // MARK: - Constants
    
    /// 点阵列数
    static let cols = 160
    
    /// 点阵行数
    static let rows = 120
    
    /// 总像素数 (160 × 120 = 19,200)
    static let totalPixels = cols * rows
    
    // MARK: - Properties
    
    /// Ghost Logo 掩码：true = Logo 像素，false = 背景像素
    /// 长度为 19,200，按行优先存储 (row * cols + col)
    private(set) var ghostMask: [Bool]
    
    /// 当前级别的点亮序列（Fisher-Yates 洗牌后的索引数组）
    /// 长度为 19,200，包含 0..<19200 的随机排列
    private(set) var activationOrder: [Int]
    
    // MARK: - Initialization
    
    /// 初始化 TestGhostMatrixModel
    init() {
        self.ghostMask = [Bool](repeating: false, count: Self.totalPixels)
        self.activationOrder = []
    }
    
    /// 用于测试的初始化方法
    init(ghostMask: [Bool], activationOrder: [Int]) {
        self.ghostMask = ghostMask
        self.activationOrder = activationOrder
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
    
    // MARK: - Persistence (for Property 3 testing)
    
    /// UserDefaults key for testing (unique to avoid conflicts with production)
    private static let testCacheKey = "ghostTwin.activationOrder.test"
    
    /// 持久化 activationOrder 到 UserDefaults
    /// Mirrors the production implementation in GhostMatrixModel.swift
    /// Validates: Requirements 5.4
    func saveActivationOrder() {
        // 将 Int 数组转换为 Data 存储（比 JSON 更高效）
        let data = activationOrder.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
        UserDefaults.standard.set(data, forKey: Self.testCacheKey)
    }
    
    /// 从 UserDefaults 加载 activationOrder
    /// Mirrors the production implementation in GhostMatrixModel.swift
    /// - Returns: 加载成功返回 true，失败返回 false
    /// Validates: Requirements 5.4
    @discardableResult
    func loadActivationOrder() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Self.testCacheKey) else {
            return false
        }
        
        // 验证数据长度
        let expectedSize = Self.totalPixels * MemoryLayout<Int>.size
        guard data.count == expectedSize else {
            return false
        }
        
        // 将 Data 转换回 Int 数组
        let order = data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Int.self))
        }
        
        // 验证是否为有效排列
        guard isValidPermutation(order) else {
            return false
        }
        
        activationOrder = order
        return true
    }
    
    /// 清除测试用的 UserDefaults 缓存
    static func clearTestCache() {
        UserDefaults.standard.removeObject(forKey: testCacheKey)
    }
}

// MARK: - Property Tests

/// Property-based tests for GhostMatrixModel
/// Feature: ghost-twin-incubator
final class GhostMatrixModelPropertyTests: XCTestCase {
    
    // MARK: - Property 1: Fisher-Yates shuffle produces valid permutation
    
    /// Property 1: Fisher-Yates shuffle produces valid permutation
    /// *For any* call to `shuffleActivationOrder()`, the resulting `activationOrder` array
    /// shall be a valid permutation of `0..<19200`: it has exactly 19,200 elements,
    /// contains no duplicates, and every element is in the range `[0, 19199]`.
    /// Feature: ghost-twin-incubator
    /// **Validates: Requirements 5.2**
    func testProperty1_FisherYatesShuffleProducesValidPermutation() {
        PropertyTest.verify(
            "Fisher-Yates shuffle produces valid permutation of 0..<19200",
            iterations: 100
        ) {
            // Generate a random seed for this iteration
            let seed = UInt64.random(in: 0...UInt64.max)
            
            // Create model and shuffle
            let model = TestGhostMatrixModel()
            model.shuffleActivationOrder(seed: seed)
            
            let order = model.activationOrder
            
            // Verify: exactly 19,200 elements
            guard order.count == TestGhostMatrixModel.totalPixels else {
                return false
            }
            
            // Verify: no duplicates (Set size equals array size)
            let set = Set(order)
            guard set.count == order.count else {
                return false
            }
            
            // Verify: all elements in valid range [0, 19199]
            for element in order {
                guard element >= 0, element < TestGhostMatrixModel.totalPixels else {
                    return false
                }
            }
            
            return true
        }
    }
    
    /// Property 1 (additional): Shuffle with nil seed also produces valid permutation
    /// **Validates: Requirements 5.2**
    func testProperty1_ShuffleWithNilSeedProducesValidPermutation() {
        PropertyTest.verify(
            "Shuffle with nil seed (system random) produces valid permutation",
            iterations: 100
        ) {
            // Create model and shuffle with nil seed (system random)
            let model = TestGhostMatrixModel()
            model.shuffleActivationOrder(seed: nil)
            
            let order = model.activationOrder
            
            // Verify: exactly 19,200 elements
            guard order.count == TestGhostMatrixModel.totalPixels else {
                return false
            }
            
            // Verify: no duplicates
            let set = Set(order)
            guard set.count == order.count else {
                return false
            }
            
            // Verify: all elements in valid range
            for element in order {
                guard element >= 0, element < TestGhostMatrixModel.totalPixels else {
                    return false
                }
            }
            
            return true
        }
    }
    
    /// Property 1 (determinism): Same seed produces same permutation
    /// **Validates: Requirements 5.2**
    func testProperty1_SameSeedProducesSamePermutation() {
        PropertyTest.verify(
            "Same seed produces identical permutation",
            iterations: 100
        ) {
            // Generate a random seed
            let seed = UInt64.random(in: 0...UInt64.max)
            
            // Create two models and shuffle with the same seed
            let model1 = TestGhostMatrixModel()
            model1.shuffleActivationOrder(seed: seed)
            
            let model2 = TestGhostMatrixModel()
            model2.shuffleActivationOrder(seed: seed)
            
            // Verify: both produce identical permutations
            guard model1.activationOrder == model2.activationOrder else {
                return false
            }
            
            return true
        }
    }
    
    /// Property 1 (uniqueness): Different seeds produce different permutations (with high probability)
    /// Note: This is a probabilistic test - there's an astronomically small chance
    /// that two different seeds could produce the same permutation.
    /// **Validates: Requirements 5.2**
    func testProperty1_DifferentSeedsProduceDifferentPermutations() {
        PropertyTest.verify(
            "Different seeds produce different permutations",
            iterations: 100
        ) {
            // Generate two different random seeds
            let seed1 = UInt64.random(in: 0...UInt64.max)
            var seed2 = UInt64.random(in: 0...UInt64.max)
            while seed2 == seed1 {
                seed2 = UInt64.random(in: 0...UInt64.max)
            }
            
            // Create two models and shuffle with different seeds
            let model1 = TestGhostMatrixModel()
            model1.shuffleActivationOrder(seed: seed1)
            
            let model2 = TestGhostMatrixModel()
            model2.shuffleActivationOrder(seed: seed2)
            
            // Verify: permutations are different
            // (With 19,200! possible permutations, collision is essentially impossible)
            guard model1.activationOrder != model2.activationOrder else {
                return false
            }
            
            return true
        }
    }
    
    /// Property 1 (validation helper): isValidPermutation correctly identifies valid permutations
    /// **Validates: Requirements 5.2**
    func testProperty1_IsValidPermutationCorrectlyValidates() {
        PropertyTest.verify(
            "isValidPermutation correctly validates shuffled arrays",
            iterations: 100
        ) {
            let seed = UInt64.random(in: 0...UInt64.max)
            
            let model = TestGhostMatrixModel()
            model.shuffleActivationOrder(seed: seed)
            
            // The shuffled activationOrder should pass validation
            guard model.isValidPermutation(model.activationOrder) else {
                return false
            }
            
            return true
        }
    }
    
    // MARK: - Property 2: getActivePixels returns correct count with valid indices
    
    /// Property 2: getActivePixels returns correct count with valid indices
    /// *For any* `wordCount` in `0...10000`, `getActivePixels(wordCount:)` shall return a `Set<Int>` where:
    /// - The set size equals `min(wordCount * 19200 / 10000, 19200)`
    /// - Every element in the set is in the range `[0, 19199]`
    /// Feature: ghost-twin-incubator
    /// **Validates: Requirements 5.3**
    func testProperty2_GetActivePixelsReturnsCorrectCountWithValidIndices() {
        PropertyTest.verify(
            "getActivePixels returns correct count with valid indices",
            iterations: 100
        ) {
            // Generate random wordCount in 0...10000
            let wordCount = Int.random(in: 0...10000)
            
            // Create model and shuffle
            let model = TestGhostMatrixModel()
            model.shuffleActivationOrder(seed: UInt64.random(in: 0...UInt64.max))
            
            // Get active pixels
            let activePixels = model.getActivePixels(wordCount: wordCount)
            
            // Calculate expected count
            let expectedCount = min(wordCount * TestGhostMatrixModel.totalPixels / 10_000, TestGhostMatrixModel.totalPixels)
            
            // Verify: set size equals expected count
            guard activePixels.count == expectedCount else {
                return false
            }
            
            // Verify: all elements in valid range [0, 19199]
            for pixel in activePixels {
                guard pixel >= 0, pixel < TestGhostMatrixModel.totalPixels else {
                    return false
                }
            }
            
            return true
        }
    }
    
    /// Property 2 (subset): Active pixels are always a subset of activationOrder
    /// **Validates: Requirements 5.3**
    func testProperty2_ActivePixelsAreSubsetOfActivationOrder() {
        PropertyTest.verify(
            "Active pixels are always a subset of activationOrder",
            iterations: 100
        ) {
            let wordCount = Int.random(in: 0...10000)
            
            let model = TestGhostMatrixModel()
            model.shuffleActivationOrder(seed: UInt64.random(in: 0...UInt64.max))
            
            let activePixels = model.getActivePixels(wordCount: wordCount)
            let activationOrderSet = Set(model.activationOrder)
            
            // All active pixels should be in the activation order
            guard activePixels.isSubset(of: activationOrderSet) else {
                return false
            }
            
            return true
        }
    }
    
    /// Property 2 (monotonicity): More words means more or equal active pixels
    /// **Validates: Requirements 5.3**
    func testProperty2_MoreWordsMeansMoreOrEqualActivePixels() {
        PropertyTest.verify(
            "More words means more or equal active pixels",
            iterations: 100
        ) {
            let wordCount1 = Int.random(in: 0...5000)
            let wordCount2 = Int.random(in: wordCount1...10000)
            
            let model = TestGhostMatrixModel()
            model.shuffleActivationOrder(seed: UInt64.random(in: 0...UInt64.max))
            
            let activePixels1 = model.getActivePixels(wordCount: wordCount1)
            let activePixels2 = model.getActivePixels(wordCount: wordCount2)
            
            // More words should result in more or equal active pixels
            guard activePixels2.count >= activePixels1.count else {
                return false
            }
            
            return true
        }
    }
    
    /// Property 2 (prefix consistency): Active pixels for smaller wordCount is subset of larger
    /// **Validates: Requirements 5.3**
    func testProperty2_SmallerWordCountIsSubsetOfLarger() {
        PropertyTest.verify(
            "Active pixels for smaller wordCount is subset of larger wordCount",
            iterations: 100
        ) {
            let wordCount1 = Int.random(in: 0...5000)
            let wordCount2 = Int.random(in: wordCount1...10000)
            
            let model = TestGhostMatrixModel()
            model.shuffleActivationOrder(seed: UInt64.random(in: 0...UInt64.max))
            
            let activePixels1 = model.getActivePixels(wordCount: wordCount1)
            let activePixels2 = model.getActivePixels(wordCount: wordCount2)
            
            // Smaller wordCount's active pixels should be a subset of larger wordCount's
            guard activePixels1.isSubset(of: activePixels2) else {
                return false
            }
            
            return true
        }
    }
    
    // MARK: - Edge Case Tests for getActivePixels
    
    /// Edge case: wordCount = 0 returns empty set
    /// **Validates: Requirements 5.3**
    func testGetActivePixels_WordCountZero() {
        let model = TestGhostMatrixModel()
        model.shuffleActivationOrder(seed: 12345)
        
        let activePixels = model.getActivePixels(wordCount: 0)
        
        XCTAssertTrue(activePixels.isEmpty, "wordCount = 0 should return empty set")
    }
    
    /// Edge case: wordCount = 10000 returns all 19,200 pixels
    /// **Validates: Requirements 5.3**
    func testGetActivePixels_WordCount10000() {
        let model = TestGhostMatrixModel()
        model.shuffleActivationOrder(seed: 12345)
        
        let activePixels = model.getActivePixels(wordCount: 10000)
        
        XCTAssertEqual(activePixels.count, TestGhostMatrixModel.totalPixels,
                       "wordCount = 10000 should return all 19,200 pixels")
        
        // Verify all pixels are in valid range
        for pixel in activePixels {
            XCTAssertTrue(pixel >= 0 && pixel < TestGhostMatrixModel.totalPixels,
                          "All pixels should be in range [0, 19199]")
        }
    }
    
    /// Edge case: wordCount exceeds max (10000) caps at 19,200 pixels
    /// **Validates: Requirements 5.3**
    func testGetActivePixels_WordCountExceedsMax() {
        let model = TestGhostMatrixModel()
        model.shuffleActivationOrder(seed: 12345)
        
        // Test with wordCount > 10000
        let activePixels = model.getActivePixels(wordCount: 15000)
        
        XCTAssertEqual(activePixels.count, TestGhostMatrixModel.totalPixels,
                       "wordCount > 10000 should cap at 19,200 pixels")
    }
    
    /// Edge case: wordCount = 5000 returns exactly half (9,600 pixels)
    /// **Validates: Requirements 5.3**
    func testGetActivePixels_WordCount5000() {
        let model = TestGhostMatrixModel()
        model.shuffleActivationOrder(seed: 12345)
        
        let activePixels = model.getActivePixels(wordCount: 5000)
        
        // 5000 * 19200 / 10000 = 9600
        let expectedCount = 5000 * TestGhostMatrixModel.totalPixels / 10_000
        XCTAssertEqual(activePixels.count, expectedCount,
                       "wordCount = 5000 should return 9,600 pixels")
        XCTAssertEqual(expectedCount, 9600, "Expected count should be 9600")
    }
    
    /// Edge case: getActivePixels before shuffle returns empty set
    /// **Validates: Requirements 5.3**
    func testGetActivePixels_BeforeShuffleReturnsEmpty() {
        let model = TestGhostMatrixModel()
        // Don't call shuffleActivationOrder
        
        let activePixels = model.getActivePixels(wordCount: 5000)
        
        XCTAssertTrue(activePixels.isEmpty,
                      "getActivePixels before shuffle should return empty set")
    }
    
    /// Edge case: wordCount = 1 returns approximately 2 pixels (1 * 19200 / 10000 = 1)
    /// **Validates: Requirements 5.3**
    func testGetActivePixels_WordCount1() {
        let model = TestGhostMatrixModel()
        model.shuffleActivationOrder(seed: 12345)
        
        let activePixels = model.getActivePixels(wordCount: 1)
        
        // 1 * 19200 / 10000 = 1 (integer division)
        let expectedCount = 1 * TestGhostMatrixModel.totalPixels / 10_000
        XCTAssertEqual(activePixels.count, expectedCount,
                       "wordCount = 1 should return \(expectedCount) pixel(s)")
    }
    
    // MARK: - Edge Case Tests for Property 1
    
    /// Edge case: Verify constants are correct
    func testConstants() {
        XCTAssertEqual(TestGhostMatrixModel.cols, 160, "cols should be 160")
        XCTAssertEqual(TestGhostMatrixModel.rows, 120, "rows should be 120")
        XCTAssertEqual(TestGhostMatrixModel.totalPixels, 19200, "totalPixels should be 19200 (160 × 120)")
    }
    
    /// Edge case: Empty model before shuffle
    func testEmptyModelBeforeShuffle() {
        let model = TestGhostMatrixModel()
        XCTAssertTrue(model.activationOrder.isEmpty, "activationOrder should be empty before shuffle")
    }
    
    /// Edge case: Specific seed produces consistent results
    func testSpecificSeedConsistency() {
        let seed: UInt64 = 12345
        
        let model1 = TestGhostMatrixModel()
        model1.shuffleActivationOrder(seed: seed)
        
        let model2 = TestGhostMatrixModel()
        model2.shuffleActivationOrder(seed: seed)
        
        XCTAssertEqual(model1.activationOrder, model2.activationOrder,
                       "Same seed should produce identical permutations")
        XCTAssertEqual(model1.activationOrder.count, 19200,
                       "Permutation should have exactly 19,200 elements")
    }
    
    // MARK: - Property 3: activationOrder round-trip persistence
    
    /// Property 3: activationOrder round-trip persistence
    /// *For any* valid `activationOrder` array (a permutation of `0..<19200`),
    /// saving it to UserDefaults and then loading it back shall produce an identical array.
    /// Feature: ghost-twin-incubator
    /// **Validates: Requirements 5.4**
    func testProperty3_ActivationOrderRoundTripPersistence() {
        // Clean up before test
        TestGhostMatrixModel.clearTestCache()
        
        PropertyTest.verify(
            "activationOrder round-trip persistence produces identical array",
            iterations: 100
        ) {
            let seed = UInt64.random(in: 0...UInt64.max)
            
            // Create model and shuffle
            let model = TestGhostMatrixModel()
            model.shuffleActivationOrder(seed: seed)
            
            let originalOrder = model.activationOrder
            
            // Save to UserDefaults
            model.saveActivationOrder()
            
            // Create new model and load
            let loadedModel = TestGhostMatrixModel()
            let loadSuccess = loadedModel.loadActivationOrder()
            
            guard loadSuccess else {
                return false
            }
            
            // Verify: loaded array is identical to original
            guard loadedModel.activationOrder == originalOrder else {
                return false
            }
            
            return true
        }
        
        // Clean up after test
        TestGhostMatrixModel.clearTestCache()
    }
    
    /// Property 3 (data integrity): Loaded activationOrder is still a valid permutation
    /// **Validates: Requirements 5.4**
    func testProperty3_LoadedActivationOrderIsValidPermutation() {
        // Clean up before test
        TestGhostMatrixModel.clearTestCache()
        
        PropertyTest.verify(
            "Loaded activationOrder is still a valid permutation",
            iterations: 100
        ) {
            let seed = UInt64.random(in: 0...UInt64.max)
            
            // Create model and shuffle
            let model = TestGhostMatrixModel()
            model.shuffleActivationOrder(seed: seed)
            
            // Save to UserDefaults
            model.saveActivationOrder()
            
            // Create new model and load
            let loadedModel = TestGhostMatrixModel()
            let loadSuccess = loadedModel.loadActivationOrder()
            
            guard loadSuccess else {
                return false
            }
            
            // Verify: loaded array is a valid permutation
            guard loadedModel.isValidPermutation(loadedModel.activationOrder) else {
                return false
            }
            
            return true
        }
        
        // Clean up after test
        TestGhostMatrixModel.clearTestCache()
    }
    
    /// Property 3 (multiple saves): Last save wins
    /// **Validates: Requirements 5.4**
    func testProperty3_MultipleSavesLastWins() {
        // Clean up before test
        TestGhostMatrixModel.clearTestCache()
        
        PropertyTest.verify(
            "Multiple saves - last save wins",
            iterations: 100
        ) {
            let seed1 = UInt64.random(in: 0...UInt64.max)
            var seed2 = UInt64.random(in: 0...UInt64.max)
            while seed2 == seed1 {
                seed2 = UInt64.random(in: 0...UInt64.max)
            }
            
            // Create first model and save
            let model1 = TestGhostMatrixModel()
            model1.shuffleActivationOrder(seed: seed1)
            model1.saveActivationOrder()
            
            // Create second model with different seed and save (overwrite)
            let model2 = TestGhostMatrixModel()
            model2.shuffleActivationOrder(seed: seed2)
            model2.saveActivationOrder()
            
            let expectedOrder = model2.activationOrder
            
            // Load should return the second (last) saved order
            let loadedModel = TestGhostMatrixModel()
            let loadSuccess = loadedModel.loadActivationOrder()
            
            guard loadSuccess else {
                return false
            }
            
            // Verify: loaded array matches the last saved order
            guard loadedModel.activationOrder == expectedOrder else {
                return false
            }
            
            return true
        }
        
        // Clean up after test
        TestGhostMatrixModel.clearTestCache()
    }
    
    // MARK: - Edge Case Tests for Property 3
    
    /// Edge case: Load before any save returns false
    /// **Validates: Requirements 5.4**
    func testProperty3_LoadBeforeSaveReturnsFalse() {
        // Clean up to ensure no cached data
        TestGhostMatrixModel.clearTestCache()
        
        let model = TestGhostMatrixModel()
        let loadSuccess = model.loadActivationOrder()
        
        XCTAssertFalse(loadSuccess, "Load before any save should return false")
        XCTAssertTrue(model.activationOrder.isEmpty, "activationOrder should remain empty after failed load")
    }
    
    /// Edge case: Save and load preserves exact element order
    /// **Validates: Requirements 5.4**
    func testProperty3_SaveLoadPreservesExactOrder() {
        // Clean up before test
        TestGhostMatrixModel.clearTestCache()
        
        let seed: UInt64 = 42
        
        let model = TestGhostMatrixModel()
        model.shuffleActivationOrder(seed: seed)
        
        // Record first 10 and last 10 elements for detailed comparison
        let firstTen = Array(model.activationOrder.prefix(10))
        let lastTen = Array(model.activationOrder.suffix(10))
        
        model.saveActivationOrder()
        
        let loadedModel = TestGhostMatrixModel()
        let loadSuccess = loadedModel.loadActivationOrder()
        
        XCTAssertTrue(loadSuccess, "Load should succeed")
        
        // Verify exact order preservation
        XCTAssertEqual(Array(loadedModel.activationOrder.prefix(10)), firstTen,
                       "First 10 elements should match exactly")
        XCTAssertEqual(Array(loadedModel.activationOrder.suffix(10)), lastTen,
                       "Last 10 elements should match exactly")
        
        // Clean up after test
        TestGhostMatrixModel.clearTestCache()
    }
    
    /// Edge case: Clear cache makes load fail
    /// **Validates: Requirements 5.4**
    func testProperty3_ClearCacheMakesLoadFail() {
        // Save some data first
        let model = TestGhostMatrixModel()
        model.shuffleActivationOrder(seed: 12345)
        model.saveActivationOrder()
        
        // Verify save worked
        let verifyModel = TestGhostMatrixModel()
        XCTAssertTrue(verifyModel.loadActivationOrder(), "Load should succeed after save")
        
        // Clear cache
        TestGhostMatrixModel.clearTestCache()
        
        // Now load should fail
        let afterClearModel = TestGhostMatrixModel()
        XCTAssertFalse(afterClearModel.loadActivationOrder(), "Load should fail after cache clear")
    }
    
    /// Edge case: Specific seed round-trip consistency
    /// **Validates: Requirements 5.4**
    func testProperty3_SpecificSeedRoundTripConsistency() {
        // Clean up before test
        TestGhostMatrixModel.clearTestCache()
        
        let seed: UInt64 = 9876543210
        
        let model = TestGhostMatrixModel()
        model.shuffleActivationOrder(seed: seed)
        
        let originalOrder = model.activationOrder
        
        // Save
        model.saveActivationOrder()
        
        // Load into new model
        let loadedModel = TestGhostMatrixModel()
        let loadSuccess = loadedModel.loadActivationOrder()
        
        XCTAssertTrue(loadSuccess, "Load should succeed")
        XCTAssertEqual(loadedModel.activationOrder.count, 19200,
                       "Loaded array should have 19,200 elements")
        XCTAssertEqual(loadedModel.activationOrder, originalOrder,
                       "Loaded array should be identical to original")
        
        // Clean up after test
        TestGhostMatrixModel.clearTestCache()
    }
}
