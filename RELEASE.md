# Release Quickshot

Quickshot targets macOS 14 and later. Distribute a universal (Apple silicon and
Intel), Developer ID–signed, notarized app for direct download.

## Artwork

The app icon is the predesigned screenshot icon from
[WhiteSur Icon Theme](https://github.com/vinceliuice/WhiteSur-icon-theme), a macOS
Big Sur–style collection by Vince Liuice and contributors. The ten macOS icon
slots (16 through 1024 pixels) are in `Quickshot/Assets.xcassets/AppIcon.appiconset`.
Xcode compiles the catalog into the app icon and sets the bundle icon metadata.

`Quickshot/IconCredits.txt` records the pinned upstream revision. The original
SVG, author list, and GPLv3 license are bundled in Resources alongside the credit
notice, so the distributed artwork includes its source and license.

To regenerate the PNGs, render `Quickshot/WhiteSur-screenshot.svg` to a transparent
1024-pixel PNG with resvg, then resize to each size listed in `Contents.json`.
The current assets were rendered using `@resvg/resvg-js-cli` 2.6.2-beta.1 and
ImageMagick. No artwork-generation tooling is needed to build the app.

## Build and sign

1. Set `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in both target build
   configurations for each release. The Info.plist uses these build settings.
2. Run the regression commands in README.md and the manual capture checks below.
3. Archive with a separate build directory:

   ```sh
   xcodebuild -project Quickshot.xcodeproj -scheme Quickshot \
     -configuration Release -destination 'generic/platform=macOS' \
     -derivedDataPath /tmp/quickshot-release-build \
     -archivePath /tmp/Quickshot.xcarchive archive
   ```

4. Open the archive in Xcode Organizer and select **Distribute App → Developer
   ID**, exporting with a **Developer ID Application** certificate and submitting
   for notarization. Release enables hardened runtime. Development signing is
   retained for local builds; an Apple Development signature is not a public
   distribution signature.
5. Staple and verify the exported app, then package it:

   ```sh
   xcrun stapler staple /path/to/export/Quickshot.app
   xcrun stapler validate /path/to/export/Quickshot.app
   codesign --verify --deep --strict --verbose=2 /path/to/export/Quickshot.app
   codesign -dvv -r- /path/to/export/Quickshot.app
   spctl --assess --type execute --verbose=2 /path/to/export/Quickshot.app
   lipo -archs /path/to/export/Quickshot.app/Contents/MacOS/Quickshot
   ditto -c -k --keepParent /path/to/export/Quickshot.app /path/to/Quickshot.zip
   ```

   Expect Developer ID authority, the `runtime` signing flag, a notarized
   Gatekeeper assessment, and both `arm64` and `x86_64` architectures.

## Final desktop checks

- Download the packaged app on a clean Mac/account and move it to Applications.
  Verify Gatekeeper accepts it, Finder shows the icon, and launch creates only a
  menu-bar item.
- Grant Input Monitoring and Screen Recording to that installed build. Verify
  permission denial, recovery, and relaunch behavior. Development-build permission
  grants do not establish that the exported app is authorized.
- Capture from Finder, Terminal, another Space, and a full-screen app. Test both
  Command-key orders, one capture per hold, Command-C/V cancellation, and sleep/wake.
- Capture on each display, paste the path, and open the PNG. Check full resolution,
  exclusion of Quickshot windows, preview open/dismiss, Reduce Motion, and mute.
- Check both save destinations, persisted selection after relaunch, and temporary
  cleanup. Desktop files remain until deleted; temporary files can also be purged
  by macOS, so their paths are not permanent.

## Review — September 24, 2026

Added complete app-icon assets and their source/license, enabled Release hardened
runtime, and connected bundle version/minimum-OS metadata to build settings.
The setup window and error alerts now use the app icon.

Verified locally:

- Signed Debug build and AppKit launch smoke test passed.
- Signed Release archive contains both `arm64` and `x86_64`.
- Strict code-signature verification passed; hardened runtime is enabled.
- Compiled bundle contains `AppIcon.icns`, `Assets.car`, and all four icon
  source/credit/license files; bundle metadata specifies Utilities and macOS 14.
- Gesture (including 10,000 cycles), keyboard-access, preview-layout, and screenshot
  storage/cleanup regression checks passed.
- Plist validation and `git diff --check` passed.

Xcode emitted an empty-scheme-platform diagnostic even though builds and archive
completed successfully. The direct Debug smoke launch also logged a sandbox
extension diagnostic before passing; it did not exercise TCC permissions.

Public distribution is blocked until a Developer ID Application certificate is
available and the exported build is notarized. At review time this Mac had only
Apple Development signing identities. Permission-dependent desktop checks and a
clean-machine Gatekeeper check remain release gates.
