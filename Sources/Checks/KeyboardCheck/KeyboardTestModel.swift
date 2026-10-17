import AppKit
import Combine

/// 键盘测试状态机。用局部事件监听（不是全局 Accessibility 监听）——
/// 全屏测试窗口本身是 key window 时就能收到按键事件，无需辅助功能权限。
///
/// 修复记录（对应上游 issue #5「F11 识别不准、多个键误报卡键」）：
/// - 以前带 ⌘ 的事件直接放行不记录：按下 ⌘ 时被跳过、松开时却被当成"按下"，于是 ⌘ 被误判为卡键；
///   现在每个修饰键都按 modifierFlags 里的设备位判断真实的按下/松开状态。
/// - caps lock 是锁定键，系统只在切换时发一次事件，不能当成"按住"，否则 5 秒后必然误报卡键。
/// - App 失去焦点（如 ⌘Tab）时松开事件会发给别的 App，现在失焦时清空按住状态，避免误报。
/// - Apple 笔记本 F1–F12 默认是亮度/音量/调度中心等系统功能，按下时发送的不是 F 键码，
///   现在把这些系统功能事件映射回对应的 F 键；仍被系统完全拦截的键（例如部分机型的 F11 显示桌面）可点击键帽手动确认。
@MainActor
final class KeyboardTestModel: ObservableObject {

    /// 选择器里"自动"对应的取值
    static let auto = "auto"

    // 用户选择：默认"自动"，每次打开都重新检测；手动选择才会保存在本机。
    @Published var physicalSelection: String {
        didSet {
            guard oldValue != physicalSelection else { return }
            save(physicalSelection, forKey: Self.physicalKey)
            resetProgress()
        }
    }
    @Published var layoutSelection: String {
        didSet {
            guard oldValue != layoutSelection else { return }
            save(layoutSelection, forKey: Self.layoutKey)
            legends = KeyLegendProvider.legends(for: layoutID)
        }
    }

    /// 本次检测到的物理形态与当前输入布局
    let detectedPhysicalType: PhysicalKeyboardType
    let detectedLayoutID: String

    /// 实际生效的物理形态 / 键盘布局
    var physicalType: PhysicalKeyboardType {
        physicalSelection == Self.auto
            ? detectedPhysicalType
            : PhysicalKeyboardType(rawValue: physicalSelection) ?? detectedPhysicalType
    }
    var layoutID: String {
        layoutSelection == Self.auto ? detectedLayoutID : layoutSelection
    }

    func layoutName(_ id: String) -> String {
        availableLayouts.first { $0.id == id }?.name ?? id
    }

    private func save(_ value: String, forKey key: String) {
        if value == Self.auto {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(value, forKey: key)
        }
    }

    @Published private(set) var legends: [UInt16: String] = [:]
    @Published private(set) var availableLayouts: [KeyboardInputLayout] = []

    @Published private(set) var testedKeyCodes: Set<UInt16> = []    // 实际按下过的键
    @Published private(set) var manualKeyCodes: Set<UInt16> = []    // 系统拦截、由用户点击手动确认的键
    @Published private(set) var absentKeyCodes: Set<UInt16> = []    // 本机键盘上没有的键（不计入总数）
    @Published private(set) var pressedKeyCodes: Set<UInt16> = []
    @Published private(set) var stuckKeyCodes: Set<UInt16> = []

    var onRequestFinish: (() -> Void)?

    private var pressStartTimes: [UInt16: Date] = [:]
    private var monitor: Any?
    private var stuckCheckTimer: Timer?
    private var resignObserver: NSObjectProtocol?

    private static let physicalKey = "keyboardTest.physicalSelection"
    private static let layoutKey = "keyboardTest.layoutSelection"
    private static let escKeyCode: UInt16 = 53
    private static let capsLockKeyCode: UInt16 = 57
    private static let escHoldToExitSeconds: TimeInterval = 1.2
    private static let stuckThresholdSeconds: TimeInterval = 5.0

    /// 修饰键 keyCode → NSEvent.modifierFlags 中对应的设备相关位（IOKit NX_DEVICE*KEYMASK）。
    private static let modifierDeviceMasks: [UInt16: UInt] = [
        59: 0x0000_0001,  // 左 control
        62: 0x0000_2000,  // 右 control
        56: 0x0000_0002,  // 左 shift
        60: 0x0000_0004,  // 右 shift
        55: 0x0000_0008,  // 左 command
        54: 0x0000_0010,  // 右 command
        58: 0x0000_0020,  // 左 option
        61: 0x0000_0040,  // 右 option
    ]

    /// 笔记本功能行默认发送的系统功能 keyCode → 对应的 F 键 keyCode。
    private static let functionRowAliases: [UInt16: UInt16] = [
        145: 122, // 亮度降低 → F1
        144: 120, // 亮度增加 → F2
        160: 99,  // 调度中心 → F3
        131: 118, // 启动台 → F4
        177: 118, // 聚焦搜索 → F4
        176: 96,  // 听写 → F5
        178: 97,  // 勿扰模式 → F6
        179: 63,  // 地球仪键（部分外接键盘）→ fn
    ]

