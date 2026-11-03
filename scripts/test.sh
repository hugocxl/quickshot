#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
SOURCES=(CommandChordDetector 'CommandChordDetector HotKeyManager' CapturePreviewLayout ScreenshotService)
TESTS=(CommandChord KeyboardAccess CapturePreviewLayout ScreenshotStorage)
for index in "${!TESTS[@]}"; do
    files=()
    for source in ${SOURCES[$index]}; do files+=("Quickshot/$source.swift"); done
    xcrun swiftc -swift-version 6 -warnings-as-errors -Onone "${files[@]}" \
        "Tests/${TESTS[$index]}Tests.swift" -o "build/tests/${TESTS[$index]}"
    "build/tests/${TESTS[$index]}"
done
