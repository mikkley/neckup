@preconcurrency import AVFoundation
import Foundation
import NeckUpCore

/// 8-bit 音效引擎（设计文档 §6.3）：AVAudioEngine 常驻，音效用方波/噪声程序合成（零音频资产），
/// 全部预载 AVAudioPCMBuffer，scheduleBuffer 即时触发；离散事件音对 AirPods 蓝牙延迟不敏感。
/// 尊重 settings.soundEnabled，输出跟随系统默认路由（戴着 AirPods 即在耳机里响）。
@MainActor
final class SoundEngine {
    private let engine = AVAudioEngine()
    private let settings: AppSettings
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private var buffers: [String: AVAudioPCMBuffer] = [:]

    init(settings: AppSettings) {
        self.settings = settings
        // 预载全部合成音效
        buffers["confirm"] = Self.makeConfirm(format: format)
        buffers["thud"] = Self.makeThud(format: format)
        buffers["victory"] = Self.makeVictory(format: format)
        buffers["block"] = Self.makeBlock(format: format)
        buffers["gem"] = Self.makeGem(format: format)
        buffers["burst"] = Self.makeBurst(format: format)
        buffers["blast"] = Self.makeQiBlast(format: format)
        buffers["lock"] = Self.makeLock(format: format)
        buffers["arrow"] = Self.makeArrow(format: format)
        buffers["fall"] = Self.makeFall(format: format)
        for level in 1...RatchetTracker.slots.count {
            buffers["ratchet\(level)"] = Self.makeRatchet(level: level, format: format)
        }
        for n in 2...12 {
            buffers["combo\(n)"] = Self.makeCombo(n: n, format: format)
        }
        // 引擎懒启动：裸图 start 会抛 NSException，首次播放接好节点再 start
    }

    /// 棘轮咔哒：短促干燥 <80ms，音高按半音阶随档位上行（越接近目标越"高、亮"）
    func playRatchet(level: Int) {
        let clamped = min(max(level, 1), RatchetTracker.slots.count)
        play(buffers["ratchet\(clamped)"])
    }

    /// 劈中确认：木质劈裂短音 + 上行两音（<300ms）
    func playConfirm() { play(buffers["confirm"]) }

    /// combo 递增：五声音阶逐级上行（n ≥ 2 时由 AppState 触发）
    func playCombo(_ n: Int) { play(buffers["combo\(min(max(n, 2), 12))"]) }

    /// 甩头警告：低音量钝音 thunk
    func playThud() { play(buffers["thud"]) }

    /// 一局胜利：上行琶音（<800ms）
    func playVictory() { play(buffers["victory"]) }

    /// M2 格挡：金属闷响「铛」
    func playBlock() { play(buffers["block"]) }

    /// M3 接宝石：清亮「叮」
    func playGem() { play(buffers["gem"]) }

    /// M3 大宝石定住迸发：快速上行琶音
    func playBurst() { play(buffers["burst"]) }

    /// M4 气功波发射：短促爆发音
    func playQiBlast() { play(buffers["blast"]) }

    /// M5 瞄准锁定：锁链咔哒（双击）
    func playLock() { play(buffers["lock"]) }

    /// M5 放箭：弦响
    func playArrow() { play(buffers["arrow"]) }

    /// M5 蝙蝠坠落：下行滑音（音高下降=下落）
    func playFall() { play(buffers["fall"]) }

    // MARK: 连续 sonification（M3/M4 蓄力音，设计文档 §6.2/§6.3）

    private var chargeNode: AVAudioPlayerNode?
    private var chargeLevel = -1.0

    /// 蓄力进度更新（0~1）：惰性启动循环音，rate 随进度上行（音高 0.8x→1.7x）；
    /// 变化 ≥2% 才调 rate（10Hz 级节流，避免爆音）
    func updateCharge(progress: Double) {
        guard settings.soundEnabled else { return }
        let p = min(max(progress, 0), 1)
        if chargeNode == nil { startChargeNode() }
        guard let node = chargeNode, abs(p - chargeLevel) >= 0.02 else { return }
        chargeLevel = p
        node.rate = Float(0.8 + p * 0.9)
    }

    /// 蓄力中止/结束：停掉循环音并摘除节点
    func stopCharge() {
        guard let node = chargeNode else { return }
        node.stop()
        engine.detach(node)
        chargeNode = nil
        chargeLevel = -1
    }

    private func startChargeNode() {
        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        if !engine.isRunning { try? engine.start() }
        guard engine.isRunning else {
            engine.detach(node)
            return
        }
        node.volume = 0.16
        if let loop = Self.makeChargeLoop(format: format) {
            node.scheduleBuffer(loop, at: nil, options: .loops)
        }
        node.rate = 0.8
        node.play()
        chargeNode = node
        chargeLevel = 0
    }

    /// 每个事件一个独立 player node，避免互相打断；播完自动摘除
    private func play(_ buffer: AVAudioPCMBuffer?) {
        guard settings.soundEnabled, let buffer else { return }
        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        if !engine.isRunning { try? engine.start() }
        guard engine.isRunning else {
            engine.detach(node)
            return
        }
        node.scheduleBuffer(buffer) { [weak self, weak node] in
            Task { @MainActor in
                guard let self, let node else { return }
                self.engine.detach(node)
            }
        }
        node.play()
    }
}

// MARK: - PCM 程序合成（纯函数，44.1kHz mono Float32）

extension SoundEngine {
    /// 方波（8-bit 芯片音基底）
    private static func square(_ freq: Double, _ t: Double) -> Double {
        sin(2 * .pi * freq * t) >= 0 ? 1 : -1
    }

