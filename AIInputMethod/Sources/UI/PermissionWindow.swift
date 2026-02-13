import SwiftUI
import AVFoundation

struct PermissionWindowView: View {
    var permissionManager: PermissionManager
    var onAllGranted: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                
                Text("AI Input Method")
                    .font(.title.bold())
                
                Text("需要以下权限才能正常工作")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            
            // Permission List
            VStack(spacing: 16) {
                PermissionRow(
                    icon: "hand.raised.fill",
                    title: "辅助功能",
                    description: "检测输入框并插入文字",
                    isGranted: permissionManager.isAccessibilityTrusted,
                    action: {
                        permissionManager.promptForAccessibility()
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                )
                
                PermissionRow(
                    icon: "mic.fill",
                    title: "麦克风",
                    description: "录制语音",
                    isGranted: permissionManager.isMicrophoneGranted,
                    action: {
                        permissionManager.requestMicrophoneAccess()
                    }
                )
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Bottom buttons
            VStack(spacing: 12) {
                Button(action: {
                    refreshStatus()
                }) {
                    Label("刷新状态", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                if allPermissionsGranted {
                    Button(action: onAllGranted) {
                        Text("开始使用")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 380, height: 420)
        .onAppear {
            refreshStatus()
        }
    }
    
    var allPermissionsGranted: Bool {
        permissionManager.isAccessibilityTrusted &&
        permissionManager.isMicrophoneGranted
    }
    
    func refreshStatus() {
        permissionManager.checkAccessibilityStatus()
        permissionManager.checkMicrophoneStatus()
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isGranted ? .green : .orange)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Button("授权") {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}
