#!/bin/bash
# The validation every change must pass before it is finished.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
git config core.hooksPath .githooks 2>/dev/null || true
mkdir -p build/validation
scripts/changelog.sh check
python3 Tests/ReleaseWorkflowTests.py 2>&1 | tail -5
plutil -lint Quickshot/Info.plist Quickshot.xcodeproj/project.pbxproj
DERIVED_DATA_PATH=build/validation-derived scripts/build.sh CODE_SIGNING_ALLOWED=NO \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES \
    2>&1 | tee build/validation/build.log | tail -20
scripts/test.sh 2>&1 | tee build/validation/test.log | tail -40
source scripts/worktree.sh com.quickshot.app Quickshot
APP="build/validation-derived/$WT_HASH/Build/Products/Debug/Quickshot.app"
test -x "$APP/Contents/MacOS/Quickshot"
plutil -lint "$APP/Contents/Info.plist"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" = "$WT_BUNDLE_ID"
test "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$APP/Contents/Info.plist")" = true
for resource in AppIcon.icns Assets.car Quickshot-icon.svg IconCredits.txt WhiteSur-screenshot.svg WhiteSur-AUTHORS.txt WhiteSur-COPYING.txt; do
    test -f "$APP/Contents/Resources/$resource"
done
git diff --check
echo "validation passed"
