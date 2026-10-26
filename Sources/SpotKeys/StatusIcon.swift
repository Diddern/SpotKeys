import AppKit

/// The menu bar icon: a key cap with a play/pause glyph, drawn as a template image
/// so macOS tints it for light and dark menu bars.
enum StatusIcon {
    static func make(filled: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let key = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 2, width: 15, height: 14),
                                   xRadius: 3.8, yRadius: 3.8)
            NSColor.black.set()
            if filled {
                key.fill()
                // Punch the glyph out of the key cap.
                NSGraphicsContext.current?.compositingOperation = .destinationOut
            } else {
                key.lineWidth = 1.4
                key.stroke()
            }
            glyph(in: NSRect(x: 5, y: 6.2, width: 8.6, height: 5.6)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "SpotKeys"
        return image
    }

    /// Play triangle followed by two pause bars, filling `rect`.
    private static func glyph(in rect: NSRect) -> NSBezierPath {
        let unit = rect.width / 264
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.minY))
        path.line(to: NSPoint(x: rect.minX + 140 * unit, y: rect.midY))
        path.line(to: NSPoint(x: rect.minX, y: rect.maxY))
        path.close()
        for x in [176.0, 230.0] {
            path.append(NSBezierPath(rect: NSRect(x: rect.minX + x * unit, y: rect.minY,
                                                  width: 34 * unit, height: rect.height)))
        }
        return path
    }
}
