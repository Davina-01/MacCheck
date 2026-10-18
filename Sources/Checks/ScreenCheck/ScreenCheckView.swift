import SwiftUI

/// 屏幕坏点/色带/残影测试：全屏轮播纯色与图案，点按或空格切换，随时可标记异常。
/// 在独立的全屏窗口中显示（见 FullscreenTestPresenter），覆盖包括菜单栏区域在内的整块屏幕。
struct ScreenCheckView: View {
    @StateObject private var model = ScreenCheckModel()
    @FocusState private var isFocused: Bool
    /// 控制条会挡住屏幕下方一块区域，按 H 可隐藏，以便检查那一块的像素。
    @State private var showsControls = true
    let onFinish: (CheckResult) -> Void

    var body: some View {
        ZStack {
            stageBackground(for: model.currentStage)
                .ignoresSafeArea()

            if showsControls {
                VStack {
                    Spacer()
                    overlayBar
                }
                .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(.space) { model.advance(); return .handled }
        .onKeyPress(.rightArrow) { model.advance(); return .handled }
        .onKeyPress(.escape) { finish(exitedEarly: !model.isLastStage); return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "fF")) { _ in
            model.flagCurrent()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "hH")) { _ in
            withAnimation(.easeInOut(duration: 0.15)) { showsControls.toggle() }
            return .handled
        }
        .onTapGesture { model.advance() }
    }

    @ViewBuilder
    private func stageBackground(for stage: ScreenStage) -> some View {
        switch stage {
        case .black: Color.black
        case .white: Color.white
        case .red: Color.red
        case .green: Color.green
        case .blue: Color.blue
        case .grayGradient:
            LinearGradient(colors: [.black, .white], startPoint: .leading, endPoint: .trailing)
        case .checkerboard:
            CheckerboardView()
        }
    }

    private var overlayBar: some View {
        VStack(spacing: 10) {
            Text(model.currentStage.title)
                .font(.system(size: 16, weight: .semibold))
            Text(L("第 {0} / {1} 项 · 点按屏幕或按空格切换下一项 · 按 F 标记异常 · 按 H 隐藏/显示此提示 · Esc 结束", model.currentIndex + 1, model.stages.count))
                .font(.system(size: 12))
                .opacity(0.75)
            Label(L("退出：Esc 结束测试并保存 · ⌘Q 直接退出 MacCheck"), systemImage: "escape")
                .font(.system(size: 12, weight: .semibold))
            HStack(spacing: 12) {
                Button(L("标记此画面异常")) { model.flagCurrent() }
                Button(L("隐藏提示 (H)")) {
                    withAnimation(.easeInOut(duration: 0.15)) { showsControls = false }
                }
                Button(model.isLastStage ? L("完成测试") : L("下一项")) {
                    if model.isLastStage {
                        finish(exitedEarly: false)
                    } else {
                        model.advance()
                    }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(model.currentStage == .white || model.currentStage == .green ? .black : .white)
        .padding(.bottom, 40)
    }

    private func finish(exitedEarly: Bool) {
        onFinish(model.buildResult(exitedEarly: exitedEarly))
    }
}

private struct CheckerboardView: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 40
            let cols = Int((size.width / cell).rounded(.up))
            let rows = Int((size.height / cell).rounded(.up))
            for r in 0..<rows {
                for c in 0..<cols {
                    let isBlack = (r + c).isMultiple(of: 2)
                    let rect = CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(isBlack ? .black : .white))
                }
            }
        }
    }
}
