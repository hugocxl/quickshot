import AppKit

@main
@MainActor
final class QuickshotApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotKeyManager = HotKeyManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setStatusIcon("camera.viewfinder", toolTip: "Quickshot: Control-Option-Command-4")

        let menu = NSMenu()
        menu.addItem(withTitle: "Take Screenshot", action: #selector(takeScreenshot), keyEquivalent: "4")
        menu.items.last?.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(withTitle: "Show Screenshots in Finder", action: #selector(showOutputFolder), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Quickshot", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu

        if !hotKeyManager.register(onPress: { [weak self] in self?.takeScreenshot() }) {
            setStatusIcon("exclamationmark.triangle", toolTip: "Quickshot: shortcut unavailable")
        }
    }

    @objc private func takeScreenshot() {
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            setStatusIcon("lock", toolTip: "Quickshot needs Screen Recording permission")
            return
        }

        do {
            let screenshotURL = try ScreenshotService.captureActiveDisplay()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(screenshotURL.path, forType: .string)
            setStatusIcon("checkmark", toolTip: "Screenshot path copied: \(screenshotURL.lastPathComponent)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.setStatusIcon("camera.viewfinder", toolTip: "Quickshot: Control-Option-Command-4")
            }
        } catch {
            setStatusIcon("exclamationmark.triangle", toolTip: error.localizedDescription)
        }
    }

    @objc private func showOutputFolder() {
        guard let directory = try? ScreenshotService.outputDirectory() else { return }
        NSWorkspace.shared.open(directory)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func setStatusIcon(_ symbolName: String, toolTip: String) {
        statusItem.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Quickshot")
        statusItem.button?.toolTip = toolTip
    }
}
