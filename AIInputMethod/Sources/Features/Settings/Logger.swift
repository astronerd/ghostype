import Foundation

/// 简单的文件日志工具
/// Release 和 Debug 都写日志到 ~/ghostype_debug.log
class FileLogger {
    static let shared = FileLogger()
    
    private let logFile: URL
    private let queue = DispatchQueue(label: "com.ghostype.logger")
    
    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        logFile = home.appendingPathComponent("ghostype_debug.log")
        
        // 每次启动清空旧日志
        try? "".write(to: logFile, atomically: true, encoding: .utf8)
    }
    
    static func log(_ message: String) {
        shared.write(message)
    }
    
    private func write(_ message: String) {
        queue.async {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let line = "[\(timestamp)] \(message)\n"
            
            if let handle = try? FileHandle(forWritingTo: self.logFile) {
                handle.seekToEndOfFile()
                if let data = line.data(using: .utf8) {
                    handle.write(data)
                }
                handle.closeFile()
            } else {
                try? line.write(to: self.logFile, atomically: true, encoding: .utf8)
            }
        }
    }
}

/// Debug print - 只在 DEBUG 模式下输出
func debugLog(_ message: String) {
    #if DEBUG
    print(message)
    #endif
}
