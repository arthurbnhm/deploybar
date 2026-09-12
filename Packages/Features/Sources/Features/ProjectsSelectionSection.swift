import Core
import Observation
import SwiftUI

/// Emits the "Scope" and "Watched Projects" form sections.
/// Place directly inside a `Form` (not wrapped in another `Section`).
struct ProjectsSelectionSection: View {
    @Bindable var store: DeployBarAppStore
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

    var body: some View {
        if store.authUser == nil {
            Section {
                Label("Connect your Vercel account to load teams and projects.", systemImage: "key.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            let buckets = projectBuckets()

            Section {
                Picker("Scope", selection: $store.selectedScope) {
                    Text("Personal").tag(TeamScope.personal)
                    ForEach(store.teams) { team in
                        Text(team.name).tag(TeamScope.team(id: team.id, slug: team.slug))
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: store.selectedScope) { _, _ in
                    Task {
                        let refreshed = await store.refreshProjectsForScope()
                        if refreshed, persistSelectionChanges {
                            store.updateWatchedProjects()
                        }
                    }
                }
            } footer: {
                Text("Choose which account or team to load projects from.")
            }

            Section {
                if !buckets.watched.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(buckets.watched) { project in
                            ProjectChip(name: project.name) {
                                toggleProject(project.id)
                            }
                        }
                    }
                    .animation(.snappy(duration: 0.25), value: store.selectedProjectIDs)
                    .padding(.vertical, 2)
                }

                if buckets.watched.isEmpty {
                    if store.availableProjects.isEmpty {
                        Label("No projects found for this scope.", systemImage: "tray")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Add at least one project to start monitoring.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if !buckets.unwatched.isEmpty {
                    Button {
                        projectSearchText = ""
                        showProjectPicker.toggle()
                    } label: {
                        Label("Add Project…", systemImage: "plus")
                    }
                    .controlSize(.small)
                    .popover(isPresented: $showProjectPicker, arrowEdge: .bottom) {
                        projectPickerPopover
                    }
                }
            } header: {
                HStack {
                    Text("Watched Projects")

                    Spacer()

                    Text("\(store.selectedProjectIDs.count) of 20")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } footer: {
                if store.selectedProjectIDs.count >= 20 {
                    Text("Project limit reached. Remove one project before adding another.")
                }
            }
        }
    }

    private var projectPickerPopover: some View {
        let filteredProjects = projectBuckets().filteredUnwatched

        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.callout)
                    .foregroundStyle(.tertiary)

                TextField("Search projects…", text: $projectSearchText)
                    .textFieldStyle(.plain)
                    .font(.body)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if filteredProjects.isEmpty {
                Text(projectSearchText.isEmpty ? "All projects are watched." : "No matching projects.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredProjects) { project in
                            ProjectPickerRow(name: project.name) {
                                toggleProject(project.id)
                            }
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

    private func projectBuckets() -> ProjectBuckets {
        let sortedProjects = store.availableProjects.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        var watched: [Project] = []
        var unwatched: [Project] = []
        watched.reserveCapacity(sortedProjects.count)
        unwatched.reserveCapacity(sortedProjects.count)

        for project in sortedProjects {
            if store.selectedProjectIDs.contains(project.id) {
                watched.append(project)
            } else {
                unwatched.append(project)
            }
        }

        let filteredUnwatched: [Project]
        if projectSearchText.isEmpty {
            filteredUnwatched = unwatched
        } else {
            filteredUnwatched = unwatched.filter {
                $0.name.localizedStandardContains(projectSearchText)
            }
        }

        return ProjectBuckets(
            watched: watched,
            unwatched: unwatched,
            filteredUnwatched: filteredUnwatched
        )
    }
}

private struct ProjectBuckets {
    let watched: [Project]
    let unwatched: [Project]
    let filteredUnwatched: [Project]
}

private struct ProjectPickerRow: View {
    let name: String
    let onAdd: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 8) {
                Text(name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.tint)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                in: .rect(cornerRadius: 6)
            )
            .contentShape(.rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct ProjectChip: View {
    let name: String
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 5) {
            Text(name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
                    .background(.quaternary, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(name)")
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 5)
        .background(
            isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.quinary),
            in: .capsule
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
