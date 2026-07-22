import AppKit
import ApplicationServices
import Foundation

final class AccessibilityTextReader {
    private let directTextRoles: Set<String> = [
        "AXStaticText", "AXTextArea", "AXTextField", "AXHeading",
        "AXLink", "AXCell", "AXListItem", "AXTextView"
    ]

    private let documentRoles: Set<String> = [
        "AXWebArea", "AXDocument", "AXScrollArea", "AXTextArea", "AXTextView"
    ]

    func isTrusted(prompt: Bool) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func readSelectedText(applicationPID: pid_t) throws -> ExtractedText {
        guard isTrusted(prompt: false) else {
            throw FullCopyError.accessibilityPermissionMissing
        }
        let focused = try focusedElement(applicationPID: applicationPID)
        for element in elementAndAncestors(startingAt: focused, limit: 10) {
            if let text = readSelectedTextByRange(element), !text.isEmpty {
                return ExtractedText(text: text, method: .accessibilitySelection)
            }
            if let text = stringAttribute(element, attribute: kAXSelectedTextAttribute), !text.isEmpty {
                return ExtractedText(text: text, method: .accessibilitySelection)
            }
        }
        throw FullCopyError.noSelectedText
    }

    func readFullText(applicationPID: pid_t) throws -> ExtractedText {
        guard isTrusted(prompt: false) else {
            throw FullCopyError.accessibilityPermissionMissing
        }
        let focused = try focusedElement(applicationPID: applicationPID)
        let candidates = elementAndAncestors(startingAt: focused, limit: 14)
        var bestRange: ExtractedText?
        var bestValue: ExtractedText?

        for element in candidates {
            if let text = readTextByParameterizedRange(element), !text.isEmpty {
                bestRange = longer(bestRange, ExtractedText(text: text, method: .accessibilityRange))
            }
            if let text = readableValue(element), !text.isEmpty {
                bestValue = longer(bestValue, ExtractedText(text: text, method: .accessibilityValue))
            }
        }

        if let bestRange { return bestRange }
        var best = bestValue
        let roots = candidates.filter { element in
            guard let role = stringAttribute(element, attribute: kAXRoleAttribute) else { return false }
            return documentRoles.contains(role)
        }
        for root in roots.prefix(4) {
            if let treeText = try collectTextFromTree(root: root), !treeText.isEmpty {
                best = longer(best, ExtractedText(text: treeText, method: .accessibilityTree))
            }
        }
        if let best, !best.text.isEmpty { return best }
        throw FullCopyError.noReadableText
    }

    func focusedElement(applicationPID: pid_t) throws -> AXUIElement {
        let application = AXUIElementCreateApplication(applicationPID)
        if let focused = elementAttribute(application, attribute: kAXFocusedUIElementAttribute) { return focused }
        let systemWide = AXUIElementCreateSystemWide()
        if let focused = elementAttribute(systemWide, attribute: kAXFocusedUIElementAttribute) { return focused }
        throw FullCopyError.noReadableText
    }

    func selectedTextRange(of element: AXUIElement) -> AXValue? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value)
        guard error == .success, let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXValue.self)
    }

    func restoreSelectedTextRange(_ range: AXValue?, to element: AXUIElement?) {
        guard let range, let element else { return }
        AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, range)
    }

    private func longer(_ lhs: ExtractedText?, _ rhs: ExtractedText) -> ExtractedText {
        guard let lhs else { return rhs }
        return rhs.text.count > lhs.text.count ? rhs : lhs
    }

    private func elementAndAncestors(startingAt element: AXUIElement, limit: Int) -> [AXUIElement] {
        var result: [AXUIElement] = []
        var current: AXUIElement? = element
        while let item = current, result.count < limit {
            result.append(item)
            current = elementAttribute(item, attribute: kAXParentAttribute)
        }
        return result
    }

    private func readTextByParameterizedRange(_ element: AXUIElement) -> String? {
        guard let countNumber = numberAttribute(element, attribute: kAXNumberOfCharactersAttribute) else { return nil }
        let characterCount = countNumber.intValue
        guard characterCount > 0 else { return nil }
        return readString(element: element, range: CFRange(location: 0, length: characterCount))
    }

    private func readSelectedTextByRange(_ element: AXUIElement) -> String? {
        guard let rangeValue = selectedTextRange(of: element) else { return nil }
        var range = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &range), range.length > 0 else { return nil }
        return readString(element: element, range: range)
    }

    private func readString(element: AXUIElement, range: CFRange) -> String? {
        let chunkSize = 32_768
        let end = range.location + range.length
        var offset = range.location
        var output = String()
        output.reserveCapacity(range.length)

        while offset < end {
            let length = min(chunkSize, end - offset)
            var chunkRange = CFRange(location: offset, length: length)
            guard let axRange = AXValueCreate(.cfRange, &chunkRange) else { return nil }
            var value: CFTypeRef?
            let error = AXUIElementCopyParameterizedAttributeValue(
                element,
                kAXStringForRangeParameterizedAttribute as CFString,
                axRange,
                &value
            )
            guard error == .success, let chunk = value as? String else { return nil }
            output.append(chunk)
            offset += length
        }

        guard output.utf16.count == range.length else { return nil }
        return output
    }

    private func readableValue(_ element: AXUIElement) -> String? {
        if let value = stringAttribute(element, attribute: kAXValueAttribute) { return value }
        var rawValue: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &rawValue)
        guard error == .success, let rawValue else { return nil }
        if let attributed = rawValue as? NSAttributedString { return attributed.string }
        return nil
    }

    private func collectTextFromTree(root: AXUIElement) throws -> String? {
        let maxNodes = 100_000
        var queue: [AXUIElement] = [root]
        var cursor = 0
        var visitedNodes = 0
        var pieces: [String] = []
        var lastPiece: String?

        while cursor < queue.count {
            if visitedNodes >= maxNodes { throw FullCopyError.accessibilityTreeTooLarge }
            let element = queue[cursor]
            cursor += 1
            visitedNodes += 1
            let role = stringAttribute(element, attribute: kAXRoleAttribute) ?? ""
            var consumedAsText = false
            if directTextRoles.contains(role),
               let text = preferredText(of: element),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if text != lastPiece {
                    pieces.append(text)
                    lastPiece = text
                }
                consumedAsText = true
            }
            if !consumedAsText, let children = elementsAttribute(element, attribute: kAXChildrenAttribute) {
                queue.append(contentsOf: children)
            }
        }

        guard !pieces.isEmpty else { return nil }
        return pieces.joined(separator: "\n")
    }

    private func preferredText(of element: AXUIElement) -> String? {
        if let value = readableValue(element), !value.isEmpty { return value }
        if let title = stringAttribute(element, attribute: kAXTitleAttribute), !title.isEmpty { return title }
        if let description = stringAttribute(element, attribute: kAXDescriptionAttribute), !description.isEmpty { return description }
        return nil
    }

    private func stringAttribute(_ element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success, let value else { return nil }
        if let string = value as? String { return string }
        if let attributed = value as? NSAttributedString { return attributed.string }
        return nil
    }

    private func numberAttribute(_ element: AXUIElement, attribute: String) -> NSNumber? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else { return nil }
        return value as? NSNumber
    }

    private func elementAttribute(_ element: AXUIElement, attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success, let value else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func elementsAttribute(_ element: AXUIElement, attribute: String) -> [AXUIElement]? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success, let values = value as? [AXUIElement] else { return nil }
        return values
    }
}
