import AppKit
import Security

/// Looks for new SpotKeys releases on GitHub once a day and installs them when the user agrees.
final class Updater {
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    private let defaults = UserDefaults.standard
    private var timer: Timer?

    /// What the updater is busy with, for the menu. Nil while idle.
    private(set) var status: String?

    var checksAutomatically: Bool {
        get { defaults.bool(forKey: "checkForUpdates") }
        set {
            defaults.set(newValue, forKey: "checkForUpdates")
            checkIfDue()
        }
    }

    func start() {
        checkIfDue()
        // SpotKeys runs for weeks at a time, so look every hour whether a day has passed.
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            self?.checkIfDue()
        }
        timer?.tolerance = 10 * 60
    }

    func checkNow() { check(userInitiated: true) }

    private func checkIfDue() {
        let lastCheck = defaults.object(forKey: "lastUpdateCheck") as? Date ?? .distantPast
        if checksAutomatically, Date().timeIntervalSince(lastCheck) >= Self.checkInterval {
            check(userInitiated: false)
        }
    }

    private func check(userInitiated: Bool) {
        guard status == nil else { return }
        status = String(localized: "Checking for Updates…")
        Task { @MainActor in
            let release: Release
            do {
                release = try await UpdateInstaller.latestRelease()
            } catch {
                status = nil
                // Automatic checks fail silently, e.g. while offline, and try again in an hour.
                if userInitiated { showFailure(String(localized: "Couldn’t Check for Updates"), error) }
                return
            }
            status = nil
            defaults.set(Date(), forKey: "lastUpdateCheck")

            if release.version > .current {
                offer(release)
            } else if userInitiated {
                let alert = NSAlert()
                alert.messageText = String(localized: "SpotKeys Is Up to Date")
                alert.informativeText = String(localized: "Version \(Version.current.description) is the newest version.")
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
        }
    }

    private func offer(_ release: Release) {
        let alert = NSAlert()
        alert.messageText = String(localized: "SpotKeys \(release.version.description) Is Available")
        alert.informativeText = String(localized: "You have version \(Version.current.description). SpotKeys downloads the update, checks that it’s signed by the same developer and restarts.")
        alert.addButton(withTitle: String(localized: "Install and Restart"))
        alert.addButton(withTitle: String(localized: "Later"))
        alert.addButton(withTitle: String(localized: "Release Notes"))
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn: install(release)
        case .alertThirdButtonReturn: NSWorkspace.shared.open(release.page)
        default: break
        }
    }

    private func install(_ release: Release) {
        status = String(localized: "Installing SpotKeys \(release.version.description)…")
        let app = Bundle.main.bundleURL
        Task { @MainActor in
            do {
                let newApp = try await UpdateInstaller.download(release, replacing: app)
                _ = try FileManager.default.replaceItemAt(app, withItemAt: newApp)
                try? FileManager.default.removeItem(at: newApp.deletingLastPathComponent())
                relaunch()
            } catch {
                status = nil
                showFailure(String(localized: "Couldn’t Update SpotKeys"), error, page: release.page)
            }
        }
    }

    /// Quits and opens the newly installed version once this process is gone.
    private func relaunch() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "while /bin/kill -0 \"$1\" 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$2\"",
                             "sh", String(ProcessInfo.processInfo.processIdentifier), Bundle.main.bundlePath]
        try? process.run()
        NSApp.terminate(nil)
    }

    private func showFailure(_ title: String, _ error: Error, page: URL? = nil) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: String(localized: "OK"))
        if page != nil { alert.addButton(withTitle: String(localized: "Download Manually…")) }
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn, let page { NSWorkspace.shared.open(page) }
    }
}

/// A plain major.minor.patch version, as used by the release tags.
struct Version: Comparable, CustomStringConvertible {
    let components: [Int]

    static let current = Version(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
        ?? Version(components: [0, 0, 0])

    init(components: [Int]) { self.components = components }

    init?(_ string: String) {
        let parts = string.drop(while: { $0 == "v" }).split(separator: ".", omittingEmptySubsequences: false)
        let numbers = parts.compactMap { Int($0) }
        guard numbers.count == 3, parts.count == 3 else { return nil }
        components = numbers
    }

    static func < (lhs: Version, rhs: Version) -> Bool {
        lhs.components.lexicographicallyPrecedes(rhs.components)
    }

    var description: String { components.map(String.init).joined(separator: ".") }
}

struct Release {
    let version: Version
    let page: URL
    let download: URL?
}

enum UpdateError: LocalizedError {
    case badResponse
    case missingDownload
    case notSigned
    case translocated
    case notWritable(String)
    case diskImage
    case untrusted
    case notNotarized

