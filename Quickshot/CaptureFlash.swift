import AppKit

@MainActor
final class CaptureFlash {
    private var panel: NSPanel?

    func show(on screen: NSScreen) async {
        let panel = NSPanel(contentRect: screen.frame,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.setFrame(screen.frame, display: false)
        panel.backgroundColor = .white
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.alphaValue = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.12 : 0.28
        self.panel = panel
        panel.orderFrontRegardless()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                panel.animator().alphaValue = 0
            } completionHandler: {
                continuation.resume()
            }
        }
        panel.orderOut(nil)
        panel.close()
        self.panel = nil
    }
}
