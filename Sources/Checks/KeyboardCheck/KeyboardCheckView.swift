import SwiftUI

/// 键盘可视化测试：按一下键，对应键位立刻在屏幕上亮起并保持"已测"状态——不是打字框。
/// 支持 ANSI / ISO / JIS 三种物理形态，键帽字符取自所选的系统键盘布局（法语 AZERTY、德语 QWERTZ 等）。
struct KeyboardCheckView: View {
    @StateObject private var model = KeyboardTestModel()
    let onFinish: (CheckResult) -> Void

    private let keySpacing: CGFloat = 6
    /// 每行约 14.6 个键位宽，加上间距按 15.6 估算可用宽度。
    private let rowUnits: CGFloat = 15.6

    var body: some View {
        GeometryReader { geo in
            let unit = min(54, max(30, (geo.size.width - 80) / rowUnits))
            VStack(spacing: 22) {
                header
                settingsBar
                keyboardGrid(unit: unit)
                legendBar
                footer
            }
            .padding(40)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Color.black.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .onAppear {
            model.onRequestFinish = finish
            model.start()
        }
        .onDisappear { model.stop() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(L("键盘测试"))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            Text(L("依次按下每一个按键，亮起代表已检测。长按 esc 键 1.2 秒可随时结束测试。"))
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
            Text(L("F1–F12 若触发了亮度、音量等系统功能也会被记录；个别被系统完全拦截的键（如显示桌面）可直接点击键帽手动确认。"))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            ProgressView(value: model.progress)
                .frame(width: 360)
            Text(L("{0} / {1} 已测试", model.verifiedCount, model.totalKeyCount))
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var settingsBar: some View {
        HStack(spacing: 16) {
            Picker(L("键盘形态"), selection: $model.physicalType) {
                ForEach(PhysicalKeyboardType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .frame(width: 240)

            Picker(L("键盘布局"), selection: $model.layoutID) {
                ForEach(model.availableLayouts) { layout in
                    Text(layout.name).tag(layout.id)
                }
            }
            .frame(width: 300)

            Button(L("自动识别")) { model.useDetectedSettings() }
            Button(L("重新开始")) { model.resetProgress() }
        }
        .font(.system(size: 12))
        .buttonStyle(.bordered)
    }

    private func keyboardGrid(unit: CGFloat) -> some View {
        VStack(spacing: keySpacing) {
            ForEach(Array(model.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: keySpacing) {
                    ForEach(row) { slot in
                        slotView(slot, unit: unit)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func slotView(_ slot: KeySlot, unit: CGFloat) -> some View {
        let width = unit * slot.width + keySpacing * max(0, slot.width - 1)
        if slot.isStacked {
            VStack(spacing: 2) {
                ForEach(slot.keys) { key in
                    keyView(key, width: width, height: (unit - 2) / 2, fontSize: 10)
                }
            }
        } else if let key = slot.keys.first {
            keyView(key, width: width, height: unit, fontSize: unit > 40 ? 14 : 11)
        }
    }

    private func keyView(_ key: KeyDef, width: CGFloat, height: CGFloat, fontSize: CGFloat) -> some View {
        let code = key.keyCode
        let isAbsent = model.absentKeyCodes.contains(code)
        let isPressed = model.pressedKeyCodes.contains(code)
        let isStuck = model.stuckKeyCodes.contains(code)
        let isTested = model.testedKeyCodes.contains(code)
        let isManual = model.manualKeyCodes.contains(code) && !isTested

        let fill: Color
        let border: Color
        if isAbsent {
            fill = .clear; border = Color.white.opacity(0.12)
        } else if isStuck {
            fill = .red; border = .red
        } else if isPressed {
            fill = .green; border = .green
        } else if isTested {
            fill = Color.green.opacity(0.35); border = .green
        } else if isManual {
            fill = Color.blue.opacity(0.35); border = .blue
        } else {
            fill = Color.white.opacity(0.08); border = Color.white.opacity(0.3)
        }

        return Text(model.label(for: key))
            .font(.system(size: fontSize, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(.white.opacity(isAbsent ? 0.25 : 1))
            .strikethrough(isAbsent)
            .frame(width: width, height: height)
            .background(RoundedRectangle(cornerRadius: 6).fill(fill))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(border, style: StrokeStyle(lineWidth: 1.5, dash: isAbsent ? [3, 3] : []))
            )
            .contentShape(Rectangle())
            .onTapGesture { model.cycleManualState(code) }
            .help(L("点击：手动确认可用 → 本机没有此键 → 恢复未测"))
            .animation(.easeOut(duration: 0.12), value: isPressed)
    }

    private var legendBar: some View {
        HStack(spacing: 18) {
            legendItem(Color.green.opacity(0.35), .green, L("已按下测试"))
            legendItem(Color.blue.opacity(0.35), .blue, L("手动确认"))
            legendItem(.red, .red, L("疑似卡键"))
            legendItem(.clear, Color.white.opacity(0.3), L("本机没有（不计入）"), dashed: true)
        }
        .font(.system(size: 12))
        .foregroundStyle(.white.opacity(0.7))
    }

    private func legendItem(_ fill: Color, _ border: Color, _ text: String, dashed: Bool = false) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(fill)
                .overlay(RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(border, style: StrokeStyle(lineWidth: 1.2, dash: dashed ? [2, 2] : [])))
                .frame(width: 16, height: 12)
            Text(text)
        }
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Button(L("结束并保存结果")) { finish() }
                .keyboardShortcut(.cancelAction)
            if model.isComplete {
                Text(L("全部按键已测试完成 ✅")).foregroundStyle(.green)
            }
        }
        .buttonStyle(.bordered)
        .tint(.white)
    }

    private func finish() {
        onFinish(model.buildResult())
    }
}
