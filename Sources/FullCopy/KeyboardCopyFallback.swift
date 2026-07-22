import AppKit
import ApplicationServices
import Carbon
import Foundation

final class KeyboardCopyFallback {
    private let pasteboardManager: PasteboardManager
    private let accessibilityReader: AccessibilityTextReader

    init(pasteboardManager: PasteboardManager, accessibilityReader: AccessibilityTextReader) {
        self.pasteboardManager = pasteboardManager
        self.accessibilityReader = accessibilityReader
    }

    func copy(applicationPID: pid_t, selectAll: Bool) throws -> ExtractedText {
        guard let application = NSRunningApplication(processIdentifier: applicationPID) else {
            throw FullCopyError.targetApplicationUnavailable
        }

        let snapshot = pasteboardManager.snapshot()
        let sentinel = "__FULL_COPY_SENTINEL_\(UUID().uuidString)__"
        pasteboardManager.replaceWithSentinel(sentinel)

        var focusedElement: AXUIElement?
        var originalSelectionRange: AXValue?
        if selectAll {
            focusedElement = try? accessibilityReader.focusedElement(applicationPID: applicationPID)
            if let focusedElement {
                originalSelectionRange = accessibilityReader.selectedTextRange(of: focusedElement)
            }
        }

        application.activate(options: [.activateIgnoringOtherApps])
        Thread.sleep(forTimeInterval: 0.12)

        if selectAll {
            postCommandKey(keyCode: CGKeyCode(kVK_ANSI_A))
            Thread.sleep(forTimeInterval: 0.12)
        }
        postCommandKey(keyCode: CGKeyCode(kVK_ANSI_C))

        let deadline = Date().addingTimeInterval(2.5)
        var result: String?
        while Date() < deadline {
            if let text = pasteboardManager.currentString(), text != sentinel {
                result = text
                break
            }
            Thread.sleep(forTimeInterval: 0.04)
        }

        if selectAll {
            accessibilityReader.restoreSelectedTextRange(originalSelectionRange, to: focusedElement)
        }

        guard let result, !result.isEmpty else {
            pasteboardManager.restore(snapshot)
            throw FullCopyError.keyboardCopyTimedOut
        }

        return ExtractedText(text: result, method: selectAll ? .keyboardSelectAllCopy : .keyboardCopy)
    }

    private func postCommandKey(keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
