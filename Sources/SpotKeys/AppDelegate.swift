import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let keyTap = MediaKeyTap()
    private let defaults = UserDefaults.standard
    private var statusItem: NSStatusItem!
    private var accessTimer: Timer?

    private var interceptKeys: Bool {
        get { defaults.bool(forKey: "interceptKeys") }
        set {
            defaults.set(newValue, forKey: "interceptKeys")
            keyTap.isEnabled = newValue
            updateIcon()
        }
    }

    private var launchSpotifyOnPlay: Bool {
        get { defaults.bool(forKey: "launchSpotifyOnPlay") }
        set { defaults.set(newValue, forKey: "launchSpotifyOnPlay") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: ["interceptKeys": true, "launchSpotifyOnPlay": true])

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        keyTap.isEnabled = interceptKeys
        keyTap.onKeyDown = { [weak self] key in self?.handle(key) }
        installKeyTap(promptForAccess: true)
    }

    // MARK: - Media keys

    private func installKeyTap(promptForAccess: Bool) {
        let options = ["AXTrustedCheckOptionPrompt": promptForAccess] as CFDictionary
        if AXIsProcessTrustedWithOptions(options), keyTap.install() {
            accessTimer?.invalidate()
            accessTimer = nil
        } else if accessTimer == nil {
            // Keep checking until access is granted in System Settings.
            accessTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                self?.installKeyTap(promptForAccess: false)
            }
        }
        updateIcon()
    }

    private func handle(_ key: MediaKey) {
        switch key {
        case .playPause:
            if Spotify.isRunning {
                Spotify.playPause()
            } else if launchSpotifyOnPlay {
                Spotify.launchAndPlay()
            }
        case .next:
            if Spotify.isRunning { Spotify.nextTrack() }
        case .previous:
            if Spotify.isRunning { Spotify.previousTrack() }
        }
    }

    private func updateIcon() {
        // A solid key cap while SpotKeys owns the media keys, an outline while it doesn't.
        let isActive = keyTap.isInstalled && interceptKeys
        statusItem?.button?.image = StatusIcon.make(filled: isActive)
        statusItem?.button?.appearsDisabled = !isActive
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if let track = Spotify.nowPlaying() {
            menu.addItem(label((track.isPlaying ? "▶︎  " : "❚❚  ") + truncated(track.title)))
        } else {
            menu.addItem(label(Spotify.isRunning
                ? String(localized: "Nothing Playing")
                : String(localized: "Spotify Isn’t Running")))
        }
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Play / Pause"), #selector(playPause)))
        menu.addItem(item(String(localized: "Next Track"), #selector(nextTrack)))
        menu.addItem(item(String(localized: "Previous Track"), #selector(previousTrack)))
        menu.addItem(.separator())

        if !keyTap.isInstalled {
            menu.addItem(label(String(localized: "⚠︎  SpotKeys Needs Accessibility Access")))
            menu.addItem(item(String(localized: "Open System Settings…"), #selector(openAccessibilitySettings)))
            menu.addItem(.separator())
        }

        if interceptKeys {
            let interceptors = MediaKeyTap.otherInterceptors()
            for app in interceptors {
                let warning = label(String(localized: "⚠︎  \(app.localizedName!) May Take the Media Keys"))
                warning.toolTip = String(localized: "Quit it if the media keys don’t reach Spotify.")
                menu.addItem(warning)
            }
            if !interceptors.isEmpty { menu.addItem(.separator()) }
        }

        menu.addItem(item(String(localized: "Control Spotify with Media Keys"), #selector(toggleInterceptKeys), isOn: interceptKeys))
        menu.addItem(item(String(localized: "Launch Spotify on Play"), #selector(toggleLaunchSpotify), isOn: launchSpotifyOnPlay))
        menu.addItem(item(String(localized: "Open at Login"), #selector(toggleLoginItem),
                          isOn: SMAppService.mainApp.status == .enabled))
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "About SpotKeys"), #selector(showAbout)))
        menu.addItem(item(String(localized: "Quit SpotKeys"), #selector(NSApplication.terminate(_:)), key: "q", target: NSApp))
    }

    private func item(_ title: String, _ action: Selector, key: String = "", isOn: Bool = false,
                      target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target ?? self
        item.state = isOn ? .on : .off
        return item
    }

    private func label(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func truncated(_ text: String, limit: Int = 50) -> String {
        text.count > limit ? text.prefix(limit - 1) + "…" : text
    }

    // MARK: - Actions

    @objc private func playPause() { handle(.playPause) }
    @objc private func nextTrack() { handle(.next) }
    @objc private func previousTrack() { handle(.previous) }

    @objc private func toggleInterceptKeys() { interceptKeys.toggle() }
    @objc private func toggleLaunchSpotify() { launchSpotifyOnPlay.toggle() }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            NSAlert(error: error).runModal()
        }
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph,
        ]
        let credits = NSMutableAttributedString(
            string: String(localized: "Play, pause, next and previous always go to Spotify.") + "\n\n",
            attributes: attributes)
        var linkAttributes = attributes
        linkAttributes[.link] = Self.repositoryURL
        credits.append(NSAttributedString(string: "github.com/Diddern/SpotKeys", attributes: linkAttributes))

        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    private static let repositoryURL = URL(string: "https://github.com/Diddern/SpotKeys")!
}
