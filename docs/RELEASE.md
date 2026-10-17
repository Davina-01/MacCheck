# 发布说明

## 版本号

当前版本号在 `Sources/App/Info.plist` 中维护：

- `CFBundleShortVersionString`: 对外版本号，例如 `1.0`
- `CFBundleVersion`: 构建号，例如 `1`

发布前请同步更新 `scripts/build_and_notarize.sh` 中的 `VERSION`，以及 `project.yml` 中的版本号。

打包脚本会构建通用二进制（arm64 + x86_64）并用 `lipo` 校验，缺少任一架构会直接失败，避免再次发布只支持 Apple Silicon 的版本。

## 本地打包

```bash
./scripts/build_and_notarize.sh
```

输出文件：

```text
~/Desktop/MacCheck-1.3.dmg
```

## 签名和公证

如需正式分发，需要：

1. Apple Developer 账号
2. 钥匙串中安装 `Developer ID Application` 证书
3. 保存 notarytool 凭证

```bash
xcrun notarytool store-credentials "maccheck-notary" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID" \
  --password "APP_SPECIFIC_PASSWORD"
```

可选环境变量：

```bash
export MACCHECK_SIGN_ID="Developer ID Application: Your Name (TEAMID)"
export MACCHECK_NOTARY_PROFILE="maccheck-notary"
```

## GitHub Release

```bash
gh release create v1.3 ~/Desktop/MacCheck-1.3.dmg \
  --repo Davina-01/MacCheck \
  --title "MacCheck 1.3" \
  --notes "三语界面（中/英/法）、多国键盘布局、通用二进制，并修复原项目 issue #1–#5。"
```

## 发布后检查

- Release 页面能看到 DMG 附件
- 下载 DMG 后 `hdiutil verify` 通过
- App 可以启动并完成首页扫描
- README 中的安装和使用说明仍然准确

## 用户安装疑难排查

如果用户首次打开 ad-hoc 或未公证版本时被 macOS Gatekeeper 拦截，优先建议右键点击 `MacCheck.app`，选择“打开”。

如需在系统设置中显示“任何来源”选项，可在终端执行：

```bash
sudo spctl --master-disable
```

如果提示 App“已损坏，无法打开”，可在确认 App 来源可信、且 App 已放入 `/Applications` 后执行：

```bash
sudo xattr -rd com.apple.quarantine /Applications/MacCheck.app
```
