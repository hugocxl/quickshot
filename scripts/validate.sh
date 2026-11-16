#!/bin/bash
# The validation every change must pass before it is finished.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p build/validation
scripts/changelog.sh check
python3 Tests/ReleaseWorkflowTests.py 2>&1 | tail -5
plutil -lint Quickshot/Info.plist Quickshot.xcodeproj/project.pbxproj
# Its own DerivedData, so the signed app running from Xcode keeps its grants.
DERIVED_DATA_PATH=build/validation-derived scripts/build.sh CODE_SIGNING_ALLOWED=NO \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES \
    2>&1 | tee build/validation/build.log | tail -20
scripts/test.sh 2>&1 | tee build/validation/test.log | tail -40
APP=build/validation-derived/Build/Products/Debug/Quickshot.app
test -x "$APP/Contents/MacOS/Quickshot"
plutil -lint "$APP/Contents/Info.plist"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" = com.quickshot.app
test "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$APP/Contents/Info.plist")" = true
for resource in AppIcon.icns Assets.car Quickshot-icon.svg IconCredits.txt WhiteSur-screenshot.svg WhiteSur-AUTHORS.txt WhiteSur-COPYING.txt; do
    test -f "$APP/Contents/Resources/$resource"
done
git diff --check
echo "validation passed"