    var errorDescription: String? {
        switch self {
        case .badResponse:
            String(localized: "GitHub didn’t return the latest release. Try again later.")
        case .missingDownload:
            String(localized: "The release has no SpotKeys download.")
        case .notSigned:
            String(localized: "This copy of SpotKeys isn’t signed with a Developer ID, so it can’t update itself.")
        case .translocated:
            String(localized: "Move SpotKeys to the Applications folder and open it from there, then try again.")
        case .notWritable(let folder):
            String(localized: "SpotKeys isn’t allowed to replace itself in \(folder).")
        case .diskImage:
            String(localized: "The downloaded disk image couldn’t be opened.")
        case .untrusted:
            String(localized: "The download isn’t signed by the SpotKeys developer, so it wasn’t installed.")
        case .notNotarized:
            String(localized: "macOS doesn’t accept the download as notarized, so it wasn’t installed.")
        }
    }
}

/// Fetches releases and checks them thoroughly before anything on disk is replaced.
enum UpdateInstaller {
    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/Diddern/SpotKeys/releases/latest")!
    // No cookies, cache or credentials: each request stands alone.
    private static let session = URLSession(configuration: .ephemeral)

    private struct GitHubRelease: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: URL
        }
        let tagName: String
        let htmlUrl: URL
        let assets: [Asset]
    }

    static func latestRelease() async throws -> Release {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.badResponse }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let release = try? decoder.decode(GitHubRelease.self, from: data),
              let version = Version(release.tagName)
        else { throw UpdateError.badResponse }
        // release.yml names the disk image after the version.
        let dmg = release.assets.first { $0.name == "SpotKeys-\(version).dmg" }
        return Release(version: version, page: release.htmlUrl, download: dmg?.browserDownloadUrl)
    }

    /// Downloads and verifies the release, and returns the new app, ready to move in place of `app`.
    ///
    /// The new app must be signed with a Developer ID from the same team as the running app,
    /// notarized, and contain exactly the version the release claims.
    static func download(_ release: Release, replacing app: URL,
                         team: String? = ownTeamIdentifier()) async throws -> URL {
        // App Translocation runs a quarantined app from a read-only, randomized path.
        guard !app.path.contains("/AppTranslocation/") else { throw UpdateError.translocated }
        let folder = app.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: folder.path) else {
            throw UpdateError.notWritable(folder.path)
        }
        guard let team, team.count == 10, team.allSatisfy({ $0.isASCII && ($0.isUppercase || $0.isNumber) }) else {
            throw UpdateError.notSigned
        }
        guard let url = release.download else { throw UpdateError.missingDownload }

        // On the same volume as the app, so it can be swapped in with a rename.
        let work = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                               appropriateFor: app, create: true)
        do {
            let (file, response) = try await session.download(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.badResponse }
            let dmg = work.appending(path: "SpotKeys.dmg")
            try FileManager.default.moveItem(at: file, to: dmg)

            // Check the disk image before mounting it, and the app again once it's copied out.
            try verify(dmg, requirement: developerIDRequirement(team: team))
            let mountPoint = work.appending(path: "mount")
            guard run("/usr/bin/hdiutil", "attach", dmg.path, "-nobrowse", "-readonly", "-noautoopen",
                      "-mountpoint", mountPoint.path)
            else { throw UpdateError.diskImage }
            let newApp = work.appending(path: "SpotKeys.app")
            do {
                defer { run("/usr/bin/hdiutil", "detach", mountPoint.path, "-force") }
                try FileManager.default.copyItem(at: mountPoint.appending(path: "SpotKeys.app"), to: newApp)
            }
            try? FileManager.default.removeItem(at: dmg)

            let identifier = Bundle.main.bundleIdentifier ?? "com.diddern.SpotKeys"
            try verify(newApp, requirement: "identifier \"\(identifier)\" and " + developerIDRequirement(team: team))
            let newVersion = Bundle(url: newApp)?.infoDictionary?["CFBundleShortVersionString"] as? String
            guard newVersion.flatMap(Version.init) == release.version else { throw UpdateError.untrusted }
            guard run("/usr/sbin/spctl", "--assess", "--type", "execute", newApp.path) else {
                throw UpdateError.notNotarized
            }
            return newApp
        } catch {
            try? FileManager.default.removeItem(at: work)
            throw error
        }
    }

    /// The Developer ID team that signed the running app, or nil for ad hoc and unsigned builds.
    static func ownTeamIdentifier() -> String? {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var info: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation),
                                            &info) == errSecSuccess
        else { return nil }
        return (info as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
    }

    /// Code signed with a Developer ID certificate issued to `team`, the same requirement Gatekeeper uses.
    private static func developerIDRequirement(team: String) -> String {
        "anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists"
            + " and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"
            + " and certificate leaf[subject.OU] = \"\(team)\""
    }

    private static func verify(_ url: URL, requirement text: String) throws {
        var code: SecStaticCode?
        var requirement: SecRequirement?
        let flags = SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode)
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
              SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess, let requirement,
              SecStaticCodeCheckValidity(code, flags, requirement) == errSecSuccess
        else { throw UpdateError.untrusted }
    }

    @discardableResult
    private static func run(_ tool: String, _ arguments: String...) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
