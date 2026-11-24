#!/bin/bash
set -euo pipefail
source_image="${1:?Supply the original Android tarkastus_cloud_icon.jpg}"
root="$(cd "$(dirname "$0")/.." && pwd)"
dest="$root/TarkastusCloud/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$dest"
sips -s format png -z 1024 1024 "$source_image" --out "$dest/AppIcon.png" >/dev/null
printf '%s\n' '{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}' > "$dest/Contents.json"
printf '%s\n' '{"info":{"author":"xcode","version":1}}' > "$root/TarkastusCloud/Assets.xcassets/Contents.json"
echo "Original Android artwork imported. Set ASSETCATALOG_COMPILER_APPICON_NAME to AppIcon in project.yml if not already set."
