#!/bin/bash
# Local builds retain Xcode development signing; validation passes CODE_SIGNING_ALLOWED=NO.
# Linked worktrees build with an isolated bundle id, display name, and DerivedData.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/worktree.sh com.quickshot.app Quickshot
VERSION="$(sed -n 's/^## \([0-9][0-9.]*\) - .*/\1/p' CHANGELOG.md | head -1)"
EXTRA=()
if [ "$WT_IS_LINKED" = 1 ]; then
    EXTRA+=(PRODUCT_BUNDLE_IDENTIFIER="$WT_BUNDLE_ID" INFOPLIST_KEY_CFBundleDisplayName="$WT_APP_NAME")
fi
xcodebuild -project Quickshot.xcodeproj -scheme Quickshot \
    -configuration Debug -destination 'generic/platform=macOS' \
    -derivedDataPath "$WT_DERIVED_DATA" MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$(git rev-list --count HEAD)" \
    ${EXTRA[@]+"${EXTRA[@]}"} "$@" build
