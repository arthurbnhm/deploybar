import Core
import Foundation

enum VercelLinks {
    private static let pathComponentAllowed: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: "/")
        return set
    }()

    static func projectDashboardURL(project: WatchedProject, username: String?) -> URL? {
        let scope = project.teamSlug ?? username
        guard let scope, !scope.isEmpty else {
            return nil
        }

        let encodedScope = encode(scope)
        let encodedProject = encode(project.name)
        return URL(string: "https://vercel.com/\(encodedScope)/\(encodedProject)")
    }

    private static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: pathComponentAllowed) ?? value
    }
}
