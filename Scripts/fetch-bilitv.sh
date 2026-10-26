#!/bin/zsh
set -euo pipefail

root="${0:A:h:h}"
version="2.5.1"
asset="com.biliwebos.app_${version}_all.ipk"
expected="d41f4da03eecd40e1b06425d3037dd8f1fb5c4ae4cfe79953ee8a4d96862d2aa"
external="$root/External/BiliTV"
archive="$external/$asset"
destination="$external/v$version"
url="https://github.com/asdf17128/bili-webos/releases/download/v$version/$asset"

mkdir -p "$external"
if [[ ! -f "$archive" ]]; then
  curl --fail --location --show-error --output "$archive" "$url"
fi

actual=$(shasum -a 256 "$archive" | awk '{print $1}')
if [[ "$actual" != "$expected" ]]; then
  echo "BiliTV archive checksum mismatch: expected $expected, received $actual" >&2
  exit 1
fi

if [[ -e "$destination" ]]; then
  echo "BiliTV v$version is already extracted at $destination"
  exit 0
fi

staging=$(mktemp -d /tmp/mmtv-bilitv.XXXXXX)
cleanup() { rm -rf "$staging"; }
trap cleanup EXIT
(
  cd "$staging"
  ar -x "$archive"
  mkdir payload
  tar -xzf data.tar.gz -C payload
)
mv "$staging/payload" "$destination"
echo "Verified and extracted BiliTV v$version to $destination"

