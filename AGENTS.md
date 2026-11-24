# Quickshot

Native macOS menu-bar screenshot utility written in Swift and AppKit for macOS 14+ on Apple silicon and Intel. Keep it small with zero third-party runtime dependencies.

## Commands

```sh
scripts/build.sh                  # Debug build into checkout-isolated DerivedData
scripts/run.sh                    # build and relaunch this checkout's dev app
scripts/stop.sh                   # quit this checkout's dev app
scripts/test.sh                   # standalone Swift regression tests
scripts/validate.sh               # build (warnings as errors), tests, app bundle, changelog check
RELEASE_VERSION=X.Y.Z scripts/release.sh  # local ad-hoc universal ZIP for inspection
cd website && npm ci && npm run build:site && npm run check:site
```

A change is finished only when `scripts/validate.sh` passes. If a task opened a dev app, run `scripts/stop.sh` before finishing.

## Why & Invariants

- **Privacy & signing identity:** the production bundle ID is `com.quickshot.app` with certificate-based local signing; changing either invalidates TCC (Input Monitoring / Screen Recording) grants. Never reset TCC unless asked. Running the raw executable from a terminal inherits the terminal's TCC identity and proves nothing about the installed app.
- **Event tap threading:** `HotKeyManager` runs a listen-only global event tap on its own run-loop thread — the event callback must never capture images, log, or block; UI callbacks hop to `@MainActor`.
- **Safe captures & cleanup:** captures copy the PNG path to the clipboard and never overwrite existing files. Cleanup removes only expired Quickshot PNGs — never other files, symlinks, or Desktop captures.
- **Standalone tests:** `Tests/` contains standalone `@main` Swift programs compiled by `scripts/test.sh` (no XCTest target). Automated checks cannot prove TCC-dependent flows; trust manual results confirmed by the maintainer. Debug builds accept `--smoke-test` and `--setup-preview`.
- **Bundled artwork provenance:** keep `Quickshot/IconCredits.txt` and WhiteSur license/source files in app resources.
- **Worktrees:** linked worktrees build with `com.quickshot.app-dev.<hash>`, a distinct display name, and partitioned DerivedData via `scripts/worktree.sh`. Never use `pkill`/`killall` or bare `git stash`.
- **No root Node tooling:** the website and its `@hugocxl/*` devDependencies live exclusively inside `website/`.

## Commits & Releases

- Commit and push only when asked. Pull with `git pull --rebase --autostash origin main` before committing.
- Commit messages must use `<Added|Changed|Removed|Improved|Fixed>: <One user-facing sentence.>` (enforced by `.githooks/commit-msg`, which automatically prepends `CHANGELOG.md` and triggers `.githooks/post-commit` to tag `vX.Y.Z`).
- Every push to `main` runs the Release workflow (validate, sign, notarize, publish universal ZIP + `.sha256`). Do not edit versions in Xcode or tag releases by hand.
