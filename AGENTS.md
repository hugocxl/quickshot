# Quickshot

Quickshot is a native macOS menu-bar screenshot utility written in Swift and
AppKit, for macOS 14+ on Apple silicon and Intel. Keep the app small, with no
third-party runtime dependencies.

## Commands

```sh
scripts/build.sh                  # signed Debug build (local identity)
scripts/test.sh                   # the standalone Swift regression tests
scripts/changelog.sh check        # changelog format and version order
scripts/validate.sh               # build (warnings are errors), tests, app bundle
RELEASE_VERSION=X.Y.Z scripts/release.sh  # ad-hoc universal ZIP for inspection
npm ci && npm run build:site && npm run check:site  # the website in _site/
```

A change is finished only when `scripts/validate.sh` passes. The release workflow
runs the same script.

- Build products and logs live in the ignored `build/`.
- The website in `website/` builds with the `@hugocxl/design-system`, `@hugocxl/icons`
  and `@hugocxl/vectors` npm packages, which are site-only devDependencies; the app
  ships none of them. The Pages workflow builds with their latest releases.
- `scripts/validate.sh` builds unsigned into its own DerivedData. Never replace the
  signed app running from Xcode with that build; `scripts/build.sh` keeps
  development signing.

## Architecture

- `Quickshot.xcodeproj` has one application target with synchronized folders, so
  new files need no project edits. `Quickshot/Info.plist` takes its version and
  minimum OS from build settings.
- `QuickshotApp.swift`: the AppKit lifecycle, menu-bar actions, permission
  diagnostics, capture coordination and the clipboard path. There is no Dock icon
  (`LSUIElement`).
- `CommandChordDetector.swift`: a pure state machine for left + right Command. One
  capture per hold, a full release re-arms it, and ordinary shortcuts cancel it.
- `HotKeyManager.swift`: a listen-only global event tap on its own run-loop thread.
  - The tap, detector and recovery stay on that thread. UI callbacks go to the
    main actor.
  - The event callback never captures images, logs or blocks.
- `ScreenshotService.swift`: ScreenCaptureKit capture of the display under the
  pointer, without Quickshot's windows. Full-resolution PNGs and safe cleanup.
- `CaptureFeedback.swift` and `CapturePreviewLayout.swift`: flash, shutter sound,
  floating preview and display geometry. They respect focus, Reduce Motion, muted
  audio and multiple displays.
- `PermissionWindowController.swift`: Input Monitoring and Screen Recording setup.
- A capture copies the PNG path to the clipboard and never overwrites an existing
  file. Cleanup removes only expired Quickshot PNGs: never other files, symlinks or
  Desktop captures. The save destination lives in `UserDefaults`.
- The keyboard is ready only with an Input Monitoring grant and an enabled tap.
  Secure Keyboard Entry can pause delivery, and a Screen Recording preflight
  doesn't prove a capture works.
- The bundle identity is `com.quickshot.app` with certificate-based local signing.
  Changing either can invalidate privacy (TCC) grants. Never reset TCC unless asked.

## Code standards

- Swift 6, AppKit and Apple frameworks only. Proposing a dependency needs the
  maintainer's approval.
- UI stays on the main actor. Shared mutable state is confined or synchronized.
- Prefer value types, explicit `enum` state and early returns.
- No new force unwraps or `try!`. Log runtime failures with `NSLog`.
- Choose self-explanatory names over comments.
- Follow the existing patterns, and fix root causes rather than symptoms.
- The icon's source SVG, credits, authors and GPL license ship in the app's
  resources; keep them. Record the provenance of third-party artwork or code you
  adapt.

## Testing

- Tests are standalone `@main` Swift programs in `Tests/`, compiled with
  assertions on by `scripts/test.sh`. There is no XCTest target.
- Test real risks: chord cancellation and recovery, permission states, preview
  geometry and screenshot cleanup. Don't test defaults.
- For UI work, rebuild and look at the app. The Debug app has `--smoke-test` (no
  permission prompts) and `--setup-preview`.
- Automated checks don't prove permission-dependent behavior. The manual checks
  (Finder, full-screen apps, Spaces, sleep and wake, multiple displays, denied and
  revoked permissions) are in `RELEASE.md`.
  - Running the executable directly inherits the terminal's TCC identity, so it
    proves nothing about the installed app.
  - Trust results the maintainer confirms by hand.

## Commits and the changelog

- Commit only when asked.
- Don't push, open pull requests or comment on issues unless asked.
- Before committing, run `git pull --rebase --autostash origin main`. Other
  branches push to `main`, so the next version comes from the latest `main`.
  Stage only your own changes.
- Every commit is a version. It adds one `## X.Y.Z - YYYY-MM-DD` section on top of
  `CHANGELOG.md`, dated today and newer than the section below it.
  - Bump the patch for fixes and invisible changes, and the minor version for new
    features or visible changes.
  - If the rebase conflicts there, renumber your section above theirs. Never add
    to an older section.
- Group entries under `### Added`, `### Changed`, `### Fixed` or `### Removed` as
  `- ` items, with wrapped lines indented two spaces and inline Markdown only.
- Write one sentence per entry for someone using Quickshot. Don't mention file
  names or refactors.
  - The release workflow rejects a commit without a newer version, so even a CI fix
    gets a short entry.
  - `scripts/changelog.sh check` checks the format.
- The changelog is the only version source. Builds take the marketing version from
  it and the build number from the commit count; don't edit versions in Xcode.

## Releasing

Every push to `main` runs the Release workflow. It tags each pushed commit with its
changelog version, then validates, signs, notarizes and publishes the newest one as
a universal ZIP with its SHA-256 checksum. Don't tag versions by hand, and never
replace a public release's assets.

- After pushing, don't watch or check the Release workflow unless asked.
- Signing and notarization inputs are documented at the top of `scripts/release.sh`.
- GitHub secrets are set with `scripts/setup-release-secrets.sh`, only when asked.
  Credentials never go in the repository.
- A local ad-hoc build is for inspection only. The workflow fails rather than
  publish an unsigned app.
- Report local validation, the push and the published release as separate outcomes.
