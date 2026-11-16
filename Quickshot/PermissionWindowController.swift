import AppKit
import SwiftUI

@MainActor
final class PermissionWindowController: NSObject, NSWindowDelegate {
    private let model = PermissionModel()
    private let onRetry: () -> Void
    private var panel: NSPanel?
    private var refreshTimer: Timer?

    init(onRetry: @escaping () -> Void) { self.onRetry = onRetry }

    func show(reason: String? = nil) {
        model.message = reason
        model.refresh()
        if panel == nil {
            let panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: 520, height: 580),
                                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            panel.title = "Set up Quickshot"
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.delegate = self
            panel.contentView = NSHostingView(rootView: PermissionSetupView(model: model, onDone: { [weak self] in
                self?.panel?.close()
                self?.onRetry()
            }))
            self.panel = panel
        }
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }), let panel {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(CGPoint(x: frame.midX - panel.frame.width / 2, y: frame.midY - panel.frame.height / 2))
        }
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.model.refresh()
                self?.onRetry()
            }
        }
        refreshTimer?.tolerance = 0.2
    }

    func windowWillClose(_ notification: Notification) {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func close() { panel?.close() }

    /// Native error modal with a concrete recovery action; only shown after an explicit operation fails.
    func presentError(title: String, detail: String, retry: Bool = false) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: retry ? "Try Again" : "OK")
        if retry { alert.addButton(withTitle: "Cancel") }
        alert.window.level = .floating
        alert.window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn && retry
    }
}

@MainActor
private final class PermissionModel: ObservableObject {
    @Published var inputAllowed = false
    @Published var screenAllowed = false
    @Published var message: String?

    var ready: Bool { inputAllowed && screenAllowed }

    func refresh() {
        inputAllowed = CGPreflightListenEventAccess()
        screenAllowed = CGPreflightScreenCaptureAccess()
    }

    func allowInput() {
        if !CGRequestListenEventAccess() { openSettings("Privacy_ListenEvent") }
        refresh()
    }

    func allowScreen() {
        if !CGRequestScreenCaptureAccess() { openSettings("Privacy_ScreenCapture") }
        refresh()
    }

    func openSettings(_ pane: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!)
    }

    func revealApp() { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
}

private struct PermissionSetupView: View {
    @ObservedObject var model: PermissionModel
    let onDone: () -> Void
    @State private var showRecovery = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
            VStack(spacing: 22) {
            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 88, height: 88)
                    .accessibilityHidden(true)
                Text(model.ready ? "You’re ready to Quickshot." : "A little setup. A lot less friction.")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(model.ready
                     ? "Press both Command keys to capture.\nYour screenshot’s path will be ready to paste."
                     : "Two permissions unlock one effortless shortcut.\nYour screenshots stay on this Mac.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                permissionCard(symbol: "keyboard", title: "Global shortcut",
                    subtitle: "Input Monitoring recognizes both Command keys, even when another app is focused.",
                    allowed: model.inputAllowed, action: model.allowInput,
                    settings: { model.openSettings("Privacy_ListenEvent") })
                permissionCard(symbol: "rectangle.inset.filled.and.person.filled", title: "Screen capture",
                    subtitle: "Screen Recording allows a screenshot of the display under your pointer, only when you ask.",
                    allowed: model.screenAllowed, action: model.allowScreen,
                    settings: { model.openSettings("Privacy_ScreenCapture") })
            }

            if let message = model.message, !model.ready {
                Label(message, systemImage: "info.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DisclosureGroup("Already enabled, but not working?", isExpanded: $showRecovery) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("macOS may still remember an older build. Remove Quickshot from the affected permission list, add this running app again, then quit and reopen Quickshot. Follow any restart request from macOS.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Button("Show This App in Finder", action: model.revealApp)
                        .buttonStyle(.link)
                }.padding(.top, 8)
            }
            .font(.system(size: 12))
            }.padding(28)
            }
            Divider().padding(.horizontal, 28)
            HStack(spacing: 8) {
                Text("⌘ Left").font(.system(size: 14, weight: .medium, design: .monospaced))
                    .padding(8).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                Text("+").foregroundStyle(.tertiary)
                Text("⌘ Right").font(.system(size: 14, weight: .medium, design: .monospaced))
                    .padding(8).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                Text("Press together").font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Button(model.ready ? "Let’s go" : "Set Up Later", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }.padding(28)
        }
        .tint(Color.accentColor)
        .frame(width: 520, height: 580)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func permissionCard(symbol: String, title: String, subtitle: String, allowed: Bool,
                                action: @escaping () -> Void, settings: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 23, weight: .regular))
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if allowed {
                Button(action: settings) {
                    Label("Allowed", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.green)
                }.buttonStyle(.plain).help("Open permission in System Settings")
            } else {
                Button("Allow", action: action).buttonStyle(.borderedProminent).controlSize(.regular)
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
    }
}
