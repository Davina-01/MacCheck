import SwiftUI
import IOKit
import IOKit.usb

/// B5+：接口逐口实测。定时枚举 USB 设备并与上一帧差分，实时输出插入/拔出事件与速率，
/// 引导用户依次插入每个物理接口逐口验证。用轮询差分而非 C 回调桥接（避开 Swift 6 并发陷阱）。
@MainActor
final class PortLiveMonitor: ObservableObject {
    struct Event: Identifiable {
        let id = UUID()
        let time: String
        let inserted: Bool
        let name: String
        let speed: String
    }

    @Published var events: [Event] = []
    @Published var currentDevices: [String] = []
    @Published var isMonitoring = false

    private var previous: Set<String> = []
    private var timer: Timer?
    private var startedBaseline = false

    func start() {
        guard timer == nil else { return }
        isMonitoring = true
        // 先建立基线（当前已连接的设备不算"新插入"）
        previous = Set(Self.enumerate().map(\.key))
        startedBaseline = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate(); timer = nil
        isMonitoring = false
    }

    func reset() {
        events.removeAll()
        previous = Set(Self.enumerate().map(\.key))
    }

    private var isTicking = false

    private func tick() {
        // 枚举含 diskutil 调用，放到后台执行，避免每秒卡一下主线程
        guard !isTicking else { return }
        isTicking = true
        Task {
            let now = await Task.detached { PortLiveMonitor.enumerate() }.value
            apply(now)
            isTicking = false
        }
    }

    private func apply(_ now: [Dev]) {
        let nowKeys = Set(now.map(\.key))
        let inserted = nowKeys.subtracting(previous)
        let removed = previous.subtracting(nowKeys)

        for key in inserted {
            if let dev = now.first(where: { $0.key == key }) {
                events.insert(Event(time: Self.timestamp(), inserted: true, name: dev.name, speed: dev.speed), at: 0)
            }
        }
        for key in removed {
            let name = key.components(separatedBy: "|").first ?? key
            events.insert(Event(time: Self.timestamp(), inserted: false, name: name, speed: ""), at: 0)
        }
        previous = nowKeys
        currentDevices = now.map { "\($0.name) · \($0.speed)" }
    }

    /// 事件数（插入）——用于统计验证了多少次接入。
    var insertCount: Int { events.filter(\.inserted).count }

    // MARK: - IOKit 枚举

    private struct Dev: Sendable { let key: String; let name: String; let speed: String }

    /// 枚举所有外接设备：USB、雷雳 / USB4，以及外接物理磁盘。
    ///
    /// 以前只枚举 IOUSBHostDevice，雷雳 3 固态硬盘走的是 PCIe 隧道而不是 USB，
    /// 插上后完全不会出现（上游 issue #5）。现在额外枚举雷雳交换器节点和外接磁盘。
    nonisolated private static func enumerate() -> [Dev] {
        usbDevices() + thunderboltDevices() + externalDisks()
    }

    nonisolated private static func usbDevices() -> [Dev] {
        var result: [Dev] = []
        var iterator: io_iterator_t = 0
        // 现代 macOS 用 IOUSBHostDevice
        guard let matching = IOServiceMatching("IOUSBHostDevice") else { return [] }
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            let name = stringProp(service, "USB Product Name")
                ?? stringProp(service, "Product Name")
                ?? registryName(service)
            guard let name, !name.isEmpty else { continue }
            let speed = speedLabel(intProp(service, "Device Speed"))
            let locationID = intProp(service, "locationID") ?? 0
            // key 用 名称+locationID 保证不同口的同名设备也能区分
            result.append(Dev(key: "\(name)|\(locationID)", name: name, speed: speed))
        }
        return result
    }

    /// 雷雳 / USB4 设备：枚举 IOThunderboltSwitch 节点，Route String 为 0 的是本机自身的控制器，跳过。
    nonisolated private static func thunderboltDevices() -> [Dev] {
        var result: [Dev] = []
        var iterator: io_iterator_t = 0
        guard let matching = IOServiceMatching("IOThunderboltSwitch") else { return [] }
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            let route = intProp(service, "Route String") ?? 0
            let depth = intProp(service, "Depth") ?? 0
            guard route != 0 || depth > 0 else { continue }
            let vendor = stringProp(service, "Device Vendor Name") ?? ""
            let model = stringProp(service, "Device Model Name") ?? ""
            let name = [vendor, model].filter { !$0.isEmpty }.joined(separator: " ")
            let displayName = name.isEmpty ? L("雷雳设备") : name
            result.append(Dev(key: "tb|\(displayName)|\(route)", name: displayName, speed: L("雷雳 / USB4")))
        }
        return result
    }

    /// 外接物理磁盘（含雷雳 NVMe 硬盘盒、USB 硬盘），通过 diskutil 读取型号与总线类型。
    nonisolated private static func externalDisks() -> [Dev] {
        let listOutput = ShellRunner.run("/usr/sbin/diskutil", ["list", "-plist", "external", "physical"])
        guard let listData = listOutput.data(using: .utf8),
              let list = try? PropertyListSerialization.propertyList(from: listData, format: nil) as? [String: Any],
              let disks = list["WholeDisks"] as? [String]
        else { return [] }

        return disks.compactMap { disk -> Dev? in
            let infoOutput = ShellRunner.run("/usr/sbin/diskutil", ["info", "-plist", disk])
            guard let infoData = infoOutput.data(using: .utf8),
                  let info = try? PropertyListSerialization.propertyList(from: infoData, format: nil) as? [String: Any]
            else { return nil }
            // 磁盘映像（.dmg）也会显示为外接磁盘，排除
            if (info["VirtualOrPhysical"] as? String) == "Virtual" { return nil }
            let media = (info["MediaName"] as? String) ?? disk
            let bus = (info["BusProtocol"] as? String) ?? ""
            let size = (info["TotalSize"] as? NSNumber).map {
                ByteCountFormatter.string(fromByteCount: $0.int64Value, countStyle: .file)
            } ?? ""
            let speed = [L("外接磁盘"), bus, size].filter { !$0.isEmpty }.joined(separator: " · ")
            return Dev(key: "disk|\(disk)|\(media)", name: media, speed: speed)
        }
    }

    nonisolated private static func stringProp(_ service: io_service_t, _ key: String) -> String? {
        guard let cf = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) else { return nil }
        return cf.takeRetainedValue() as? String
    }

    nonisolated private static func intProp(_ service: io_service_t, _ key: String) -> Int? {
        guard let cf = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) else { return nil }
        return (cf.takeRetainedValue() as? NSNumber)?.intValue
    }

    nonisolated private static func registryName(_ service: io_service_t) -> String? {
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: 128)
        defer { buffer.deallocate() }
        guard IORegistryEntryGetName(service, buffer) == KERN_SUCCESS else { return nil }
        return String(cString: buffer)
    }

    nonisolated private static func speedLabel(_ speed: Int?) -> String {
        switch speed {
        case 0: return L("USB 1.0 低速")
        case 1: return L("USB 1.1 全速")
        case 2: return L("USB 2.0 高速")
        case 3: return "USB 3.0 (5 Gbps)"
        case 4: return "USB 3.1 (10 Gbps)"
        case 5: return "USB 3.2 (20 Gbps)"
        default: return L("未知速率")
        }
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }
}

