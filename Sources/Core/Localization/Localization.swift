import Foundation

/// App 界面语言。`.system` 跟随 macOS 首选语言，其余固定为对应语言。
/// 选择保存在 UserDefaults（key: `appLanguage`），切换后立即生效，无需重启。
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case zhHans = "zh-Hans"
    case en
    case fr

    var id: String { rawValue }

    static let storageKey = "appLanguage"

    /// 语言选择器里显示的名字：每种语言用它自己的写法，方便看不懂当前界面语言的人也能找到自己的语言。
    var displayName: String {
        switch self {
        case .system: return L("跟随系统")
        case .zhHans: return "简体中文"
        case .en: return "English"
        case .fr: return "Français"
        }
    }

    /// 当前用户选择（未设置时为 `.system`）。
    static var selected: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }

    /// 实际生效的语言：`.system` 时按 macOS 首选语言顺序匹配，匹配不到回退英文。
    static var effective: AppLanguage {
        let choice = selected
        if choice != .system { return choice }
        for code in Locale.preferredLanguages {
            let lower = code.lowercased()
            if lower.hasPrefix("zh") { return .zhHans }
            if lower.hasPrefix("fr") { return .fr }
            if lower.hasPrefix("en") { return .en }
        }
        return .en
    }

    /// 与当前语言对应的 Locale，用于日期格式等。
    var locale: Locale {
        switch self {
        case .system: return AppLanguage.effective.locale
        case .zhHans: return Locale(identifier: "zh-Hans")
        case .en: return Locale(identifier: "en")
        case .fr: return Locale(identifier: "fr")
        }
    }
}

/// 翻译表缓存。源语言（键）就是原有的简体中文文案，所以中文不需要翻译文件；
/// 英文、法文分别读取 `en.lproj` / `fr.lproj` 下的 `Localizable.strings`。
/// 可在任意线程调用（后台检测任务里也会生成文案），内部用锁保护。
private final class LocalizationTable: @unchecked Sendable {
    static let shared = LocalizationTable()

    private let lock = NSLock()
    private var bundles: [String: Bundle] = [:]

    func lookup(_ key: String) -> String {
        let language = AppLanguage.effective
        guard language != .zhHans, language != .system else { return key }
        guard let bundle = bundle(for: language.rawValue) else { return key }
        // value 传 key：缺失的条目回退显示中文原文，而不是显示空白。
        return bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    private func bundle(for code: String) -> Bundle? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = bundles[code] { return cached }
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return nil }
        bundles[code] = bundle
        return bundle
    }
}

/// 取当前语言的文案。`key` 为简体中文原文。
///
/// 带参数时，在原文里用 `{0}`、`{1}`… 作为占位符，按顺序替换为 `args`。
/// 用编号占位符而不是 `%@`，是为了让译文可以自由调整参数顺序（法语语序常与中文不同）。
///
///     L("已测 {0} / {1} 个按键", tested, total)
func L(_ key: String, _ args: Any...) -> String {
    var text = LocalizationTable.shared.lookup(key)
    for (index, arg) in args.enumerated() {
        text = text.replacingOccurrences(of: "{\(index)}", with: String(describing: arg))
    }
    return text
}
