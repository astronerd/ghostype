import Foundation

// MARK: - Quota Providing Protocol

/// QuotaManager 协议抽象
/// 为外部消费方提供可测试的额度管理接口
protocol QuotaProviding: AnyObject {
    var usedPercentage: Double { get }
    var formattedUsed: String { get }
    func refresh() async
    func reportAndRefresh(characters: Int) async
}

// MARK: - QuotaManager Conformance

extension QuotaManager: QuotaProviding {}
