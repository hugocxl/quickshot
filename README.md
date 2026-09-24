# Quickshot

Quickshot is a macOS menu-bar utility for taking full-display screenshots and copying their file locations for immediate pasting into terminal tools.

The first version has no settings: press **left Command + right Command together** to capture the display under the pointer. Quickshot saves the PNG in `~/Pictures/Quickshot` and copies its absolute path to the clipboard.

## Run

Requires macOS 14 or newer. Open `Quickshot.xcodeproj` in Xcode and run the `Quickshot` target. It runs only in the menu bar, with an icon and a native popup menu, not in the Dock.

The project uses **Apple Development** signing with Hugo Corta's team (`JFMWLVS6WR`). On another developer's Mac, select their team in **Signing & Capabilities**. Debug uses a single executable (`ENABLE_DEBUG_DYLIB = NO`) to keep the development bundle straightforward to identify and sign.

1. Open **Permissions & Setup…** from the menu (also shown automatically when access is missing). Click **Allow** beside **Global shortcut** to authorize Input Monitoring.
2. Click **Allow** beside **Screen capture** to authorize Screen Recording. The cards update as permissions change. Relaunch if macOS asks. Quickshot explains what each permission enables before opening the system-owned consent dialog or Settings pane.
3. Hold **left Command and right Command at the same time**, in either order. One screenshot is taken per hold; release both keys before taking another. The display containing the pointer is the active display for this version, including its full desktop and windows. Ordinary shortcuts such as Command-C cancel the gesture until both Command keys are released.
4. A soft exposure flash and shutter sound confirm success. The captured view lifts and shrinks into a bottom-right preview labeled **Path copied**. Paste into Claude Code, OpenCode, or another tool immediately; feedback does not delay clipboard availability.

Screenshots remain in `~/Pictures/Quickshot` until you delete them. Names contain a timestamp and unique identifier; captures never overwrite one another. The popup shows permission or capture failures. Screen capture uses ScreenCaptureKit without running a continuous recording stream.

### Capture feedback

- A 0.72-second Core Animation sequence takes the actual captured image from full-screen size to a rounded, shadowed corner card, with a brief 0.22-second exposure flash.
- The preview sits inside the captured display's usable area, above the Dock, maintains the screenshot's aspect ratio, and stays for three seconds before fading away. Hovering over it keeps it on screen. Its footer fades in once the flight lands.
- Click the image to open the saved PNG, or click **×** to dismiss it. Appearance never takes keyboard focus; only the small preview accepts clicks, while the full-screen animation is click-through.
- New captures cancel and replace the previous animation/preview. Quickshot's own windows are excluded from ScreenCaptureKit, so feedback and setup UI cannot appear in subsequent screenshots.
- Changing Spaces or disconnecting/rearranging displays dismisses feedback rather than leaving it on the wrong desktop.
- With **Reduce Motion**, the thumbnail simply fades in without a screen-wide flash or flight. A VoiceOver announcement confirms that the path was copied.
- Shutter audio uses macOS's own screenshot sound (`Screen Capture.aif`, falling back to `Grab.aif`) through `NSSound` at reduced volume, respecting system output/mute. If that system resource is unavailable, a short native confirmation sound is used instead.

The setup window offers live permission cards, an **Already enabled, but not working?** recovery section, and **Show This App in Finder** to identify the exact build to authorize. Closing setup or choosing **Set Up Later** is supported. The app remains menu-bar-only with no Dock entry. Capture errors use focused native dialogs with retry/cancel actions rather than silently failing.

### Global shortcut behavior

The shortcut uses a **session-wide, listen-only Core Graphics event tap**, independent of the focused application, display, or Space. This includes ordinary full-screen apps and Quickshot itself. No window needs to be focused and no app-specific shortcut registration is involved. Events pass through unchanged.

- A dedicated named thread and run loop handle keyboard events, independently of AppKit menus and screenshot encoding.
- Only modifier changes and key-down events are observed. The key path checks physical left/right Command flags and a small state machine; it does not read text, log keys, capture images, or synchronously wait for the UI. Only recognized chords are dispatched to the main actor.
- When healthy, there is no periodic polling timer. Disabled taps recover via callbacks; wake, session activation, Space changes, app activation, and the menu can trigger a health check. A two-second, tolerance-enabled retry timer exists only while monitoring is unavailable or Secure Keyboard Entry is detected.
- Keys held across startup, wake, or listener interruption must be released before another chord can fire, preventing accidental captures from stale modifier state. Ordinary app/Space changes preserve the chord state: the first press on a new desktop must not be canceled by a delayed Space-change notification.