struct PortLiveCheckView: View {
    @StateObject private var monitor = PortLiveMonitor()
    let onComplete: (CheckResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            CheckHeader(
                icon: "cable.connector.horizontal",
                title: L("接口逐口实测"),
                subtitle: L("依次把 U 盘/读卡器/线缆插入每一个 USB-C 或读卡器接口，下方会实时显示接入的设备与速率。逐口都能识别即说明接口正常。")
            )

            Card {
                HStack {
                    Circle().fill(monitor.isMonitoring ? .green : .secondary).frame(width: 8, height: 8)
                    Text(monitor.isMonitoring ? L("监听中，请插入设备…") : L("未开始"))
                        .font(DS.Font.body).foregroundStyle(.secondary)
                    Spacer()
                    Text(L("已捕获接入 {0} 次", monitor.insertCount)).font(DS.Font.caption).foregroundStyle(.secondary)
                }
                if monitor.events.isEmpty {
                    Text(L("暂无插拔事件")).font(DS.Font.caption).foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, DS.Spacing.md)
                } else {
                    ForEach(monitor.events.prefix(12)) { e in
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: e.inserted ? "arrow.down.circle.fill" : "arrow.up.circle")
                                .foregroundStyle(e.inserted ? .green : .secondary)
                            Text(e.time).font(DS.Font.mono).foregroundStyle(.secondary)
                            Text(e.inserted ? L("接入") : L("拔出")).font(DS.Font.bodyEmphasis)
                            Text(e.name).font(DS.Font.body).lineLimit(1)
                            Spacer()
                            if !e.speed.isEmpty {
                                Text(e.speed).font(DS.Font.caption).foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }

            DS.Divider()

            HStack(spacing: DS.Spacing.md) {
                if monitor.isMonitoring {
                    Button(L("停止监听")) { monitor.stop() }.buttonStyle(.bordered)
                    Button(L("清除记录")) { monitor.reset() }.buttonStyle(.bordered)
                } else {
                    Button(L("开始监听")) { monitor.start() }.buttonStyle(.borderedProminent)
                }
                Spacer()
                Button(L("每个接口都识别正常")) {
                    finish(pass: true)
                }.buttonStyle(.borderedProminent).disabled(monitor.insertCount == 0)
                Button(L("有接口无反应")) { finish(pass: false) }.buttonStyle(.bordered)
            }
        }
        .padding(DS.Spacing.xl)
        .checkPane(L("接口逐口实测"))
        .onDisappear { monitor.stop() }
    }

    private func finish(pass: Bool) {
        monitor.stop()
        let names = monitor.events.filter(\.inserted).map { "\($0.name) (\($0.speed))" }
        onComplete(CheckResult(
            id: "portsLive",
            title: L("接口逐口实测"),
            status: pass ? .pass : .warning,
            summary: pass
                ? L("共捕获 {0} 次接入，接口通信正常", monitor.insertCount)
                : L("用户反馈有接口无反应，建议重点复测该接口"),
            rawDetails: names.isEmpty ? [:] : [L("接入设备记录"): names.joined(separator: L("；"))]
        ))
    }
}
