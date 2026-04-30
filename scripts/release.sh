#!/bin/bash
#
# SetPlayer release pipeline.
#
# Builds, signs, notarizes, staples, and packages SetPlayer as a DMG ready
# for Homebrew Cask distribution.
#
# Prerequisites (one-time):
#   - Developer ID Application certificate in keychain
#   - Run scripts/setup-notary.sh once to store the notarytool credential
#
# Usage:
#   scripts/release.sh <version>
#
# Example:
#   scripts/release.sh 0.1.0
#
# Outputs in build/release/:
#   SetPlayer-<version>.dmg     — signed, notarized, stapled
#   SetPlayer-<version>.dmg.sha256
#

set -euo pipefail

VERSION="${1:-}"
if [ -z "${VERSION}" ]; then
    echo "Usage: $0 <version>" >&2
    echo "Example: $0 0.1.0" >&2
    exit 1
fi

APP_NAME="SetPlayer"
SCHEME="SetPlayer"
TEAM_ID="KEM5K64B8P"
NOTARY_PROFILE="SetPlayerNotary"
SIGN_ID="Developer ID Application: Joao Mourato (${TEAM_ID})"
BUILD_NUMBER="$(date +%Y%m%d%H%M)"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT}/build/release"
ARCHIVE="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"
APP_PATH="${EXPORT_DIR}/${APP_NAME}.app"
DMG_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"
ZIP_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.zip"
EXPORT_OPTIONS="${BUILD_DIR}/exportOptions.plist"

step() { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
fail() { printf "\n\033[1;31mFAIL: %s\033[0m\n" "$*" >&2; exit 1; }

# Verify required commands
for cmd in xcodebuild xcodegen ditto hdiutil shasum codesign; do
    command -v "${cmd}" >/dev/null 2>&1 || fail "Missing required command: ${cmd}"
done

# Verify code signing identity exists
if ! security find-identity -v -p codesigning | grep -q "${SIGN_ID}"; then
    fail "Code signing identity not found: ${SIGN_ID}"
fi

# Verify notary keychain profile exists
if ! xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" >/dev/null 2>&1; then
    fail "Notary keychain profile '${NOTARY_PROFILE}' not found. Run scripts/setup-notary.sh first."
fi

step "1/8  Cleaning build dir"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

step "2/8  Regenerating Xcode project"
(cd "${ROOT}" && xcodegen generate)

step "3/8  Archiving (Release)"
xcodebuild archive \
    -project "${ROOT}/SetPlayer.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "${ARCHIVE}" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    CODE_SIGN_IDENTITY="${SIGN_ID}" \
    OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
    MARKETING_VERSION="${VERSION}" \
    CURRENT_PROJECT_VERSION="${BUILD_NUMBER}" \
    -quiet

step "4/8  Exporting signed .app"
cat > "${EXPORT_OPTIONS}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "${ARCHIVE}" \
    -exportPath "${EXPORT_DIR}" \
    -exportOptionsPlist "${EXPORT_OPTIONS}" \
    -quiet

[ -d "${APP_PATH}" ] || fail "Export did not produce ${APP_PATH}"

step "5/8  Notarizing .app"
ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"
xcrun notarytool submit "${ZIP_PATH}" \
    --keychain-profile "${NOTARY_PROFILE}" \
    --wait
rm -f "${ZIP_PATH}"

step "6/8  Stapling .app"
xcrun stapler staple "${APP_PATH}"
xcrun stapler validate "${APP_PATH}"

step "7/8  Building DMG"
# Use attach/copy/convert flow instead of hdiutil -srcfolder, which is flaky
# on macOS Sequoia when DiskArbitration is busy (e.g. simulators booting/shutting).
APP_SIZE_MB=$(du -sm "${APP_PATH}" | awk '{print $1}')
DMG_SIZE_MB=$(( APP_SIZE_MB + 20 ))
RW_DMG="${BUILD_DIR}/${APP_NAME}-rw.dmg"

hdiutil create -size "${DMG_SIZE_MB}m" -fs HFS+ -volname "${APP_NAME}" -ov "${RW_DMG}"
MOUNT_POINT="$(hdiutil attach "${RW_DMG}" -nobrowse | tail -1 | awk '{print $NF}')"
[ -n "${MOUNT_POINT}" ] || fail "Failed to mount writable DMG"
cp -R "${APP_PATH}" "${MOUNT_POINT}/"
hdiutil detach "${MOUNT_POINT}" -force
hdiutil convert "${RW_DMG}" -format UDZO -o "${DMG_PATH}"
rm -f "${RW_DMG}"

codesign --force --sign "${SIGN_ID}" --timestamp "${DMG_PATH}"

codesign --force --sign "${SIGN_ID}" --timestamp "${DMG_PATH}"

step "8/8  Notarizing + stapling DMG"
xcrun notarytool submit "${DMG_PATH}" \
    --keychain-profile "${NOTARY_PROFILE}" \
    --wait
xcrun stapler staple "${DMG_PATH}"
xcrun stapler validate "${DMG_PATH}"

# Output SHA256 sidecar for cask formula
SHA256="$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')"
echo "${SHA256}  $(basename "${DMG_PATH}")" > "${DMG_PATH}.sha256"

printf "\n\033[1;32m✅ Release ready\033[0m\n"
echo "    DMG:    ${DMG_PATH}"
echo "    SHA256: ${SHA256}"
echo ""
echo "Next steps:"
echo "    1. Tag and push:  git tag v${VERSION} && git push origin v${VERSION}"
echo "    2. Create GitHub Release with the DMG attached"
echo "    3. Update Casks/setplayer.rb in your homebrew tap with:"
echo "         version \"${VERSION}\""
echo "         sha256 \"${SHA256}\""
