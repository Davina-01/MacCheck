import AppKit
import SwiftUI

/// 无边框、覆盖整块屏幕的测试窗口。默认的无边框窗口不能成为 key window，键盘测试需要收按键，所以重写。
private final class FullscreenTestWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    /// 不让系统把窗口挤到菜单栏下方——屏幕测试必须覆盖包括顶部菜单栏、刘海两侧在内的每一个像素。
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// 键盘 / 屏幕测试的全屏呈现。
///
/// 以前这两项测试只是覆盖在 App 窗口内容区上的一层视图，窗口标题栏、工具栏和系统菜单栏所在的
/// 顶部区域始终测不到（上游 issue #5「屏幕测试无法覆盖顶部一条」）。现在改为在 App 窗口所在的屏幕上
/// 打开一个独立的无边框窗口，尺寸等于整块屏幕，层级高于菜单栏，并临时隐藏菜单栏与程序坞。
@MainActor
final class FullscreenTestPresenter {
    static let shared = FullscreenTestPresenter()

    private var window: NSWindow?
    private var savedPresentationOptions: NSApplication.PresentationOptions?

    private init() {}

    func present<Content: View>(_ content: Content) {
        dismiss()

        let screen = NSApp.keyWindow?.screen ?? NSApp.mainWindow?.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        let window = FullscreenTestWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        // 高于菜单栏（mainMenu）与状态栏图标，低于弹出菜单（popUpMenu），保证窗口内的下拉选择器仍可正常弹出。
        window.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 2)
        window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.hasShadow = false
        window.isOpaque = true
        window.contentView = NSHostingView(rootView: content.ignoresSafeArea())
        window.setFrame(screen.frame, display: true)

        // App 主窗口处于系统原生全屏时，系统不允许再修改这些选项，跳过即可（此时菜单栏本来就是隐藏的）。
        if !NSApp.currentSystemPresentationOptions.contains(.fullScreen) {
            savedPresentationOptions = NSApp.presentationOptions
            NSApp.presentationOptions = [.hideDock, .hideMenuBar]
        }

        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    func dismiss() {
        guard let window else { return }
        self.window = nil
        window.orderOut(nil)
        if let saved = savedPresentationOptions {
            NSApp.presentationOptions = saved
            savedPresentationOptions = nil
        }
        // 结束测试通常是由窗口里的按钮触发的。如果在按钮的点击处理过程中立刻拆掉 NSHostingView，
        // AppKit 还在使用这些视图，会导致闪退。所以先隐藏窗口，等这次事件处理结束后再释放内容；
        // 释放内容会触发 onDisappear，从而停止键盘监听。
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            window.contentView = nil
            window.close()
        }
    }
}
