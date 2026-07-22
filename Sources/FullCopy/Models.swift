import Foundation

struct ExtractedText {
    enum Method: String {
        case accessibilitySelection = "辅助功能：选中文本"
        case accessibilityRange = "辅助功能：分块全文"
        case accessibilityValue = "辅助功能：控件全文"
        case accessibilityTree = "辅助功能：界面树"
        case keyboardCopy = "系统快捷键复制"
        case keyboardSelectAllCopy = "系统全选并复制"
    }

    let text: String
    let method: Method
}

enum CopyMode {
    case selection
    case fullDocument
}

enum FullCopyError: LocalizedError {
    case accessibilityPermissionMissing
    case targetApplicationUnavailable
    case noSelectedText
    case noReadableText
    case pasteboardWriteFailed
    case pasteboardReadBackFailed
    case pasteboardMismatch(expectedCharacters: Int, actualCharacters: Int)
    case keyboardCopyTimedOut
    case accessibilityTreeTooLarge

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionMissing:
            return "尚未授予辅助功能权限。"
        case .targetApplicationUnavailable:
            return "没有找到可读取的前台应用。"
        case .noSelectedText:
            return "当前应用没有可读取的选中文本。"
        case .noReadableText:
            return "当前应用没有向 macOS 暴露可读取的全文。"
        case .pasteboardWriteFailed:
            return "写入系统剪贴板失败。"
        case .pasteboardReadBackFailed:
            return "写入后无法从系统剪贴板回读。"
        case let .pasteboardMismatch(expected, actual):
            return "剪贴板校验不一致：原文 \(expected) 字符，回读 \(actual) 字符。"
        case .keyboardCopyTimedOut:
            return "目标应用未在规定时间内写入剪贴板。"
        case .accessibilityTreeTooLarge:
            return "目标应用的界面树过大，已明确停止读取，未静默截断。"
        }
    }
}