**macOS limitation:** Secure Keyboard Entry (including Terminal's optional Secure Keyboard Entry mode), protected password entry, login/lock screens, and inactive user sessions can suppress third-party keyboard delivery. Quickshot cannot override that. When detected, the menu reports the secure-input state; turn off Terminal's Secure Keyboard Entry for global shortcuts there. The monitor resumes after access returns.

### Permissions show enabled but the app is denied

Older Quickshot builds were ad-hoc signed. Their designated code-signing requirement was a binary hash, which can change with rebuilds. A permission toggle for an older build can therefore remain enabled without authorizing the current build. Certificate-based signing gives rebuilds a stable identity.

After switching to the signed build:

1. Stop Quickshot in Xcode, then build it again with the selected development team.
2. In System Settings → Privacy & Security, remove the old **Quickshot** entry from both **Input Monitoring** and **Screen & System Audio Recording** using the minus button.
3. In Xcode, right-click **Products → Quickshot.app → Show in Finder**. Add that exact app to both permission lists with the plus button and enable it.
4. Run Quickshot again. Its menu should report **Shortcut: ready**. Try **Take Screenshot**, then left Command + right Command together.

If the old entry cannot be repaired in Settings, `tccutil reset ListenEvent com.quickshot.app` resets only Quickshot's Input Monitoring consent. Re-enable the signed app and relaunch. This does not reset Screen Recording or other applications' permissions.

The menu offers **Retry Shortcut** and **Copy Permission Diagnostics**, including the running app path and PID, macOS permission results, keyboard-monitor status, recognized-chord count, completed-capture count, and last capture result. **Global keyboard readiness requires both a valid Input Monitoring grant and an enabled event tap.** An enabled tap alone can work while Quickshot is frontmost without receiving other applications' events. Screen capture still attempts ScreenCaptureKit directly rather than being blocked by its separate preflight result. Shortcut status is separate from capture status, so background retries cannot overwrite capture feedback. The camera icon remains visible even when the shortcut is unavailable; the menu explains the failure.

## Verification

For app-icon credits, archiving, Developer ID signing, notarization, and the final
release checklist, see [RELEASE.md](RELEASE.md).

Build:

```sh
xcodebuild -project Quickshot.xcodeproj -scheme Quickshot -configuration Debug build
```

Use a separate `-derivedDataPath` for automated checks. Never run unsigned verification builds into the same DerivedData directory used by the app running in Xcode, as that replaces its signed bundle. Verify signing with `codesign -dvv -r- /path/to/Quickshot.app`; it should show an Apple Development authority and a certificate-based designated requirement, not `Signature=adhoc` and only a `cdhash` requirement.

Run gesture regression checks:

```sh
swiftc Quickshot/CommandChordDetector.swift Tests/CommandChordTests.swift -o /tmp/quickshot-tests
/tmp/quickshot-tests
swiftc -swift-version 6 Quickshot/CommandChordDetector.swift Quickshot/HotKeyManager.swift Tests/KeyboardAccessTests.swift -o /tmp/quickshot-access-tests
/tmp/quickshot-access-tests
swiftc Quickshot/CapturePreviewLayout.swift Tests/CapturePreviewLayoutTests.swift -o /tmp/quickshot-preview-tests
/tmp/quickshot-preview-tests
```

The Debug executable accepts `--smoke-test` to launch the actual AppKit lifecycle, check delegate attachment, menu actions, icon creation, and accessory activation policy, then exit without prompting for permissions.

Use `--setup-preview` to inspect the setup window without starting the shortcut monitor. Preview-layout tests verify portrait/landscape aspect ratio, Dock margins, and secondary displays with negative coordinates. For feedback integration, capture repeatedly while the previous preview is visible, verify the PNG excludes it, open/dismiss the thumbnail, and try Reduce Motion, muted output, a full-screen app, and multiple monitors.

The Debug executable also accepts `--permission-diagnostics` to attempt keyboard-monitor registration, wait three seconds, log/print the same diagnostic details as the menu command, then exit. Launch it with `open -n /path/to/Quickshot.app --args --permission-diagnostics` and inspect Console, or use the menu diagnostics from a normally running instance. **A direct executable launch from a terminal is not a valid global-permission test**: TCC may attribute access to the terminal/host instead of Quickshot. A successful registration under that inherited identity does not prove the Xcode-launched app has global access.

Manual integration check (requires permission approval): verify the icon appears with no Dock entry; grant both permissions; press left and right Command together over each monitor; paste into a text editor and open the resulting PNG. Confirm it matches the chosen display at full resolution and does not include the flash. Verify only the captured display flashes, the frontmost app keeps focus (including in full screen), holding the keys produces one capture, and releasing both allows another. Verify Command-C followed by Command-V does not capture, denied permission is visible in the menu, and repeated captures produce different existing files. Build and smoke checks do not substitute for this permission-dependent desktop check.

For global-listener regression checks, repeat in Finder, a browser, an editor, Terminal with Secure Keyboard Entry off, each Space, and a full-screen app. Repeat after sleep/wake and unlock. Use a trackpad to switch Spaces with one Command key held, then press the other: the healthy listener should preserve that chord. Across a true interruption (sleep or listener restart), release both keys before trying again. With Terminal Secure Keyboard Entry on, open Quickshot's menu to inspect the reported state, then turn it off and verify recovery. Automated gesture tests cover both key orders, held-key suppression, cancellation, interrupted-listener resynchronization, and 10,000 consecutive capture cycles. Access-state tests reject a foreground-only enabled tap with no global permission. These unit tests do not simulate macOS desktop transitions.

Confirmed during the September 23, 2026 fix: TCC logs rejected the old ad-hoc requirement for the signed Xcode build. After resetting only Input Monitoring and authorizing the signed app, normal-desktop and full-screen operation were confirmed by the user; runtime logs recorded 15 recognized chords and 15 completed captures, including with other apps frontmost.
