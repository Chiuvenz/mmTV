#!/bin/zsh
set -euo pipefail

root="${0:A:h:h}"
app_path="${1:-$root/Integrations/BiliTVMac/dist/mac-arm64/BiliTVMac.app}"
executable="$app_path/Contents/MacOS/BiliTVMac"
[[ -x "$executable" ]] || { echo "BiliTVMac executable not found: $executable" >&2; exit 1; }

smoke_dir="$(mktemp -d)"
result="$smoke_dir/result.json"
"$executable" --smoke-test "$result"
node -e 'const fs=require("node:fs"); const r=JSON.parse(fs.readFileSync(process.argv[1])); if (!r.ok) process.exit(1); console.log(JSON.stringify({ok:r.ok, cards:r.page.videoCards, focusMoved:r.input.moved, playbackStarted:r.playback.started, returned:r.playback.returned}, null, 2));' "$result"
echo "BiliTVMac smoke evidence: $result"
