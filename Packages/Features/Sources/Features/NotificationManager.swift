import Core
import Foundation
import UserNotifications

public actor MacNotificationRouter: NotificationRouting {
    private var center: UNUserNotificationCenter?
    private let delegate = NotificationCenterDelegate()

    public init(center: UNUserNotificationCenter? = nil) {
        self.center = center
    }

    public func requestAuthorization() async -> Bool {
        guard let center = notificationCenterIfAvailable() else {
            return false
        }

        return await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    public func notify(title: String, body: String) async {
        guard let center = notificationCenterIfAvailable() else {
            return
        }

        let status = await authorizationStatus()
        switch status {
        case .notDetermined:
            let granted = await requestAuthorization()
            guard granted else { return }
        case .authorized, .provisional, .ephemeral:
            break
        case .denied:
            return
        @unknown default:
            return
        }

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
            center.add(request) { _ in
                continuation.resume(returning: ())
            }
        }
    }

    private func authorizationStatus() async -> UNAuthorizationStatus {
        guard let center = notificationCenterIfAvailable() else {
            return .denied
        }

        return await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    private func notificationCenterIfAvailable() -> UNUserNotificationCenter? {
        if let center {
            return center
        }

        // UNUserNotificationCenter.current() throws an NSException when the process
        // is not launched from an .app bundle (for example `swift run` debug binary).
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            return nil
        }

        let resolvedCenter = UNUserNotificationCenter.current()
        resolvedCenter.delegate = delegate
        center = resolvedCenter
        return resolvedCenter
    }
}

private final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
    }
}
