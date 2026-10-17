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
            // macOS 会在 App 收到按键之前先执行亮度、音量、调度中心等功能，普通 App 无法拦截，
            // 所以醒目提示：按住 fn 再按 F 键，发送的就是真正的 F1–F12。
            Label(L("测试 F1–F12 时请按住 fn（🌐）键，否则会触发亮度、音量、调度中心等系统功能。被系统拦截的键可直接点击键帽手动确认。"),
                  systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.yellow)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.yellow.opacity(0.15)))
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
            Picker(L("键盘形态"), selection: $model.physicalSelection) {
                Text(L("自动（{0}）", model.detectedPhysicalType.title)).tag(KeyboardTestModel.auto)
                Divider()
                ForEach(PhysicalKeyboardType.allCases) { type in
                    Text(type.title).tag(type.rawValue)
                }
            }
            .frame(width: 280)

            Picker(L("键盘布局"), selection: $model.layoutSelection) {
                Text(L("自动（{0}）", model.layoutName(model.detectedLayoutID))).tag(KeyboardTestModel.auto)
                Divider()
                ForEach(model.availableLayouts) { layout in
                    Text(layout.name).tag(layout.id)
                }
            }
            .frame(width: 320)

            Button(L("自动识别")) { model.useDetectedSettings() }
            Button(L("重新开始")) { model.resetProgress() }
        }
        .font(.system(size: 12))
        .buttonStyle(.bordered)
    }

    // MARK: - 键盘网格

    private func slotWidth(_ slot: KeySlot, unit: CGFloat) -> CGFloat {
        unit * slot.width + keySpacing * max(0, slot.width - 1)
    }

    private func rowWidth(_ row: [KeySlot], unit: CGFloat) -> CGFloat {
        row.reduce(0) { $0 + slotWidth($1, unit: unit) } + keySpacing * CGFloat(max(0, row.count - 1))
    }

    private func isReturnPart(_ slot: KeySlot, _ suffix: String) -> Bool {
        slot.keys.count == 1 && slot.keys[0].id.hasSuffix(suffix)
    }

    /// 第 index 行与下一行之间是否有跨两行的竖回车（ISO / JIS）。
    private func hasTallReturn(at index: Int) -> Bool {
        let rows = model.rows
        guard index + 1 < rows.count else { return false }
        return rows[index].contains { isReturnPart($0, "-top") } && rows[index + 1].contains { isReturnPart($0, "-bottom") }
    }

    private func keyboardGrid(unit: CGFloat) -> some View {
        let rows = model.rows
        // 以数字行为基准宽度，让各行右边缘对齐
        let reference = rowWidth(rows[min(1, rows.count - 1)], unit: unit)
        return VStack(alignment: .leading, spacing: keySpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if hasTallReturn(at: index) {
                    tallReturnBlock(upper: row, lower: rows[index + 1], unit: unit, reference: reference)
                } else if index > 0 && hasTallReturn(at: index - 1) {
                    EmptyView()   // 已在上一行的组合块里画过
                } else {
                    HStack(spacing: keySpacing) {
                        ForEach(row) { slot in
                            slotView(slot, unit: unit)
                        }
                    }
                }
            }
        }
        .frame(width: reference, alignment: .leading)
    }

    /// ISO / JIS 竖回车：上下两行的左侧按键照常排列，右侧画成一个完整的倒 L 形回车键。
    /// 以前把它画成两个独立的小键，看起来像是两个回车。
    private func tallReturnBlock(upper: [KeySlot], lower: [KeySlot], unit: CGFloat, reference: CGFloat) -> some View {
        let upperLeft = upper.filter { !isReturnPart($0, "-top") }
        let lowerLeft = lower.filter { !isReturnPart($0, "-bottom") }
        let topWidth = max(unit * 0.8, reference - rowWidth(upperLeft, unit: unit) - keySpacing)
        let bottomWidth = min(topWidth, max(unit * 0.6, reference - rowWidth(lowerLeft, unit: unit) - keySpacing))
        let height = unit * 2 + keySpacing
        let returnKey = upper.first { isReturnPart($0, "-top") }?.keys.first

        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: keySpacing) {
                HStack(spacing: keySpacing) { ForEach(upperLeft) { slotView($0, unit: unit) } }
                HStack(spacing: keySpacing) { ForEach(lowerLeft) { slotView($0, unit: unit) } }
            }
            if let returnKey {
                tallReturnKey(returnKey, topWidth: topWidth, bottomWidth: bottomWidth,
                              topHeight: unit, height: height, fontSize: unit > 40 ? 14 : 11)
                    .offset(x: reference - topWidth)
            }
        }
        .frame(width: reference, height: height, alignment: .topLeading)
    }

    private func tallReturnKey(_ key: KeyDef, topWidth: CGFloat, bottomWidth: CGFloat,
                               topHeight: CGFloat, height: CGFloat, fontSize: CGFloat) -> some View {
        let style = keyStyle(key.keyCode)
        let shape = InvertedLShape(bottomWidth: bottomWidth, topHeight: topHeight, cornerRadius: 6)
        return ZStack(alignment: .top) {
            shape.fill(style.fill)
            shape.stroke(style.border, style: StrokeStyle(lineWidth: 1.5, dash: style.isAbsent ? [3, 3] : []))
            Text("⏎")
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(.white.opacity(style.isAbsent ? 0.25 : 1))
                .frame(width: topWidth, height: topHeight)
        }
        .frame(width: topWidth, height: height)
        .contentShape(shape)
        .onTapGesture { model.cycleManualState(key.keyCode) }
        .help(L("点击：手动确认可用 → 本机没有此键 → 恢复未测"))
        .animation(.easeOut(duration: 0.12), value: style.isPressed)
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

    private struct KeyStyle {
        var fill: Color
        var border: Color
        var isAbsent: Bool
        var isPressed: Bool
    }

    private func keyStyle(_ code: UInt16) -> KeyStyle {
        let isAbsent = model.absentKeyCodes.contains(code)
        let isPressed = model.pressedKeyCodes.contains(code)
        let isStuck = model.stuckKeyCodes.contains(code)
        let isTested = model.testedKeyCodes.contains(code)
        let isManual = model.manualKeyCodes.contains(code) && !isTested

        let fill: Color, border: Color
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
        return KeyStyle(fill: fill, border: border, isAbsent: isAbsent, isPressed: isPressed)
    }

    private func keyView(_ key: KeyDef, width: CGFloat, height: CGFloat, fontSize: CGFloat) -> some View {
        let style = keyStyle(key.keyCode)
        return Text(model.label(for: key))
            .font(.system(size: fontSize, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(.white.opacity(style.isAbsent ? 0.25 : 1))
            .strikethrough(style.isAbsent)
            .frame(width: width, height: height)
            .background(RoundedRectangle(cornerRadius: 6).fill(style.fill))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(style.border, style: StrokeStyle(lineWidth: 1.5, dash: style.isAbsent ? [3, 3] : []))
            )
            .contentShape(Rectangle())
            .onTapGesture { model.cycleManualState(key.keyCode) }
            .help(L("点击：手动确认可用 → 本机没有此键 → 恢复未测"))
            .animation(.easeOut(duration: 0.12), value: style.isPressed)
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

/// ISO / JIS 竖回车的倒 L 形：上半部分占满宽度，下半部分靠右、较窄。
private struct InvertedLShape: Shape {
    let bottomWidth: CGFloat
    let topHeight: CGFloat
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, topHeight / 2, bottomWidth / 2)
        let notchX = rect.maxX - bottomWidth
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + r), radius: r)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - r, y: rect.maxY), radius: r)
        p.addLine(to: CGPoint(x: notchX + r, y: rect.maxY))
        p.addArc(tangent1End: CGPoint(x: notchX, y: rect.maxY), tangent2End: CGPoint(x: notchX, y: rect.maxY - r), radius: r)
        p.addLine(to: CGPoint(x: notchX, y: rect.minY + topHeight + r))
        p.addArc(tangent1End: CGPoint(x: notchX, y: rect.minY + topHeight), tangent2End: CGPoint(x: notchX - r, y: rect.minY + topHeight), radius: r)
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.minY + topHeight))
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY + topHeight), tangent2End: CGPoint(x: rect.minX, y: rect.minY + topHeight - r), radius: r)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + r, y: rect.minY), radius: r)
        p.closeSubpath()
        return p
    }
}
