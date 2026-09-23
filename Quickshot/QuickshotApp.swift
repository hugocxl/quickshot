import AppKit

@main
@MainActor
final class QuickshotApp: NSObject, NSApplicationDelegate {
    static func main() {
        let application = NSApplication.shared
        let delegate = QuickshotApp()
        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }

    private var statusItem: NSStatusItem!
    private let hotKeyManager = HotKeyManager()
    private let statusMessage = NSMenuItem(title: "Double-tap ⌘ to capture", action: nil, keyEquivalent: "")
    private var permissionTimer: Timer?
    private var capturing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setStatusIcon("camera.viewfinder", toolTip: "Quickshot: press Command twice")

        let menu = NSMenu()
        menu.addItem(statusMessage)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Take Screenshot", action: #selector(takeScreenshot), keyEquivalent: "")
        menu.addItem(withTitle: "Show Screenshots in Finder", action: #selector(showOutputFolder), keyEquivalent: "")
        menu.addItem(withTitle: "Screen Recording Permission…", action: #selector(openScreenPermission), keyEquivalent: "")
        menu.addItem(withTitle: "Input Monitoring Permission…", action: #selector(openInputPermission), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Quickshot", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items where item.action != nil { item.target = self }
        statusItem.menu = menu

        #if DEBUG
        if CommandLine.arguments.contains("--smoke-test") {
            precondition(NSApp.delegate === self)
            precondition(NSApp.activationPolicy() == .accessory)
            precondition(statusItem.isVisible && statusItem.button?.image != nil)
            precondition(statusItem.menu?.items.contains { $0.target === self } == true)
            print("PASS: application launched, delegate retained, menu-bar icon and actions installed, no Dock presence")
            NSApp.terminate(nil)
            return
        }
        #endif

        CGRequestListenEventAccess()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.retryShortcut() }
        }
        retryShortcut()
    }

    @objc private func takeScreenshot() {
        guard !capturing else { return }
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            setStatusIcon("lock", toolTip: "Enable Screen Recording in the menu; relaunch if macOS asks")
            return
        }

        capturing = true
        Task { @MainActor [self] in
            defer { capturing = false }
            do {
                let screenshotURL = try await ScreenshotService.captureActiveDisplay()
                NSPasteboard.general.clearContents()
                guard NSPasteboard.general.setString(screenshotURL.path, forType: .string) else {
                    setStatusIcon("exclamationmark.triangle", toolTip: "Saved screenshot, but clipboard is unavailable")
                    return
                }
                setStatusIcon("checkmark", toolTip: "Screenshot path copied: \(screenshotURL.lastPathComponent)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self, !capturing else { return }
                    setStatusIcon("camera.viewfinder", toolTip: "Quickshot: press Command twice")
                }
            } catch {
                setStatusIcon("exclamationmark.triangle", toolTip: error.localizedDescription)
            }
        }
    }

    private func retryShortcut() {
        guard hotKeyManager.register(onPress: { [weak self] in
            DispatchQueue.main.async { self?.takeScreenshot() }
        }) else {
            setStatusIcon("lock", toolTip: "Enable Input Monitoring for Quickshot using the menu")
            return
        }
        permissionTimer?.invalidate()
        permissionTimer = nil
        setStatusIcon("camera.viewfinder", toolTip: "Double-tap ⌘ to capture")
    }

    @objc private func openScreenPermission() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    @objc private func openInputPermission() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }

    @objc private func showOutputFolder() {
        guard let directory = try? ScreenshotService.outputDirectory() else { return }
        NSWorkspace.shared.open(directory)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func setStatusIcon(_ symbolName: String, toolTip: String) {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Quickshot")
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        statusItem.button?.image = image
        statusItem.button?.toolTip = toolTip
        statusMessage.title = toolTip
    }
}
