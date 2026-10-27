#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/dist/菜单栏间距.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$PWD/.module-cache"
/usr/bin/xcrun swift -module-cache-path "$PWD/.module-cache" BuildIcon.swift "$PWD/dist/AppIcon.iconset"
/usr/bin/iconutil -c icns "$PWD/dist/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
/usr/bin/xcrun swiftc -swift-version 5 -O -target arm64-apple-macos14.0 \
  -module-cache-path "$PWD/.module-cache" \
  -framework AppKit -framework SwiftUI \
  Sources/Preferences.swift Sources/SelfCheck.swift Sources/LiveMenuBarPreview.swift Sources/MenuBarSpacing.swift \
  -o "$APP/Contents/MacOS/MenuBarSpacing"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>菜单栏间距</string>
<key>CFBundleDisplayName</key><string>菜单栏间距</string>
<key>CFBundleIdentifier</key><string>local.ncj.MenuBarSpacing</string>
<key>CFBundleExecutable</key><string>MenuBarSpacing</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1.0</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>Copyright © 2026 NiCaijia. MIT License.</string>
</dict></plist>
PLIST
/usr/bin/codesign --force --sign - "$APP"
/usr/bin/plutil -lint "$APP/Contents/Info.plist"
printf '%s\n' "$APP"
