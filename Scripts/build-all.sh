#!/bin/zsh
set -euo pipefail

root="${0:A:h:h}"
"$root/Scripts/build.sh"
"$root/Scripts/build-bilitv.sh"

echo "mmTV suite packages are ready in $root/dist"
