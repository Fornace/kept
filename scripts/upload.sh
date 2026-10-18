#!/usr/bin/env bash
# One command to archive, export and upload Kept to App Store Connect.
#
# It needs one thing that is not on this Mac yet: the App Store Connect team key
#   ~/.agent_credentials/apple/AuthKey_K6R4NZ46Z5.p8
# named in appstore-connect.env. With that file present, Xcode can register the App Group
# capability, mint the distribution profiles, sign, export and upload without any further edit.
#
#   scripts/upload.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

ENV_FILE="$HOME/.agent_credentials/apple/appstore-connect.env"
# shellcheck disable=SC1090
source "$ENV_FILE"

KEY_PATH="${APP_STORE_CONNECT_KEY_FILEPATH:?}"
KEY_ID="${APP_STORE_CONNECT_KEY_ID:?}"
ISSUER="${APP_STORE_CONNECT_ISSUER_ID:?}"
BUNDLE_ID="it.fornace.kept"
SKU="kept-001"
APP_NAME="Kept: Receipts & Warranties"
ASC="$HOME/.local/bin/asc"
ARCHIVE="build/Kept-iOS.xcarchive"
EXPORT_DIR="build/export"

log() { printf '\n== %s\n' "$*"; }

log "checking the App Store Connect key"
if [[ ! -f "$KEY_PATH" ]]; then
  cat >&2 <<MSG
Missing App Store Connect key: $KEY_PATH

Download the team key from App Store Connect > Users and Access > Integrations > Team Keys
(key id $KEY_ID), save it at the path above, then run this script again. Nothing else is missing:
the Apple Distribution certificate for Fornace s.r.l. (2V6YSU4HFB) is already in the keychain and
the project already declares the App Group and bundle identifiers.
MSG
  exit 1
fi

log "authenticating"
export ASC_KEY_ID="$KEY_ID" ASC_ISSUER_ID="$ISSUER" ASC_PRIVATE_KEY_PATH="$KEY_PATH"
"$ASC" apps list --bundle-id "$BUNDLE_ID" --output json >/dev/null

log "making sure the app record exists"
if ! "$ASC" apps list --bundle-id "$BUNDLE_ID" --output json | grep -q "$BUNDLE_ID"; then
  echo "No app record for $BUNDLE_ID yet."
  echo "Create it once (web session, no API path exists for app creation):"
  echo "  $ASC web auth login --apple-id <your apple id>"
  echo "  $ASC web apps create --name \"$APP_NAME\" --bundle-id \"$BUNDLE_ID\" --sku \"$SKU\""
  exit 2
fi

log "archiving for App Store distribution"
xcodebuild archive \
  -project Kept.xcodeproj -scheme Kept -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER"

log "exporting and uploading"
rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"
cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><true/>
  <key>teamID</key><string>2V6YSU4HFB</string>
  <key>signingStyle</key><string>automatic</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist build/ExportOptions.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER"

log "done: build uploaded, processing on App Store Connect"
"$ASC" builds list --app "$("$ASC" apps list --bundle-id "$BUNDLE_ID" --output json | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"][0]["id"])')" --output table | head -5