    private static func noise() -> Double { Double.random(in: -1 ... 1) }

    /// 按采样函数渲染一段 buffer
    private static func render(_ duration: Double, format: AVAudioFormat,
                               _ sample: (Double) -> Double) -> AVAudioPCMBuffer? {
        let count = Int(duration * format.sampleRate)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else { return nil }
        buf.frameLength = AVAudioFrameCount(count)
        guard let ch = buf.floatChannelData?[0] else { return nil }
        for i in 0..<count {
            let v = sample(Double(i) / format.sampleRate)
            ch[i] = Float(max(-1, min(1, v)))
        }
        return buf
    }

    /// 棘轮咔哒：方波 + 少量噪声，指数快衰减，基频 700Hz 半音阶上行
    private static func makeRatchet(level: Int, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let freq = 700 * pow(2, Double(level - 1) / 12)
        return render(0.07, format: format) { t in
            let env = exp(-t * 45)
            return 0.3 * env * (square(freq, t) * 0.7 + noise() * 0.3)
        }
    }

    /// 劈中确认：50ms 噪声劈裂 + 上行两音（E5→A5）
    private static func makeConfirm(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        render(0.26, format: format) { t in
            if t < 0.05 {
                return 0.35 * exp(-t * 60) * noise()   // 木质劈裂
            }
            let t2 = t - 0.05
            let (freq, local): (Double, Double) = t2 < 0.1 ? (659.25, t2) : (880, t2 - 0.1)
            return 0.3 * exp(-local * 12) * square(freq, local)
        }
    }

    /// combo 音：五声音阶（C D E G A）随 n 上行
    private static func makeCombo(n: Int, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let penta = [1.0, 9.0 / 8, 5.0 / 4, 3.0 / 2, 5.0 / 3]
        let idx = n - 2
        let freq = 523.25 * penta[idx % penta.count] * pow(2, Double(idx / penta.count))
        return render(0.15, format: format) { t in
            0.28 * exp(-t * 14) * square(freq, t)
        }
    }

    /// 甩头钝音：90Hz 正弦快衰减，低音量
    private static func makeThud(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        render(0.2, format: format) { t in
            0.25 * exp(-t * 18) * sin(2 * .pi * 90 * t)
        }
    }

    /// 胜利琶音：C5 E5 G5 C6 上行
    private static func makeVictory(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let notes = [523.25, 659.25, 783.99, 1046.5]
        return render(0.7, format: format) { t in
            let idx = min(Int(t / 0.15), notes.count - 1)
            let local = t - Double(idx) * 0.15
            return 0.32 * exp(-local * 8) * square(notes[idx], local)
        }
    }

    /// M2 格挡「铛」：不谐和双音（金属感）+ 起始噪声快衰减
    private static func makeBlock(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        render(0.22, format: format) { t in
            let metal = 0.2 * square(1567, t) + 0.12 * square(2217, t)
            let click = t < 0.01 ? 0.2 * noise() : 0
            return (metal + click) * exp(-t * 22)
        }
    }

    /// M3 接宝石「叮」：清亮高频正弦 + 泛音，余音稍长
    private static func makeGem(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        render(0.3, format: format) { t in
            (0.28 * sin(2 * .pi * 1318 * t) + 0.1 * sin(2 * .pi * 2636 * t)) * exp(-t * 10)
        }
    }

    /// M3 大宝石迸发：五音快速上行琶音
    private static func makeBurst(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let notes = [523.25, 659.25, 783.99, 1046.5, 1318.5]
        return render(0.5, format: format) { t in
            let idx = min(Int(t / 0.08), notes.count - 1)
            let local = t - Double(idx) * 0.08
            return 0.3 * exp(-local * 10) * square(notes[idx], local)
        }
    }

    /// M4 气功波发射：上行扫频方波 + 噪声爆发
    private static func makeQiBlast(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        render(0.4, format: format) { t in
            let freq = 220 * pow(4, t / 0.4)   // 220→880 指数扫频
            let sweep = 0.26 * square(freq, t) * exp(-t * 5)
            let puff = t < 0.06 ? 0.18 * noise() * exp(-t * 40) : 0
            return sweep + puff
        }
    }

    /// M5 锁定：锁链咔哒双击
    private static func makeLock(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        render(0.12, format: format) { t in
            let local = t < 0.07 ? t : t - 0.07
            guard local < 0.03 else { return 0 }
            return 0.3 * exp(-local * 90) * (square(1800, local) * 0.6 + noise() * 0.4)
        }
    }

    /// M5 放箭：弦响（快速衰减弹拨）
    private static func makeArrow(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        render(0.18, format: format) { t in
            let pluck = 0.3 * square(392, t) * exp(-t * 30)
            let snap = t < 0.015 ? 0.15 * noise() * exp(-t * 80) : 0
            return pluck + snap
        }
    }

    /// M5 蝙蝠坠落：下行滑音（900→180 指数下滑）
    private static func makeFall(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        render(0.45, format: format) { t in
            let freq = 900 * pow(0.2, t / 0.45)
            return 0.24 * sin(2 * .pi * freq * t) * exp(-t * 4)
        }
    }

    /// 蓄力循环音：220Hz 正弦 + 三次泛音，0.5s 整 110 周期无缝循环；rate 变调驱动音高上行
    private static func makeChargeLoop(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        render(0.5, format: format) { t in
            0.7 * sin(2 * .pi * 220 * t) + 0.3 * sin(2 * .pi * 660 * t)
        }
    }
}
