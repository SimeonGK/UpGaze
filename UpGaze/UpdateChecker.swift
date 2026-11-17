import AppKit
import Foundation

/// Checks the latest GitHub release against the running app's version.
@MainActor
final class UpdateChecker: ObservableObject {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(version: String)
        case noRelease
        case failed
    }

    static let shared = UpdateChecker()

    static let repository = "SimeonGK/UpGaze"
    static let latestReleaseURL = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    static let downloadURL = URL(string: "https://github.com/\(repository)/releases/latest/download/UpGaze.dmg")!

    @Published private(set) var status: Status = .idle

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func check() {
        guard status != .checking else { return }
        status = .checking
        Task {
            status = await fetchStatus()
        }
    }

    func openDownload() {
        NSWorkspace.shared.open(Self.downloadURL)
    }

    private func fetchStatus() async -> Status {
        struct Release: Decodable {
            let tagName: String

            enum CodingKeys: String, CodingKey {
                case tagName = "tag_name"
            }
        }

        var request = URLRequest(url: Self.latestReleaseURL, timeoutInterval: 15)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        // GitHub's API rejects requests without a User-Agent.
        request.setValue("UpGaze", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            switch (response as? HTTPURLResponse)?.statusCode {
            case 200:
                break
            // GitHub answers 404 on /releases/latest while the repository has no published release.
            case 404:
                return .noRelease
            default:
                return .failed
            }
            let latest = Self.normalized(try JSONDecoder().decode(Release.self, from: data).tagName)
            return Self.isVersion(latest, newerThan: currentVersion)
                ? .updateAvailable(version: latest)
                : .upToDate
        } catch {
            return .failed
        }
    }

    /// Strips a leading "v", so the tag "v1.0.1" becomes "1.0.1".
    nonisolated static func normalized(_ tag: String) -> String {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.lowercased().hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
    }

    /// Semantic-version precedence: numeric major.minor.patch, then a release outranks its own
    /// pre-releases ("1.1.0" is newer than "1.1.0-beta"). Build metadata after "+" is ignored.
    nonisolated static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let lhs = parse(candidate)
        let rhs = parse(current)

        for index in 0..<max(lhs.core.count, rhs.core.count) {
            let left = index < lhs.core.count ? lhs.core[index] : 0
            let right = index < rhs.core.count ? rhs.core[index] : 0
            if left != right { return left > right }
        }

        if lhs.prerelease.isEmpty || rhs.prerelease.isEmpty {
            return lhs.prerelease.isEmpty && !rhs.prerelease.isEmpty
        }
        for (left, right) in zip(lhs.prerelease, rhs.prerelease) where left != right {
            switch (Int(left), Int(right)) {
            case let (l?, r?): return l > r
            case (nil, _?): return true
            case (_?, nil): return false
            case (nil, nil): return left > right
            }
        }
        return lhs.prerelease.count > rhs.prerelease.count
    }

    private nonisolated static func parse(_ version: String) -> (core: [Int], prerelease: [String]) {
        let withoutBuild = normalized(version).split(separator: "+", maxSplits: 1).first.map(String.init) ?? ""
        let parts = withoutBuild.split(separator: "-", maxSplits: 1).map(String.init)
        let core = (parts.first ?? "").split(separator: ".").map { Int($0) ?? 0 }
        let prerelease = parts.count > 1 ? parts[1].split(separator: ".").map(String.init) : []
        return (core, prerelease)
    }
}
