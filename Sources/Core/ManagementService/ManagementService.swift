import Foundation

/// A7：监管与锁定检测——二手交易里最容易被忽视、后果最重的一类问题。
/// 命中任意一项即产生红旗，因为这些问题"重装系统也解决不了"。
enum ManagementService {

    // MARK: - MDM 监管

    private struct MDMEnrollmentStatus {
        var enrolledViaDEP: Bool?
        var mdmEnrolled: Bool?
        var rawOutput: String
    }

    private static func mdmEnrollmentStatus() -> MDMEnrollmentStatus {
        let output = ShellRunner.run("/usr/bin/profiles", ["status", "-type", "enrollment"])
        func flag(after marker: String) -> Bool? {
            guard let range = output.range(of: marker) else { return nil }
            let tail = output[range.upperBound...].trimmingCharacters(in: .whitespaces)
            if tail.hasPrefix("Yes") { return true }
            if tail.hasPrefix("No") { return false }
            return nil
        }
        return MDMEnrollmentStatus(
            enrolledViaDEP: flag(after: "Enrolled via DEP:"),
            mdmEnrolled: flag(after: "MDM enrollment:"),
            rawOutput: output
        )
    }

    private static func installedConfigurationProfilesSummary() -> (count: Int?, rawOutput: String) {
        let output = ShellRunner.run("/usr/bin/profiles", ["list", "-all"])
        // 无管理员权限时该命令通常直接报错或输出为空，如实降级而不是伪造结果。
        let profileLines = output.components(separatedBy: "\n").filter { $0.contains("profileIdentifier") }
        if output.isEmpty || output.lowercased().contains("you need to run this tool as root") {
            return (nil, output)
        }
        return (profileLines.count, output)
    }

    // MARK: - MDM 绕过痕迹（上游 issue #2）

    /// Apple 设备注册 / MDM 相关域名。常见的"跳过 MDM"教程会在 /etc/hosts 里把它们指向 0.0.0.0，
    /// 让机器联系不到 Apple 的注册服务器，从而在 `profiles status` 里显示为"未监管"——
    /// 但设备仍在原企业的 Apple 商务管理名单里，重装系统或抹掉 hosts 后会立刻被重新监管。
    private static let enrollmentDomains = [
        "deviceenrollment.apple.com",
        "mdmenrollment.apple.com",
        "iprofiles.apple.com",
        "acmdm.apple.com",
        "axm-adm-mdm.apple.com",
        "gdmf.apple.com",
    ]

    struct MDMBypassEvidence {
        var blockedDomains: [String] = []
        var bypassMarkerFound = false
        var isSuspicious: Bool { !blockedDomains.isEmpty || bypassMarkerFound }
    }

    /// 读取 /etc/hosts（所有用户可读，无需管理员权限），找出被指向本机或空地址的注册域名。
    static func blockedEnrollmentDomains(hostsContent: String) -> [String] {
        let sinkholes: Set<String> = ["0.0.0.0", "127.0.0.1", "::", "::1", "::0"]
        var blocked: [String] = []
        for rawLine in hostsContent.components(separatedBy: .newlines) {
            let line = rawLine.components(separatedBy: "#").first?.trimmingCharacters(in: .whitespaces) ?? ""
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map { String($0).lowercased() }
            guard parts.count >= 2, sinkholes.contains(parts[0]) else { continue }
            for host in parts.dropFirst() where enrollmentDomains.contains(host) && !blocked.contains(host) {
                blocked.append(host)
            }
        }
        return blocked
    }

    private static func mdmBypassEvidence() -> MDMBypassEvidence {
        var evidence = MDMBypassEvidence()
        if let hosts = try? String(contentsOfFile: "/etc/hosts", encoding: .utf8) {
            evidence.blockedDomains = blockedEnrollmentDomains(hostsContent: hosts)
        }
        // 绕过脚本会伪造"已安装云配置描述文件"的标记文件，让设置助理不再弹出远程管理界面
        let settings = "/var/db/ConfigurationProfiles/Settings/"
        let fm = FileManager.default
        evidence.bypassMarkerFound = fm.fileExists(atPath: settings + ".cloudConfigProfileInstalled")
            && fm.fileExists(atPath: settings + ".cloudConfigRecordNotFound")
        return evidence
    }

    // MARK: - Apple ID / 查找我的 Mac

    private static func isICloudAccountSignedIn() -> Bool {
        let output = ShellRunner.run("/usr/bin/defaults", ["read", "MobileMeAccounts", "Accounts"])
        return !output.isEmpty && output.contains("AccountID")
    }

    // MARK: - 激活锁

    private static func activationLockStatus() -> String {
        let sp = HardwareProbe.systemProfilerHardwareJSON()
        return (sp["activation_lock_status"] as? String) ?? ""
    }

    // MARK: - 汇总检测

