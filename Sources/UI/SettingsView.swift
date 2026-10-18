import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L("跟随系统")
        case .light: return L("浅色")
        case .dark: return L("深色")
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct SettingsView: View {
    @AppStorage("appTheme") private var themeRawValue = AppTheme.system.rawValue
    @AppStorage(AppLanguage.storageKey) private var languageRawValue = AppLanguage.system.rawValue

    private var selectedTheme: Binding<AppTheme> {
        Binding {
            AppTheme(rawValue: themeRawValue) ?? .system
        } set: { newValue in
            themeRawValue = newValue.rawValue
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                CheckHeader(
                    icon: "gearshape.fill",
                    title: L("设置"),
                    subtitle: L("调整 MacCheck 的显示偏好。设置会保存在本机，下次打开自动沿用。")
                )

                Card {
                    HStack(alignment: .top, spacing: DS.Spacing.md) {
                        Image(systemName: "globe")
                            .font(.system(size: 20))
                            .foregroundStyle(.tint)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            // 标题同时写出三种语言，误切到看不懂的语言时也能找回来
                            Text(L("界面语言") + " · Language · Langue").font(DS.Font.bodyEmphasis)
                            Text(L("切换后界面立即更新，并自动重新扫描一次，让检测结果也换成新语言。已完成的交互测试结果保留原语言。"))
                                .font(DS.Font.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Picker(L("界面语言"), selection: $languageRawValue) {
                                ForEach(AppLanguage.allCases) { language in
                                    Text(language.displayName).tag(language.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .padding(.top, DS.Spacing.xs)
                        }
                    }
                }

                Card {
                    HStack(alignment: .top, spacing: DS.Spacing.md) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.tint)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text(L("外观主题")).font(DS.Font.bodyEmphasis)
                            Text(L("选择跟随系统，或固定使用浅色 / 深色模式。"))
                                .font(DS.Font.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Picker(L("外观主题"), selection: selectedTheme) {
                                ForEach(AppTheme.allCases) { theme in
                                    Label(theme.title, systemImage: theme.icon)
                                        .tag(theme)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .padding(.top, DS.Spacing.xs)
                        }
                    }
                }

                aboutCard
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle(L("设置"))
    }

    // MARK: - 关于

    private static let originalRepo = "https://github.com/andyhuo520/MacCheck"
    private static let forkRepo = "https://github.com/Davina-01/MacCheck"
    /// 把含 Markdown 链接的文案转成可点击的富文本；解析失败时按纯文本显示。
    private func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }

    private var aboutCard: some View {
        Card {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.tint)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(L("关于")).font(DS.Font.bodyEmphasis)

                    // andyhuo520 与 Davina-01 在文中是指向各自 GitHub 主页的超链接（Markdown 链接，译文中同样保留）
                    Text(markdown(L("本软件基于 [andyhuo520](https://github.com/andyhuo520) 在 GitHub 上的开源项目 MacCheck，由 [Davina-01](https://github.com/Davina-01) 在 AI 协助下修改，新增中 / 英 / 法三种界面语言、多国键盘布局支持，并修复了若干问题。")))
                        .font(DS.Font.body)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        aboutLink(L("原版开源项目"), Self.originalRepo, icon: "chevron.left.forwardslash.chevron.right")
                        aboutLink(L("本修改版（开源）"), Self.forkRepo, icon: "arrow.triangle.branch")
                    }
                    .padding(.top, DS.Spacing.xs)

                    Text(markdown(L("本版本仍在调试中，可能存在 bug，欢迎在 GitHub 反馈问题。感谢 [andyhuo520](https://github.com/andyhuo520) 开源原版项目。")))
                        .font(DS.Font.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, DS.Spacing.xs)

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(L("免责声明")).font(DS.Font.caption.weight(.semibold))
                        Text(L("本软件按现状免费提供，不提供任何担保。检测结果仅供参考，不能替代专业检测或 Apple 官方查询，部分问题可能无法被检测到；生成的报告不构成 Davina-01 或作者出具的证书或质保。在法律允许的最大范围内，原作者、贡献者及 Davina-01 不对因使用本软件产生的任何损失（包括买卖决定、数据丢失或设备损坏）承担责任，但不影响消费者依法享有的强制性权利。硬盘测速与性能压测会对机器施加负载，使用前请备份数据。本项目与 Apple Inc. 无关联，Apple、Mac、macOS 等为 Apple Inc. 的商标。"))
                            .font(DS.Font.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, DS.Spacing.sm)
                }
            }
        }
    }

    private func aboutLink(_ title: String, _ url: String, icon: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 16)
            Text(title).font(DS.Font.body).foregroundStyle(.secondary)
            if let link = URL(string: url) {
                Link(url.replacingOccurrences(of: "https://", with: ""), destination: link)
                    .font(DS.Font.body)
            }
        }
    }
}
