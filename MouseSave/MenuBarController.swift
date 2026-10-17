import AppKit
import Combine
import SwiftUI

final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem
    private var settingsWindow: NSWindow?
    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "computermouse.fill",
                accessibilityDescription: "MouseSave"
            )
        }

        setupMenu()
        observeSettings()
    }

    // MARK: - Menu

    private func setupMenu() {
        let menu = NSMenu()

        // 1. App Title Header
        let titleItem = NSMenuItem(title: "MouseSave v1.2.0", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // 2. Quick Toggles
        let gestureItem = NSMenuItem(
            title: "手勢切換桌面 (Spaces)",
            action: #selector(toggleGestures),
            keyEquivalent: ""
        )
        gestureItem.target = self
        gestureItem.state = settings.gestureEnabled ? .on : .off
        menu.addItem(gestureItem)

        let scrollItem = NSMenuItem(
            title: "自然捲動 (反轉滾輪)",
            action: #selector(toggleScrollInvert),
            keyEquivalent: ""
        )
        scrollItem.target = self
        scrollItem.state = settings.invertScrollDirection ? .on : .off
        menu.addItem(scrollItem)

        let smoothItem = NSMenuItem(
            title: "平滑滾動",
            action: #selector(toggleSmoothScrolling),
            keyEquivalent: ""
        )
        smoothItem.target = self
        smoothItem.state = settings.smoothScrolling ? .on : .off
        menu.addItem(smoothItem)

        menu.addItem(NSMenuItem.separator())

        // 3. Settings & Quit
        let settingsItem = NSMenuItem(
            title: "偏好設定…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "結束 MouseSave",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Settings observation

    private func observeSettings() {
        settings.$showInMenuBar
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in
                self?.statusItem.isVisible = visible
            }
            .store(in: &cancellables)

        Publishers.Merge4(
            settings.$gestureEnabled,
            settings.$invertScrollDirection,
            settings.$smoothScrolling,
            settings.$isEnabled
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            self?.setupMenu()
        }
        .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func toggleGestures() {
        settings.gestureEnabled.toggle()
    }

    @objc private func toggleScrollInvert() {
        settings.invertScrollDirection.toggle()
    }

    @objc private func toggleSmoothScrolling() {
        settings.smoothScrolling.toggle()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "MouseSave 設定"
            window.setContentSize(NSSize(width: 680, height: 520))
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.center()
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
