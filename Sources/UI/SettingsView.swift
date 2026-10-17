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
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle(L("设置"))
    }
}
