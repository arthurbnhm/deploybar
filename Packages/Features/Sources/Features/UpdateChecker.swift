import Foundation

/// Outcome of comparing the currently running app version against the latest GitHub release.
public enum UpdateAvailability: Equatable {
    case upToDate
    case updateAvailable(latestVersion: String, releaseURL: URL)
    case checkFailed(String)
}

/// Minimal update checker: polls the GitHub Releases API and compares versions.
///
/// This is a prototype for Plan 009 (spike). It does not download or install anything —
/// it only tells the user a newer release exists and hands them a link to it. See
/// `plans-findings-009.md` for the Sparkle-vs-minimal-checker decision this stands in for.
public enum UpdateChecker {
    /// GitHub REST API endpoint for the latest non-draft, non-prerelease release.
    public static let latestReleaseAPIURL = URL(
        string: "https://api.github.com/repos/arthurbnhm/DeployBar/releases/latest"
    )!

    struct LatestReleaseResponse: Decodable {
        let tagName: String
        let htmlURL: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    /// The version of the app that is currently running, read from the app bundle's
    /// `CFBundleShortVersionString` (set from `APP_VERSION` / the `VERSION` file at
    /// package time — see `scripts/install_app.sh`). Falls back to "0.0.0" outside of
    /// a real app bundle (e.g. `swift test`, previews).
    public static var runningVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Parses a dot-separated numeric version, tolerating an optional leading "v"/"V".
    /// Returns nil for anything that isn't purely numeric components (a malformed tag).
    static func parseVersion(_ raw: String) -> [Int]? {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            trimmed.removeFirst()
        }
        guard !trimmed.isEmpty else {
            return nil
        }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        var components: [Int] = []
        for part in parts {
            guard let value = Int(part) else {
                return nil
            }
            components.append(value)
        }
        return components
    }

    /// Returns true when `remote` is a strictly newer version than `current`.
    /// Malformed input on either side fails closed (never reports "newer") so a bad
    /// or unexpected tag can never trigger an update prompt.
    static func isNewer(remote: String, current: String) -> Bool {
        guard let remoteParts = parseVersion(remote), let currentParts = parseVersion(current) else {
            return false
        }

        let length = max(remoteParts.count, currentParts.count)
        for index in 0..<length {
            let remoteValue = index < remoteParts.count ? remoteParts[index] : 0
            let currentValue = index < currentParts.count ? currentParts[index] : 0
            if remoteValue != currentValue {
                return remoteValue > currentValue
            }
        }
        return false
    }

    /// Fetches the latest GitHub release and compares its tag against `currentVersion`.
    /// `session` is injectable for future test coverage; today's tests exercise only the
    /// pure `isNewer`/`parseVersion` logic above and never call this function, per the
    /// spike's "no real network calls in tests" requirement.
    public static func checkForUpdate(
        currentVersion: String,
        session: URLSession = .shared
    ) async -> UpdateAvailability {
        var request = URLRequest(url: latestReleaseAPIURL)
        request.setValue("DeployBar/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return .checkFailed("Couldn't reach GitHub Releases.")
            }

            let payload = try JSONDecoder().decode(LatestReleaseResponse.self, from: data)
            guard let releaseURL = URL(string: payload.htmlURL) else {
                return .checkFailed("GitHub returned an invalid release URL.")
            }

            if isNewer(remote: payload.tagName, current: currentVersion) {
                return .updateAvailable(latestVersion: payload.tagName, releaseURL: releaseURL)
            }
            return .upToDate
        } catch {
            return .checkFailed("Couldn't check for updates.")
        }
    }
}
