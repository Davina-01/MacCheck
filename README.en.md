[Français](README.md) · **English** · [简体中文](README.zh-CN.md)

# MacCheck

> [!WARNING]
> **Work in progress: this version still has many bugs and is being debugged.** Some features may not work or may crash the app. Please report any problem in the [issues](../../issues).

> [!NOTE]
> **About this version.** This is a modified fork of the open-source project **[andyhuo520/MacCheck](https://github.com/andyhuo520/MacCheck)** by andyhuo520. It was adapted with the help of AI to add a **three-language interface (English / Français / 简体中文)** and **support for many national keyboard layouts**, plus fixes for several issues reported upstream. Because these changes were AI-assisted and have not yet been tested on every Mac model, **this version may contain bugs or mistakes. Feedback is very welcome**: please [open an issue](../../issues) describing your Mac model, macOS version and what you saw.
>
> This fork is maintained by **[INNOMICRO](https://innomicro.fr)** (a Paris-based wholesaler specializing in PC screens and Apple parts). Visit **[innomicro.fr](https://innomicro.fr)**.
>
> Open-source links:
> - Original project: [github.com/andyhuo520/MacCheck](https://github.com/andyhuo520/MacCheck)
> - This modified version: [github.com/Davina-01/MacCheck](https://github.com/Davina-01/MacCheck)
>
> Results are indicative and are not a warranty: see the **Disclaimer** at the bottom of this page.
>
> Thanks to andyhuo520 for open-sourcing the original project. The upstream repository does not include a license file; if you plan to redistribute this app commercially, please contact the original author first.

MacCheck is a local macOS inspection tool for buying and selling used Macs, in-store checks and self-diagnosis. It automatically reads hardware specs, battery, storage, network, security and port information, and provides interactive tests for the keyboard, display, audio, microphone, camera, trackpad, disk speed and more. Results can be exported as a PDF or PNG report.

> Privacy: MacCheck runs entirely on your Mac and never uploads serial numbers, results or reports. Screenshots in this README come from real devices (taken with the original Chinese interface) with serial numbers masked.

![MacCheck overview](docs/assets/overview-demo.png)

## What's new in this fork (v1.3.0)

**Interface in three languages.** English, Français and 简体中文, switchable at any time in **Settings → Interface language**, or following the macOS language automatically. Reports, check results, permission prompts and device names (e.g. "MacBook Pro (14 pouces, 2021)") are all translated.

**Keyboard test for every country's keyboard.**
- Detects the physical keyboard type automatically: **ANSI** (US), **ISO** (French, German, British, Spanish, Italian, Nordic…) or **JIS** (Japanese), with the correct shape for the Return key, the extra ISO key and the JIS keys.
- Keycap labels are read from the keyboard layouts installed in macOS, so **AZERTY, QWERTZ, Spanish, Swiss, Belgian, Nordic, Russian** and every other layout shows the right characters. You can pick any layout manually.
- Click a keycap to confirm it manually (for keys the system intercepts) or to mark it as not present on this Mac.

**Fixes for issues reported upstream.**

| Upstream issue | Fix |
| --- | --- |
| [#1](https://github.com/andyhuo520/MacCheck/issues/1) Won't open on Intel Macs | The release build is now a **universal binary** (Apple Silicon + Intel), and the release script refuses to package if a slice is missing. Temperature and fan readings now also work on Intel Macs. |
| [#2](https://github.com/andyhuo520/MacCheck/issues/2) Stronger MDM detection | Detects the common **MDM bypass**: Apple's enrollment servers (`deviceenrollment.apple.com`, `mdmenrollment.apple.com`, `iprofiles.apple.com`…) redirected to `0.0.0.0` in `/etc/hosts`, plus the forged marker files that bypass scripts leave behind. |
| [#3](https://github.com/andyhuo520/MacCheck/issues/3) English language | English interface and README (plus French). |
| [#4](https://github.com/andyhuo520/MacCheck/issues/4) Disk read/write totals via `smartctl` | New "Disk lifetime & data written" check: total data written/read, life used, power-on hours, unsafe shutdowns and media errors. Requires [smartmontools](https://www.smartmontools.org) (`brew install smartmontools`); without it the check explains how to install it. |
| [#5](https://github.com/andyhuo520/MacCheck/issues/5) F11 / false stuck keys, Thunderbolt SSD not detected, top of screen not tested | ⌘, caps lock and other modifiers no longer show as falsely "stuck"; F1–F12 media functions (brightness, volume…) are mapped back to their F-keys. The port test now detects **Thunderbolt / USB4 devices and external disks**. The keyboard and screen tests now open in a true **full-screen window that covers the whole display**, including the menu bar strip and the area beside the notch; press **H** to hide the screen-test panel. |

Also fixed: the battery cycle-count tamper check never appeared in the report.

## Features

- Model, chip, memory, macOS version, serial number and model year
- Battery cycle count and health, storage, network, Bluetooth and ports
- High-risk checks for used-Mac deals: MDM (including bypass detection), Apple ID / Activation Lock, security chip
- Interactive tests: keyboard (key by key), display (solid colors / gray gradient / checkerboard), speakers, microphone, camera, Touch ID, trackpad
- Disk speed test, CPU stress test with temperatures and fan speeds, port-by-port test
- Local AI model suitability estimate based on memory
- One-click PDF / PNG report export and saved history for later comparison
- Light, dark or system appearance

![MacCheck hardware specs](docs/assets/hardware-specs-real.png)

## Requirements

- macOS 14.0 or later
- Apple Silicon or Intel Mac
- Xcode 16 or later to build from source
- Optional: [`xcodegen`](https://github.com/yonaskolb/XcodeGen) to regenerate the Xcode project from `project.yml`
- Optional: [`smartmontools`](https://www.smartmontools.org) for disk lifetime data (`brew install smartmontools`)

## Installation

1. Download `MacCheck-IM-x.y.z.dmg` from the **[Releases](https://github.com/Davina-01/MacCheck/releases/latest)** page. The same file works on Apple Silicon and Intel Macs.
2. Open the DMG and drag `MacCheck.app` into `Applications`.
3. Permissions (camera, microphone, Bluetooth) are requested when needed.

The DMG is built automatically by GitHub Actions and ad-hoc signed (no Developer ID signature or Apple notarization yet), so macOS shows a warning on first launch.

If macOS says the app "can't be opened because the developer cannot be verified", right-click `MacCheck.app` and choose **Open**. If it says the app "is damaged", the download quarantine flag is usually the cause; after moving the app to `/Applications`, run:

```bash
sudo xattr -rd com.apple.quarantine /Applications/MacCheck.app
```

## How to use

1. Open MacCheck and wait for the automatic system scan on the Overview page.
2. Read the **Overview** and **Critical issues** sections first; red items need attention.
3. Go through each test under **Hardware tests** (keyboard, screen, audio, camera…).
4. Click **Save to history** to keep a snapshot of this inspection.
5. Click **Export report** and choose PNG or PDF.

![MacCheck security checks](docs/assets/security-real.png)

![MacCheck keyboard test](docs/assets/testing-demo.png)

## Build from source

```bash
git clone https://github.com/Davina-01/MacCheck.git
cd MacCheck

# Optional: only if you changed project.yml
brew install xcodegen
xcodegen generate

# Universal build (Apple Silicon + Intel)
xcodebuild \
  -project MacCheck.xcodeproj \
  -scheme MacCheck \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build_release \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO

# Check that both architectures are present
lipo -archs build_release/Build/Products/Release/MacCheck.app/Contents/MacOS/MacCheck
```

The app is built at `build_release/Build/Products/Release/MacCheck.app`.

## Packaging a DMG

```bash
./scripts/build_and_notarize.sh
```

The script regenerates the project if `xcodegen` is installed, builds a universal Release binary and verifies both architectures, signs and notarizes it if a Developer ID certificate is available (otherwise it produces an ad-hoc DMG for local use), and writes `dist/MacCheck-IM-1.3.0.dmg`.

For public distribution, configure:

```bash
export MACCHECK_SIGN_ID="Developer ID Application: Your Name (TEAMID)"
export MACCHECK_NOTARY_PROFILE="maccheck-notary"
```

and store notarization credentials with `xcrun notarytool store-credentials`.

## Version numbers

- App version (shown by macOS): numeric `x.y.z` only, as Apple requires. This fork continues the original numbering from 1.3.0.
- InnoMicro release: Git tag `vX.Y.Z-im`, file `MacCheck-IM-X.Y.Z.dmg`, release "MacCheck IM X.Y.Z".
- Rule: bug fix → `1.3.1`, new feature → `1.4.0`, breaking change → `2.0.0`.

## Translations

The source language is Simplified Chinese: each interface string is written in Chinese in the code and looked up with `L("…")`. Translations live in:

```text
Sources/Resources/en.lproj/Localizable.strings
Sources/Resources/fr.lproj/Localizable.strings
```

Placeholders such as `{0}` and `{1}` must be kept in translations (their order can change). Corrections are welcome via pull request.

## Project structure

```text
Sources/
  App/                 App entry point and Info.plist
  Core/                Hardware probing, reports, history, system services, localization
  Checks/              Keyboard, screen, audio, camera and other interactive tests
  UI/                  SwiftUI views, design system and navigation
  Resources/           Translations (en, fr) and localized permission prompts
scripts/
  build_and_notarize.sh
docs/
  TESTING.md
  RELEASE.md
  assets/
```

## Disclaimer and limitation of liability

- **Provided "as is".** MacCheck is distributed free of charge without any warranty, express or implied, including as to the accuracy of results, freedom from bugs, or fitness for a particular purpose. This modified version is still being debugged.
- **Results are indicative only.** Results do not replace an inspection by a professional or Apple's official checks (warranty coverage, Activation Lock, repairs). Some problems may go undetected, for example MDM enrollment bypassed by an unknown method, non-genuine parts or falsified data. A "normal" result does not guarantee the actual condition of the device.
- **Not a certification.** Reports generated by MacCheck are not a certificate, appraisal or warranty issued by INNOMICRO or by the authors.
- **Hardware tests.** Some tests put load on the machine: the disk test writes and then deletes a 1 GB temporary file, and the stress test heats the processor. Back up your data before use; you run these tests at your own risk.
- **Liability.** To the fullest extent permitted by applicable law, neither the original author, the contributors nor INNOMICRO shall be liable for any direct or indirect damage arising from the use of this software, including purchase or sale decisions, data loss or damage to equipment. This clause does not limit any mandatory rights you have as a consumer.
- **Original project.** The original author (andyhuo520) is not responsible for the changes made in this version.
- **Trademarks.** This project is not affiliated with, endorsed or sponsored by Apple Inc. Apple, Mac, MacBook, macOS, Touch ID and Thunderbolt are trademarks of Apple Inc. or their respective owners.
- **Data.** The app runs entirely locally; no data is sent to INNOMICRO or any third party.

## Credits

- Original app: **[andyhuo520/MacCheck](https://github.com/andyhuo520/MacCheck)** by andyhuo520
- Multilingual and multi-layout version: **[Davina-01/MacCheck](https://github.com/Davina-01/MacCheck)**, maintained by **[INNOMICRO](https://innomicro.fr)** (Paris-based wholesaler of PC screens and Apple parts), with AI assistance
