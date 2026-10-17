import SwiftUI
import AVFoundation

/// B6：摄像头测试。打开预览画面，用户确认画面清晰、无坏点/色斑。
@MainActor
final class CameraCheckModel: ObservableObject {
    @Published var permissionDenied = false
    @Published var noCamera = false
    @Published var isRunning = false
    let session = AVCaptureSession()

    /// 修复闪退：以前用回调版 requestAccess，系统在后台线程回调，而闭包写在 @MainActor 类里，
    /// Swift 6 会把它视为"必须在主线程执行"，运行时检查失败直接终止 App。
    /// 现在用 async 版本，await 返回后自动回到主线程。
    func start() {
        Task {
            let granted: Bool
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: granted = true
            case .notDetermined: granted = await AVCaptureDevice.requestAccess(for: .video)
            default: granted = false
            }
            if granted { configure() } else { permissionDenied = true }
        }
    }

    private func configure() {
        permissionDenied = false
        // 再次打开此页面时 session 里已有输入，直接重新启动即可（以前会重复添加失败并误报"权限被拒绝"）
        if session.inputs.isEmpty {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                noCamera = true
                return
            }
            session.beginConfiguration()
            session.sessionPreset = .high
            if session.canAddInput(input) { session.addInput(input) }
            session.commitConfiguration()
        }
        guard !session.isRunning else { isRunning = true; return }
        nonisolated(unsafe) let session = self.session
        Task.detached(priority: .userInitiated) { [weak self] in
            session.startRunning()   // 阻塞调用，放到后台线程
            await self?.markRunning()
        }
    }

    private func markRunning() { isRunning = true }

    func stop() {
        nonisolated(unsafe) let session = self.session
        if session.isRunning {
            Task.detached { session.stopRunning() }
        }
        isRunning = false
    }
}

/// AVCaptureVideoPreviewLayer 的 SwiftUI 包装。
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        preview.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer = preview
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct CameraCheckView: View {
    @StateObject private var model = CameraCheckModel()
    let onComplete: (CheckResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            CheckHeader(
                icon: "camera.fill",
                title: L("摄像头测试"),
                subtitle: L("观察下方预览画面：是否清晰、有无坏点、色斑或明显偏色。")
            )

            if model.noCamera {
                InlineNotice(icon: "video.slash", tint: .secondary,
                    text: L("未检测到可用的摄像头。"))
            } else if model.permissionDenied {
                InlineNotice(icon: "exclamationmark.triangle.fill", tint: .orange,
                    text: L("摄像头权限被拒绝。请在「系统设置 › 隐私与安全性 › 摄像头」中允许 MacCheck。"))
            } else {
                CameraPreview(session: model.session)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).strokeBorder(DS.Color.hairline))
            }

            DS.Divider()

            HStack(spacing: DS.Spacing.md) {
                Text(L("测试结果：")).font(DS.Font.body).foregroundStyle(.secondary)
                Button(L("画面清晰正常")) {
                    model.stop()
                    onComplete(CheckResult(id: "camera", title: L("摄像头"), status: .pass,
                        summary: L("摄像头画面清晰，无坏点或异常")))
                }
                .buttonStyle(.borderedProminent)
                Button(L("画面异常")) {
                    model.stop()
                    onComplete(CheckResult(id: "camera", title: L("摄像头"), status: .warning,
                        summary: L("用户反馈画面异常，建议进一步检查摄像头")))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(DS.Spacing.xl)
        .checkPane(L("摄像头"))
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}
