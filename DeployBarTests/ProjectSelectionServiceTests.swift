import Core
@testable import Features
import XCTest

final class ProjectSelectionServiceTests: XCTestCase {
    func testWatchedProjectsPreservesProjectTeamOwnershipWhenScopeIsPersonal() {
        let teams = [Team(id: "team_1", slug: "arthurbnhm-gtm", name: "GTM")]
        let availableProjects = [
            Project(id: "proj_1", name: "photomateai", teamId: "team_1", updatedAt: nil)
        ]

        let watched = ProjectSelectionService.watchedProjects(
            availableProjects: availableProjects,
            selectedIDs: ["proj_1"],
            selectedScope: .personal,
            teams: teams
        )

        XCTAssertEqual(watched.count, 1)
        XCTAssertEqual(watched[0].teamId, "team_1")
        XCTAssertEqual(watched[0].teamSlug, "arthurbnhm-gtm")
    }

    func testDashboardURLResolvesScopeFromTeamIDWhenSlugMissing() {
        let teams = [Team(id: "team_1", slug: "arthurbnhm-gtm", name: "GTM")]
        let watchedProject = WatchedProject(
            id: "proj_1",
            name: "photomateai",
            teamId: "team_1",
            teamSlug: nil
        )

        let dashboardURL = VercelLinks.projectDashboardURL(
            project: watchedProject,
            teams: teams,
            username: "arthurbnhm"
        )

        XCTAssertEqual(dashboardURL?.absoluteString, "https://vercel.com/arthurbnhm-gtm/photomateai")
    }
}
