import Foundation

/// 轻量更新检查：GitHub Releases API 比对版本号（无第三方依赖）
@MainActor
final class UpdateChecker: ObservableObject {
    enum Result {
        case newer(String)   // 有新版（版本号）
        case upToDate
        case failed
        case devBuild        // swift run 开发模式，无版本信息
    }

    /// 非 nil = 有更新可用（菜单项标题据此变化）
    @Published private(set) var latestVersion: String?

    static let releasePageURL = URL(string: "https://github.com/mikkley/neckup/releases/latest")!
    static let brewCommand = "brew upgrade --cask neckup"
    private static let apiURL = URL(string: "https://api.github.com/repos/mikkley/neckup/releases/latest")!
    private static let lastCheckKey = "lastUpdateCheckAt"

    /// 当前版本（swift run 无 Info.plist → nil）
    var currentVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    /// 启动时静默检查：24h 节流；开发构建跳过
    func checkAutomatically() {
        guard currentVersion != nil else { return }
        let last = UserDefaults.standard.double(forKey: Self.lastCheckKey)
        guard Date().timeIntervalSince1970 - last > 24 * 3600 else { return }
        Task { _ = await self.check() }
    }

    /// 请求 GitHub 比对版本；成功且有新版时写入 latestVersion
    @discardableResult
    func check() async -> Result {
        guard let current = currentVersion else { return .devBuild }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheckKey)
        do {
            var req = URLRequest(url: Self.apiURL)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.timeoutInterval = 10
            let (data, _) = try await URLSession.shared.data(for: req)
            struct Payload: Decodable { let tag_name: String }
            let tag = try JSONDecoder().decode(Payload.self, from: data).tag_name
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            guard Self.isNewer(latest, than: current) else { return .upToDate }
            latestVersion = latest
            return .newer(latest)
        } catch {
            return .failed
        }
    }

    /// 语义化版本比较：1.10.0 > 1.9.0
    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0 ..< max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
