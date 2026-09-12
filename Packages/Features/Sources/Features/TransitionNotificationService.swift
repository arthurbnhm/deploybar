import Core
import Foundation

enum TransitionNotificationService {
    static func process(
        transitions: [DeploymentTransition],
        settings: AppSettings,
        notificationRouter: NotificationRouting,
        soundPlayer: SoundPlayback
    ) async {
        guard !transitions.isEmpty else {
            return
        }

        for transition in transitions {
            guard !Task.isCancelled else { return }
            let userInfo = [
                "projectId": transition.project.id,
                "deploymentId": transition.current.id
            ]

            switch transition.current.stage {
            case .ready:
                if settings.notificationsEnabled {
                    await notificationRouter.notify(
                        title: "DeployBar: Success",
                        body: "\(transition.project.name) deployed successfully.",
                        userInfo: userInfo
                    )
                }
                if settings.soundsEnabled, !Task.isCancelled {
                    soundPlayer.play(.success, theme: settings.soundTheme)
                }

            case .failed:
                if settings.notificationsEnabled {
                    await notificationRouter.notify(
                        title: "DeployBar: Failed",
                        body: "\(transition.project.name) deployment failed.",
                        userInfo: userInfo
                    )
                }
                if settings.soundsEnabled, !Task.isCancelled {
                    soundPlayer.play(.failure, theme: settings.soundTheme)
                }

            default:
                continue
            }
        }
    }
}
