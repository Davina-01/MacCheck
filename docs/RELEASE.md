# 发布说明

## 版本号

- App 版本号只在 `Sources/App/Info.plist` 的 `CFBundleShortVersionString` 维护，必须是纯数字 `x.y.z`（Apple 要求，否则无法公证、版本比较也会出错）；`project.yml` 同步修改。
- `CFBundleVersion` 是构建号，每次发布 +1。
- InnoMicro 版本标识只放在 App 之外：Git 标签 `vX.Y.Z-im`、安装包 `MacCheck-IM-X.Y.Z.dmg`、Release 标题 `MacCheck IM X.Y.Z`。
- 规则（语义化版本）：修 bug → 第三位 +1；加功能 → 第二位 +1；重大不兼容改动 → 第一位 +1。

## 自动发布（推荐）

1. 修改 `Info.plist` 与 `project.yml` 中的版本号并合并到 `main`。
2. 打标签并推送：

```bash
git tag v1.3.1-im
git push origin v1.3.1-im
```

3. GitHub Actions（`.github/workflows/release.yml`）会在 macOS 机器上构建通用二进制、校验 arm64 + x86_64、打包 `MacCheck-IM-1.3.1.dmg`，并自动创建 Release 上传安装包。标签版本号与 `Info.plist` 不一致时构建会失败。

每个 Pull Request 也会自动构建一次，可在 Actions 页面下载 DMG 测试。

## 本地打包

```bash
./scripts/build_and_notarize.sh
```

输出文件：

```text
dist/MacCheck-IM-<版本号>.dmg
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
# 通常由 GitHub Actions 自动完成；手动发布时：
gh release create v1.3.0-im dist/MacCheck-IM-1.3.0.dmg \
  --repo Davina-01/MacCheck \
  --title "MacCheck IM 1.3.0" \
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
