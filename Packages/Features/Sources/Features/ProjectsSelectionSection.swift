import Core
import SwiftUI

struct ProjectsSelectionSection: View {
    @ObservedObject var store: DeployBarAppStore
    let persistSelectionChanges: Bool

    @State private var showProjectPicker = false
    @State private var projectSearchText = ""

    init(
        store: DeployBarAppStore,
        persistSelectionChanges: Bool
    ) {
        self.store = store
        self.persistSelectionChanges = persistSelectionChanges
    }

    private var watchedProjects: [Project] {
        store.availableProjects
            .filter { store.selectedProjectIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var unwatchedProjects: [Project] {
        store.availableProjects
            .filter { !store.selectedProjectIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filteredUnwatchedProjects: [Project] {
        if projectSearchText.isEmpty {
            return unwatchedProjects
        }

        return unwatchedProjects.filter {
            $0.name.localizedCaseInsensitiveContains(projectSearchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.sectionSpacing) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Scope")
                        .font(.system(size: 13, weight: .semibold))

                    Spacer()

                    Picker("Scope", selection: $store.selectedScope) {
                        Text("Personal").tag(TeamScope.personal)
                        ForEach(store.teams) { team in
                            Text(team.name).tag(TeamScope.team(id: team.id, slug: team.slug))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: store.selectedScope) { _, _ in
                        Task {
                            await store.refreshProjectsForScope()
                            if persistSelectionChanges {
                                store.updateWatchedProjects()
                            }
                        }
                    }
                }

                Text("Choose which account or team to load projects from.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Watched Projects")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(store.selectedProjectIDs.count) / 20")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if !watchedProjects.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(watchedProjects) { project in
                            ProjectChip(name: project.name) {
                                toggleProject(project.id)
                            }
                        }
                    }
                    .animation(.snappy(duration: 0.25), value: store.selectedProjectIDs)
                }

                if !unwatchedProjects.isEmpty {
                    Button {
                        projectSearchText = ""
                        showProjectPicker.toggle()
                    } label: {
                        Label("Add Project", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .popover(isPresented: $showProjectPicker, arrowEdge: .bottom) {
                        projectPickerPopover
                    }
                }

                if watchedProjects.isEmpty {
                    if store.availableProjects.isEmpty {
                        Label("No projects found for this scope.", systemImage: "tray")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Add at least one project to start monitoring.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                if store.selectedProjectIDs.count >= 20 {
                    Text("Project limit reached. Remove one project before adding another.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var projectPickerPopover: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)

                TextField("Search projects...", text: $projectSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if filteredUnwatchedProjects.isEmpty {
                Text(projectSearchText.isEmpty ? "All projects are watched." : "No matching projects.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredUnwatchedProjects) { project in
                            Button {
                                toggleProject(project.id)
                            } label: {
                                HStack(spacing: 8) {
                                    Text(project.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .lineLimit(1)

                                    Spacer()

                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.tint)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                }
                .frame(maxHeight: 260)
            }
        }
        .frame(width: 280)
    }

    private func toggleProject(_ projectID: String) {
        withAnimation(.snappy(duration: 0.25)) {
            store.toggleProjectSelection(projectID)
            if persistSelectionChanges {
                store.updateWatchedProjects()
            }
        }
    }
}

struct ProjectChip: View {
    let name: String
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 5) {
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(isHovered ? 0.12 : 0.06))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.black.opacity(isHovered ? 0.10 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
        )
        .onHover { isHovered = $0 }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(in: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(in maxWidth: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
