#!/bin/bash
# Quits only this checkout's Quickshot dev app by bundle id.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/worktree.sh com.quickshot.app Quickshot
osascript -e "quit app id \"$WT_BUNDLE_ID\"" 2>/dev/null || true
