import SwiftUI

/// 侧边栏：概览 + 系统检测 + 硬件测试三段分组，每行显示 SF Symbol 与状态圆点。
struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(AppLanguage.storageKey) private var languageRawValue = AppLanguage.system.rawValue

    var body: some View {
        List(selection: $model.selection) {
            row(.overview)
            row(.history)
            row(.settings)

            Section(L("系统检测")) {
                ForEach(SidebarItem.autoCategories) { row($0) }
                row(.aiModels)
            }

            Section(L("硬件测试")) {
                ForEach(SidebarItem.interactiveTests) { row($0) }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        .safeAreaInset(edge: .bottom) { rescanBar }
    }

    private func row(_ item: SidebarItem) -> some View {
        Label {
            HStack {
                Text(item.title)
                Spacer()
                if let status = model.status(for: item) {
                    StatusDot(status: status)
                } else if item.isInteractive {
                    Image(systemName: "circle.dashed")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
        } icon: {
            Image(systemName: item.icon)
        }
        .tag(item)
    }

    /// 常驻的语言切换按钮：任何页面都能一键切换，不必先进入设置。
    private var languageMenu: some View {
        Menu {
            Picker(selection: $languageRawValue) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language.rawValue)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.inline)
        } label: {
            Label(AppLanguage.selected == .system
                    ? "\(AppLanguage.system.displayName) · \(AppLanguage.effective.displayName)"
                    : AppLanguage.selected.displayName,
                  systemImage: "globe")
                .font(DS.Font.caption)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(L("界面语言") + " · Language · Langue")
    }

    private var rescanBar: some View {
        VStack(spacing: 0) {
            DS.Divider()
            HStack {
                languageMenu
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.sm)
            HStack(spacing: DS.Spacing.sm) {
                if model.isScanning {
                    ProgressView().controlSize(.small)
                    Text(L("正在扫描…")).font(DS.Font.caption).foregroundStyle(.secondary)
                } else {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green).font(.system(size: 12))
                    Text(L("已完成系统扫描")).font(DS.Font.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await model.rescan() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(model.isScanning)
                .help(L("重新扫描"))
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
    }
}
