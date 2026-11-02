import AppKit
import ApplicationServices

/// Keeps the destination of one dictation, including its field rather than just its app.
@MainActor
protocol InsertionFocusAccess {
    associatedtype Element: Equatable

    var isApplicationActive: Bool { get }
    var focusedElement: Element? { get }
    func activateApplication()
    func focus(_ element: Element) -> Bool
}

@MainActor
struct InsertionFocus<Access: InsertionFocusAccess> {
    let access: Access
    private let element: Access.Element?

    init(access: Access) {
        self.access = access
        element = access.focusedElement
    }

    var isReady: Bool {
        access.isApplicationActive && (element == nil || access.focusedElement == element)
    }

    func restore() async -> Bool {
        // Activating an already active browser can disturb its field/selection.
        if !access.isApplicationActive {
            access.activateApplication()
            for _ in 0..<20 {
                guard !Task.isCancelled else { return false }
                if access.isApplicationActive { break }
                try? await Task.sleep(for: .milliseconds(25))
            }
        }
        guard !Task.isCancelled, access.isApplicationActive else { return false }
        // Some editors expose no AX field. Preserve the paste fallback for those apps.
        guard let element else { return true }
        if access.focusedElement == element { return true }
        guard access.focus(element) else { return false }
        for _ in 0..<20 {
            guard !Task.isCancelled, access.isApplicationActive else { return false }
            if access.focusedElement == element { return true }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return false
    }
}

@MainActor
struct ApplicationFocusAccess: InsertionFocusAccess {
    let application: NSRunningApplication
    private let accessibilityApplication: AXUIElement

    init(application: NSRunningApplication) {
        self.application = application
        accessibilityApplication = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(accessibilityApplication, 0.2)
    }

    var isApplicationActive: Bool {
        !application.isTerminated && NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier
    }

    var focusedElement: AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            accessibilityApplication, kAXFocusedUIElementAttribute as CFString, &value
        ) == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let element = value as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.2)
        return element
    }

    func activateApplication() {
        application.activate()
    }

    func focus(_ element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success
    }
}
