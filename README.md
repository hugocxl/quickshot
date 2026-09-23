# Quickshot

Quickshot is a macOS menu-bar utility for taking full-display screenshots and copying their file locations for immediate pasting into terminal tools.

The first version has no settings: it captures the display under the pointer with `Control-Option-Command-4`, saves the PNG in `~/Pictures/Quickshot`, and copies its absolute path to the clipboard.

## Run

Open `Quickshot.xcodeproj` in Xcode and run the `Quickshot` target. The first screenshot asks for macOS Screen Recording permission. Approve it in System Settings, then use the fixed shortcut from any application.