    /// 媒体键（NSEvent.systemDefined，subtype 8）NX_KEYTYPE → 对应的 F 键 keyCode。
    private static let mediaKeyAliases: [Int: UInt16] = [
        3: 122,   // NX_KEYTYPE_BRIGHTNESS_DOWN → F1
        2: 120,   // NX_KEYTYPE_BRIGHTNESS_UP → F2
        22: 96,   // NX_KEYTYPE_ILLUMINATION_DOWN → F5（Intel 机型键盘背光）
        21: 97,   // NX_KEYTYPE_ILLUMINATION_UP → F6
        20: 98,   // NX_KEYTYPE_REWIND → F7
        18: 98,   // NX_KEYTYPE_PREVIOUS → F7
        16: 100,  // NX_KEYTYPE_PLAY → F8
        19: 101,  // NX_KEYTYPE_FAST → F9
        17: 101,  // NX_KEYTYPE_NEXT → F9
        7: 109,   // NX_KEYTYPE_MUTE → F10
        1: 103,   // NX_KEYTYPE_SOUND_DOWN → F11
        0: 111,   // NX_KEYTYPE_SOUND_UP → F12
    ]

    init() {
        let defaults = UserDefaults.standard
        detectedPhysicalType = PhysicalKeyboardType.detected()
        detectedLayoutID = KeyLegendProvider.currentLayoutID()
        let layouts = KeyLegendProvider.installedLayouts()

        var physical = defaults.string(forKey: Self.physicalKey) ?? Self.auto
        if physical != Self.auto && PhysicalKeyboardType(rawValue: physical) == nil { physical = Self.auto }
        var layout = defaults.string(forKey: Self.layoutKey) ?? Self.auto
        // 保存的布局可能已被卸载，回到自动（init 中赋值不会触发 didSet，所以先算好再赋值）
        if layout != Self.auto && !layouts.contains(where: { $0.id == layout }) { layout = Self.auto }

        physicalSelection = physical
        layoutSelection = layout
        availableLayouts = layouts
        legends = KeyLegendProvider.legends(for: layout == Self.auto ? detectedLayoutID : layout)
    }

    // MARK: - 统计

    var rows: [[KeySlot]] { KeyboardGeometry.rows(for: physicalType) }
    var allKeyCodes: Set<UInt16> { KeyboardGeometry.keyCodes(for: physicalType) }
    var activeKeyCodes: Set<UInt16> { allKeyCodes.subtracting(absentKeyCodes) }
    var verifiedKeyCodes: Set<UInt16> { testedKeyCodes.union(manualKeyCodes).intersection(activeKeyCodes) }
    var totalKeyCount: Int { activeKeyCodes.count }
    var verifiedCount: Int { verifiedKeyCodes.count }

    var progress: Double {
        totalKeyCount == 0 ? 0 : Double(verifiedCount) / Double(totalKeyCount)
    }

    var isComplete: Bool { totalKeyCount > 0 && verifiedCount >= totalKeyCount }

    func label(for key: KeyDef) -> String {
        if let symbol = key.symbol { return symbol }
        return legends[key.keyCode] ?? ""
    }

    // MARK: - 选择

    /// 恢复为自动识别的物理形态与当前输入布局。
    func useDetectedSettings() {
        physicalSelection = Self.auto
        layoutSelection = Self.auto
    }

    func resetProgress() {
        testedKeyCodes = []
        manualKeyCodes = []
        absentKeyCodes = []
        pressedKeyCodes = []
        stuckKeyCodes = []
        pressStartTimes = [:]
    }

    /// 点击键帽：未测 → 手动确认可用 → 本机没有此键 → 未测。
    /// 已经实际按下测过的键，点击直接标记为"本机没有"（方便纠正布局差异）。
    func cycleManualState(_ keyCode: UInt16) {
        if absentKeyCodes.contains(keyCode) {
            absentKeyCodes.remove(keyCode)
            manualKeyCodes.remove(keyCode)
            testedKeyCodes.remove(keyCode)
        } else if manualKeyCodes.contains(keyCode) || testedKeyCodes.contains(keyCode) {
            manualKeyCodes.remove(keyCode)
            testedKeyCodes.remove(keyCode)
            stuckKeyCodes.remove(keyCode)
            absentKeyCodes.insert(keyCode)
        } else {
            manualKeyCodes.insert(keyCode)
        }
    }

