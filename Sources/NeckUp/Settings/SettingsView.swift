import AppKit
import NeckUpCore
import SwiftUI

/// 设置窗口：灵敏度、持续时长、提醒开关等（零学习：不暴露角度）
struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var monitor: PostureMonitor
    @EnvironmentObject var appState: AppState
    @State private var showDirectionCal = false

    /// 灵敏度三档 ↔ 内部阈值角度的映射
    private var sensitivity: Binding<Int> {
        Binding(
            get: { settings.thresholdDeg >= -10 ? 0 : (settings.thresholdDeg <= -20 ? 2 : 1) },
            set: { settings.thresholdDeg = [-10.0, -15.0, -20.0][$0] }
        )
    }

    var body: some View {
        Form {
            Section(L10n.secLanguage) {
                Picker(L10n.languageLabel, selection: $settings.language) {
                    Text(L10n.languageSystem).tag("")
                    Text("中文").tag("zh-Hans")
                    Text("English").tag("en")
                    Text("日本語").tag("ja")
                    Text("한국어").tag("ko")
                }
            }
            Section(L10n.secPosture) {
                Picker(L10n.sensitivityLabel, selection: sensitivity) {
                    Text(L10n.sensStrict).tag(0)
                    Text(L10n.sensStandard).tag(1)
                    Text(L10n.sensRelaxed).tag(2)
                }
                .pickerStyle(.segmented)
                Text(L10n.sensDesc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Stepper(L10n.sustainedSec(Int(settings.sustainedSec)),
                        value: $settings.sustainedSec, in: 2 ... 15)
                Toggle(L10n.remindersToggle, isOn: $settings.remindersEnabled)
                Toggle(L10n.soundToggle, isOn: $settings.soundEnabled)
            }
            Section(L10n.secGame) {
                Toggle(L10n.gameToggle, isOn: $settings.gameEnabled)
                Toggle(L10n.zenToggle, isOn: $settings.zenMode)
                Text(L10n.gameDesc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(L10n.secHowToPlay) {
                ForEach(MonsterType.allCases, id: \.self) { monster in
                    Button {
                        appState.startPractice(monster)
                    } label: {
                        HStack(spacing: 10) {
                            MonsterPortrait(monster: monster)
                                .frame(width: 44, height: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(monster.displayName)
                                Text(monster.tutorialText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(L10n.tryIt)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Text(L10n.howToPlayDesc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(L10n.secBreak) {
                Picker(L10n.breakPickerLabel, selection: $settings.breakIntervalMin) {
                    Text(L10n.off).tag(0.0)
                    Text(L10n.everyMinutes(30)).tag(30.0)
                    Text(L10n.everyMinutes(45)).tag(45.0)
                    Text(L10n.everyMinutes(60)).tag(60.0)
                }
                Text(L10n.breakDesc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(L10n.secIsland) {
                Picker(L10n.showOn, selection: $settings.displayID) {
                    Text(L10n.displayAuto).tag("")
                    ForEach(NSScreen.screens, id: \.self) { screen in
                        Text(screen.localizedName).tag(NotchGeometry.displayID(of: screen))
                    }
                }
                Button(L10n.reopenOnboarding) {
                    NotificationCenter.default.post(name: .neckUpShowOnboarding, object: nil)
                }
            }
            Section(L10n.secSensor) {
                Button(L10n.recalibrateButton) { monitor.recalibrate(flash: true) }
                Button(L10n.dirCalButton) { showDirectionCal = true }
                    .disabled(!monitor.isWearing)
                Text(L10n.dirCalDesc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle(L10n.mockToggle, isOn: $settings.mockMode)
                Text(L10n.mockDesc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(L10n.secSupport) {
                HStack(spacing: 10) {
                    Button("☕ Buy Me a Coffee") {
                        NSWorkspace.shared.open(URL(string: "https://buymeacoffee.com/mikeyzhou")!)
                    }
                    DonateQRButton(title: L10n.alipayLabel, imageName: "alipay")
                    DonateQRButton(title: L10n.wechatLabel, imageName: "wechat")
                }
                Text(L10n.supportDesc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 740)
        .sheet(isPresented: $showDirectionCal, onDismiss: { appState.refreshSamplingRate() }) {
            // sheet 期间传感器全速：方向校准需要实时跟随
            DirectionCalibrationView(
                onDone: { showDirectionCal = false },
                onSkip: { showDirectionCal = false },
                cancelStyle: true
            )
            .padding(20)
            .frame(width: 380, height: 400)
            .onAppear { monitor.setHighFrequency(true) }
        }
    }
}

/// 收款码按钮：点击弹出二维码气泡
private struct DonateQRButton: View {
    let title: String
    let imageName: String
    @State private var show = false

    var body: some View {
        Button(title) { show = true }
            .popover(isPresented: $show, arrowEdge: .bottom) {
                VStack(spacing: 8) {
                    if let url = Self.imageURL(imageName), let img = NSImage(contentsOf: url) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Text(L10n.scanHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }
    }

    /// App 内从 bundle 读；开发模式（swift run）回退到源码目录 Resources/Donate/
    private static func imageURL(_ name: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: "jpg") { return url }
        let project = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Settings
            .deletingLastPathComponent()  // NeckUp
            .deletingLastPathComponent()  // Sources
            .deletingLastPathComponent()  // 项目根
        let url = project.appendingPathComponent("Resources/Donate/\(name).jpg")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
