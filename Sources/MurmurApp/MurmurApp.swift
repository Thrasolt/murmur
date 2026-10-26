import AppKit
import SwiftUI

@main
struct MurmurApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = MurmurModel()

    var body: some Scene {
        WindowGroup("Murmur", id: "main") {
            MenuContent(model: model)
                .onAppear { appDelegate.connect(model: model) }
        }

        MenuBarExtra {
            MenuContent(model: model)
                .onAppear { appDelegate.connect(model: model) }
        } label: {
            Label(model.menuTitle, systemImage: model.isRecording ? "waveform" : "mic")
                .onAppear { appDelegate.connect(model: model) }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlay: OverlayWindow?
    private weak var model: MurmurModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func connect(model: MurmurModel) {
        guard self.model == nil else { return }
        self.model = model
        model.registerHotkeyIfNeeded()
        let panel = OverlayWindow(model: model)
        overlay = panel
        model.onShowOverlay = { [weak panel] in panel?.showOverlay() }
        model.onHideOverlay = { [weak panel] in panel?.orderOut(nil) }
        model.onShowOverlay?()
        model.onHideOverlay?()
    }
}

@MainActor
final class OverlayWindow: NSPanel {
    init(model: MurmurModel) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 258),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        hasShadow = true
        isOpaque = false
        backgroundColor = .clear
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = NSHostingView(rootView: OverlayContent(model: model))
    }

    func showOverlay() {
        guard let screen = NSScreen.main else { return }
        let height: CGFloat = modelHasTranscript ? 340 : 258
        setContentSize(NSSize(width: 430, height: height))
        let origin = NSPoint(
            x: screen.visibleFrame.midX - frame.width / 2,
            y: screen.visibleFrame.midY - frame.height / 2
        )
        setFrameOrigin(origin)
        orderFrontRegardless()
    }

    private var modelHasTranscript: Bool {
        guard let contentView = contentView as? NSHostingView<OverlayContent> else { return false }
        return !contentView.rootView.model.transcript.isEmpty
    }
}
