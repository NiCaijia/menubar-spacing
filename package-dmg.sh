#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
app_path="$PWD/dist/菜单栏间距.app"
if [[ ! -x "$app_path/Contents/MacOS/MenuBarSpacing" ]]; then
  printf '%s\n' 'Build the app first: bash build.sh' >&2
  exit 1
fi
/usr/bin/codesign --verify --strict "$app_path"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf '%s\n' "Invalid app version: $version" >&2
  exit 1
fi
dmg_name="MenuBarSpacing-${version}-arm64.dmg"
dmg_path="$PWD/dist/$dmg_name"
if [[ -e "$dmg_path" || -e "$dmg_path.sha256" ]]; then
  printf '%s\n' "Output already exists; move it aside before packaging: $dmg_path" >&2
  exit 1
fi
stage_dir=$(mktemp -d "${TMPDIR:-/tmp}/menubar-dmg.XXXXXX")
trap 'rm -rf "$stage_dir"' EXIT
/usr/bin/ditto "$app_path" "$stage_dir/菜单栏间距.app"
ln -s /Applications "$stage_dir/Applications"
cp LICENSE "$stage_dir/LICENSE.txt"
cat > "$stage_dir/安装说明.txt" <<EOF
菜单栏间距 / MenuBar Spacing $version

适用于 Apple Silicon（M 系列芯片），macOS 14 或更新版本。

安装：把“菜单栏间距.app”拖到旁边的 Applications（应用程序），然后从应用程序中打开。
更新：先退出旧版本，再拖入并选择替换。

此版本采用本地临时签名，尚无 Developer ID 签名和 Apple 公证。
首次打开如被系统拦截，请先确认安装包来自本项目，再参照 Apple 的说明操作：
https://support.apple.com/zh-cn/102445

macOS 27 为有限兼容：部分第三方图标可能生效，Wi-Fi、电池、时钟等系统图标可能不变。
macOS 28 及以后的新自定义值写入暂时停用，仍可恢复默认。

卸载前若希望撤销间距调整，请先在应用中点击“恢复系统默认”。

源码与更新：https://github.com/NiCaijia/menubar-spacing
许可证：MIT（见 LICENSE.txt）
EOF
/usr/bin/hdiutil create -volname "MenuBar Spacing $version" -fs HFS+   -srcfolder "$stage_dir" -format UDZO -imagekey zlib-level=9 "$dmg_path"
/usr/bin/hdiutil verify "$dmg_path"
(cd dist && /usr/bin/shasum -a 256 "$dmg_name" > "$dmg_name.sha256")
printf '%s\n' "$dmg_path" "$dmg_path.sha256"
