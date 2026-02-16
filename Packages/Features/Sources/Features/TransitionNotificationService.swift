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
            switch transition.current.stage {
            case .ready:
                if settings.notificationsEnabled {
                    await notificationRouter.notify(
                        title: "DeployBar: Success",
                        body: "\(transition.project.name) deployed successfully."
                    )
                }
                if settings.soundsEnabled {
                    soundPlayer.playSuccess()
                }

            case .failed:
                if settings.notificationsEnabled {
                    await notificationRouter.notify(
                        title: "DeployBar: Failed",
                        body: "\(transition.project.name) deployment failed."
                    )
                }
                if settings.soundsEnabled {
                    soundPlayer.playFailure()
                }

            default:
                continue
            }
        }
    }
}
