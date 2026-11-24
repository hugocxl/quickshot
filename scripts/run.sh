#!/bin/bash
# Builds and (re)launches only this checkout's Quickshot dev app.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/worktree.sh com.quickshot.app Quickshot
scripts/build.sh
APP="$WT_DERIVED_DATA/Build/Products/Debug/Quickshot.app"
osascript -e "quit app id \"$WT_BUNDLE_ID\"" 2>/dev/null || true
sleep 0.3
open "$APP"
echo "Launched $WT_APP_NAME ($WT_BUNDLE_ID): $APP"
