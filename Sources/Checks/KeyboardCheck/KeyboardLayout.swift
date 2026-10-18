import Foundation
import Carbon

// MARK: - 物理键盘形态

/// 键盘的物理形态。macOS 的虚拟 keyCode 是"按位置"定义的，同一位置的键在任何语言布局下 keyCode 都相同，
/// 所以只需区分三种物理形态，每个键上印的字符再从系统键盘布局里读取（见 `KeyLegendProvider`）。
enum PhysicalKeyboardType: String, CaseIterable, Identifiable, Sendable {
    case ansi   // 美式：横长回车，左 Shift 宽（美国、中国大陆、台湾、韩国等）
    case iso    // 欧式：L 形竖回车，左 Shift 旁多一个键，数字 1 左边是 §（法、德、英、西、意、北欧等）
    case jis    // 日式：多出 ¥、_、英数、かな 键

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ansi: return L("ANSI（美式）")
        case .iso: return L("ISO（欧式）")
        case .jis: return L("JIS（日式）")
        }
    }

    /// 读取当前机器内建键盘的物理形态（Carbon `KBGetLayoutType`）。
    static func detected() -> PhysicalKeyboardType {
        let type = KBGetLayoutType(Int16(LMGetKbdType()))
        if type == PhysicalKeyboardLayoutType(kKeyboardISO) { return .iso }
        if type == PhysicalKeyboardLayoutType(kKeyboardJIS) { return .jis }
        return .ansi
    }
}

// MARK: - 键位定义

/// 单个物理按键。
struct KeyDef: Identifiable, Hashable, Sendable {
    let id: String            // 位置唯一标识（ISO 竖回车在两行各画一段，keyCode 相同但 id 不同）
    let keyCode: UInt16
    let symbol: String?       // 功能键固定显示的符号；nil 表示字符键，显示内容取自系统键盘布局
    let width: CGFloat        // 相对宽度，1.0 = 一个标准键位

    init(_ keyCode: UInt16, _ symbol: String? = nil, width: CGFloat = 1.0, part: String = "") {
        self.id = "\(keyCode)\(part)"
        self.keyCode = keyCode
        self.symbol = symbol
        self.width = width
    }
}

/// 键盘上的一个"格子"：通常放一个键；方向键 ↑↓ 上下堆叠成半高的两个键放在同一格。
struct KeySlot: Identifiable, Hashable, Sendable {
    let keys: [KeyDef]
    var id: String { keys.map(\.id).joined(separator: "+") }
    var width: CGFloat { keys.first?.width ?? 1 }
    var isStacked: Bool { keys.count > 1 }

    static func key(_ k: KeyDef) -> KeySlot { KeySlot(keys: [k]) }
}

/// Mac 内建键盘几何定义。keyCode 参考 Carbon HIToolbox `Events.h`（kVK_*）。
/// 每行总宽度都约为 14.6 个键位，保证三种形态画出来左右对齐。
enum KeyboardGeometry {

    // 修饰键与功能键用通用符号，不随语言变化
    private static let esc = KeyDef(53, "esc", width: 1.4)
    private static let functionRow: [KeySlot] = [.key(esc)] + [
        KeyDef(122, "F1", width: 1.1), KeyDef(120, "F2", width: 1.1), KeyDef(99, "F3", width: 1.1),
        KeyDef(118, "F4", width: 1.1), KeyDef(96, "F5", width: 1.1), KeyDef(97, "F6", width: 1.1),
        KeyDef(98, "F7", width: 1.1), KeyDef(100, "F8", width: 1.1), KeyDef(101, "F9", width: 1.1),
        KeyDef(109, "F10", width: 1.1), KeyDef(103, "F11", width: 1.1), KeyDef(111, "F12", width: 1.1),
    ].map(KeySlot.key)

    private static func chars(_ codes: [UInt16]) -> [KeySlot] {
        codes.map { .key(KeyDef($0)) }
    }

