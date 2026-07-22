import AppKit

final class ToastPresenter {
    private var panel: NSPanel?
    private var closeWorkItem: DispatchWorkItem?

    func show(_ message: String, isError: Bool = false) {
        DispatchQueue.main.async {
            self.closeWorkItem?.cancel()
            self.panel?.orderOut(nil)

            let label = NSTextField(wrappingLabelWithString: message)
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.textColor = .white
            label.alignment = .left
            label.maximumNumberOfLines = 5

            let icon = NSImageView()
            icon.image = NSImage(
                systemSymbolName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                accessibilityDescription: nil
            )
            icon.contentTintColor = .white
            icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)

            let stack = NSStackView(views: [icon, label])
            stack.orientation = .horizontal
            stack.alignment = .centerY
            stack.spacing = 10
            stack.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)

            let fitting = stack.fittingSize
            let width = min(max(fitting.width, 260), 520)
            let height = max(fitting.height, 48)

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = NSColor.black.withAlphaComponent(0.86)
            panel.level = .floating
            panel.hasShadow = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = stack
            panel.contentView?.wantsLayer = true
            panel.contentView?.layer?.cornerRadius = 12
            panel.contentView?.layer?.masksToBounds = true

            let mouse = NSEvent.mouseLocation
            let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
            if let visibleFrame = screen?.visibleFrame {
                panel.setFrameOrigin(NSPoint(
                    x: visibleFrame.maxX - width - 24,
                    y: visibleFrame.maxY - height - 24
                ))
            }

            panel.orderFrontRegardless()
            self.panel = panel

            let work = DispatchWorkItem { [weak self] in
                self?.panel?.orderOut(nil)
                self?.panel = nil
            }
            self.closeWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + (isError ? 4.5 : 2.8), execute: work)
        }
    }
}
