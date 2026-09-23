# Quickshot

Quickshot is a macOS menu-bar utility for taking full-display screenshots and copying their file locations for immediate pasting into terminal tools.

The first version has no settings: press **left Command + right Command together** to capture the display under the pointer. Quickshot saves the PNG in `~/Pictures/Quickshot` and copies its absolute path to the clipboard.

## Run

Requires macOS 14 or newer. Open `Quickshot.xcodeproj` in Xcode and run the `Quickshot` target. It runs only in the menu bar, with an icon and a native popup menu, not in the Dock.

The project uses **Apple Development** signing with Hugo Corta's team (`JFMWLVS6WR`). On another developer's Mac, select their team in **Signing & Capabilities**. Debug uses a single executable (`ENABLE_DEBUG_DYLIB = NO`) to keep the development bundle straightforward to identify and sign.

1. Enable **Quickshot** in System Settings → Privacy & Security → **Input Monitoring** when prompted. Registration retries automatically after approval; relaunch if macOS requests it.
2. Choose **Take Screenshot** from the menu once to request **Screen Recording** permission. Enable Quickshot and relaunch if macOS requests it. Both permission panels are accessible from the menu.
3. Hold **left Command and right Command at the same time**, in either order. One screenshot is taken per hold; release both keys before taking another. The display containing the pointer is the active display for this version, including its full desktop and windows. Ordinary shortcuts such as Command-C cancel the gesture until both Command keys are released.
4. A brief white flash on the captured display and a menu-bar checkmark indicate that the PNG has been saved and its absolute path copied as plain text. The flash fades over 0.25 seconds, does not steal focus or intercept clicks, and is shown only after capture so it is not included in the image. Paste into Claude Code, OpenCode, or another tool.

Screenshots remain in `~/Pictures/Quickshot` until you delete them. Names contain a timestamp and unique identifier; captures never overwrite one another. The popup shows permission or capture failures. Screen capture uses ScreenCaptureKit without running a continuous recording stream.

### Permissions show enabled but the app is denied

Older Quickshot builds were ad-hoc signed. Their designated code-signing requirement was a binary hash, which can change with rebuilds. A permission toggle for an older build can therefore remain enabled without authorizing the current build. Certificate-based signing gives rebuilds a stable identity.

After switching to the signed build:

1. Stop Quickshot in Xcode, then build it again with the selected development team.
2. In System Settings → Privacy & Security, remove the old **Quickshot** entry from both **Input Monitoring** and **Screen & System Audio Recording** using the minus button.
3. In Xcode, right-click **Products → Quickshot.app → Show in Finder**. Add that exact app to both permission lists with the plus button and enable it.
4. Run Quickshot again. Its menu should report **Shortcut: ready**. Try **Take Screenshot**, then left Command + right Command together.

The menu offers **Retry Shortcut** and **Copy Permission Diagnostics**, including the running app path and PID, macOS preflight results, and the actual keyboard-monitor status. The app attempts the real keyboard and ScreenCaptureKit APIs instead of treating a negative preflight result as proof of denial. Shortcut status is separate from capture status, so background retries cannot overwrite capture feedback. The camera icon remains visible even when the shortcut is unavailable; the menu explains the failure.

## Verification

Build:

```sh
xcodebuild -project Quickshot.xcodeproj -scheme Quickshot -configuration Debug build
```

Use a separate `-derivedDataPath` for automated checks. Never run unsigned verification builds into the same DerivedData directory used by the app running in Xcode, as that replaces its signed bundle. Verify signing with `codesign -dvv -r- /path/to/Quickshot.app`; it should show an Apple Development authority and a certificate-based designated requirement, not `Signature=adhoc` and only a `cdhash` requirement.

Run gesture regression checks:

```sh
swiftc Quickshot/CommandChordDetector.swift Tests/CommandChordTests.swift -o /tmp/quickshot-tests
/tmp/quickshot-tests
```

The Debug executable accepts `--smoke-test` to launch the actual AppKit lifecycle, check delegate attachment, menu actions, icon creation, and accessory activation policy, then exit without prompting for permissions.

The Debug executable also accepts `--permission-diagnostics` to attempt keyboard-monitor registration, print the same diagnostic details as the menu command, then exit. Running an app directly from a terminal may affect macOS permission attribution; use the menu diagnostics when investigating an Xcode-launched instance.

Manual integration check (requires permission approval): verify the icon appears with no Dock entry; grant both permissions; press left and right Command together over each monitor; paste into a text editor and open the resulting PNG. Confirm it matches the chosen display at full resolution and does not include the flash. Verify only the captured display flashes, the frontmost app keeps focus (including in full screen), holding the keys produces one capture, and releasing both allows another. Verify Command-C followed by Command-V does not capture, denied permission is visible in the menu, and repeated captures produce different existing files. Build and smoke checks do not substitute for this permission-dependent desktop check.
