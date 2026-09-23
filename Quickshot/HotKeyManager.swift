import ApplicationServices
import IOKit.hidsystem

final class HotKeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var detector = CommandChordDetector()
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
        if eventTap != nil { return true }
        guard CGPreflightListenEventAccess() else { return false }

        let eventMask = CGEventMask((1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue))
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userData in
                guard let userData else {
                    return Unmanaged.passUnretained(event)
                }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    manager.detector = CommandChordDetector()
                    if let tap = manager.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
                } else if type == .keyDown {
                    if event.flags.contains(.maskCommand) { manager.detector.cancel() }
                } else if type == .flagsChanged {
                    manager.handleFlagsChanged(event)
                }
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
        let otherModifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskSecondaryFn]
        // The aggregate .maskCommand flag cannot distinguish the two physical keys.
        if detector.update(leftDown: event.flags.rawValue & UInt64(NX_DEVICELCMDKEYMASK) != 0,
                           rightDown: event.flags.rawValue & UInt64(NX_DEVICERCMDKEYMASK) != 0,
                           otherModifierDown: !event.flags.intersection(otherModifiers).isEmpty) {
            onPress?()
        }
    }
}
