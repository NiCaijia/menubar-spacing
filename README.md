# 菜单栏间距 · MenuBar Spacing

[![Build](https://github.com/NiCaijia/menubar-spacing/actions/workflows/build.yml/badge.svg)](https://github.com/NiCaijia/menubar-spacing/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

用原生 macOS 界面调整菜单栏图标的间距与留白。SwiftUI + AppKit，无第三方运行时依赖。

**macOS 27 为有限兼容：读取相关偏好设置的应用可能生效，Wi-Fi、电池、时钟等系统图标可能不变。** 窗口内的预览是示意图，不能用来证明所有图标的实际变化。

## 下载与安装

[下载 v1.1.0 DMG（Apple Silicon）](https://github.com/NiCaijia/menubar-spacing/releases/download/v1.1.0/MenuBarSpacing-1.1.0-arm64.dmg) · [全部版本](https://github.com/NiCaijia/menubar-spacing/releases)

1. 下载并打开 DMG，把“菜单栏间距.app”拖入旁边的 **Applications（应用程序）**。
2. 从“应用程序”打开；更新旧版本时，请先退出旧版再替换。
3. 此版本使用临时签名，**尚无 Developer ID 签名和 Apple 公证**。首次打开如被系统拦截，在确认下载来自本仓库后，可按照 [Apple 官方说明](https://support.apple.com/zh-cn/102445) 在“系统设置 → 隐私与安全性”中选择“仍要打开”。

安装包不需要 Xcode 或其他开发工具。Release 同时提供 `.sha256` 文件用于核对下载完整性；当前不提供 Intel 安装包。

## 功能

- 独立调整间距与留白，范围为 4–32；提供紧凑、适中、宽松预设。
- 点击“应用”才保存，保存后读回核验；支持撤销上一次修改。
- 恢复系统默认会移除自定义键值，而不是写入猜测的默认数字。
- “菜单栏实测”临时显示 MBS 和双箭头图标，30 秒后自动收起，可手动提前结束。
- 不需要管理员密码、辅助功能或屏幕录制权限；不联网、不收集数据。
- 不自动重启其他应用，不注销用户，也不设置开机启动。

## 系统要求与兼容性

当前构建脚本生成 **Apple Silicon（arm64）** 应用，最低部署版本为 macOS 14。Intel 构建尚未提供。

| 系统 | 状态 |
| --- | --- |
| macOS 14–26 | 启用传统偏好设置调整路径；并非每个版本、每款应用都经过实机测试 |
| macOS 27 | 有限兼容；27.0.1 上已实测本工具的传统 AppKit 状态栏图标 |
| macOS 28 及以后 | 暂停应用新的自定义值，仍允许恢复默认 |

这些偏好键不是 Apple 承诺稳定支持的公开间距配置接口。系统更新或应用自己的布局方式可能改变效果。详见 [兼容性与测量范围](docs/compatibility.md)。

## 从源码构建

需要 macOS、Apple Silicon，以及 Xcode 或 Xcode Command Line Tools（含 Swift 编译器）。如尚未安装开发工具，可运行 `xcode-select --install` 并完成系统提示。

```sh
git clone https://github.com/NiCaijia/menubar-spacing.git
cd menubar-spacing
bash build.sh
bash test.sh
open 'dist/菜单栏间距.app'
```

应用输出在 `dist/菜单栏间距.app`。可在 Finder 中将它拖入“应用程序”或用户自己的 Applications 文件夹。构建脚本只生成应用，不自动安装或修改菜单栏设置。

构建产物采用本地临时签名（ad-hoc），没有 Developer ID 签名或 Apple 公证。通过浏览器下载的构建产物可能被 Gatekeeper 拦截；本项目不提供关闭系统安全检查的脚本。

运行 `bash package-dmg.sh` 可把已构建的应用打包成 DMG，并生成 SHA-256 校验文件。为避免覆盖现有包，同版本输出已存在时脚本会停止。

GitHub Actions 会构建、运行自检，并保存 ZIP、DMG 和校验文件作为工作流产物。工作流产物有保留期限；正式安装包从上面的 Releases 下载。

## 使用

1. 打开应用，查看“当前已保存”的设置。
2. 拖动滑块或选择预设，再点击“应用”。
3. 重新打开希望调整的菜单栏应用，观察实际效果；不同应用可能读取不同的布局设置。
4. 点击“菜单栏实测”，可以观察本工具自己的两个临时状态栏图标。
5. 不满意时使用“撤销上次修改”或“恢复系统默认”。

退出工具后偏好设置仍然保留。若卸载前希望取消调整，请先恢复默认，并重新打开相关菜单栏应用。撤销状态只保存在当前工具进程中，关闭应用后不会继续保留。

## 实现与测试

通过 Core Foundation 读写当前用户、当前主机的全局偏好设置：

- `NSStatusItemSpacing`
- `NSStatusItemSelectionPadding`

写入失败时尝试恢复操作前的值；读回成功只代表设置已保存，不代表其他应用已经采用。

`bash test.sh` 检查独立偏好域中的持久化、跨进程读回、恢复默认、撤销、macOS 27 模式与未来版本保护，并验证应用签名。测试使用随机命名的临时域，不修改真实全局菜单栏设置。它不验证所有第三方或系统图标，也不代替实机界面测试。

## English overview

A small native SwiftUI/AppKit utility for adjusting macOS menu bar spacing preferences. It offers independent spacing and padding controls, presets, undo, restore defaults, and a temporary preview using its own status items. No networking or third-party runtime dependencies.

Build on an Apple Silicon Mac with Xcode Command Line Tools: `bash build.sh`, then `bash test.sh`. The app is written in Simplified Chinese. macOS 27 support is limited: only the app's own traditional AppKit status items have been measured on 27.0.1, and system icons may ignore the preferences. New custom writes are disabled on macOS 28 and later pending validation.

## 参与与许可

欢迎提交 Issue 和 Pull Request。反馈兼容性问题时请提供系统版本、芯片类型、受影响应用名称，以及重启该应用后的表现；不要上传个人偏好文件或带私人内容的整屏截图。见 [贡献说明](CONTRIBUTING.md)。

本项目使用 [MIT License](LICENSE)。这是独立工具，与 Apple 无隶属关系。
