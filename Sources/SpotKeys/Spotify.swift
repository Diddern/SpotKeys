import AppKit

/// Controls the Spotify desktop app over AppleScript.
enum Spotify {
    static let bundleIdentifier = "com.spotify.client"

    static var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    static var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    static func playPause() { tell("playpause") }
    static func play() { tell("play") }
    static func nextTrack() { tell("next track") }
    static func previousTrack() { tell("previous track") }

    /// The current track as "Artist – Title", or nil if Spotify isn't running or nothing is loaded.
    static func nowPlaying() -> (title: String, isPlaying: Bool)? {
        guard isRunning,
              let result = tell("""
                  if player state is stopped then return {}
                  return {player state is playing, artist of current track, name of current track}
                  """),
              result.numberOfItems == 3,
              let artist = result.atIndex(2)?.stringValue,
              let name = result.atIndex(3)?.stringValue
        else { return nil }
        let title = artist.isEmpty ? name : "\(artist) – \(name)"
        return (title, result.atIndex(1)?.booleanValue ?? false)
    }

    /// Opens Spotify in the background and starts playback once it accepts commands.
    static func launchAndPlay() {
        guard let url = appURL else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.async { playWhenReady(attemptsLeft: 10) }
        }
    }

    private static func playWhenReady(attemptsLeft: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            play()
            if nowPlaying()?.isPlaying != true && attemptsLeft > 1 {
                playWhenReady(attemptsLeft: attemptsLeft - 1)
            }
        }
    }

    @discardableResult
    private static func tell(_ commands: String) -> NSAppleEventDescriptor? {
        let source = """
            with timeout of 5 seconds
                tell application id "\(bundleIdentifier)"
                    \(commands)
                end tell
            end timeout
            """
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error { NSLog("SpotKeys: AppleScript failed: \(error)") }
        return result
    }
}
