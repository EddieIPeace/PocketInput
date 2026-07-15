import AppKit
import CoreGraphics
import PocketInputKit

struct InputInjector {
    func inject(_ event: InputEvent) {
        switch event {
        case .move(let dx, let dy):
            moveBy(dx: dx, dy: dy)
        case .click(let button, let phase):
            click(button: button, phase: phase)
        }
    }

    private func moveBy(dx: Double, dy: Double) {
        let current = CGEvent(source: nil)?.location ?? .zero
        // CG coordinates: origin bottom-left; iOS drag dy increases downward → flip for Mac.
        let target = CGPoint(x: current.x + dx, y: current.y - dy)
        guard let move = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: target,
            mouseButton: .left
        ) else { return }
        move.post(tap: .cghidEventTap)
    }

    private func click(button: MouseButton, phase: ClickPhase) {
        let location = CGEvent(source: nil)?.location ?? .zero
        let (downType, upType, cgButton): (CGEventType, CGEventType, CGMouseButton) = {
            switch button {
            case .left:
                return (.leftMouseDown, .leftMouseUp, .left)
            case .right:
                return (.rightMouseDown, .rightMouseUp, .right)
            }
        }()

        switch phase {
        case .down:
            postMouse(type: downType, button: cgButton, at: location)
        case .up:
            postMouse(type: upType, button: cgButton, at: location)
        case .tap:
            postMouse(type: downType, button: cgButton, at: location)
            postMouse(type: upType, button: cgButton, at: location)
        }
    }

    private func postMouse(type: CGEventType, button: CGMouseButton, at location: CGPoint) {
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: location,
            mouseButton: button
        ) else { return }
        event.post(tap: .cghidEventTap)
    }
}