    // MARK: - 事件监听

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged, .systemDefined]) { [weak self] event in
            guard let self else { return event }
            self.handle(event)
            // 带 ⌘ 的组合键照常放行（⌘Q 退出、⌘Tab 切换），保证全屏测试期间始终能安全退出；
            // 其余按键吞掉，避免发出提示音或误触其他控件。修饰键与媒体键事件放行，交给系统处理。
            switch event.type {
            case .flagsChanged, .systemDefined:
                return event
            default:
                return event.modifierFlags.contains(.command) ? event : nil
            }
        }
        stuckCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkForStuckKeys() }
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.releaseAllPressed() }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        stuckCheckTimer?.invalidate()
        stuckCheckTimer = nil
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
    }

    private func releaseAllPressed() {
        pressedKeyCodes.removeAll()
        pressStartTimes.removeAll()
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            let code = Self.functionRowAliases[event.keyCode] ?? event.keyCode
            keyDown(code)

        case .keyUp:
            let code = Self.functionRowAliases[event.keyCode] ?? event.keyCode
            if code == Self.escKeyCode, let start = pressStartTimes[code],
               Date().timeIntervalSince(start) >= Self.escHoldToExitSeconds {
                keyUp(code)
                onRequestFinish?()
                return
            }
            keyUp(code)

        case .flagsChanged:
            handleModifier(event)

        case .systemDefined:
            handleMediaKey(event)

        default:
            break
        }
    }

    private func keyDown(_ code: UInt16) {
        testedKeyCodes.insert(code)
        pressedKeyCodes.insert(code)
        if pressStartTimes[code] == nil { pressStartTimes[code] = Date() }
        stuckKeyCodes.remove(code)
    }

    private func keyUp(_ code: UInt16) {
        pressedKeyCodes.remove(code)
        pressStartTimes[code] = nil
        stuckKeyCodes.remove(code)
    }

    /// 修饰键：根据设备位判断这一次是按下还是松开，而不是简单地翻转状态。
    private func handleModifier(_ event: NSEvent) {
        let code = Self.functionRowAliases[event.keyCode] ?? event.keyCode
        let raw = event.modifierFlags.rawValue

        if code == Self.capsLockKeyCode {
            // 锁定键：每次切换算一次有效按压，短暂高亮后熄灭，永不计入"按住"
            testedKeyCodes.insert(code)
            pressedKeyCodes.insert(code)
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 250_000_000)
                self?.pressedKeyCodes.remove(code)
            }
            return
        }

        let isDown: Bool
        if code == 63 {
            isDown = event.modifierFlags.contains(.function)
        } else if let mask = Self.modifierDeviceMasks[code] {
            isDown = raw & mask != 0
        } else {
            // 未知修饰键：退回翻转逻辑
            isDown = !pressedKeyCodes.contains(code)
        }
        if isDown { keyDown(code) } else { keyUp(code) }
    }

    /// 媒体键（亮度、音量、播放控制）以 systemDefined 事件到达，data1 高 16 位是键类型，第 8–15 位是按下/松开。
    private func handleMediaKey(_ event: NSEvent) {
        guard event.subtype.rawValue == 8 else { return }
        let data = event.data1
        let keyType = (data & 0xFFFF_0000) >> 16
        let state = (data & 0x0000_FF00) >> 8
        guard let code = Self.mediaKeyAliases[keyType] else { return }
        if state == 0x0A {
            keyDown(code)
        } else if state == 0x0B {
            keyUp(code)
        }
    }

    private func checkForStuckKeys() {
        let now = Date()
        for (code, start) in pressStartTimes where now.timeIntervalSince(start) > Self.stuckThresholdSeconds {
            stuckKeyCodes.insert(code)
        }
    }

    // MARK: - 结果

    private func names(_ codes: Set<UInt16>) -> String {
        codes.sorted().map { KeyboardGeometry.displayName(for: $0, type: physicalType, legends: legends) }
            .joined(separator: ", ")
    }

    /// 生成本项检测结果：完全测过且无卡键 → pass；有卡键 → warning；未测完就退出 → 按已测覆盖率降级。
    func buildResult() -> CheckResult {
        let layoutText = layoutName(layoutID)
        var details: [String: String] = [
            L("已测键位数"): "\(verifiedCount) / \(totalKeyCount)",
            L("键盘形态"): physicalType.title,
            L("键盘布局"): layoutText,
        ]
        let manual = manualKeyCodes.subtracting(testedKeyCodes).intersection(activeKeyCodes)
        if !manual.isEmpty { details[L("手动确认的键")] = names(manual) }
        if !absentKeyCodes.isEmpty { details[L("标记为本机没有的键")] = names(absentKeyCodes) }
        let untested = activeKeyCodes.subtracting(verifiedKeyCodes)
        if !untested.isEmpty { details[L("未测试的键")] = names(untested) }

        if !stuckKeyCodes.isEmpty {
            let stuck = names(stuckKeyCodes)
            details[L("疑似卡键")] = stuck
            return CheckResult(
                id: "keyboard",
                title: L("键盘测试"),
                status: .warning,
                summary: L("检测到疑似卡键：{0}，建议重点复测这几个键", stuck),
                rawDetails: details
            )
        }
        if isComplete {
            return CheckResult(
                id: "keyboard",
                title: L("键盘测试"),
                status: .pass,
                summary: L("已逐键测试全部 {0} 个按键，均正常响应", totalKeyCount),
                rawDetails: details
            )
        }
        return CheckResult(
            id: "keyboard",
            title: L("键盘测试"),
            status: .warning,
            summary: L("仅测试了 {0}/{1} 个按键就退出，建议重新完整测试一遍", verifiedCount, totalKeyCount),
            rawDetails: details
        )
    }
}
