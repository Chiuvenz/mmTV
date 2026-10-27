#!/bin/zsh
set -euo pipefail

root="${0:A:h:h}"
"$root/Scripts/build.sh"

echo "mmTV package is ready in $root/dist"
echo "BiliTVMac and other third-party adapters build from https://github.com/Chiuvenz/mmTVAdapters (~/vibeCoding/mmTVAdapters)"
