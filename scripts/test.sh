#!/usr/bin/env bash
# Runs the tests. With only the Command Line Tools installed (no Xcode), SwiftPM can't find the
# Swift Testing framework by itself, so point it at the copy inside the Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")/.."

CLT=/Library/Developer/CommandLineTools/Library/Developer
if [[ "$(xcode-select -p)" == "/Library/Developer/CommandLineTools" && -d "$CLT/Frameworks/Testing.framework" ]]; then
  exec swift test \
    -Xswiftc -F"$CLT/Frameworks" -Xlinker -F"$CLT/Frameworks" \
    -Xlinker -rpath -Xlinker "$CLT/Frameworks" -Xlinker -rpath -Xlinker "$CLT/usr/lib" "$@"
fi
exec swift test "$@"
