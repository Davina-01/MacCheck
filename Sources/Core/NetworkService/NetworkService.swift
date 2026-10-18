import Foundation
import CoreWLAN

/// A8/B7-8：无线连接。Wi-Fi 当前连接信息走 CoreWLAN（原生框架），蓝牙控制器状态走 system_profiler。
enum NetworkService {

    // MARK: - Wi-Fi

    private static func wifiResult() -> CheckResult {
        guard let iface = CWWiFiClient.shared().interface() else {
            return CheckResult(
                id: "network.wifi",
                title: "Wi-Fi",
                status: .unsupported,
                summary: L("未检测到 Wi-Fi 网卡")
            )
        }

        var details: [String: String] = [:]
        let powerOn = iface.powerOn()
        details[L("Wi-Fi 开关")] = powerOn ? L("已开启") : L("已关闭")
        if let hw = iface.hardwareAddress() { details[L("网卡 MAC")] = hw }

        if let ssid = iface.ssid() {
            details[L("当前网络")] = ssid
            let rssi = iface.rssiValue()
            details[L("信号强度(RSSI)")] = "\(rssi) dBm"
            details[L("发射速率")] = "\(iface.transmitRate()) Mbps"
            details[L("频段")] = phyModeString(iface.activePHYMode())
            let quality = rssi >= -60 ? L("信号良好") : (rssi >= -75 ? L("信号一般") : L("信号偏弱"))
            return CheckResult(
                id: "network.wifi",
                title: "Wi-Fi",
                status: .pass,
                summary: L("已连接「{0}」· {1} dBm · {2}", ssid, rssi, quality),
                rawDetails: details
            )
        }

        return CheckResult(
            id: "network.wifi",
            title: "Wi-Fi",
            status: powerOn ? .pass : .warning,
            summary: powerOn ? L("Wi-Fi 已开启但未连接网络，网卡工作正常") : L("Wi-Fi 当前处于关闭状态"),
            rawDetails: details
        )
    }

    private static func phyModeString(_ mode: CWPHYMode) -> String {
        switch mode {
        case .mode11a: return "802.11a"
        case .mode11b: return "802.11b"
        case .mode11g: return "802.11g"
        case .mode11n: return "802.11n (Wi-Fi 4)"
        case .mode11ac: return "802.11ac (Wi-Fi 5)"
        case .mode11ax: return "802.11ax (Wi-Fi 6/6E)"
        case .modeNone: return L("未连接")
        @unknown default: return L("未知")
        }
    }

    // MARK: - 蓝牙

    private static func bluetoothResult() -> CheckResult {
        let output = ShellRunner.run("/usr/sbin/system_profiler", ["SPBluetoothDataType", "-json"])
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["SPBluetoothDataType"] as? [[String: Any]],
              let first = items.first,
              let ctrl = first["controller_properties"] as? [String: Any]
        else {
            return CheckResult(
                id: "network.bluetooth",
                title: L("蓝牙"),
                status: .warning,
                summary: L("未能读取蓝牙控制器状态")
            )
        }

        let state = (ctrl["controller_state"] as? String) ?? ""
        let chipset = (ctrl["controller_chipset"] as? String) ?? ""
        let address = (ctrl["controller_address"] as? String) ?? ""
        let isOn = state.contains("on")

        var details: [String: String] = [
            L("控制器状态"): isOn ? L("已开启") : L("已关闭"),
            L("蓝牙芯片"): chipset,
            L("蓝牙地址"): address,
        ]
        if let connected = first["device_connected"] as? [[String: Any]] {
            details[L("已连接设备数")] = "\(connected.count)"
        }

        return CheckResult(
            id: "network.bluetooth",
            title: L("蓝牙"),
            status: isOn ? .pass : .warning,
            summary: isOn ? L("蓝牙控制器正常工作（{0}）", chipset) : L("蓝牙当前处于关闭状态，无法验证射频"),
            rawDetails: details
        )
    }

    static func runAll() -> [CheckResult] {
        [wifiResult(), bluetoothResult()]
    }
}
