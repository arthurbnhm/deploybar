import Core
import Foundation
import UserNotifications

public actor MacNotificationRouter: NotificationRouting {
    public init() {}

    public func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    public func notify(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().add(request) { _ in
                continuation.resume(returning: ())
            }
        }
    }
}
