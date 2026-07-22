import AppKit

final class WelcomeWindowController: NSWindowController {
    private let permissionStatusLabel = NSTextField(labelWithString: "")
    private let onRequestPermission: () -> Void
    private let onOpenSettings: () -> Void
    private let isTrusted: () -> Bool

    init(
        isTrusted: @escaping () -> Bool,
        onRequestPermission: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.isTrusted = isTrusted
        self.onRequestPermission = onRequestPermission
        self.onOpenSettings = onOpenSettings

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 390),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "全文复制助手"
        window.center()
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]

        super.init(window: window)
        window.contentView = makeContentView()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func showAndActivate() {
        refreshPermissionStatus()
        guard let window else { return }
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    func refreshPermissionStatus() {
        if isTrusted() {
            permissionStatusLabel.stringValue = "辅助功能权限：已授权"
            permissionStatusLabel.textColor = .systemGreen
        } else {
            permissionStatusLabel.stringValue = "辅助功能权限：未授权"
            permissionStatusLabel.textColor = .systemRed
        }
    }

    private func makeContentView() -> NSView {
        let title = NSTextField(labelWithString: "全文复制助手已经启动")
        title.font = .systemFont(ofSize: 24, weight: .semibold)

        let description = NSTextField(wrappingLabelWithString: "应用会常驻菜单栏。它不会在你打开文档时自动读取内容，只有按下快捷键或点击菜单命令后才会执行复制。")
        description.font = .systemFont(ofSize: 14)
        description.textColor = .secondaryLabelColor

        permissionStatusLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        let permissionButton = NSButton(title: "申请辅助功能权限", target: self, action: #selector(requestPermission))
        permissionButton.bezelStyle = .rounded

        let settingsButton = NSButton(title: "打开辅助功能设置", target: self, action: #selector(openSettings))
        settingsButton.bezelStyle = .rounded

        let buttons = NSStackView(views: [permissionButton, settingsButton])
        buttons.orientation = .horizontal
        buttons.spacing = 10

        let divider = NSBox()
        divider.boxType = .separator

        let selectionTitle = shortcutRow(
            shortcut: "⌃⌥C",
            title: "复制当前选中文本",
            detail: "先在任意应用中选中文字，再按快捷键。"
        )
        let fullTitle = shortcutRow(
            shortcut: "⌃⌥A",
            title: "复制当前文档全文",
            detail: "先把光标放在文档正文或编辑区域，再按快捷键。"
        )

        let tip = NSTextField(wrappingLabelWithString: "复制完成后，屏幕右上角会显示来源应用、读取方式、字符数和剪贴板校验结果。关闭此窗口不会退出应用；退出请点击菜单栏剪贴板图标。")
        tip.font = .systemFont(ofSize: 12)
        tip.textColor = .tertiaryLabelColor

        let stack = NSStackView(views: [
            title,
            description,
            permissionStatusLabel,
            buttons,
            divider,
            selectionTitle,
            fullTitle,
            tip
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 26),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -24),
            divider.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        return container
    }

    private func shortcutRow(shortcut: String, title: String, detail: String) -> NSView {
        let badge = NSTextField(labelWithString: shortcut)
        badge.font = .monospacedSystemFont(ofSize: 17, weight: .semibold)
        badge.alignment = .center
        badge.wantsLayer = true
        badge.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        badge.layer?.cornerRadius = 8
        badge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 72),
            badge.heightAnchor.constraint(equalToConstant: 42)
        ])

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        let detailLabel = NSTextField(labelWithString: detail)
        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabelColor

        let labels = NSStackView(views: [titleLabel, detailLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 3

        let row = NSStackView(views: [badge, labels])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 14
        return row
    }

    @objc private func requestPermission() {
        onRequestPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.refreshPermissionStatus()
        }
    }

    @objc private func openSettings() {
        onOpenSettings()
    }
}
