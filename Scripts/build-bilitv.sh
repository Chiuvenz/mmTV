#!/bin/zsh
set -euo pipefail

root="${0:A:h:h}"
integration="$root/Integrations/BiliTVMac"
upstream="$root/External/BiliTV/v2.5.1"
vendor="$integration/vendor"
app_path="$integration/dist/mac-arm64/BiliTVMac.app"
archive_path="$integration/dist/BiliTVMac-0.1.0-arm64.zip"

"$root/Scripts/fetch-bilitv.sh"
[[ "$vendor" == "$root/Integrations/BiliTVMac/vendor" ]] || { echo "Unexpected vendor path" >&2; exit 1; }
rm -rf "$vendor"
mkdir -p "$vendor"
ditto "$upstream/usr" "$vendor/usr"

(
  cd "$integration"
  export ELECTRON_MIRROR="${ELECTRON_MIRROR:-https://npmmirror.com/mirrors/electron/}"
  export ELECTRON_BUILDER_BINARIES_MIRROR="${ELECTRON_BUILDER_BINARIES_MIRROR:-https://npmmirror.com/mirrors/electron-builder-binaries/}"
  npm ci
  npm test
  npm audit --audit-level=high
  npm run build:mac
)

codesign --force --deep --sign - --options runtime --entitlements "$integration/entitlements.mac.plist" "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"
if [[ "${MMTV_SKIP_BILITV_SMOKE:-0}" != "1" ]]; then
  "$root/Scripts/smoke-bilitv.sh" "$app_path"
fi
archive_tmp="$(mktemp -d)/BiliTVMac.zip"
ditto -c -k --keepParent "$app_path" "$archive_tmp"
mv "$archive_tmp" "$archive_path"
mkdir -p "$root/dist"
ditto "$archive_path" "$root/dist/BiliTVMac-0.1.0-arm64.zip"

echo "BiliTVMac package created at $root/dist/BiliTVMac-0.1.0-arm64.zip"
