import Foundation

/// A3：存储/固态硬盘检测。读取 SSD 型号、容量、SMART 健康状态、TRIM，以及剩余可用空间。
enum StorageService {

    private static func nvmeDrives() -> [[String: Any]] {
        let output = ShellRunner.run("/usr/sbin/system_profiler", ["SPNVMeDataType", "-json"])
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let controllers = json["SPNVMeDataType"] as? [[String: Any]]
        else { return [] }
        return controllers.flatMap { ($0["_items"] as? [[String: Any]]) ?? [] }
    }

    private static func freeSpaceBytes() -> Int64? {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let bytes = values.volumeAvailableCapacityForImportantUsage
        else { return nil }
        return bytes
    }

    private static func gb(_ bytes: Int64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_000_000_000)
    }

    // MARK: - smartctl 寿命数据（上游 issue #4）

    /// smartmontools 不是系统自带，常见安装位置（Apple Silicon / Intel 的 Homebrew、MacPorts）。
    private static let smartctlPaths = ["/opt/homebrew/bin/smartctl", "/usr/local/bin/smartctl", "/opt/local/sbin/smartctl"]

    struct NVMeHealth {
        var dataWrittenBytes: Double?
        var dataReadBytes: Double?
        var percentageUsed: Int?
        var availableSpare: Int?
        var powerOnHours: Int?
        var powerCycles: Int?
        var unsafeShutdowns: Int?
        var mediaErrors: Int?
        var criticalWarning: Int?
    }

    static func smartctlPath() -> String? {
        smartctlPaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// 解析 `smartctl -a -j disk0` 的 JSON 输出（NVMe 健康日志）。
    /// NVMe 的 data units 以 1000 个 512 字节扇区为单位，即 1 单位 = 512,000 字节。
    static func parseNVMeHealth(json: String) -> NVMeHealth? {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let log = root["nvme_smart_health_information_log"] as? [String: Any]
        else { return nil }
        func int(_ key: String) -> Int? { (log[key] as? NSNumber)?.intValue }
        var health = NVMeHealth()
        health.dataWrittenBytes = (log["data_units_written"] as? NSNumber).map { $0.doubleValue * 512_000 }
        health.dataReadBytes = (log["data_units_read"] as? NSNumber).map { $0.doubleValue * 512_000 }
        health.percentageUsed = int("percentage_used")
        health.availableSpare = int("available_spare")
        health.powerOnHours = int("power_on_hours")
        health.powerCycles = int("power_cycles")
        health.unsafeShutdowns = int("unsafe_shutdowns")
        health.mediaErrors = int("media_errors")
        health.criticalWarning = int("critical_warning")
        return health
    }

    private static func tb(_ bytes: Double) -> String {
        bytes >= 1_000_000_000_000
            ? String(format: "%.2f TB", bytes / 1_000_000_000_000)
            : String(format: "%.0f GB", bytes / 1_000_000_000)
    }

    private static func lifetimeResult() -> CheckResult {
        guard let path = smartctlPath() else {
            return CheckResult(
                id: "storage.lifetime",
                title: L("硬盘寿命与读写量"),
                status: .skipped,
                summary: L("未安装 smartctl，无法读取硬盘累计读写量与磨损度。在「终端」执行 brew install smartmontools 后重新扫描即可查看。"),
                rawDetails: [L("安装命令"): "brew install smartmontools"]
            )
        }
        let output = ShellRunner.run(path, ["-a", "-j", "disk0"])
        guard let h = parseNVMeHealth(json: output) else {
            return CheckResult(
                id: "storage.lifetime",
                title: L("硬盘寿命与读写量"),
                status: .unsupported,
                summary: L("smartctl 未返回 NVMe 健康数据（部分机型或外置启动盘不支持）"),
                rawDetails: ["smartctl": path]
            )
        }

        var details: [String: String] = ["smartctl": path]
        if let w = h.dataWrittenBytes { details[L("累计写入")] = tb(w) }
        if let r = h.dataReadBytes { details[L("累计读取")] = tb(r) }
        if let p = h.percentageUsed { details[L("已用寿命")] = "\(p)%" }
        if let s = h.availableSpare { details[L("可用备用块")] = "\(s)%" }
        if let hrs = h.powerOnHours { details[L("通电时间")] = L("{0} 小时", hrs) }
        if let c = h.powerCycles { details[L("通电次数")] = "\(c)" }
        if let u = h.unsafeShutdowns { details[L("异常断电次数")] = "\(u)" }
        if let m = h.mediaErrors { details[L("介质错误")] = "\(m)" }

        let used = h.percentageUsed ?? 0
        let written = h.dataWrittenBytes.map(tb) ?? "—"
        let critical = (h.criticalWarning ?? 0) != 0 || (h.mediaErrors ?? 0) > 0

        if critical || used >= 100 {
            return CheckResult(
                id: "storage.lifetime",
                title: L("硬盘寿命与读写量"),
                status: .redFlag,
                summary: L("硬盘已用寿命 {0}%，累计写入 {1}，并报告了严重警告或介质错误", used, written),
                rawDetails: details,
                isRedFlagHeadline: L("⛔ 固态硬盘的 NVMe 健康日志报告了严重警告或介质错误（已用寿命 {0}%），硬盘可能即将损坏。Mac 的固态硬盘焊在主板上，无法单独更换，不建议购买。", used)
            )
        }
        let status: CheckStatus = used >= 80 ? .warning : .pass
        let verdict = used >= 80 ? L("磨损较重，建议议价") : (used >= 30 ? L("中度使用") : L("磨损很低"))
        return CheckResult(
            id: "storage.lifetime",
            title: L("硬盘寿命与读写量"),
            status: status,
            summary: L("已用寿命 {0}% · 累计写入 {1} —— {2}", used, written, verdict),
            rawDetails: details
        )
    }

    static func runAll() -> [CheckResult] {
        storageResults() + [lifetimeResult()]
    }

    private static func storageResults() -> [CheckResult] {
        let drives = nvmeDrives()
        guard let disk = drives.first else {
            return [CheckResult(
                id: "storage",
                title: L("存储"),
                status: .unsupported,
                summary: L("未检测到内建 NVMe 固态硬盘信息")
            )]
        }

        let model = (disk["device_model"] as? String) ?? (disk["_name"] as? String) ?? L("未知")
        let size = (disk["size"] as? String) ?? ""
        let smart = (disk["smart_status"] as? String) ?? ""
        let trim = (disk["spnvme_trim_support"] as? String) ?? ""
        let revision = (disk["device_revision"] as? String) ?? ""

        var details: [String: String] = [
            L("型号"): model,
            L("容量"): size,
            L("SMART 状态"): smart.isEmpty ? L("未知") : smart,
            L("TRIM 支持"): trim.isEmpty ? L("未知") : trim,
            L("固件版本"): revision,
        ]
        if let free = freeSpaceBytes() {
            details[L("可用空间")] = gb(free)
        }

        // SMART "Verified" = 正常；其它值（如 Failing）→ 红旗
        let smartOK = smart.lowercased() == "verified"
        if !smart.isEmpty && !smartOK {
            return [CheckResult(
                id: "storage",
                title: L("存储 / 固态硬盘"),
                status: .redFlag,
                summary: L("硬盘 SMART 健康状态异常（{0}），存在数据丢失风险", smart),
                rawDetails: details,
                isRedFlagHeadline: L("⛔ 固态硬盘的 SMART 健康检测未通过（状态：{0}），说明硬盘可能即将损坏，随时有数据丢失风险，不建议购买或应立即备份更换。", smart)
            )]
        }

        return [CheckResult(
            id: "storage",
            title: L("存储 / 固态硬盘"),
            status: .pass,
            summary: L("{0} · {1} · SMART 健康状态正常", model, size),
            rawDetails: details
        )]
    }
}
