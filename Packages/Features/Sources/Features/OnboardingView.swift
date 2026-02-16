import Core
import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case connect
    case projects
    case review

    var index: Int { rawValue + 1 }

    var title: String {
        switch self {
        case .connect: "Connect Your Account"
        case .projects: "Choose Watched Projects"
        case .review: "Review & Start"
        }
    }

    var subtitle: String {
        switch self {
        case .connect: "Add a Vercel access token to unlock your teams and projects."
        case .projects: "Pick the scope and projects DeployBar should monitor."
        case .review: "Confirm your setup and start monitoring deployments."
        }
    }

    var primaryActionTitle: String {
        switch self {
        case .connect: "Continue"
        case .projects: "Continue"
        case .review: "Start Monitoring"
        }
    }
}

public struct OnboardingView: View {
    @ObservedObject var store: DeployBarAppStore
    @State private var step: OnboardingStep = .connect
    @State private var isCompleting = false

    public init(store: DeployBarAppStore) {
        self.store = store
    }

    private var selectedProjects: [Project] {
        store.availableProjects
            .filter { store.selectedProjectIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerCard
                wizardCard

                if let error = store.tokenError {
                    ErrorInlineBanner(message: error)
                }
            }
            .padding(24)
            .frame(width: 620)
        }
        .onAppear {
            syncStepToCurrentState(animated: false)
        }
        .onChange(of: store.authUser?.id) { _, _ in
            syncStepToCurrentState(animated: true)
        }
        .onChange(of: store.selectedProjectIDs) { _, _ in
            if step == .review, store.selectedProjectIDs.isEmpty {
                withAnimation(.snappy(duration: 0.2)) {
                    step = .projects
                }
            }
        }
    }

    private var headerCard: some View {
        AppCard {
            HStack(spacing: 12) {
                Image(systemName: "triangle.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("DeployBar")
                    .font(.system(size: 42, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var wizardCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: DesignSystem.sectionSpacing) {
                wizardHeader

                SubtleDivider()

                stepContent

                SubtleDivider()

                wizardFooter
            }
        }
    }

    private var wizardHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Step \(step.index) of \(OnboardingStep.allCases.count)")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 6) {
                    ForEach(OnboardingStep.allCases, id: \.self) { item in
                        Capsule(style: .continuous)
                            .fill(item.rawValue <= step.rawValue ? Color.accentColor.opacity(0.75) : DesignSystem.stepProgressTrack)
                            .frame(width: item == step ? 26 : 14, height: 5)
                    }
                }
                .animation(.snappy(duration: 0.2), value: step)
            }

            Text(step.title)
                .font(.system(size: 22, weight: .bold))

            Text(step.subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .connect:
            connectStepContent
        case .projects:
            ProjectsSelectionSection(
                store: store,
                persistSelectionChanges: false
            )
        case .review:
            reviewStepContent
        }
    }

    private var connectStepContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vercel Access Token")
                .font(.system(size: 13, weight: .semibold))

            HStack(spacing: 8) {
                SecureField("Paste your token...", text: $store.tokenInput)
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task {
                        await store.connectToken()
                        if store.authUser != nil {
                            syncStepToCurrentState(animated: true)
                        }
                    }
                } label: {
                    if store.isValidatingToken {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(store.authUser == nil ? "Connect" : "Connected")
                            .frame(minWidth: 82)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isValidatingToken || store.authUser != nil)
            }

            if let user = store.authUser {
                Label("Connected as @\(user.username)", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.green)
            }
        }
    }

    private var reviewStepContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ReviewLine(title: "Account", value: "@\(store.authUser?.username ?? "Not connected")")
            ReviewLine(title: "Scope", value: selectedScopeLabel)
            ReviewLine(title: "Watched Projects", value: "\(store.selectedProjectIDs.count) / 20")

            if selectedProjects.isEmpty {
                Text("No projects selected yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(selectedProjects.prefix(4))) { project in
                        Text("- \(project.name)")
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }

                    if selectedProjects.count > 4 {
                        Text("+\(selectedProjects.count - 4) more")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var wizardFooter: some View {
        HStack {
            if step != .connect {
                Button("Back") {
                    guard let previousStep = OnboardingStep(rawValue: step.rawValue - 1) else {
                        return
                    }
                    withAnimation(.snappy(duration: 0.2)) {
                        step = previousStep
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button {
                handlePrimaryAction()
            } label: {
                if isCompleting {
                    ProgressView()
                        .controlSize(.small)
                        .frame(minWidth: 28)
                } else {
                    Text(step.primaryActionTitle)
                        .frame(minWidth: 112)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(primaryActionDisabled)
        }
    }

    private var primaryActionDisabled: Bool {
        switch step {
        case .connect:
            return store.authUser == nil
        case .projects:
            return store.selectedProjectIDs.isEmpty
        case .review:
            return !store.canFinishOnboarding || isCompleting
        }
    }

    private var selectedScopeLabel: String {
        switch store.selectedScope {
        case .personal:
            return "Personal"
        case let .team(id, slug):
            return store.teams.first(where: { $0.id == id })?.name ?? slug
        }
    }

    private func handlePrimaryAction() {
        switch step {
        case .connect:
            withAnimation(.snappy(duration: 0.2)) {
                step = .projects
            }
        case .projects:
            withAnimation(.snappy(duration: 0.2)) {
                step = .review
            }
        case .review:
            isCompleting = true
            Task {
                await store.completeOnboarding()
                isCompleting = false
            }
        }
    }

    private func syncStepToCurrentState(animated: Bool) {
        let target: OnboardingStep
        if store.authUser == nil {
            target = .connect
        } else if store.selectedProjectIDs.isEmpty {
            target = .projects
        } else if step == .connect {
            target = .projects
        } else {
            target = step
        }

        if animated {
            withAnimation(.snappy(duration: 0.2)) {
                step = target
            }
        } else {
            step = target
        }
    }
}

private struct ReviewLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
