#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
app_dir="$repo_dir/dist/AutoTyper.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
# Keep compiler caches within the build directory for sandboxed builds.
mkdir -p "$repo_dir/dist/module-cache"
swiftc -parse-as-library -O \
  -module-cache-path "$repo_dir/dist/module-cache" \
  -framework SwiftUI -framework AppKit -framework ApplicationServices -framework Carbon \
  "$repo_dir/Sources/AutoTyper.swift" -o "$app_dir/Contents/MacOS/AutoTyper"
cp "$repo_dir/Info.plist" "$app_dir/Contents/Info.plist"
cp "$repo_dir/assets/AutoTyper.icns" "$repo_dir/assets/AutoTyper.png" "$app_dir/Contents/Resources/"
# Sign the complete bundle only AFTER copying Info.plist and resources.
# The linker's automatic executable-only signature does not seal an app bundle.
# Use the same certificate for each release to preserve permissions across updates.
# Finder/iCloud can attach metadata to the generated bundle that signing rejects.
xattr -dr com.apple.FinderInfo "$app_dir" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$app_dir" 2>/dev/null || true
codesign --force --sign "${AUTOTYPER_SIGNING_IDENTITY:--}" \
  --identifier local.svanik.autotyper.v2 "$app_dir"
codesign --verify --deep --strict "$app_dir"
echo "$app_dir"
