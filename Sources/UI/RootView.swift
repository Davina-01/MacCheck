import SwiftUI

struct RootView: View {
    @StateObject private var model = AppModel()
    @AppStorage("appTheme") private var themeRawValue = AppTheme.system.rawValue
    @AppStorage(AppLanguage.storageKey) private var languageRawValue = AppLanguage.system.rawValue

    private var preferredScheme: ColorScheme? {
        (AppTheme(rawValue: themeRawValue) ?? .system).colorScheme
    }

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            DetailRouter()
        }
        .disabled(model.fullscreenTest != nil)
        // 切换语言时整棵视图重建，所有 L() 文案立即换成新语言
        .id(languageRawValue)
        .environment(\.locale, AppLanguage.effective.locale)
        .environmentObject(model)
        .preferredColorScheme(preferredScheme)
        .task { await model.scanIfNeeded() }
        .onChange(of: languageRawValue) {
            // 自动检测结果里的文案是在检测时生成的，换语言后重新检测一次
            Task { await model.rescan() }
        }
        .onChange(of: model.fullscreenTest?.id) {
            if let test = model.fullscreenTest {
                FullscreenTestPresenter.shared.present(fullscreenContent(test))
            } else {
                FullscreenTestPresenter.shared.dismiss()
            }
        }
    }

    @ViewBuilder
    private func fullscreenContent(_ test: FullscreenTest) -> some View {
        switch test {
        case .keyboard:
            KeyboardCheckView { [model = self.model] result in
                model.recordTest(result)
                model.fullscreenTest = nil
            }
        case .screen:
            ScreenCheckView { [model = self.model] result in
                model.recordTest(result)
                model.fullscreenTest = nil
            }
        }
    }
}
