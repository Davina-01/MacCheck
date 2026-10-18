# MacCheck 测试清单

本文档用于发布前自测和门店验机流程复核。自动检测可以通过构建和 App 启动完成，交互测试需要真实 Mac 硬件配合。

## 发布前基础验证

```bash
xcodebuild -project MacCheck.xcodeproj -scheme MacCheck -configuration Release -destination 'generic/platform=macOS' -derivedDataPath build_release ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO
lipo -archs build_release/Build/Products/Release/MacCheck.app/Contents/MacOS/MacCheck   # 应输出 x86_64 arm64
./scripts/build_and_notarize.sh
hdiutil verify dist/MacCheck-IM-1.0.0.dmg
```

验证项：

- App 能正常启动，首页自动扫描结束
- 左侧导航所有页面能打开，无明显布局挤压或空白
- “保存到历史”可以生成历史记录
- “导出报告”可以导出 PNG 和 PDF
- DMG 可以挂载，包含 `MacCheck.app` 与 Applications 快捷方式

## 自动检测项目

| 模块 | 期望结果 |
| --- | --- |
| 硬件规格 | 显示机型、序列号、芯片、内存、架构、macOS 版本 |
| 电池 | 笔记本显示循环次数与健康信息，台式机显示不适用或无数据 |
| 安全与锁定 | 显示安全芯片、MDM、Apple ID / 激活锁相关提示 |
| 存储 | 显示容量、可用空间、SMART 或磁盘状态 |
| 网络 | 显示 Wi-Fi / 蓝牙状态 |
| 接口 | 显示检测到的 USB / Thunderbolt 控制器或设备 |
| AI 大模型 | 根据内存给出本地模型可跑性建议 |

## 交互测试项目

| 模块 | 操作 | 通过标准 |
| --- | --- | --- |
| 键盘 | 进入全屏，逐个按下实体按键 | 按下按键高亮，无失灵、连击、卡键 |
| 屏幕 | 切换纯色、灰阶、棋盘格画面 | 无明显坏点、亮点、漏光、色带 |
| 扬声器 / 耳机 | 播放测试音 | 左右声道与耳机输出正常 |
| 麦克风 | 授权后录音或观察电平 | 有稳定输入，无异常底噪 |
| 摄像头 | 授权后查看预览 | 画面清晰，无遮挡、坏点、闪烁 |
| Touch ID | 按页面提示确认 | 可用或明确显示不支持 |
| 触控板 | 点击、滑动、手势测试 | 点击、移动、滚动响应正常 |
| 性能压测 | 开始短时压力测试 | 无异常卡死或温度/性能红旗 |
| 硬盘测速 | 开始读写采样 | 读写结果可显示，未出现异常失败 |
| 接口逐口实测 | 插拔外设并记录 | 目标接口均可识别外设 |

## v1.0.0 新增项目复核

| 项目 | 操作 | 通过标准 |
| --- | --- | --- |
| 界面语言 | 设置 → 界面语言，依次切换 简体中文 / English / Français / 跟随系统 | 侧边栏、各页面、检测结论立即换成对应语言，自动重新扫描；导出报告与文件名为对应语言 |
| 权限提示 | 在英文 / 法文系统下首次打开摄像头、麦克风测试 | 系统权限弹窗文案为对应语言 |
| 键盘形态 | 分别在 ANSI、ISO（如法语 AZERTY）、JIS 键盘上进入键盘测试 | 自动识别正确形态；回车、§/`、¥、英数/かな 等键位置正确 |
| 键盘布局 | 切换「键盘布局」为 French、German、Spanish 等 | 键帽字符与实体键盘一致（AZERTY / QWERTZ 等） |
| 修饰键 | 按住 ⌘ 后松开、切换 caps lock、按 ⌘Tab 切走再切回 | 不再出现误报「疑似卡键」 |
| 功能行 | 不按 fn 直接按 F1–F12 | 亮度、音量、媒体键也能点亮对应 F 键；被系统拦截的键可点击键帽手动确认 |
| 屏幕覆盖 | 在带刘海的 MacBook 上进行屏幕测试，按 H 隐藏面板 | 纯色画面覆盖整块屏幕，包括菜单栏与刘海两侧，无未覆盖条带 |
| 雷雳设备 | 接口逐口实测中插入雷雳 3 / 4 固态硬盘盒 | 事件列表出现「雷雳 / USB4」或「外接磁盘」接入记录 |
| MDM 绕过 | 在测试机 `/etc/hosts` 中加入 `0.0.0.0 deviceenrollment.apple.com` 后重新扫描（测完删除） | 「安全与锁定」出现红色 MDM 绕过警告 |
| smartctl | 未安装时查看「存储」；`brew install smartmontools` 后重新扫描 | 未安装时提示安装命令；安装后显示累计写入、已用寿命等 |
| Intel 机型 | 在 Intel Mac 上打开通用二进制版本 | 可正常启动；性能压测能读到温度（若机型提供） |

## 隐私与截图

真实截图和报告通常包含序列号、设备名称、系统版本等信息。发布到 GitHub、官网或社交平台前，请先脱敏。

本仓库 `docs/assets` 中的图片为真机测试截图，已对序列号等敏感信息做打码处理。
