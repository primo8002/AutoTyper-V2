#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
app_dir="$repo_dir/dist/AutoTyper.app"
mkdir -p "$app_dir/Contents/MacOS"
swiftc -parse-as-library -O \
  -framework SwiftUI -framework AppKit -framework ApplicationServices -framework Carbon \
  "$repo_dir/Sources/AutoTyper.swift" -o "$app_dir/Contents/MacOS/AutoTyper"
cp "$repo_dir/Info.plist" "$app_dir/Contents/Info.plist"
echo "$app_dir"
