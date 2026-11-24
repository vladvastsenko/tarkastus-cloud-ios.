#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl --fail --silent --show-error --location 'https://raw.githubusercontent.com/vladvastsenko/valvontapoytakirja/8b81960aad348cbadee0f56acd67fdc65e77cd32/app/src/main/res/drawable-nodpi/tarkastus_cloud_icon.jpg' -o "$tmp/icon.jpg"
test "$(git hash-object "$tmp/icon.jpg")" = "0b2a37592230a968315c50739315787172a051d2"
bash "$root/scripts/import_android_icon.sh" "$tmp/icon.jpg"
