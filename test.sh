#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/dist/菜单栏间距.app"
if [[ ! -x "$APP/Contents/MacOS/MenuBarSpacing" ]]; then
  printf '%s\n' 'Build the app first: bash build.sh' >&2
  exit 1
fi
"$APP/Contents/MacOS/MenuBarSpacing" --self-test
/usr/bin/codesign --verify --strict "$APP"
/usr/bin/plutil -lint "$APP/Contents/Info.plist"
