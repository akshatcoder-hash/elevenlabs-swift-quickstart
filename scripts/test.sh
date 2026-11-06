#!/bin/bash
# Runs the tests with Xcode or with just the Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")/.."
dev="$(xcode-select -p)"
if [[ "$dev" == /Library/Developer/CommandLineTools ]]; then
  fw="$dev/Library/Developer/Frameworks"
  swift test -Xswiftc -F -Xswiftc "$fw" -Xswiftc -plugin-path -Xswiftc "$dev/usr/lib/swift/host/plugins/testing" \
    -Xlinker -F -Xlinker "$fw" -Xlinker -rpath -Xlinker "$fw" -Xlinker -rpath -Xlinker "$dev/Library/Developer/usr/lib"
else
  swift test
fi
