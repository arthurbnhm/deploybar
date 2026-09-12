import Foundation
import Observation

@MainActor
@Observable
public final class DeployBarStartup {
    public private(set) var store: DeployBarAppStore?
    public private(set) var errorMessage: String?
    private let makeEnvironment: () throws -> DeployBarEnvironment

    public init(makeEnvironment: @escaping () throws -> DeployBarEnvironment = DeployBarEnvironment.live) {
        self.makeEnvironment = makeEnvironment
        retry()
    }

    public func retry() {
        guard store == nil else { return }
        do {
            let environment = try makeEnvironment()
            let store = DeployBarAppStore(environment: environment)
            self.store = store
            errorMessage = nil
            store.start()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
