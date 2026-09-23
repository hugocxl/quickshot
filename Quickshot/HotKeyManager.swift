import AppKit
import Carbon
import IOKit.hidsystem

@MainActor
final class HotKeyManager: NSObject {
    enum RegistrationStatus: String, Sendable {
        case starting = "Shortcut: starting keyboard monitor…"
        case ready = "Shortcut: ready — Left ⌘ + Right ⌘"
        case secureInput = "Shortcut: paused by macOS Secure Keyboard Entry"
        case permissionDenied = "Shortcut: macOS denies input access to this build"
        case tapUnavailable = "Shortcut: keyboard monitor unavailable"
        case sourceUnavailable = "Shortcut: could not attach keyboard monitor"

        nonisolated static func evaluate(inputAllowed: Bool, tapEnabled: Bool, secureInput: Bool) -> Self {
            // An enabled tap can still only receive foreground events without a valid TCC grant.
            guard inputAllowed else { return .permissionDenied }
            guard tapEnabled else { return .tapUnavailable }
            return secureInput ? .secureInput : .ready
        }
    }

    private(set) var status: RegistrationStatus = .starting
    private var worker: KeyboardWorker?

    func start(onPress: @escaping @MainActor @Sendable () -> Void,
               onStatus: @escaping @MainActor @Sendable (RegistrationStatus) -> Void) {
        guard worker == nil else { return }
        let worker = KeyboardWorker(onPress: {
            Task { @MainActor in onPress() }
        }, onStatus: { [weak self] status in
            Task { @MainActor in
                guard let self, self.worker != nil else { return }
                self.status = status
                onStatus(status)
            }
        })
        self.worker = worker
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            center.addObserver(self, selector: #selector(resume), name: name, object: nil)
        }
        center.addObserver(self, selector: #selector(refresh), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        // A Space change is not an input-stream interruption. Resetting here races with the
        // first Command press on the new Space and can cancel a legitimate chord.
        center.addObserver(self, selector: #selector(refresh), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        worker.start()
    }

    @objc func refresh() { worker?.refresh(reset: false) }
    @objc private func resume() { worker?.refresh(reset: true) }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        worker?.stop()
        worker = nil
    }
}

/// Tap, detector, and recovery timer are confined to one thread. Only run-loop publication and
/// shutdown cross threads, protected by controlLock. Callbacks are immutable Sendable closures.
private final class KeyboardWorker: @unchecked Sendable {
    private let onPress: @Sendable () -> Void
    private let onStatus: @Sendable (HotKeyManager.RegistrationStatus) -> Void
    private let controlLock = NSLock()
    private var loop: CFRunLoop?
    private var stopped = false
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var retryTimer: Timer?
    private var detector = CommandChordDetector()
    private var lastStatus: HotKeyManager.RegistrationStatus?

    init(onPress: @escaping @Sendable () -> Void,
         onStatus: @escaping @Sendable (HotKeyManager.RegistrationStatus) -> Void) {
        self.onPress = onPress
        self.onStatus = onStatus
    }

    func start() {
        let thread = Thread { [self] in
            autoreleasepool {
                let current = CFRunLoopGetCurrent()!
                controlLock.lock()
                if stopped { controlLock.unlock(); return }
                loop = current
                controlLock.unlock()
                // Keep the run loop available for wake/retry commands even if macOS invalidates
                // the event-tap port. An unsignaled source consumes no periodic CPU time.
                var context = CFRunLoopSourceContext(version: 0, info: nil, retain: nil, release: nil,
                                                     copyDescription: nil, equal: nil, hash: nil,
                                                     schedule: nil, cancel: nil, perform: { _ in })
                let controlSource = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context)!
                CFRunLoopAddSource(current, controlSource, .commonModes)
                connect()
                CFRunLoopRun()
                retryTimer?.invalidate()
                disconnect()
                CFRunLoopRemoveSource(current, controlSource, .commonModes)
                controlLock.lock()
                loop = nil
                controlLock.unlock()
            }
        }
        thread.name = "Quickshot keyboard monitor"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    func refresh(reset: Bool) {
        controlLock.lock()
        defer { controlLock.unlock() }
        guard !stopped, let loop else { return }
        CFRunLoopPerformBlock(loop, CFRunLoopMode.commonModes.rawValue) { [self] in
            if reset { synchronizeKeys() }
            connect()
        }
        CFRunLoopWakeUp(loop)
    }

    func stop() {
        controlLock.lock()
        defer { controlLock.unlock() }
        stopped = true
        if let loop {
            CFRunLoopPerformBlock(loop, CFRunLoopMode.commonModes.rawValue) { CFRunLoopStop(CFRunLoopGetCurrent()) }
            CFRunLoopWakeUp(loop)
        }
    }

    private func synchronizeKeys() {
        detector.resynchronize(leftDown: CGEventSource.keyState(.combinedSessionState, key: 55),
                               rightDown: CGEventSource.keyState(.combinedSessionState, key: 54))
    }

    private func disconnect() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        tap = nil
        source = nil
    }

    private func connect() {
        // Do not mistake foreground-only delivery for a globally authorized listener.
        guard CGPreflightListenEventAccess() else {
            disconnect()
            report(.permissionDenied)
            return
        }
        if let tap, CFMachPortIsValid(tap) {
            if !CGEvent.tapIsEnabled(tap: tap) {
                synchronizeKeys()
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            if CGEvent.tapIsEnabled(tap: tap) {
                report(.evaluate(inputAllowed: CGPreflightListenEventAccess(), tapEnabled: true,
                                 secureInput: IsSecureEventInputEnabled()))
                return
            }
        }
        disconnect()
        synchronizeKeys()
        let mask = CGEventMask((1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue))
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                               options: .listenOnly, eventsOfInterest: mask,
                               callback: { _, type, event, context in
            if let context {
                Unmanaged<KeyboardWorker>.fromOpaque(context).takeUnretainedValue().receive(type, event)
            }
            return Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else {
            report(CGPreflightListenEventAccess() ? .tapUnavailable : .permissionDenied)
            return
        }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            disconnect()
            report(.sourceUnavailable)
            return
        }
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        report(.evaluate(inputAllowed: CGPreflightListenEventAccess(),
                         tapEnabled: CGEvent.tapIsEnabled(tap: tap), secureInput: IsSecureEventInputEnabled()))
    }

    private func report(_ status: HotKeyManager.RegistrationStatus) {
        if lastStatus == .secureInput && status == .ready { synchronizeKeys() }
        if lastStatus != status {
            lastStatus = status
            onStatus(status)
        }
        if status == .ready {
            retryTimer?.invalidate()
            retryTimer = nil
        } else if retryTimer == nil {
            let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.connect() }
            timer.tolerance = 0.5
            RunLoop.current.add(timer, forMode: .common)
            retryTimer = timer
        }
    }

    private func receive(_ type: CGEventType, _ event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            synchronizeKeys()
            connect()
            return
        }
        // No image work, AppKit access, logging, or main-thread synchronization in the key path.
        if type == .keyDown {
            if event.flags.contains(.maskCommand) { detector.cancel() }
            return
        }
        guard type == .flagsChanged else { return }
        let other: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskSecondaryFn]
        if detector.update(leftDown: event.flags.rawValue & UInt64(NX_DEVICELCMDKEYMASK) != 0,
                           rightDown: event.flags.rawValue & UInt64(NX_DEVICERCMDKEYMASK) != 0,
                           otherModifierDown: !event.flags.intersection(other).isEmpty) {
            onPress()
        }
    }
}
