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
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return .failed }
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

    /// Compares major.minor.patch numerically; a pre-release or build suffix ("-beta", "+5") is ignored.
    nonisolated static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        func components(_ version: String) -> [Int] {
            let core = normalized(version).split(whereSeparator: { $0 == "-" || $0 == "+" }).first ?? ""
            return core.split(separator: ".").map { Int($0) ?? 0 }
        }

        let lhs = components(candidate)
        let rhs = components(current)
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return false
    }
}
