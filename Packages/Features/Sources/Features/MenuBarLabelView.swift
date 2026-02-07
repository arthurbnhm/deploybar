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
            .foregroundStyle(statusColor)
            .symbolEffect(.pulse, isActive: aggregateStatus == .building)
            .accessibilityLabel("DeployBar: \(aggregateStatus.label)")
    }

    private var statusColor: Color {
        switch aggregateStatus {
        case .healthy:
            Color(red: 0.20, green: 0.78, blue: 0.48)
        case .building:
            Color(red: 0.96, green: 0.65, blue: 0.14)
        case .failed:
            Color(red: 0.94, green: 0.32, blue: 0.28)
        case .unknown:
            Color(red: 0.56, green: 0.56, blue: 0.58)
        }
    }
}
