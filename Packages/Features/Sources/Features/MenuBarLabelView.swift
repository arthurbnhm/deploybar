import Core
import SwiftUI

public struct MenuBarLabelView: View {
    let aggregateStatus: AggregateStatus

    public init(aggregateStatus: AggregateStatus) {
        self.aggregateStatus = aggregateStatus
    }

    public var body: some View {
        Image(systemName: "triangle.fill")
            .font(.system(size: 11.5))
            .foregroundStyle(aggregateStatus.tint)
            .symbolEffect(.pulse, isActive: aggregateStatus == .building)
            .accessibilityLabel("DeployBar: \(aggregateStatus.label)")
    }
}
