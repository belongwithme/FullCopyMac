import AppKit
import Foundation

struct PasteboardSnapshot {
    struct Item {
        let values: [(NSPasteboard.PasteboardType, Data)]
    }
    let items: [Item]
}

final class PasteboardManager {
    private let pasteboard = NSPasteboard.general

    func writeAndVerify(_ text: String) throws -> (characters: Int, utf8Bytes: Int) {
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw FullCopyError.pasteboardWriteFailed
        }
        guard let copied = pasteboard.string(forType: .string) else {
            throw FullCopyError.pasteboardReadBackFailed
        }
        guard copied == text else {
            throw FullCopyError.pasteboardMismatch(
                expectedCharacters: text.count,
                actualCharacters: copied.count
            )
        }
        return (text.count, text.lengthOfBytes(using: .utf8))
    }

    func snapshot() -> PasteboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            let values = item.types.compactMap { type -> (NSPasteboard.PasteboardType, Data)? in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
            return PasteboardSnapshot.Item(values: values)
        }
        return PasteboardSnapshot(items: items)
    }

    func restore(_ snapshot: PasteboardSnapshot) {
        pasteboard.clearContents()
        let items: [NSPasteboardItem] = snapshot.items.map { snapshotItem in
            let item = NSPasteboardItem()
            for (type, data) in snapshotItem.values {
                item.setData(data, forType: type)
            }
            return item
        }
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }

    func replaceWithSentinel(_ sentinel: String) {
        pasteboard.clearContents()
        pasteboard.setString(sentinel, forType: .string)
    }

    func currentString() -> String? {
        pasteboard.string(forType: .string)
    }
}
