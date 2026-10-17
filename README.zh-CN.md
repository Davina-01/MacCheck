[Français](README.md) · [English](README.en.md) · **简体中文**

# MacCheck 验机宝

> [!NOTE]
> **关于本版本。** 这是开源项目 **[andyhuo520/MacCheck](https://github.com/andyhuo520/MacCheck)**（作者 andyhuo520）的修改版（Fork）。本版本在 AI 协助下修改，新增了 **中 / 英 / 法三种界面语言** 和 **多国键盘布局支持**，并修复了原项目中用户反馈的若干问题。由于改动由 AI 协助完成，且尚未在所有 Mac 机型上实测，**本版本可能存在 bug 或错误，欢迎反馈**：请 [提交 issue](../../issues)，注明你的 Mac 机型、macOS 版本和遇到的现象。
>
> 本 Fork 由 **[InnoMicro](https://innomicro.fr)** 维护，我们是位于巴黎的 PC 屏幕与苹果零件批发商，欢迎访问 **[innomicro.fr](https://innomicro.fr)**。
>
> 原版 App 的全部功劳归原作者所有。原仓库没有附带许可证文件，如计划将本 App 用于商业分发，请先联系原作者确认授权。

MacCheck 是一款面向二手 Mac 交易、门店验机和个人自检的 macOS 本地验机工具。它会自动读取硬件规格、电池、存储、网络、安全与接口信息，并提供键盘、屏幕、音频、麦克风、摄像头、触控板、硬盘测速等交互测试，最后可导出 PDF 或 PNG 验机报告。

> 隐私说明：MacCheck 完全本地运行，不上传序列号、检测结果或报告内容。README 中的图片为真机测试截图，序列号等敏感信息已打码。

![MacCheck overview](docs/assets/overview-demo.png)

## 本 Fork 新增内容（v1.3.0）

**三种界面语言。** English、Français、简体中文，可在 **设置 → 界面语言** 中随时切换，或自动跟随 macOS 系统语言。报告、检测结论、系统权限提示和机型名称（如「MacBook Pro（14 英寸，2021）」）都会随语言切换。

**支持各国键盘的键盘测试。**
- 自动识别键盘物理形态：**ANSI**（美式）、**ISO**（法、德、英、西、意、北欧等欧式）或 **JIS**（日式），正确绘制回车键形状、ISO 多出的键和 JIS 专有键。
- 键帽字符直接读取 macOS 已安装的键盘布局，**AZERTY、QWERTZ、西班牙语、瑞士、比利时、北欧、俄语** 等所有布局都能显示正确字符，也可手动选择任意布局。
- 点击键帽可手动确认（用于被系统拦截的键），或标记为本机没有此键。

**修复原项目中反馈的问题。**

| 原项目 issue | 修复内容 |
| --- | --- |
| [#1](https://github.com/andyhuo520/MacCheck/issues/1) Intel Mac 无法打开 | Release 构建改为 **通用二进制**（Apple Silicon + Intel），打包脚本发现缺少任一架构时会直接停止。Intel 机型也能读取温度与风扇转速。 |
| [#2](https://github.com/andyhuo520/MacCheck/issues/2) 加强 MDM 检测 | 识别常见的 **绕过 MDM** 手法：在 `/etc/hosts` 里把 Apple 设备注册服务器（`deviceenrollment.apple.com`、`mdmenrollment.apple.com`、`iprofiles.apple.com` 等）指向 `0.0.0.0`，以及绕过脚本留下的伪造标记文件。 |
| [#3](https://github.com/andyhuo520/MacCheck/issues/3) 英文界面 | 新增英文界面与英文 README（另含法语）。 |
| [#4](https://github.com/andyhuo520/MacCheck/issues/4) 用 `smartctl` 查看磁盘读写量 | 新增「硬盘寿命与读写量」检测：累计写入/读取、已用寿命、通电时间、异常断电次数和介质错误。需要安装 [smartmontools](https://www.smartmontools.org)（`brew install smartmontools`），未安装时会提示安装方法。 |
| [#5](https://github.com/andyhuo520/MacCheck/issues/5) F11 识别不准 / 误报卡键、雷雳硬盘识别不到、屏幕顶部测不到 | ⌘、caps lock 等修饰键不再被误判为「卡键」；F1–F12 触发的亮度、音量等系统功能会映射回对应 F 键。接口实测新增识别 **雷雳 / USB4 设备与外接磁盘**。键盘与屏幕测试改为在 **覆盖整块屏幕的真正全屏窗口** 中进行，包括菜单栏区域和刘海两侧；屏幕测试中按 **H** 可隐藏提示面板。 |

另外修复：电池循环次数防篡改核对的结果此前从未出现在报告中。

## 功能亮点

- 自动识别机型、芯片、内存、macOS 版本、序列号、机型年份等基础信息
- 电池循环次数、健康度、存储空间、网络、蓝牙、接口等自动检测
- MDM（含绕过检测）、Apple ID / 激活锁、安全芯片等二手机交易高风险项提示
- 键盘逐键点亮、屏幕纯色/灰阶/棋盘格、音频、麦克风、摄像头、Touch ID、触控板等交互测试
- 硬盘读写测速、性能压测（含温度与风扇转速）、接口逐口实测
- AI 大模型可跑性建议，按本机内存估算本地模型适配度
- 一键导出 PDF / PNG 长图报告，支持保存历史记录便于后续对比
- 支持跟随系统、浅色、深色三种外观主题

![MacCheck hardware specs](docs/assets/hardware-specs-real.png)

## 系统要求

- macOS 14.0 或更高版本
- Apple Silicon 或 Intel Mac
- Xcode 16 或更高版本用于源码构建
- 可选：[`xcodegen`](https://github.com/yonaskolb/XcodeGen)，用于根据 `project.yml` 重新生成 Xcode 工程
- 可选：[`smartmontools`](https://www.smartmontools.org)，用于读取硬盘寿命数据（`brew install smartmontools`）

## 安装

1. 到 **[Releases](https://github.com/Davina-01/MacCheck/releases/latest)** 页面下载 `MacCheck-IM-x.y.z.dmg`，同一个文件同时支持 Apple Silicon 和 Intel Mac。
2. 打开 DMG，将 `MacCheck.app` 拖到 `Applications`。
3. 摄像头、麦克风、蓝牙等权限会按需请求。

DMG 由 GitHub Actions 自动构建，目前为 ad-hoc 签名（尚未使用 Developer ID 签名和 Apple 公证），首次打开时 macOS 会弹出提示。

如果 macOS 提示"无法打开，因为无法验证开发者"，右键点击 `MacCheck.app`，选择"打开"。如果提示 App"已损坏，无法打开"，通常是下载隔离属性导致；确认已将 App 拖入 `/Applications` 后，在终端执行：

```bash
sudo xattr -rd com.apple.quarantine /Applications/MacCheck.app
```

## 使用流程

1. 打开 MacCheck，等待概览页自动完成系统检测。
2. 先查看「概览」和「重大问题」区域，红色项目需要优先确认。
3. 依次进入左侧「硬件测试」项目，完成键盘、屏幕、音频、摄像头等人工确认项。
4. 点击「保存到历史」，保留本次检测快照。
5. 点击「导出报告」，选择 PNG 长图或 PDF。

![MacCheck security checks](docs/assets/security-real.png)

![MacCheck keyboard test](docs/assets/testing-demo.png)

## 源码构建

```bash
git clone https://github.com/Davina-01/MacCheck.git
cd MacCheck

# 可选：如果你修改了 project.yml
brew install xcodegen
xcodegen generate

# 通用二进制构建（Apple Silicon + Intel）
xcodebuild \
  -project MacCheck.xcodeproj \
  -scheme MacCheck \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build_release \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO

# 确认两个架构都在
lipo -archs build_release/Build/Products/Release/MacCheck.app/Contents/MacOS/MacCheck
```

构建产物位于 `build_release/Build/Products/Release/MacCheck.app`。

## 打包 DMG

```bash
./scripts/build_and_notarize.sh
```

脚本会：如已安装 `xcodegen` 则重新生成工程；构建通用二进制 Release 版本并校验两个架构；有 Developer ID 证书时执行签名与公证，否则生成本地可运行的 ad-hoc DMG；最终输出 `dist/MacCheck-IM-1.3.0.dmg`。

如要正式分发，请先配置：

```bash
export MACCHECK_SIGN_ID="Developer ID Application: Your Name (TEAMID)"
export MACCHECK_NOTARY_PROFILE="maccheck-notary"
```

并按 Apple 官方流程使用 `xcrun notarytool store-credentials` 保存公证凭证。

## 版本号

- App 版本号（macOS 中显示）：只用数字 `x.y.z`，这是 Apple 的要求。本 Fork 在原项目基础上从 1.3.0 继续编号。
- InnoMicro 发布版：Git 标签 `vX.Y.Z-im`，安装包 `MacCheck-IM-X.Y.Z.dmg`，Release 标题「MacCheck IM X.Y.Z」。
- 规则：修 bug → `1.3.1`，加功能 → `1.4.0`，重大不兼容改动 → `2.0.0`。

## 翻译

源语言是简体中文：界面文案在代码中直接用中文书写，通过 `L("…")` 取当前语言的译文。译文位于：

```text
Sources/Resources/en.lproj/Localizable.strings
Sources/Resources/fr.lproj/Localizable.strings
```

译文中必须保留 `{0}`、`{1}` 等占位符（顺序可以调整）。欢迎通过 pull request 修正翻译。

## 项目结构

```text
Sources/
  App/                 App 入口与 Info.plist
  Core/                硬件探测、报告、历史记录、系统服务、多语言
  Checks/              键盘、屏幕、音频、摄像头等交互测试
  UI/                  SwiftUI 页面、设计系统与导航
  Resources/           译文（en、fr）与多语言权限提示
scripts/
  build_and_notarize.sh
docs/
  TESTING.md
  RELEASE.md
  assets/
```

## 致谢

- 原版 App：**[andyhuo520/MacCheck](https://github.com/andyhuo520/MacCheck)**，作者 andyhuo520
- 多语言与多键盘布局版本：由 **[InnoMicro](https://innomicro.fr)**（巴黎）在 AI 协助下维护
