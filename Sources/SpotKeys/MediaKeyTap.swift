import AppKit

/// The media keys SpotKeys handles.
enum MediaKey {
    case playPause
    case next
    case previous

    /// Maps an `NX_KEYTYPE_*` value from IOKit/hidsystem/ev_keymap.h.
    init?(keyType: Int) {
        switch keyType {
        case 16: self = .playPause      // NX_KEYTYPE_PLAY
        case 17, 19: self = .next       // NX_KEYTYPE_NEXT, NX_KEYTYPE_FAST
        case 18, 20: self = .previous   // NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_REWIND
        default: return nil
        }
    }
}

/// Intercepts the hardware media keys with a CGEvent tap and swallows them,
/// so macOS never routes them to Music, a browser or whichever app is "Now Playing".
final class MediaKeyTap {
    var onKeyDown: ((MediaKey) -> Void)?

    /// When false the tap is paused and the keys behave as macOS normally would.
    var isEnabled = true {
        didSet { if let tap { CGEvent.tapEnable(tap: tap, enable: isEnabled) } }
    }

    var isInstalled: Bool { tap != nil }

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Installs the tap. Fails until SpotKeys has been granted Accessibility access.
    func install() -> Bool {
        if tap != nil { return true }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1) << systemDefinedEventType,
            callback: { _, type, event, refcon in
                let keyTap = Unmanaged<MediaKeyTap>.fromOpaque(refcon!).takeUnretainedValue()
                return keyTap.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: isEnabled)
        self.tap = tap
        self.runLoopSource = source
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let passThrough = Unmanaged.passUnretained(event)

        // macOS disables taps that respond slowly or while secure input is active; turn it back on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap, isEnabled { CGEvent.tapEnable(tap: tap, enable: true) }
            return passThrough
        }

        guard type.rawValue == systemDefinedEventType,
              let nsEvent = NSEvent(cgEvent: event),
              nsEvent.subtype.rawValue == auxControlButtonsSubtype,
              let key = MediaKey(keyType: (nsEvent.data1 & 0xFFFF_0000) >> 16)
        else { return passThrough }

        let flags = nsEvent.data1 & 0xFFFF
        let isKeyDown = (flags & 0xFF00) >> 8 == 0xA
        let isRepeat = flags & 0x1 == 1
        if isKeyDown && !isRepeat {
            // Leave the callback right away; the system disables taps that block.
            DispatchQueue.main.async { [weak self] in self?.onKeyDown?(key) }
        }
        return nil  // Swallow both key down and key up.
    }
}

private let systemDefinedEventType: UInt32 = 14   // NX_SYSDEFINED
private let auxControlButtonsSubtype: Int16 = 8   // NX_SUBTYPE_AUX_CONTROL_BUTTONS
