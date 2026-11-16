# Release Quickshot

Quickshot targets macOS 14 and later. Distribute a universal (Apple silicon and
Intel), Developer ID–signed, notarized app for direct download.

## Artwork

The app icon is Quickshot’s original abstract capture mark, licensed under MIT.
Its editable source is `Quickshot/Quickshot-icon.svg`. The ten macOS icon slots
(16 through 1024 pixels) live in `Quickshot/Assets.xcassets/AppIcon.appiconset`.
Run `scripts/generate-icon.sh` to render them and the README image. This uses a
pinned development-only SVG renderer; no artwork tooling ships with the app.

The previous WhiteSur SVG, authors, GPLv3 license, and provenance notice remain
bundled in Resources. `Quickshot/IconCredits.txt` distinguishes both artworks.

## Automated publication

Every push to `main` runs `.github/workflows/release.yml`, which runs
`scripts/validate.sh` before packaging. CI uses GitHub's
[Xcode 27 arm64 runner](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md)
and selects Xcode 27.1 to match local development.

Each new commit adds a version to `CHANGELOG.md` (see `AGENTS.md`). The first
section establishes a baseline; existing history does not need rewriting. CI
rejects subsequent commits without a newer version, tags versioned commits only
after packaging succeeds, and publishes the newest version. Stable tags are
created by automation, never manually.

The pipeline builds both `arm64` and `x86_64`, applies a Developer ID signature
with hardened runtime, submits the ZIP to Apple's notary service, requires an
Accepted result, staples the app, and checks Gatekeeper. It then repackages the
stapled app, extracts and verifies the final ZIP, and generates a SHA-256 checksum.
This follows [Apple's notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

Assets are uploaded to a draft GitHub release and their uploaded sizes checked
before publication. Public assets are immutable. Reruns can recover a draft,
but refuse to overwrite a public release. There is no in-app updater or beta feed.

Downloads:

- `Quickshot-X.Y.Z-universal.zip`
- `Quickshot-X.Y.Z-universal.zip.sha256`

## GitHub Actions setup

Run only when credential configuration is requested:

```sh
scripts/setup-release-secrets.sh /path/to/DeveloperID.p12 --api-key /path/to/AuthKey_KEYID.p8 issuer-uuid
# Or use Apple ID notarization:
scripts/setup-release-secrets.sh /path/to/DeveloperID.p12 --apple-id you@example.com
```

The helper targets `hugocxl/quickshot`, checks the exported certificate/private key,
prompts for passwords, and uploads secrets through `gh`. It requires authenticated
GitHub CLI access with permission to manage repository Actions secrets.
Never commit certificates, private keys or passwords.

Required secrets:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_APPLICATION_CERTIFICATE` | Base64-encoded Developer ID Application .p12 including private key |
| `DEVELOPER_ID_APPLICATION_PASSWORD` | Export password |
| `APPLE_TEAM_ID` | Certificate's Apple developer team |
| `APPLE_API_KEY_P8` | Base64-encoded App Store Connect key (API-key mode) |
| `APPLE_API_KEY_ID` | Key ID (API-key mode) |
| `APPLE_API_ISSUER_ID` | Issuer UUID (API-key mode) |
| `APPLE_ID` | Apple ID email (Apple-ID mode) |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password (Apple-ID mode) |

Only one notarization mode is needed. API-key mode takes precedence. CI imports
the certificate into a temporary keychain and cleans up it and the API key even
on failure. Missing credentials fail publication; there is no unsigned fallback.
`GITHUB_TOKEN` provides release/tag access through job-level `contents: write`.
Repository rules must allow that token to create version tags.

## Local build and packaging

```sh
scripts/build.sh
scripts/validate.sh
RELEASE_VERSION=1.0.1 scripts/release.sh
```

The last command creates an ad-hoc universal ZIP for local inspection. It is not
a notarized download. For a distribution build, set `CODESIGN_IDENTITY` to a
Developer ID identity and supply `NOTARY_KEYCHAIN_PROFILE`, or the API-key / Apple-ID
environment variables documented in `scripts/release.sh`. Set
`REQUIRE_NOTARIZATION=1` to enforce public-distribution requirements.

`CHANGELOG.md` is the version source for scripted builds. Both marketing version
and bundle build number (Git commit count) are passed to Xcode, so no per-release
project-file edits are needed. Xcode's direct-build fallback remains 1.0 / 1.
Build directories for local Debug (`build/debug`), validation
(`build/validation-derived`) and Release (`build/release-derived`) are isolated
from Xcode's normal DerivedData and from one another.

Run the manual checks below for capture, permissions or signing changes before
requesting a publication push. CI cannot establish permission-dependent behavior.

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
