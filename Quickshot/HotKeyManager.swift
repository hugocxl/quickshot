import ApplicationServices

final class HotKeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var commandIsDown = false
    private var lastCommandPress: TimeInterval?
    private var onPress: (() -> Void)?

    deinit {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
    }

    func register(onPress: @escaping () -> Void) -> Bool {
        self.onPress = onPress

        guard AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) else {
            return false
        }

        let eventMask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userData in
                guard let userData, type == .flagsChanged else {
                    return Unmanaged.passUnretained(event)
                }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleFlagsChanged(event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap, let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            return false
        }
        self.runLoopSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        return true
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let isCommandDown = event.flags.contains(.maskCommand)
        defer { commandIsDown = isCommandDown }
        guard isCommandDown, !commandIsDown else { return }

        let now = ProcessInfo.processInfo.systemUptime
        if let lastCommandPress, now - lastCommandPress < 0.4 {
            self.lastCommandPress = nil
            onPress?()
        } else {
            lastCommandPress = now
        }
    }
}
