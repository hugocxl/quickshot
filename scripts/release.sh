#!/bin/bash
# Builds the universal app, ZIP and its SHA-256 checksum into build/release/.
# The Release workflow runs it on every push to main; locally, without
# credentials, it makes an ad-hoc signed build for inspection.
#
#   RELEASE_VERSION         required: the newest X.Y.Z in CHANGELOG.md
#   CODESIGN_IDENTITY       Developer ID Application identity (default: ad-hoc)
#   Notarization, first set found: NOTARY_KEYCHAIN_PROFILE;
#     APPLE_API_KEY_PATH + APPLE_API_KEY_ID + APPLE_API_ISSUER_ID;
#     APPLE_ID + APPLE_APP_SPECIFIC_PASSWORD + APPLE_TEAM_ID
#   REQUIRE_NOTARIZATION=1  makes missing signing or notarization an error
set -euo pipefail
cd "$(dirname "$0")/.."
: "${RELEASE_VERSION:?Set RELEASE_VERSION to the changelog version}"
[[ "$RELEASE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
VERSION="$(sed -n 's/^## \([0-9][0-9.]*\) - .*/\1/p' CHANGELOG.md | head -1)"
test "$RELEASE_VERSION" = "$VERSION"
IDENTITY="${CODESIGN_IDENTITY:--}"
NOTARY_ARGS=()
if [ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]; then
    NOTARY_ARGS=(--keychain-profile "$NOTARY_KEYCHAIN_PROFILE")
elif [ -n "${APPLE_API_KEY_PATH:-}" ]; then
    NOTARY_ARGS=(--key "$APPLE_API_KEY_PATH" --key-id "${APPLE_API_KEY_ID:?}" --issuer "${APPLE_API_ISSUER_ID:?}")
elif [ -n "${APPLE_ID:-}" ]; then
    NOTARY_ARGS=(--apple-id "$APPLE_ID" --password "${APPLE_APP_SPECIFIC_PASSWORD:?}" --team-id "${APPLE_TEAM_ID:?}")
fi
if [ "${REQUIRE_NOTARIZATION:-0}" = 1 ] && { [ "$IDENTITY" = - ] || [ "${#NOTARY_ARGS[@]}" = 0 ]; }; then
    echo 'Error: public releases require Developer ID and notarization credentials' >&2
    exit 1
fi
mkdir -p build/release
OUTPUT="$PWD/build/release"
STAGING="$(mktemp -d "$OUTPUT/.staging.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/Quickshot.app"
xcodebuild -project Quickshot.xcodeproj -scheme Quickshot -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath build/release-derived \
    ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO \
    MARKETING_VERSION="$RELEASE_VERSION" CURRENT_PROJECT_VERSION="$(git rev-list --count HEAD)" \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES build
ditto build/release-derived/Build/Products/Release/Quickshot.app "$APP"
SIGN_ARGS=(--force --sign "$IDENTITY" --options runtime)
if [ "$IDENTITY" = - ]; then SIGN_ARGS+=(--timestamp=none); else SIGN_ARGS+=(--timestamp); fi
codesign "${SIGN_ARGS[@]}" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
ARCHS="$(lipo -archs "$APP/Contents/MacOS/Quickshot")"
[[ " $ARCHS " == *' arm64 '* && " $ARCHS " == *' x86_64 '* ]]
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")" = "$RELEASE_VERSION"
if [ "$IDENTITY" != - ]; then
    codesign -dvv "$APP" 2> "$STAGING/signature.txt"
    grep -q '^Authority=Developer ID Application:' "$STAGING/signature.txt"
    grep -q 'runtime' "$STAGING/signature.txt"
    if [ -n "${APPLE_TEAM_ID:-}" ]; then
        grep -q "^TeamIdentifier=$APPLE_TEAM_ID$" "$STAGING/signature.txt"
    fi
fi
if [ "$IDENTITY" != - ] && [ "${#NOTARY_ARGS[@]}" -gt 0 ]; then
    ditto -c -k --sequesterRsrc --keepParent "$APP" "$STAGING/submission.zip"
    xcrun notarytool submit "$STAGING/submission.zip" "${NOTARY_ARGS[@]}" \
        --wait --timeout 30m --output-format plist > "$STAGING/notary.plist"
    test "$(/usr/libexec/PlistBuddy -c 'Print :status' "$STAGING/notary.plist")" = Accepted
    xcrun stapler staple "$APP"
    xcrun stapler validate "$APP"
    spctl --assess --type execute --verbose=2 "$APP"
else
    echo 'Local inspection package: notarization was skipped.'
fi
NAME="Quickshot-$RELEASE_VERSION-universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$STAGING/$NAME"
# Verify the actual distributed ZIP, including the signature and stapled ticket.
mkdir "$STAGING/unpacked"
ditto -x -k "$STAGING/$NAME" "$STAGING/unpacked"
codesign --verify --deep --strict --verbose=2 "$STAGING/unpacked/Quickshot.app"
if [ "$IDENTITY" != - ] && [ "${#NOTARY_ARGS[@]}" -gt 0 ]; then
    xcrun stapler validate "$STAGING/unpacked/Quickshot.app"
fi
(cd "$STAGING" && shasum -a 256 "$NAME" > "$NAME.sha256")
mv "$STAGING/$NAME" "$STAGING/$NAME.sha256" "$OUTPUT/"
echo "Built $OUTPUT/$NAME"
