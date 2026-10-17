import SwiftUI

@main
struct MacCheckApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 720, minHeight: 520)
        }
        .windowResizability(.automatic)
        .defaultSize(width: 1040, height: 720)
        .commands { LanguageCommands() }
    }
}

/// 菜单栏里的「语言」菜单，方便找到界面语言切换。
struct LanguageCommands: Commands {
    @AppStorage(AppLanguage.storageKey) private var languageRawValue = AppLanguage.system.rawValue

    var body: some Commands {
        CommandMenu(L("语言")) {
            Picker(selection: $languageRawValue) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language.rawValue)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.inline)
        }
    }
}