    static func runAll() -> [CheckResult] {
        var results: [CheckResult] = []

        // MDM
        let mdm = mdmEnrollmentStatus()
        let profiles = installedConfigurationProfilesSummary()
        var mdmDetails: [String: String] = [
            L("DEP 自动注册"): mdm.enrolledViaDEP.map { $0 ? L("是") : L("否") } ?? L("未知"),
            L("MDM 已监管"): mdm.mdmEnrolled.map { $0 ? L("是") : L("否") } ?? L("未知"),
        ]
        if let count = profiles.count {
            mdmDetails[L("已安装配置描述文件数量")] = "\(count)"
        } else {
            mdmDetails[L("配置描述文件列表")] = L("需要管理员权限，本次未能读取完整列表")
        }

        let bypass = mdmBypassEvidence()
        if !bypass.blockedDomains.isEmpty {
            mdmDetails[L("hosts 中被屏蔽的注册域名")] = bypass.blockedDomains.joined(separator: ", ")
        }
        if bypass.bypassMarkerFound {
            mdmDetails[L("伪造的云配置标记文件")] = L("存在")
        }

        if !bypass.blockedDomains.isEmpty && mdm.mdmEnrolled != true {
            results.append(CheckResult(
                id: "management.mdm",
                title: L("MDM 设备监管"),
                status: .redFlag,
                summary: L("检测到 MDM 被人为绕过：/etc/hosts 屏蔽了 Apple 设备注册服务器（{0}）", bypass.blockedDomains.joined(separator: ", ")),
                rawDetails: mdmDetails,
                isRedFlagHeadline: L("⛔ 此机的 /etc/hosts 屏蔽了 Apple 的设备注册 / MDM 服务器，这是「绕过 MDM」的典型手法：机器其实仍属于某个企业或学校，只是暂时联系不到注册服务器。一旦重装系统、抹掉或更新时恢复 hosts，就会被重新强制监管。强烈不建议购买，除非卖家能证明已从原组织的 Apple 商务管理中移除此设备。")
            ))
        } else if bypass.bypassMarkerFound && mdm.mdmEnrolled != true {
            results.append(CheckResult(
                id: "management.mdm",
                title: L("MDM 设备监管"),
                status: .warning,
                summary: L("发现常见「绕过 MDM」脚本留下的标记文件，此机可能曾被跳过远程管理注册"),
                rawDetails: mdmDetails,
                isRedFlagHeadline: L("⚠️ 系统中存在伪造的「云配置已安装」标记文件，通常是绕过 MDM 的脚本留下的。建议要求卖家当面抹掉并重装系统，联网完成设置助理后再确认没有出现「远程管理」页面。")
            ))
        } else if mdm.mdmEnrolled == true {
            results.append(CheckResult(
                id: "management.mdm",
                title: L("MDM 设备监管"),
                status: .redFlag,
                summary: L("此机已被 MDM（移动设备管理）监管"),
                rawDetails: mdmDetails,
                isRedFlagHeadline: L("⛔ 此机正被企业/学校的 MDM 系统监管，对方可以远程施加限制、甚至远程抹除数据，重装系统通常也无法解除（尤其是 DEP 自动注册的情况）。强烈不建议购买，除非卖家能提供从原组织解绑的证明。")
            ))
        } else if mdm.enrolledViaDEP == true {
            results.append(CheckResult(
                id: "management.mdm",
                title: L("MDM 设备监管"),
                status: .warning,
                summary: L("此机存在 DEP 自动注册记录，虽当前未监管，但重装后可能被自动拉回监管"),
                rawDetails: mdmDetails,
                isRedFlagHeadline: L("⚠️ 此机在 Apple 的 DEP 名单中有记录，一旦联网重装系统，有可能被原企业自动重新监管。建议交易前让卖家联系原企业从 DEP 中移除此设备。")
            ))
        } else if mdm.mdmEnrolled == nil {
            results.append(CheckResult(
                id: "management.mdm",
                title: L("MDM 设备监管"),
                status: .warning,
                summary: L("未能确认监管状态（命令执行异常），建议手动检查「系统设置 > 隐私与安全性 > 描述文件与设备管理」"),
                rawDetails: mdmDetails
            ))
        } else {
            results.append(CheckResult(
                id: "management.mdm",
                title: L("MDM 设备监管"),
                status: .pass,
                summary: L("未检测到 MDM 监管，可以放心购买"),
                rawDetails: mdmDetails
            ))
        }

        // Apple ID
        let signedIn = isICloudAccountSignedIn()
        results.append(CheckResult(
            id: "management.appleID",
            title: L("Apple ID 登录状态"),
            status: signedIn ? .warning : .pass,
            summary: signedIn ? L("检测到仍有 Apple ID 登录在本机，交易前必须确认已退出") : L("未检测到已登录的 Apple ID"),
            rawDetails: [L("iCloud 账户"): signedIn ? L("已登录") : L("未登录")],
            isRedFlagHeadline: signedIn
                ? L("⚠️ 本机仍登录着一个 Apple ID。如果这不是你自己的账号，说明原机主没有退出登录——过户前必须让对方在「系统设置 > 用户」里退出 Apple ID，否则你无法正常使用 iCloud、App Store 等服务。")
                : nil
        ))

        // 激活锁
        let lockStatus = activationLockStatus()
        let isLocked = lockStatus.lowercased().contains("enabled")
        if !lockStatus.isEmpty {
            results.append(CheckResult(
                id: "management.activationLock",
                title: L("查找我的 Mac / 激活锁"),
                status: isLocked ? .redFlag : .pass,
                summary: isLocked ? L("激活锁处于开启状态") : L("激活锁已关闭，可以正常使用"),
                rawDetails: [L("激活锁原始状态"): lockStatus],
                isRedFlagHeadline: isLocked
                    ? L("⛔ 此机的激活锁（查找我的 Mac）仍处于开启状态。如果卖家无法当场用自己的 Apple ID 密码关闭，这台机器有很大风险被锁定无法使用，切勿付款。")
                    : nil
            ))
        }

        return results
    }
}
