# Quickshot

Quickshot is a macOS menu-bar utility for taking full-display screenshots and copying their file locations for immediate pasting into terminal tools.

The first version has no settings: press **left Command + right Command together** to capture the display under the pointer. Quickshot saves the PNG in `~/Pictures/Quickshot` and copies its absolute path to the clipboard.

## Run

Requires macOS 14 or newer. Open `Quickshot.xcodeproj` in Xcode and run the `Quickshot` target. It runs only in the menu bar, with an icon and a native popup menu, not in the Dock.

1. Enable **Quickshot** in System Settings → Privacy & Security → **Input Monitoring** when prompted. Registration retries automatically after approval; relaunch if macOS requests it.
2. Choose **Take Screenshot** from the menu once to request **Screen Recording** permission. Enable Quickshot and relaunch if macOS requests it. Both permission panels are accessible from the menu.
3. Hold **left Command and right Command at the same time**, in either order. One screenshot is taken per hold; release both keys before taking another. The display containing the pointer is the active display for this version, including its full desktop and windows. Ordinary shortcuts such as Command-C cancel the gesture until both Command keys are released.
4. A brief white flash on the captured display and a menu-bar checkmark indicate that the PNG has been saved and its absolute path copied as plain text. The flash fades over 0.25 seconds, does not steal focus or intercept clicks, and is shown only after capture so it is not included in the image. Paste into Claude Code, OpenCode, or another tool.

Screenshots remain in `~/Pictures/Quickshot` until you delete them. Names contain a timestamp and unique identifier; captures never overwrite one another. The popup shows permission or capture failures. Screen capture uses ScreenCaptureKit without running a continuous recording stream.

## Verification

Build:

```sh
xcodebuild -project Quickshot.xcodeproj -scheme Quickshot -configuration Debug build
```

Run gesture regression checks:

```sh
swiftc Quickshot/CommandChordDetector.swift Tests/CommandChordTests.swift -o /tmp/quickshot-tests
/tmp/quickshot-tests
```

The Debug executable accepts `--smoke-test` to launch the actual AppKit lifecycle, check delegate attachment, menu actions, icon creation, and accessory activation policy, then exit without prompting for permissions.

Manual integration check (requires permission approval): verify the icon appears with no Dock entry; grant both permissions; press left and right Command together over each monitor; paste into a text editor and open the resulting PNG. Confirm it matches the chosen display at full resolution and does not include the flash. Verify only the captured display flashes, the frontmost app keeps focus (including in full screen), holding the keys produces one capture, and releasing both allows another. Verify Command-C followed by Command-V does not capture, denied permission is visible in the menu, and repeated captures produce different existing files. Build and smoke checks do not substitute for this permission-dependent desktop check.
