# Quickshot

Quickshot is a macOS menu-bar utility for taking full-display screenshots and copying their file locations for immediate pasting into terminal tools.

The first version has no settings: press `Command` twice to capture the display under the pointer. Quickshot saves the PNG in `~/Pictures/Quickshot` and copies its absolute path to the clipboard.

## Run

Open `Quickshot.xcodeproj` in Xcode and run the `Quickshot` target. It runs only in the menu bar, shown as a camera icon and `QS`, not in the Dock. On first run, approve Accessibility permission for the double-Command trigger and Screen Recording permission for screenshots in System Settings.
