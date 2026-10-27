#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
if [[ -n "${MMTV_CODE_SIGN_IDENTITY:-}" ]]; then
  signing_identity="$MMTV_CODE_SIGN_IDENTITY"
else
  signing_identity="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -1)"
  signing_identity="${signing_identity:--}"
fi
xcodegen generate
xcodebuild -project mmTV.xcodeproj -scheme mmTV -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO build
mkdir -p dist
app_output="${PWD}/dist/mmTV.app"
[[ "$app_output" == "${PWD}/dist/mmTV.app" ]] || { echo "Unexpected app output path" >&2; exit 1; }
if [[ -e "$app_output" ]]; then
  find "$app_output" -depth -delete
fi
ditto build/Build/Products/Release/mmTV.app dist/mmTV.app
codesign --force --sign "$signing_identity" --options runtime dist/mmTV.app
ditto -c -k --keepParent dist/mmTV.app dist/mmTV-0.2.0-preview-arm64.zip
