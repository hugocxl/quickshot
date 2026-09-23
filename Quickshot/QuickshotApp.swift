import AppKit
import ScreenCaptureKit

@main
@MainActor
final class QuickshotApp: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static func main() {
        let application = NSApplication.shared
        let delegate = QuickshotApp()
        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }

    private var statusItem: NSStatusItem!
    private let hotKeyManager = HotKeyManager()
    private let captureFeedback = CaptureFeedback()
    private lazy var permissions = PermissionWindowController(onRetry: { [weak self] in self?.retryShortcut() })
    private let statusMessage = NSMenuItem(title: "Left ⌘ + Right ⌘ to capture", action: nil, keyEquivalent: "")
    private let shortcutStatus = NSMenuItem(title: "Checking keyboard access…", action: nil, keyEquivalent: "")
    private let screenStatus = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var didShowPermissionSetup = false
    private var capturing = false
    private var recognizedChords = 0
    private var completedCaptures = 0
    private var lastCaptureResult = "No capture attempted"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setStatusIcon("camera.viewfinder", toolTip: "Left ⌘ + Right ⌘ to capture")

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(statusMessage)
        menu.addItem(shortcutStatus)
        menu.addItem(screenStatus)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Take Screenshot", action: #selector(takeScreenshot), keyEquivalent: "")
        menu.addItem(withTitle: "Show Screenshots in Finder", action: #selector(showOutputFolder), keyEquivalent: "")
        menu.addItem(withTitle: "Permissions & Setup…", action: #selector(showPermissions), keyEquivalent: "")
        menu.addItem(withTitle: "Retry Shortcut", action: #selector(retryShortcut), keyEquivalent: "")
        menu.addItem(withTitle: "Copy Permission Diagnostics", action: #selector(copyDiagnostics), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Quickshot", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items where item.action != nil { item.target = self }
        statusItem.menu = menu

        #if DEBUG
        if CommandLine.arguments.contains("--setup-preview") {
            permissions.show()
            return
        }
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

        hotKeyManager.start(onPress: { [weak self] in
            guard let self else { return }
            recognizedChords += 1
            NSLog("Quickshot chord recognized; count=%ld; frontmost=%@", recognizedChords,
                  NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown")
            takeScreenshot()
        }, onStatus: { [weak self] status in
            guard let self else { return }
            shortcutStatus.title = status.rawValue
            NSLog("Quickshot: %@", status.rawValue)
            #if DEBUG
            if CommandLine.arguments.contains("--permission-diagnostics") {
                // LaunchServices must be used for permission tests; direct shell launches may
                // inherit the terminal application's TCC identity. Delay to verify background access.
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(3))
                    guard let self else { return }
                    let report = permissionDiagnostics()
                    print(report)
                    NSLog("%@", report)
                    NSApp.terminate(nil)
                }
                return
            }
            #endif
            if !didShowPermissionSetup && (status == .permissionDenied || !CGPreflightScreenCaptureAccess()) {
                didShowPermissionSetup = true
                permissions.show()
            }
        })
    }

    func applicationWillTerminate(_ notification: Notification) {
        captureFeedback.dismiss()
        permissions.close()
        hotKeyManager.stop()
    }

    @objc private func takeScreenshot() {
        guard !capturing else {
            NSLog("Quickshot capture skipped: previous capture still in progress")
            return
        }
        capturing = true
        captureFeedback.dismiss()
        lastCaptureResult = "Capture in progress"
        Task { @MainActor [self] in
            defer { capturing = false }
            do {
                let screenshot = try await ScreenshotService.captureActiveDisplay()
                screenStatus.title = "Screen Recording: capture succeeded"
                let screenshotURL = screenshot.url
                NSPasteboard.general.clearContents()
                guard NSPasteboard.general.setString(screenshotURL.path, forType: .string) else {
                    lastCaptureResult = "PNG saved; clipboard write failed"
                    setStatusIcon("exclamationmark.triangle", toolTip: "Saved screenshot, but clipboard is unavailable")
                    _ = permissions.presentError(title: "Screenshot saved. Clipboard unavailable.",
                        detail: "Your PNG is safe at \(screenshotURL.path). Try copying its path again from Finder.")
                    return
                }
                setStatusIcon("checkmark", toolTip: "Screenshot path copied: \(screenshotURL.lastPathComponent)")
                completedCaptures += 1
                lastCaptureResult = "PNG saved and path copied (\(completedCaptures) total)"
                NSLog("Quickshot capture succeeded; count=%ld", completedCaptures)
                captureFeedback.show(image: screenshot.image, on: screenshot.screen, fileURL: screenshotURL)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self, !capturing else { return }
                    setStatusIcon("camera.viewfinder", toolTip: "Quickshot — Left ⌘ + Right ⌘")
                }
            } catch {
                let failure = error as NSError
                lastCaptureResult = "\(failure.domain) \(failure.code): \(failure.localizedDescription)"
                if failure.domain == SCStreamErrorDomain && failure.code == SCStreamError.Code.userDeclined.rawValue {
                    screenStatus.title = "Screen Recording: macOS denied this running build"
                    setStatusIcon("exclamationmark.triangle", toolTip: "Screen access denied — relaunch the signed build and re-authorize if needed")
                    permissions.show(reason: "macOS denied screen access to this running build. Allow Screen Recording below, then reopen Quickshot if asked.")
                } else {
                    setStatusIcon("exclamationmark.triangle", toolTip: error.localizedDescription)
                    if permissions.presentError(title: "Couldn’t capture your screen", detail: error.localizedDescription, retry: true) {
                        DispatchQueue.main.async { [weak self] in self?.takeScreenshot() }
                    }
                }
                NSLog("Quickshot capture failed: %@ (%@ %ld)", failure.localizedDescription, failure.domain, failure.code)
            }
        }
    }

    @objc private func retryShortcut() {
        hotKeyManager.refresh()
    }

    func menuWillOpen(_ menu: NSMenu) {
        retryShortcut()
        screenStatus.title = CGPreflightScreenCaptureAccess()
            ? "Screen Recording: macOS reports allowed"
            : "Screen Recording: not confirmed — try Take Screenshot"
    }

    private func permissionDiagnostics() -> String {
        """
        Quickshot permission diagnostics
        Bundle: \(Bundle.main.bundleIdentifier ?? "unknown")
        App: \(Bundle.main.bundleURL.path)
        PID: \(ProcessInfo.processInfo.processIdentifier)
        Input preflight: \(CGPreflightListenEventAccess())
        Screen preflight: \(CGPreflightScreenCaptureAccess())
        \(hotKeyManager.status.rawValue)
        Recognized Command chords: \(recognizedChords)
        Completed captures: \(completedCaptures)
        Capture busy: \(capturing)
        Last capture: \(lastCaptureResult)
        Frontmost app: \(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown")
        Global keyboard readiness requires both an Input Monitoring grant and an enabled event tap.
        If Settings shows enabled but this build is denied, stop the app, rebuild with Apple Development signing,
        remove the old Quickshot permission entries, add this app path, then relaunch.
        """
    }

    @objc private func copyDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(permissionDiagnostics(), forType: .string)
    }

    @objc private func showPermissions() { permissions.show() }

    @objc private func showOutputFolder() {
        do {
            NSWorkspace.shared.open(try ScreenshotService.outputDirectory())
        } catch {
            _ = permissions.presentError(title: "Couldn’t open your screenshots folder", detail: error.localizedDescription)
        }
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
