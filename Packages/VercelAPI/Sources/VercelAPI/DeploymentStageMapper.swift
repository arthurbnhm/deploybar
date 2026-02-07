import Core
import Foundation

enum DeploymentStageMapper {
    static func map(state: String?, readyState: String?) -> DeploymentStage {
        let stateValue = (state ?? "").lowercased()
        let readyValue = (readyState ?? "").lowercased()

        if ["error", "failed", "failure"].contains(readyValue) || ["error", "failed"].contains(stateValue) {
            return .failed
        }

        if ["canceled", "cancelled"].contains(readyValue) || ["canceled", "cancelled"].contains(stateValue) {
            return .canceled
        }

        if ["ready", "succeeded", "success"].contains(readyValue) || stateValue == "ready" {
            return .ready
        }

        if ["building", "deploying"].contains(readyValue)
            || ["building", "queued", "initializing", "deploying"].contains(stateValue)
        {
            return .building
        }

        if ["queued", "pending"].contains(readyValue) {
            return .queued
        }

        return .unknown
    }
}
