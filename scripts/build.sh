#!/bin/bash
# Local builds retain Xcode development signing; validation passes CODE_SIGNING_ALLOWED=NO.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(sed -n 's/^## \([0-9][0-9.]*\) - .*/\1/p' CHANGELOG.md | head -1)"
xcodebuild -project Quickshot.xcodeproj -scheme Quickshot \
    -configuration Debug -destination 'generic/platform=macOS' \
    -derivedDataPath "${DERIVED_DATA_PATH:-build/debug}" MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$(git rev-list --count HEAD)" "$@" build
