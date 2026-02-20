//
//  AppleNotesAdapter.swift
//  AIInputMethod
//
//  Apple Notes 同步适配器，通过 AppleScript 创建/追加笔记
//  Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5
//

import Foundation

// MARK: - AppleNotesAdapter

class AppleNotesAdapter: MemoSyncService {

    var serviceName: String { "Apple Notes" }

    // MARK: - Sync

    func sync(memo: MemoSyncPayload, config: SyncAdapterConfig) async -> SyncResult {
        let folderName = config.appleNotesFolderName ?? "GHOSTYPE"

        // 1. Generate title via TitleTemplateEngine
        let template = config.titleTemplate.isEmpty
            ? TitleTemplateEngine.defaultTemplate
            : config.titleTemplate
        let title = TitleTemplateEngine.resolve(
            template: template,
            date: memo.timestamp,
            groupingMode: config.groupingMode
        )

        // 2. Format content for Apple Notes (plain text, timestamp on separate line)
        let formattedContent = MemoContentFormatter.format(
            content: memo.content,
            timestamp: memo.timestamp,
            target: .appleNotes
        )

        // 3. Ensure folder exists
        let ensureResult = ensureFolder(named: folderName)
        if case .failure(let error) = ensureResult {
            return .failure(error)
        }

        // 4. Search for existing note by title, append or create
        let shouldAppend = config.groupingMode == .perDay || config.groupingMode == .perWeek

        if shouldAppend {
            // Try to find existing note and append
            let findResult = findNoteByTitle(title, inFolder: folderName)
            switch findResult {
            case .success(let found):
                if found {
                    // Append to existing note
                    let appendResult = appendToNote(title: title, content: formattedContent, inFolder: folderName)
                    if case .failure(let error) = appendResult {
                        return .failure(error)
                    }
                    FileLogger.log("[MemoSync] ✅ Apple Notes: appended to \"\(title)\"")
                    return .success
                } else {
                    // Note not found, create new
                    let createResult = createNote(title: title, content: formattedContent, inFolder: folderName)
                    if case .failure(let error) = createResult {
                        return .failure(error)
                    }
                    FileLogger.log("[MemoSync] ✅ Apple Notes: created \"\(title)\"")
                    return .success
                }
            case .failure(let error):
                return .failure(error)
            }
        } else {
            // perNote mode: always create new note
            let createResult = createNote(title: title, content: formattedContent, inFolder: folderName)
            if case .failure(let error) = createResult {
                return .failure(error)
            }
            FileLogger.log("[MemoSync] ✅ Apple Notes: created \"\(title)\"")
            return .success
        }
    }

    // MARK: - Validate Connection

    func validateConnection(config: SyncAdapterConfig) async -> SyncResult {
        // Test AppleScript execution by running a simple command
        let script = """
        tell application "Notes"
            name
        end tell
        """
        let result = executeAppleScript(script)
        switch result {
        case .success:
            return .success
        case .failure(let error):
            return .failure(error)
        }
    }

    // MARK: - Private: AppleScript Operations

    /// Ensure the target folder exists in Apple Notes, create if needed
    private func ensureFolder(named folderName: String) -> Result<Void, SyncError> {
        let script = """
        tell application "Notes"
            if not (exists folder "\(escapeForAppleScript(folderName))") then
                make new folder with properties {name:"\(escapeForAppleScript(folderName))"}
            end if
        end tell
        """
        let result = executeAppleScript(script)
        switch result {
        case .success:
            return .success(())
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Find a note by title in the specified folder
    /// Returns true if found, false if not found
    private func findNoteByTitle(_ title: String, inFolder folderName: String) -> Result<Bool, SyncError> {
        let script = """
        tell application "Notes"
            set matchingNotes to notes of folder "\(escapeForAppleScript(folderName))" whose name is "\(escapeForAppleScript(title))"
            return (count of matchingNotes) > 0
        end tell
        """
        let result = executeAppleScript(script)
        switch result {
        case .success(let output):
            return .success(output.lowercased().contains("true"))
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Create a new note in the specified folder
    private func createNote(title: String, content: String, inFolder folderName: String) -> Result<Void, SyncError> {
        let bodyContent = escapeForAppleScript(content)
        let script = """
        tell application "Notes"
            make new note at folder "\(escapeForAppleScript(folderName))" with properties {name:"\(escapeForAppleScript(title))", body:"\(bodyContent)"}
        end tell
        """
        let result = executeAppleScript(script)
        switch result {
        case .success:
            return .success(())
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Append content to an existing note found by title
    private func appendToNote(title: String, content: String, inFolder folderName: String) -> Result<Void, SyncError> {
        let script = """
        tell application "Notes"
            set targetNote to first note of folder "\(escapeForAppleScript(folderName))" whose name is "\(escapeForAppleScript(title))"
            set currentBody to body of targetNote
            set body of targetNote to currentBody & "<br>" & "\(escapeForAppleScript(content))"
        end tell
        """
        let result = executeAppleScript(script)
        switch result {
        case .success:
            return .success(())
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Execute an AppleScript string and return the result or error
    private func executeAppleScript(_ source: String) -> Result<String, SyncError> {
        let appleScript = NSAppleScript(source: source)
        var errorDict: NSDictionary?
        let result = appleScript?.executeAndReturnError(&errorDict)

        if let errorDict = errorDict {
            let description = errorDict[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
            FileLogger.log("[MemoSync] ❌ Apple Notes: AppleScript error - \(description)")
            return .failure(.appleScriptError(description))
        }

        return .success(result?.stringValue ?? "")
    }

    /// Escape special characters for AppleScript string literals
    private func escapeForAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
