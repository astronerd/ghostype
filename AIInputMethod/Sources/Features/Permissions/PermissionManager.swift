import Foundation
import ApplicationServices
import AVFoundation
import SwiftUI
import CoreGraphics

// MARK: - Notification Names

extension Notification.Name {
    /// 权限状态变化通知（辅助功能/麦克风授权后发送）
    static let permissionsDidChange = Notification.Name("permissionsDidChange")
    /// 检查更新通知（从偏好设置页面触发）
    static let checkForUpdates = Notification.Name("checkForUpdates")
}

@Observable
class PermissionManager {
    var isAccessibilityTrusted: Bool = false
    var isInputMonitoringGranted: Bool = false
    var isMicrophoneGranted: Bool = false
    
    /// 自动轮询定时器
    private var pollTimer: Timer?
    
    init() {
        checkAccessibilityStatus()
        checkInputMonitoringStatus()
        checkMicrophoneStatus()
    }
    
    func checkAccessibilityStatus() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        self.isAccessibilityTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    func checkInputMonitoringStatus() {
        self.isInputMonitoringGranted = CGPreflightListenEventAccess()
    }
    
    func requestInputMonitoring() {
        let granted = CGRequestListenEventAccess()
        DispatchQueue.main.async {
            self.isInputMonitoringGranted = granted
        }
    }
    
    func promptForAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    func checkMicrophoneStatus() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            self.isMicrophoneGranted = true
        case .denied, .restricted, .notDetermined:
            self.isMicrophoneGranted = false
        @unknown default:
            self.isMicrophoneGranted = false
        }
    }
    
    func requestMicrophoneAccess() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.isMicrophoneGranted = granted
            }
        }
    }
    
    /// 检查所有权限并返回是否全部已授权
    @discardableResult
    func refreshAll() -> Bool {
        checkAccessibilityStatus()
        checkMicrophoneStatus()
        checkInputMonitoringStatus()
        return isAccessibilityTrusted && isMicrophoneGranted
    }
    
    /// 开始自动轮询权限状态（每 2 秒检查一次，全部授权后自动停止）
    func startPolling(onAllGranted: (() -> Void)? = nil) {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let allGranted = self.refreshAll()
            if allGranted {
                self.stopPolling()
                onAllGranted?()
            }
        }
    }
    
    /// 停止轮询
    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
