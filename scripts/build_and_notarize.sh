#!/bin/bash
# MacCheck 发布打包脚本：Release 构建 → Developer ID 签名 → 打 DMG → 公证 → 装订。
#
# 前置条件（一次性配置）：
#   1. 一个付费 Apple Developer 账号（$99/年）。
#   2. 在钥匙串里安装「Developer ID Application」证书
#      （Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application）。
#   3. 用 App 专用密码创建 notarytool 凭证配置（只需做一次）：
#        xcrun notarytool store-credentials "maccheck-notary" \
#          --apple-id "你的AppleID邮箱" \
#          --team-id "你的TeamID(10位)" \
#          --password "App专用密码(appleid.apple.com生成)"
#
# 用法：  ./scripts/build_and_notarize.sh        （GitHub Actions 推送 v*-im 标签时也会自动调用）
# 未配置签名时，脚本会跳过签名/公证，只产出可本地运行的 ad-hoc DMG。
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT="MacCheck.xcodeproj"
SCHEME="MacCheck"
APP_NAME="MacCheck"
# 版本号只在 Sources/App/Info.plist 维护一处（纯数字 x.y.z，macOS 要求）
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Sources/App/Info.plist)
BUILD_DIR="build_release"
# innomicro.fr 版本的安装包统一命名为 MacCheck-IM-x.y.z.dmg，输出到 dist/（可用 MACCHECK_OUTPUT_DIR 覆盖）
OUTPUT_DIR="${MACCHECK_OUTPUT_DIR:-dist}"
mkdir -p "$OUTPUT_DIR"
DMG_OUT="$OUTPUT_DIR/${APP_NAME}-IM-${VERSION}.dmg"

# —— 按需修改：你的 Developer ID 与 notarytool 凭证名 ——
SIGN_ID="${MACCHECK_SIGN_ID:-Developer ID Application}"   # 留空或未装证书则跳过签名
NOTARY_PROFILE="${MACCHECK_NOTARY_PROFILE:-maccheck-notary}"

echo "▸ 生成工程"
command -v xcodegen >/dev/null && xcodegen generate

echo "▸ Release 构建（通用二进制 arm64 + x86_64）"
rm -rf "$BUILD_DIR"
# generic/platform=macOS + 显式 ARCHS：无论在哪种芯片的 Mac 上打包，都同时产出 Apple Silicon 与 Intel 两个架构。
# 以前在 Apple Silicon 上打包只得到 arm64，Intel Mac 打开会提示"不支持此 Mac"（上游 issue #1）。
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$BUILD_DIR" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO | tail -1

APP="$BUILD_DIR/Build/Products/Release/${APP_NAME}.app"

echo "▸ 校验架构"
ARCHS_FOUND=$(lipo -archs "$APP/Contents/MacOS/${APP_NAME}")
echo "  包含架构：$ARCHS_FOUND"
for arch in arm64 x86_64; do
  if ! echo "$ARCHS_FOUND" | grep -qw "$arch"; then
    echo "✗ 缺少 $arch 架构，停止打包" >&2
    exit 1
  fi
done

HAS_CERT=$(security find-identity -v -p codesigning 2>/dev/null | grep -c "Developer ID Application" || true)
if [ "$HAS_CERT" -gt 0 ]; then
  echo "▸ Developer ID 签名（含 hardened runtime）"
  codesign --force --deep --options runtime --timestamp \
    --sign "$SIGN_ID" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
  SIGNED=1
else
  echo "⚠ 未找到 Developer ID 证书，跳过签名与公证，仅产出 ad-hoc DMG（可本地运行，分发给他人需右键打开）。"
  SIGNED=0
fi

echo "▸ 打 DMG"
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG_OUT"
# CI 机器上 hdiutil 偶尔报 "Resource busy"，重试几次
for attempt in 1 2 3; do
  if hdiutil create -volname "${APP_NAME} IM ${VERSION}" -srcfolder "$STAGE" -ov -format UDZO "$DMG_OUT" | tail -1; then
    break
  fi
  echo "  hdiutil 失败，第 $attempt 次重试…"
  sleep 5
done
[ -f "$DMG_OUT" ] || { echo "✗ DMG 生成失败" >&2; exit 1; }
rm -rf "$STAGE"

if [ "$SIGNED" -eq 1 ]; then
  echo "▸ 公证 DMG（提交给 Apple，通常几分钟）"
  xcrun notarytool submit "$DMG_OUT" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "▸ 装订公证票据"
  xcrun stapler staple "$DMG_OUT"
  xcrun stapler validate "$DMG_OUT"
  echo "✅ 已签名 + 公证 + 装订：$DMG_OUT （可直接分发，用户双击即开）"
else
  echo "✅ ad-hoc DMG 已生成：$DMG_OUT"
fi
