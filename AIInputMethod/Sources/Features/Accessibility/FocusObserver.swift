import ApplicationServices
import Cocoa
import Combine

class FocusObserver: ObservableObject {
    @Published var currentFocusedElement: AXUIElement?
    @Published var isFocusedElementEditable: Bool = false
    
    private var observer: AXObserver?
    private var currentAppElement: AXUIElement?
    private var isObserving = false
    
    init() {
        // 不在 init 里启动，等权限检查完再调用 startObserving()
    }
    
    func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        
        // Listen for app activation
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // Initial check
        if let app = NSWorkspace.shared.frontmostApplication {
            observeApp(pid: app.processIdentifier)
        }
    }
    
    @objc private func appDidActivate(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            observeApp(pid: app.processIdentifier)
        }
    }
    
    private func observeApp(pid: pid_t) {
        // Remove old observer
        if let oldObserver = observer {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(oldObserver), .defaultMode)
        }
        
        // Create app element for this PID
        let appElement = AXUIElementCreateApplication(pid)
        self.currentAppElement = appElement
        
        // Create new observer
        var newObserver: AXObserver?
        let error = AXObserverCreate(pid, { (_, element, _, refcon) in
            guard let refcon = refcon else { return }
            let this = Unmanaged<FocusObserver>.fromOpaque(refcon).takeUnretainedValue()
            this.handleFocusChange(element: element)
        }, &newObserver)
        
        guard error == .success, let validObserver = newObserver else {
            print("[FocusObserver] Failed to create observer for PID \(pid)")
            return
        }
        self.observer = validObserver
        
        // Add notification to the APP element (not systemWide!)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let addResult = AXObserverAddNotification(validObserver, appElement, kAXFocusedUIElementChangedNotification as CFString, selfPtr)
        if addResult != .success {
            print("[FocusObserver] Failed to add notification: \(addResult.rawValue)")
        }
        
        // Add to RunLoop
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(validObserver), .defaultMode)
        
        // Immediate check
        updateCurrentFocus()
    }
    
    private func handleFocusChange(element: AXUIElement) {
        DispatchQueue.main.async {
            self.currentFocusedElement = element
            self.checkIfEditable(element: element)
        }
    }
    
    private func updateCurrentFocus() {
        let systemWide = AXUIElementCreateSystemWide()
        var element: AnyObject?
        let error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &element)
        if error == .success, let axElement = element {
            handleFocusChange(element: axElement as! AXUIElement)
        }
    }
    
    private func checkIfEditable(element: AXUIElement) {
        // Check 1: Is Value Settable?
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)
        
        if settable.boolValue {
            self.isFocusedElementEditable = true
            return
        }
        
        // Check 2: Check Role
        var role: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        if let roleStr = role as? String {
            if roleStr == kAXTextAreaRole || roleStr == kAXTextFieldRole || roleStr == kAXComboBoxRole {
                self.isFocusedElementEditable = true
                return
            }
        }
        
        self.isFocusedElementEditable = false
    }
}
