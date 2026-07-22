import AppKit
import ApplicationServices
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let hotKeyManager = GlobalHotKeyManager()
    private let appTracker = FrontmostApplicationTracker()
    private let reader = AccessibilityTextReader()
    private let pasteboardManager = PasteboardManager()
    private let toast = ToastPresenter()
    private let workQueue = DispatchQueue(label: "com.ian.fullcopy.worker", qos: .userInitiated)

    private lazy var keyboardFallback = KeyboardCopyFallback(
        pasteboardManager: pasteboardManager,
        accessibilityReader: reader
    )

    private var isWorking = false
    private var permissionMenuItem: NSMenuItem?
    private lazy var welcomeWindowController = WelcomeWindowController(
        isTrusted: { [weak self] in self?.reader.isTrusted(prompt: false) ?? false },
        onRequestPermission: { [weak self] in self?.requestAccessibilityPermission() },
        onOpenSettings: { [weak self] in self?.openAccessibilitySettings() }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        registerHotKeys()
        refreshPermissionMenuItem()
        welcomeWindowController.showAndActivate()
        if !reader.isTrusted(prompt: true) {
            toast.show("请授予辅助功能权限。控制面板已显示操作入口。", isError: true)
        }
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "全文复制助手")
            button.toolTip = "全文复制助手"
        }
        let menu = NSMenu()
        menu.addItem(menuItem(title: "显示控制面板", action: #selector(showControlPanel)))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "复制选中文本    ⌃⌥C", action: #selector(copySelectionFromMenu)))
        menu.addItem(menuItem(title: "复制当前文档全文    ⌃⌥A", action: #selector(copyFullDocumentFromMenu)))
        menu.addItem(.separator())
        let permissionItem = menuItem(title: "辅助功能权限", action: #selector(requestAccessibilityPermission))
        permissionMenuItem = permissionItem
        menu.addItem(permissionItem)
        menu.addItem(menuItem(title: "打开辅助功能设置…", action: #selector(openAccessibilitySettings)))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "退出全文复制助手", action: #selector(quit)))
        menu.delegate = self
        statusItem.menu = menu
    }

    private func menuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func registerHotKeys() {
        let modifiers = UInt32(controlKey | optionKey)
        let selectionRegistered = hotKeyManager.register(id: 1, keyCode: UInt32(kVK_ANSI_C), modifiers: modifiers) { [weak self] in
            self?.performCopy(mode: .selection)
        }
        let fullRegistered = hotKeyManager.register(id: 2, keyCode: UInt32(kVK_ANSI_A), modifiers: modifiers) { [weak self] in
            self?.performCopy(mode: .fullDocument)
        }
        if !selectionRegistered || !fullRegistered {
            toast.show("全局快捷键注册失败，可能与其他应用冲突。菜单功能仍可使用。", isError: true)
        }
    }

    @objc private func showControlPanel() { welcomeWindowController.showAndActivate() }

    @objc private func copySelectionFromMenu() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in self?.performCopy(mode: .selection) }
    }

    @objc private func copyFullDocumentFromMenu() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in self?.performCopy(mode: .fullDocument) }
    }

    private func performCopy(mode: CopyMode) {
        guard !isWorking else { toast.show("正在读取，请勿重复触发。", isError: true); return }
        guard reader.isTrusted(prompt: false) else { requestAccessibilityPermission(); return }
        guard let pid = appTracker.lastExternalPID else { toast.show("没有找到可读取的前台应用。", isError: true); return }

        isWorking = true
        let appName = appTracker.lastExternalName
        statusItem.button?.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "正在读取")

        workQueue.async { [weak self] in
            guard let self else { return }
            do {
                let extracted: ExtractedText
                switch mode {
                case .selection:
                    do { extracted = try self.reader.readSelectedText(applicationPID: pid) }
                    catch { extracted = try self.keyboardFallback.copy(applicationPID: pid, selectAll: false) }
                case .fullDocument:
                    do { extracted = try self.reader.readFullText(applicationPID: pid) }
                    catch FullCopyError.accessibilityTreeTooLarge { throw FullCopyError.accessibilityTreeTooLarge }
                    catch { extracted = try self.keyboardFallback.copy(applicationPID: pid, selectAll: true) }
                }
                let verification = try self.pasteboardManager.writeAndVerify(extracted.text)
                let byteDescription = ByteCountFormatter.string(fromByteCount: Int64(verification.utf8Bytes), countStyle: .file)
                self.finish {
                    self.toast.show("已复制 \(verification.characters.formatted()) 个字符（\(byteDescription)）\n来源：\(appName)\n方式：\(extracted.method.rawValue)\n剪贴板回读一致")
                }
            } catch {
                self.finish {
                    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    self.toast.show("复制失败：\(message)", isError: true)
                }
            }
        }
    }

    private func finish(_ completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.isWorking = false
            self.statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "全文复制助手")
            completion()
        }
    }

    @objc private func requestAccessibilityPermission() {
        _ = reader.isTrusted(prompt: true)
        refreshPermissionMenuItem()
        if !reader.isTrusted(prompt: false) {
            toast.show("授权后请重新触发复制；若仍无效，请退出并重新打开应用。", isError: true)
        }
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    private func refreshPermissionMenuItem() {
        let trusted = reader.isTrusted(prompt: false)
        permissionMenuItem?.title = trusted ? "辅助功能权限：已授权" : "辅助功能权限：未授权（点击申请）"
        welcomeWindowController.refreshPermissionStatus()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        welcomeWindowController.showAndActivate()
        return true
    }

    @objc private func quit() { NSApplication.shared.terminate(nil) }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) { refreshPermissionMenuItem() }
}
