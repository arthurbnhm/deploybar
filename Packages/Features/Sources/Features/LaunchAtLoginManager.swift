import Core
import Foundation
import ServiceManagement

public final class LaunchAtLoginManager: LaunchAtLoginControlling {
    public init() {}

    public func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp

        if enabled {
            if service.status != .enabled {
                try service.register()
            }
        } else {
            if service.status == .enabled {
                try service.unregister()
            }
        }
    }

    public func status() -> Bool {
        SMAppService.mainApp.status == .enabled
    }
}