    /// 数字行 1…0、-、= 的 keyCode（三种形态相同，JIS 的 = 位置印的是 ^）。
    private static let digitCodes: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24]
    /// Q…P、[、]
    private static let topLetterCodes: [UInt16] = [12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30]
    /// A…L、;、'
    private static let homeLetterCodes: [UInt16] = [0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39]
    /// Z…/、
    private static let bottomLetterCodes: [UInt16] = [6, 7, 8, 9, 11, 45, 46, 43, 47, 44]

    /// 方向键倒 T 形：← [↑ 叠 ↓] →
    private static let arrows: [KeySlot] = [
        .key(KeyDef(123, "←")),
        KeySlot(keys: [KeyDef(126, "↑"), KeyDef(125, "↓")]),
        .key(KeyDef(124, "→")),
    ]

    private static let ansiISOBottomRow: [KeySlot] = [
        .key(KeyDef(63, "fn 🌐")),
        .key(KeyDef(59, "⌃")),
        .key(KeyDef(58, "⌥")),
        .key(KeyDef(55, "⌘", width: 1.3)),
        .key(KeyDef(49, "", width: 5.0)),
        .key(KeyDef(54, "⌘", width: 1.3)),
        .key(KeyDef(61, "⌥")),
    ] + arrows

    static func rows(for type: PhysicalKeyboardType) -> [[KeySlot]] {
        switch type {
        case .ansi:
            return [
                functionRow,
                chars([50] + digitCodes) + [.key(KeyDef(51, "⌫", width: 1.6))],
                [.key(KeyDef(48, "⇥", width: 1.6))] + chars(topLetterCodes) + chars([42]),
                [.key(KeyDef(57, "⇪", width: 1.8))] + chars(homeLetterCodes) + [.key(KeyDef(36, "⏎", width: 1.8))],
                [.key(KeyDef(56, "⇧", width: 2.3))] + chars(bottomLetterCodes) + [.key(KeyDef(60, "⇧", width: 2.3))],
                ansiISOBottomRow,
            ]

        case .iso:
            // ISO：数字 1 左边是 kVK_ISO_Section(10)；左 Shift 右边的额外键是 50；
            // ANSI 的 \ 键(42) 移到主行末尾；回车是跨两行的竖键，两段共用 keyCode 36。
            return [
                functionRow,
                chars([10] + digitCodes) + [.key(KeyDef(51, "⌫", width: 1.6))],
                [.key(KeyDef(48, "⇥", width: 1.6))] + chars(topLetterCodes) + [.key(KeyDef(36, "⏎", width: 1.0, part: "-top"))],
                [.key(KeyDef(57, "⇪", width: 1.8))] + chars(homeLetterCodes + [42]) + [.key(KeyDef(36, "", width: 0.8, part: "-bottom"))],
                [.key(KeyDef(56, "⇧", width: 1.3))] + chars([50] + bottomLetterCodes) + [.key(KeyDef(60, "⇧", width: 2.3))],
                ansiISOBottomRow,
            ]

        case .jis:
            // JIS：= 位置为 ^，其后多 ¥(93)；A 左边是 control；/ 右边多 _(94)；
            // 空格两侧是 英数(102) 与 かな(104)，caps lock 位于左下角。
            return [
                functionRow,
                chars(digitCodes + [93]) + [.key(KeyDef(51, "⌫", width: 1.6))],
                [.key(KeyDef(48, "⇥", width: 1.6))] + chars(topLetterCodes) + [.key(KeyDef(36, "⏎", width: 1.0, part: "-top"))],
                [.key(KeyDef(59, "⌃", width: 1.8))] + chars(homeLetterCodes + [42]) + [.key(KeyDef(36, "", width: 0.8, part: "-bottom"))],
                [.key(KeyDef(56, "⇧", width: 2.3))] + chars(bottomLetterCodes + [94]) + [.key(KeyDef(60, "⇧", width: 1.3))],
                [
                    .key(KeyDef(63, "fn 🌐")),
                    .key(KeyDef(57, "⇪")),
                    .key(KeyDef(58, "⌥")),
                    .key(KeyDef(55, "⌘", width: 1.2)),
                    .key(KeyDef(102, "英数", width: 1.2)),
                    .key(KeyDef(49, "", width: 3.6)),
                    .key(KeyDef(104, "かな", width: 1.2)),
                    .key(KeyDef(54, "⌘", width: 1.2)),
                ] + arrows,
            ]
        }
    }

    /// 某形态下需要测试的全部 keyCode（去重：ISO/JIS 回车画了两段只算一个键）。
    static func keyCodes(for type: PhysicalKeyboardType) -> Set<UInt16> {
        Set(rows(for: type).flatMap { $0.flatMap(\.keys) }.map(\.keyCode))
    }

    /// 显示用名称（结果报告里列出卡键 / 未测键时用）。
    static func displayName(for keyCode: UInt16, type: PhysicalKeyboardType, legends: [UInt16: String]) -> String {
        if let key = rows(for: type).flatMap({ $0.flatMap(\.keys) }).first(where: { $0.keyCode == keyCode }) {
            if keyCode == 49 { return L("空格") }
            if let symbol = key.symbol, !symbol.isEmpty { return symbol }
            if keyCode == 36 { return "⏎" }
        }
        return legends[keyCode] ?? "#\(keyCode)"
    }
}

