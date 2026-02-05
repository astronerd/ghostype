import Foundation
import ApplicationServices
import AVFoundation
import SwiftUI
import CoreGraphics

class PermissionManager: ObservableObject {
    @Published var isAccessibilityTrusted: Bool = false
    @Published var isInputMonitoringGranted: Bool = false
    @Published var isMicrophoneGranted: Bool = false
    
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
        // CGEventTap 需要 Input Monitoring 权限
        self.isInputMonitoringGranted = CGPreflightListenEventAccess()
    }
    
    func requestInputMonitoring() {
        // 请求 Input Monitoring 权限
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
}
