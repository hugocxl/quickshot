import AppKit

@main
@MainActor
final class QuickshotApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Quickshot")
        statusItem.button?.toolTip = "Quickshot"

        let menu = NSMenu()
        menu.addItem(withTitle: "Quit Quickshot", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