// MARK: - 按键字符（各国键盘布局）

/// 系统里安装的一种键盘布局（U.S.、French、German、Spanish、Swiss French、Russian…）。
struct KeyboardInputLayout: Identifiable, Hashable, Sendable {
    let id: String     // TIS 输入源 ID，如 "com.apple.keylayout.French"
    let name: String   // 系统本地化名称
}

/// 通过 Text Input Sources 读取 macOS 自带的全部键盘布局，并用 `UCKeyTranslate`
/// 算出每个 keyCode 在该布局下印的字符。这样 AZERTY、QWERTZ、西班牙语、北欧、俄语等
/// 所有国家/地区的键盘都能显示正确的键帽字符，无需手工维护对照表。
@MainActor
enum KeyLegendProvider {

    private static var legendCache: [String: [UInt16: String]] = [:]

    private static func property<T>(_ source: TISInputSource, _ key: CFString) -> T? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? T
    }

    private static func allLayoutSources() -> [TISInputSource] {
        let filter = [kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        return list
    }

    /// 系统中可用的全部键盘布局，按名称排序。
    static func installedLayouts() -> [KeyboardInputLayout] {
        var seen = Set<String>()
        var result: [KeyboardInputLayout] = []
        for source in allLayoutSources() {
            guard let id: String = property(source, kTISPropertyInputSourceID), !seen.contains(id) else { continue }
            let name: String = property(source, kTISPropertyLocalizedName) ?? id
            seen.insert(id)
            result.append(KeyboardInputLayout(id: id, name: name))
        }
        return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// 当前正在使用的键盘布局（输入法激活时取其底层布局）。
    static func currentLayoutID() -> String {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let id: String = property(source, kTISPropertyInputSourceID) else {
            return "com.apple.keylayout.US"
        }
        return id
    }

    /// 指定布局下每个 keyCode 对应的键帽字符（字母转为大写，与实体键帽一致）。
    static func legends(for layoutID: String) -> [UInt16: String] {
        if let cached = legendCache[layoutID] { return cached }

        let source = allLayoutSources().first { (property($0, kTISPropertyInputSourceID) as String?) == layoutID }
            ?? TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
        guard let source, let layoutData: CFData = property(source, kTISPropertyUnicodeKeyLayoutData) else {
            return [:]
        }

        let data = layoutData as Data
        let keyboardType = UInt32(LMGetKbdType())
        var legends: [UInt16: String] = [:]

        data.withUnsafeBytes { raw in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return }
            for keyCode in UInt16(0)...UInt16(127) {
                var deadKeyState: UInt32 = 0
                var length = 0
                var chars = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(
                    layout, keyCode, UInt16(kUCKeyActionDisplay), 0, keyboardType,
                    OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeyState,
                    chars.count, &length, &chars
                )
                guard status == noErr, length > 0 else { continue }
                let text = String(utf16CodeUnits: chars, count: length)
                // 过滤控制字符（回车、退格等功能键另有固定符号）
                guard let scalar = text.unicodeScalars.first, scalar.value >= 0x20, scalar.value != 0x7F else { continue }
                legends[keyCode] = text.uppercased()
            }
        }

        legendCache[layoutID] = legends
        return legends
    }
}
