#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
xcodegen generate
xcodebuild -project mmTV.xcodeproj -scheme mmTV -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO build
mkdir -p dist
ditto build/Build/Products/Release/mmTV.app dist/mmTV.app
codesign --force --sign - --options runtime dist/mmTV.app
ditto -c -k --keepParent dist/mmTV.app dist/mmTV-0.2.0-preview-arm64.zip
