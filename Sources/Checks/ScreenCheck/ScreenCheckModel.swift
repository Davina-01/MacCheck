import Foundation

enum ScreenStage: Int, CaseIterable {
    case black, white, red, green, blue, grayGradient, checkerboard

    var title: String {
        switch self {
        case .black: return L("纯黑画面 —— 查找亮点/漏光")
        case .white: return L("纯白画面 —— 查找坏点/暗点")
        case .red: return L("纯红画面 —— 查找坏点")
        case .green: return L("纯绿画面 —— 查找坏点")
        case .blue: return L("纯蓝画面 —— 查找坏点")
        case .grayGradient: return L("灰阶渐变 —— 查找色带/断层")
        case .checkerboard: return L("棋盘格 —— 查找残影/漏光")
        }
    }
}

@MainActor
final class ScreenCheckModel: ObservableObject {
    @Published var currentIndex: Int = 0
    @Published var flaggedStages: Set<Int> = []
    @Published var didFinishEarly = false

    let stages = ScreenStage.allCases

    var currentStage: ScreenStage { stages[currentIndex] }
    var isLastStage: Bool { currentIndex == stages.count - 1 }
    var completedCount: Int { currentIndex + (isLastStage ? 1 : 0) }

    func advance() {
        if isLastStage {
            didFinishEarly = false
        } else {
            currentIndex += 1
        }
    }

    func flagCurrent() {
        flaggedStages.insert(currentIndex)
    }

    func buildResult(exitedEarly: Bool) -> CheckResult {
        let stageNames = flaggedStages.sorted().map { stages[$0].title }
        var details: [String: String] = [
            L("已完成阶段"): "\(exitedEarly ? currentIndex : stages.count) / \(stages.count)",
        ]
        if !stageNames.isEmpty {
            details[L("用户标记异常的阶段")] = stageNames.joined(separator: "; ")
        }

        if !flaggedStages.isEmpty {
            return CheckResult(
                id: "screen",
                title: L("屏幕测试"),
                status: .warning,
                summary: L("以下画面用户标记了异常：{0}，建议在光线较暗环境下再次确认坏点位置", stageNames.joined(separator: L("、"))),
                rawDetails: details
            )
        }
        if exitedEarly {
            return CheckResult(
                id: "screen",
                title: L("屏幕测试"),
                status: .warning,
                summary: L("仅完成 {0}/{1} 个画面就退出，建议重新完整测试", currentIndex, stages.count),
                rawDetails: details
            )
        }
        return CheckResult(
            id: "screen",
            title: L("屏幕测试"),
            status: .pass,
            summary: L("完整测试了纯色、灰阶、棋盘格等 {0} 种画面，未发现异常", stages.count),
            rawDetails: details
        )
    }
}
