//
//  PCPixelCanvasView+Keyboard.swift
//  pixcen
//
//  Keyboard handling for color selection, tool toggling, navigation.
//

import Cocoa

extension PCPixelCanvasView {

    // MARK: - Key Down

    override func keyDown(with event: NSEvent) {
        let characters = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let shift = event.modifierFlags.contains(.shift)

        // Arrow keys:
        //   Plain arrow = pan 1px
        //   Shift+arrow = pan 8px (fast navigation)
        //   Cmd+Shift+arrow = shift pixel content (bitmap operation)
        let cmd = event.modifierFlags.contains(.command)
        switch event.keyCode {
        case 123: // Left arrow
            if cmd && shift {
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.onSelectionShiftleft(self)
                }
            } else { panBy(dx: shift ? -8 : -1, dy: 0) }
            return
        case 124: // Right arrow
            if cmd && shift {
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.onSelectionShiftright(self)
                }
            } else { panBy(dx: shift ? 8 : 1, dy: 0) }
            return
        case 125: // Down arrow
            if cmd && shift {
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.onSelectionShiftdown(self)
                }
            } else { panBy(dx: 0, dy: shift ? 8 : 1) }
            return
        case 126: // Up arrow
            if cmd && shift {
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.onSelectionShiftup(self)
                }
            } else { panBy(dx: 0, dy: shift ? -8 : -1) }
            return
        default:
            break
        }

        // + / - for zoom
        switch characters {
        case "+", "=":
            zoomLevel = min(zoomMax, zoomLevel * 1.25)
            return
        case "-":
            zoomLevel = max(zoomMin, zoomLevel / 1.25)
            return

        // Toggle fill mode
        case "f":
            m_Fill = !m_Fill

        // Color selection (0-9, a-f for hex colors 0-15)
        case "0": m_Col1 = 0
        case "1": m_Col1 = 1
        case "2": m_Col1 = 2
        case "3": m_Col1 = 3
        case "4": m_Col1 = 4
        case "5": m_Col1 = 5
        case "6": m_Col1 = 6
        case "7": m_Col1 = 7
        case "8": m_Col1 = 8
        case "9": m_Col1 = 9
        case "a": m_Col1 = 10
        case "b": m_Col1 = 11
        case "c": m_Col1 = 12
        case "d": m_Col1 = 13
        case "e": m_Col1 = 14

        // Toggle color overflow Ignore/Replace
        case "w":
            if m_pbm.canvasModel.overflow == .NOTHING {
                m_pbm.canvasModel.overflow = .REPLACE
            } else {
                m_pbm.canvasModel.overflow = .NOTHING
            }

        // Swap colors
        case "x":
            let temp = m_Col1
            m_Col1 = m_Col2
            m_Col2 = temp

        // Escape - cancel modes and clear selection
        case "\u{1b}":
            m_Fill = false
            m_Paint = false
            m_ColorPick = false
            m_Paste = false
            selectionStart = nil
            selectionEnd = nil
            isSelecting = false
            m_MarkerCount = 0
            m_Marker = false

        default:
            super.keyDown(with: event)
            return  // don't refresh for unhandled keys
        }

        // Refresh status bar after any handled key action
        refreshStatus()
    }

    // MARK: - Pan by C64 pixels

    /// Pan the view by a number of C64 pixels. Arrow keys use this.
    private func panBy(dx: Int, dy: Int) {
        panOffset.x += Float(dx)
        panOffset.y += Float(dy)
        clampPan()
    }
}
