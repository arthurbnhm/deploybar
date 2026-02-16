import Core
import Foundation

enum ProjectSelectionService {
    static func sortedProjects(_ projects: [Project]) -> [Project] {
        projects.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    static func visibleSelectedIDs(selectedIDs: Set<String>, availableProjects: [Project]) -> Set<String> {
        let visibleIDs = Set(availableProjects.map(\.id))
        return selectedIDs.intersection(visibleIDs)
    }

    static func toggledSelection(
        current: Set<String>,
        projectID: String,
        limit: Int
    ) -> Result<Set<String>, SelectionError> {
        var next = current
        if next.contains(projectID) {
            next.remove(projectID)
            return .success(next)
        }

        guard next.count < limit else {
            return .failure(.limitReached)
        }

        next.insert(projectID)
        return .success(next)
    }

    static func watchedProjects(
        availableProjects: [Project],
        selectedIDs: Set<String>,
        selectedScope: TeamScope,
        teams: [Team]
    ) -> [WatchedProject] {
        let selectedProjects = availableProjects.filter { selectedIDs.contains($0.id) }

        return selectedProjects.map {
            let resolvedTeamID = $0.teamId ?? selectedScope.teamId
            let resolvedTeamSlug = teams.first(where: { $0.id == resolvedTeamID })?.slug
                ?? {
                    if case let .team(_, slug) = selectedScope {
                        return slug
                    }
                    return nil
                }()

            return WatchedProject(
                id: $0.id,
                name: $0.name,
                teamId: resolvedTeamID,
                teamSlug: resolvedTeamSlug
            )
        }
    }

    enum SelectionError: Error {
        case limitReached
    }
}
