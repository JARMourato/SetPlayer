#!/bin/bash
#
# One-time setup: store an app-specific password in the keychain so
# notarytool can authenticate without prompting on every release.
#
# Before running this:
#   1. Sign in at  https://appleid.apple.com
#   2. Sign-In and Security  →  App-Specific Passwords  →  Generate
#      Label it "SetPlayer notarization"
#   3. Copy the password (xxxx-xxxx-xxxx-xxxx) and have it ready
#
# Usage:
#   scripts/setup-notary.sh <apple-id-email>
#
# Example:
#   scripts/setup-notary.sh joao.armourato@gmail.com
#
# After this runs once, scripts/release.sh can notarize without further input.
#

set -euo pipefail

APPLE_ID="${1:-}"
TEAM_ID="KEM5K64B8P"
PROFILE="SetPlayerNotary"

if [ -z "${APPLE_ID}" ]; then
    echo "Usage: $0 <apple-id-email>" >&2
    echo "Example: $0 joao.armourato@gmail.com" >&2
    exit 1
fi

echo "Storing notarytool credentials in keychain profile '${PROFILE}'."
echo ""
echo "You'll be prompted for an app-specific password."
echo "Get one at: https://appleid.apple.com  →  Sign-In and Security  →  App-Specific Passwords"
echo ""

xcrun notarytool store-credentials "${PROFILE}" \
    --apple-id "${APPLE_ID}" \
    --team-id "${TEAM_ID}"

echo ""
echo "✅ Saved. You can now run scripts/release.sh <version>"
