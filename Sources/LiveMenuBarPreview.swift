import AppKit

/// A fresh process reads the saved preferences without restarting any user's app.
@MainActor
final class LiveMenuBarPreview: NSObject {
    private var items: [NSStatusItem] = []
    private var symbolWidth: Double = 0
    private var textWidth: Double = 0

    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let preview = LiveMenuBarPreview()
        preview.show()
        withExtendedLifetime(preview) { app.run() }
    }

    private func show() {
        let text = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        text.button?.title = "MBS"
        text.button?.toolTip = "菜单栏间距 · 临时测试图标"
        items.append(text)
        let icon = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        icon.button?.image = NSImage(systemSymbolName: "arrow.left.and.right", accessibilityDescription: "间距测试")
        icon.button?.image?.isTemplate = true
        icon.button?.toolTip = "菜单栏间距 · 使用当前已保存设置"
        items.append(icon)
        for item in items {
            let menu = NSMenu()
            let heading = NSMenuItem(title: "菜单栏间距 · 测试图标", action: nil, keyEquivalent: "")
            heading.isEnabled = false
            menu.addItem(heading)
            let close = NSMenuItem(title: "收起测试图标", action: #selector(finish), keyEquivalent: "")
            close.target = self
            menu.addItem(close)
            item.menu = menu
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [self] in
            guard items.count == 2 else { return }
            textWidth = Double(items[0].button?.frame.width ?? 0)
            symbolWidth = Double(items[1].button?.frame.width ?? 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [self] in finish() }
    }

    @objc private func finish() {
        let result: [String: Any] = ["textWidth": textWidth, "symbolWidth": symbolWidth,
                                    "os": ProcessInfo.processInfo.operatingSystemVersionString,
                                    "scope": "own_AppKit_items_only"]
        if let data = try? JSONSerialization.data(withJSONObject: result) { FileHandle.standardOutput.write(data) }
        items.forEach { NSStatusBar.system.removeStatusItem($0) }
        items.removeAll()
        NSApplication.shared.terminate(nil)
    }
}
