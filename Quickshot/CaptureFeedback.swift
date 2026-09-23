import AppKit
import QuartzCore

@MainActor
final class CaptureFeedback: NSObject {
    private var panel: NSPanel?
    private var presentation: Task<Void, Never>?
    private var sound: NSSound?

    override init() {
        super.init()
        sound = NSSound(contentsOfFile: "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Grab.aif", byReference: true)
            ?? NSSound(named: "Tink")
        sound?.volume = 0.55
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(dismiss),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dismiss),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc func dismiss() {
        presentation?.cancel()
        presentation = nil
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }

    func show(image: CGImage, on screen: NSScreen, fileURL: URL) {
        dismiss()
        sound?.stop()
        sound?.play()
        let layout = CapturePreviewLayout(screen: screen.frame, visible: screen.visibleFrame,
                                          imageSize: CGSize(width: image.width, height: image.height))
        let reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !reducedMotion { showFlight(image: image, screen: screen, target: layout.image) }

        presentation = Task { @MainActor [weak self] in
            do {
                if !reducedMotion { try await Task.sleep(for: .milliseconds(720)) }
                guard let self, !Task.isCancelled else { return }
                panel?.orderOut(nil)
                panel?.close()
                showPreview(image: image, layout: layout, fileURL: fileURL, fadeIn: reducedMotion)
                try await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.22
                    panel?.animator().alphaValue = 0
                }, completionHandler: nil)
                try await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                dismiss()
            } catch { /* Replaced by a new capture, dismissed, or changed Space. */ }
        }
    }

    private func makePanel(frame: CGRect, interactive: Bool) -> NSPanel {
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.setFrame(frame, display: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = interactive
        panel.ignoresMouseEvents = !interactive
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        return panel
    }

    private func showFlight(image: CGImage, screen: NSScreen, target: CGRect) {
        let panel = makePanel(frame: screen.frame, interactive: false)
        let view = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        guard let root = view.layer else { return }
        panel.contentView = view
        self.panel = panel

        let bounds = view.bounds
        let scale = target.width / bounds.width
        let destination = CGPoint(x: target.midX - screen.frame.minX, y: target.midY - screen.frame.minY)
        let start = CGPoint(x: bounds.midX, y: bounds.midY)
        let card = CALayer()
        card.bounds = bounds
        card.position = start
        card.backgroundColor = NSColor.windowBackgroundColor.cgColor
        card.shadowColor = NSColor.black.cgColor
        card.shadowOffset = CGSize(width: 0, height: -5 / scale)
        card.shadowOpacity = 0.24
        card.shadowRadius = 18 / scale
        card.cornerRadius = 14 / scale
        let photo = CALayer()
        photo.frame = bounds
        photo.contents = image
        photo.contentsGravity = .resize
        photo.masksToBounds = true
        photo.cornerRadius = 14 / scale
        photo.borderColor = NSColor.white.withAlphaComponent(0.75).cgColor
        photo.borderWidth = 1 / scale
        card.addSublayer(photo)
        root.addSublayer(card)

        // Commit final model state before adding presentation animations, so there is no snap-back.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        card.position = destination
        card.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        CATransaction.commit()
        let times: [NSNumber] = [0, 0.10, 0.28, 1]
        let ease = CAMediaTimingFunction(controlPoints: 0.22, 0.85, 0.25, 1)
        func keyframes(_ key: String, _ values: [Any]) -> CAKeyframeAnimation {
            let animation = CAKeyframeAnimation(keyPath: key)
            animation.values = values
            animation.keyTimes = times
            animation.timingFunctions = [CAMediaTimingFunction(name: .easeOut), ease, ease]
            animation.duration = 0.72
            return animation
        }
        card.add(keyframes("position", [NSValue(point: start), NSValue(point: start),
            NSValue(point: CGPoint(x: start.x, y: start.y + 6)), NSValue(point: destination)]), forKey: "flight")
        card.add(keyframes("transform.scale", [1, 1, 0.96, scale]), forKey: "scale")
        photo.add(keyframes("cornerRadius", [0, 0, 14, 14 / scale]), forKey: "corners")
        card.add(keyframes("cornerRadius", [0, 0, 14, 14 / scale]), forKey: "corners")
        card.add(keyframes("shadowOpacity", [0, 0, 0.16, 0.24]), forKey: "shadow")
        card.add(keyframes("shadowRadius", [0, 0, 18, 18 / scale]), forKey: "shadowRadius")
        photo.add(keyframes("borderWidth", [0, 0, 1, 1 / scale]), forKey: "border")

        let exposure = CALayer()
        exposure.frame = bounds
        exposure.backgroundColor = NSColor.white.cgColor
        exposure.opacity = 0
        root.addSublayer(exposure)
        let flash = CAKeyframeAnimation(keyPath: "opacity")
        flash.values = [0.0, 0.22, 0.0]
        flash.keyTimes = [0, 0.15, 1]
        flash.duration = 0.22
        exposure.add(flash, forKey: "exposure")
        panel.orderFrontRegardless()
    }

    private func showPreview(image: CGImage, layout: CapturePreviewLayout, fileURL: URL, fadeIn: Bool) {
        let panel = makePanel(frame: layout.panel, interactive: true)
        panel.contentView = CapturePreviewView(image: image, size: layout.panel.size, fileURL: fileURL,
                                              onDismiss: { [weak self] in self?.dismiss() })
        self.panel = panel
        panel.alphaValue = fadeIn ? 0 : 1
        panel.orderFrontRegardless()
        if fadeIn {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                panel.animator().alphaValue = 1
            }
        }
        NSAccessibility.post(element: panel, notification: .announcementRequested,
            userInfo: [.announcement: "Screenshot saved. File path copied to clipboard.", .priority: NSAccessibilityPriorityLevel.medium.rawValue])
    }
}

@MainActor
private final class CapturePreviewView: NSView {
    private let fileURL: URL
    private let onDismiss: () -> Void

    init(image: CGImage, size: CGSize, fileURL: URL, onDismiss: @escaping () -> Void) {
        self.fileURL = fileURL
        self.onDismiss = onDismiss
        super.init(frame: CGRect(origin: .zero, size: size))
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        let photo = NSButton(frame: CGRect(x: 0, y: CapturePreviewLayout.footerHeight,
                                          width: size.width, height: size.height - CapturePreviewLayout.footerHeight))
        photo.isBordered = false
        photo.image = NSImage(cgImage: image, size: photo.frame.size)
        photo.imageScaling = .scaleAxesIndependently
        photo.imagePosition = .imageOnly
        photo.target = self
        photo.action = #selector(openImage)
        photo.toolTip = "Open screenshot"
        photo.setAccessibilityLabel("Open captured screenshot")
        addSubview(photo)

        let check = NSImageView(frame: CGRect(x: 12, y: 10, width: 16, height: 16))
        check.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
        check.contentTintColor = .systemGreen
        addSubview(check)
        let label = NSTextField(labelWithString: "Path copied")
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.frame = CGRect(x: 34, y: 9, width: size.width - 68, height: 18)
        addSubview(label)
        let close = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Dismiss preview")!,
                             target: self, action: #selector(closePreview))
        close.frame = CGRect(x: size.width - 30, y: 6, width: 24, height: 24)
        close.isBordered = false
        close.contentTintColor = .secondaryLabelColor
        addSubview(close)
    }

    required init?(coder: NSCoder) { nil }
    @objc private func openImage() { NSWorkspace.shared.open(fileURL); onDismiss() }
    @objc private func closePreview() { onDismiss() }
}
