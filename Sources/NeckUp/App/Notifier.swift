import Foundation
import UserNotifications

/// 系统通知封装（提醒降级、番茄钟结束）
enum Notifier {
    static func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true {
            content.sound = .default
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
