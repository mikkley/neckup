import AppKit
import SwiftUI

/// 岛窗口：无边框非激活面板，置顶于菜单栏之上，全屏 Space 稳定
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true   // SwiftUI onHover 需要
        // 岛永远是深色主题：强制深色外观，否则浅色模式下默认/次要色文字是深色，在黑底上隐形
        appearance = NSAppearance(named: .darkAqua)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // 点击穿透：面板尺寸始终精确贴合可见内容（收缩态紧贴刘海下缘），
    // 内容区以外不存在面板像素，自然不会遮挡菜单栏点击。
}

/// 岛窗口管理：创建面板、按三态调整尺寸、屏幕变化重排
@MainActor
final class NotchPanelManager {
    private let panel: NotchPanel
    private let state: AppState
    private var geometry: NotchGeometry
    private var screenObserver: NSObjectProtocol?

    init(state: AppState) {
        self.state = state
        geometry = NotchGeometry.current()
        state.geometry = geometry
        panel = NotchPanel(contentRect: Self.frame(for: state.islandState, geometry: geometry))

        let root = NotchView()
            .environmentObject(state)
            .environmentObject(state.monitor)
            .environmentObject(state.pomodoro)
            .environmentObject(state.stats)
            .environmentObject(state.codex)
            .environmentObject(state.settings)
        panel.contentView = NSHostingView(rootView: root)
        panel.orderFrontRegardless()

        // 三态变化 → 调整窗口尺寸
        state.onIslandStateChange = { [weak self] s in
            self?.resize(to: s)
        }
        // 多屏/拔插显示器 → 重新计算几何并重排
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reposition() }
        }
    }

    // 说明：manager 与 App 同生命周期，观察者无需手动移除。

    /// 顶部锚定：展开时向下生长，收缩时紧贴刘海/屏幕顶部
    static func frame(for island: AppState.IslandState, geometry g: NotchGeometry) -> NSRect {
        let collapsed = g.collapsedSize
        let size: NSSize = switch island {
        case .expanded:
            NSSize(width: max(collapsed.width, 360), height: collapsed.height + 164)
        case .game:
            NSSize(width: max(collapsed.width, 360), height: collapsed.height + 292)
        case .reminder:
            // 提醒态加高：文案落在刘海下缘以下，不被开孔遮挡
            NSSize(width: collapsed.width, height: collapsed.height + 26)
        case .collapsed:
            collapsed
        }
        let x = g.screenFrame.midX - size.width / 2
        let y = g.screenFrame.maxY - size.height - (g.hasNotch ? 0 : 4)
        return NSRect(origin: NSPoint(x: x, y: y), size: size)
    }

    private func resize(to island: AppState.IslandState) {
        let target = Self.frame(for: island, geometry: geometry)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(target, display: true)
        }
    }

    private func reposition() {
        geometry = NotchGeometry.current()
        state.geometry = geometry
        panel.setFrame(Self.frame(for: state.islandState, geometry: geometry), display: true)
    }
}
