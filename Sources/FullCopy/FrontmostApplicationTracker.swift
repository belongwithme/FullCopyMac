import AppKit

final class FrontmostApplicationTracker {
    private(set) var lastExternalPID: pid_t?
    private(set) var lastExternalName: String = "未知应用"

    init() {
        update(with: NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func applicationActivated(_ notification: Notification) {
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        update(with: app)
    }

    private func update(with app: NSRunningApplication?) {
        guard let app,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return
        }
        lastExternalPID = app.processIdentifier
        lastExternalName = app.localizedName ?? "未知应用"
    }
}
