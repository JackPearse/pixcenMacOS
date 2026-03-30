//
//  PCPreferencesWindowController.swift
//  pixcen
//
//  Preferences dialog for input mode and startup options.
//

import Cocoa

class PCPreferencesWindowController: NSWindowController {

    private var inputModePopup: NSPopUpButton!
    private var introCheckbox: NSButton!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 170),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.isReleasedWhenClosed = false
        window.center()

        self.init(window: window)
        setupUI()
        loadSettings()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let padding: CGFloat = 20
        let labelWidth: CGFloat = 100
        let popupWidth: CGFloat = 160

        // --- Input mode ---
        let label = NSTextField(labelWithString: "Input device:")
        label.frame = NSRect(x: padding, y: 115, width: labelWidth, height: 20)
        label.font = NSFont.systemFont(ofSize: 13)
        contentView.addSubview(label)

        inputModePopup = NSPopUpButton(frame: NSRect(x: padding + labelWidth, y: 112, width: popupWidth, height: 26))
        inputModePopup.addItems(withTitles: ["Trackpad", "Mouse"])
        inputModePopup.target = self
        inputModePopup.action = #selector(inputModeChanged(_:))
        contentView.addSubview(inputModePopup)

        let desc = NSTextField(wrappingLabelWithString:
            "Trackpad: two-finger scroll pans, pinch zooms.\nMouse: scroll wheel zooms.")
        desc.frame = NSRect(x: padding, y: 70, width: 280, height: 34)
        desc.font = NSFont.systemFont(ofSize: 11)
        desc.textColor = .secondaryLabelColor
        contentView.addSubview(desc)

        // --- Separator ---
        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: padding, y: 60, width: 280, height: 1)
        contentView.addSubview(sep)

        // --- Miss Pixcen intro checkbox ---
        introCheckbox = NSButton(checkboxWithTitle: "Always show Miss Pixcen at startup",
                                 target: self,
                                 action: #selector(introCheckboxChanged(_:)))
        introCheckbox.frame = NSRect(x: padding, y: 28, width: 280, height: 20)
        contentView.addSubview(introCheckbox)

        let introDesc = NSTextField(labelWithString: "Show the intro image by N3XU5 every time the app starts.")
        introDesc.frame = NSRect(x: padding, y: 8, width: 280, height: 16)
        introDesc.font = NSFont.systemFont(ofSize: 11)
        introDesc.textColor = .secondaryLabelColor
        contentView.addSubview(introDesc)
    }

    private func loadSettings() {
        let mode = UserDefaults.standard.string(forKey: "inputMode") ?? "trackpad"
        inputModePopup.selectItem(at: mode == "mouse" ? 1 : 0)

        let alwaysShow = UserDefaults.standard.bool(forKey: "alwaysShowIntro")
        introCheckbox.state = alwaysShow ? .on : .off
    }

    @objc private func inputModeChanged(_ sender: NSPopUpButton) {
        let mode = sender.indexOfSelectedItem == 1 ? "mouse" : "trackpad"
        UserDefaults.standard.set(mode, forKey: "inputMode")
    }

    @objc private func introCheckboxChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "alwaysShowIntro")
    }
}
