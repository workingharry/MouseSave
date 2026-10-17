import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        TabView {
            GeneralTab(settings: settings)
                .tabItem {
                    Label(String(localized: "General"), systemImage: "gear")
                }

            ButtonsTab(settings: settings)
                .tabItem {
                    Label(String(localized: "Buttons"), systemImage: "computermouse")
                }

            ScrollingTab(settings: settings)
                .tabItem {
                    Label(String(localized: "Scrolling"), systemImage: "arrow.up.arrow.down")
                }

            ExclusionsTab(settings: settings)
                .tabItem {
                    Label(String(localized: "Exclusions"), systemImage: "gamecontroller")
                }
        }
        .frame(width: 500, height: 380)
        .padding()
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    @ObservedObject var settings: AppSettings
    @State private var isAccessibilityGranted: Bool = AXIsProcessTrusted()
    @State private var timer: Timer?

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Enable MouseSave"), isOn: $settings.isEnabled)
                Toggle(String(localized: "Show in menu bar"), isOn: $settings.showInMenuBar)
                Toggle(String(localized: "Launch at login"), isOn: $settings.launchAtLogin)
            }

            Section(header: Text(String(localized: "Permission Status"))) {
                if isAccessibilityGranted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(String(localized: "Accessibility Permission Granted"))
                            .foregroundColor(.primary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(String(localized: "Accessibility Permission Required"))
                                .foregroundColor(.red)
                                .bold()
                        }
                        Text(String(localized: "MouseSave requires Accessibility permission to intercept and modify mouse events."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(localized: "Tip: If already in the list, click '-' to remove it and re-add it so macOS recognizes the updated app."))
                            .font(.caption2)
                            .foregroundColor(.orange)

                        Button(String(localized: "Open System Settings")) {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            checkPermission()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                checkPermission()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func checkPermission() {
        let trusted = AXIsProcessTrusted()
        if isAccessibilityGranted != trusted {
            isAccessibilityGranted = trusted
            if trusted && settings.isEnabled {
                MouseHookHelper.shared.start()
            }
        }
    }
}

// MARK: - Buttons Tab

struct ButtonsTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker(String(localized: "Middle Click Action"), selection: $settings.middleClickAction) {
                    Text(String(localized: "Default Action")).tag("default")
                    Text(String(localized: "Task View / Mission Control")).tag("taskView")
                    Text(String(localized: "Show Desktop")).tag("desktop")
                    Text(String(localized: "Close Window")).tag("closeWindow")
                    Text(String(localized: "Disabled")).tag("none")
                }

                Picker(String(localized: "Side Button 4 (Back)"), selection: $settings.button4Action) {
                    Text(String(localized: "Back (Browser / Explorer)")).tag("back")
                    Text(String(localized: "Task View / Mission Control")).tag("taskView")
                    Text(String(localized: "Show Desktop")).tag("desktop")
                    Text(String(localized: "Disabled")).tag("none")
                }

                Picker(String(localized: "Side Button 5 (Forward)"), selection: $settings.button5Action) {
                    Text(String(localized: "Forward (Browser / Explorer)")).tag("forward")
                    Text(String(localized: "Task View / Mission Control")).tag("taskView")
                    Text(String(localized: "Show Desktop")).tag("desktop")
                    Text(String(localized: "Disabled")).tag("none")
                }
            }
        }
        .padding()
    }
}

// MARK: - Scrolling Tab

struct ScrollingTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Enable Smooth Scrolling"), isOn: $settings.smoothScrolling)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(String(localized: "Scroll Speed"))
                        Spacer()
                        Text(String(format: "%.1fx", settings.scrollAcceleration))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.scrollAcceleration, in: 0.5...3.0, step: 0.1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(String(localized: "Smoothness / Inertia"))
                        Spacer()
                        Text(String(format: "%.0f%%", settings.scrollFriction * 100))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.scrollFriction, in: 0.70...0.98, step: 0.02)
                }

                Toggle(String(localized: "Invert Scroll Direction (Natural Scrolling)"), isOn: $settings.invertScrollDirection)
            }
        }
        .padding()
    }
}

// MARK: - Exclusions Tab (Game Mode)

struct ExclusionsTab: View {
    @ObservedObject var settings: AppSettings
    @State private var newAppName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "App Exclusion List (Game Mode)"))
                .font(.headline)

            Text(String(localized: "When these apps/games are in the foreground, MouseSave is completely paused for raw, precise mouse response."))
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                ForEach(settings.excludedApps, id: \.self) { app in
                    HStack {
                        Image(systemName: "app.dashed")
                            .foregroundStyle(.secondary)
                        Text(app)
                        Spacer()
                        Button(role: .destructive) {
                            if let index = settings.excludedApps.firstIndex(of: app) {
                                settings.excludedApps.remove(at: index)
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 160)
            .border(Color.gray.opacity(0.2), width: 1)

            HStack {
                TextField(String(localized: "Enter process name (e.g. cs2)"), text: $newAppName)
                    .textFieldStyle(.roundedBorder)

                Button(String(localized: "Add")) {
                    let trimmed = newAppName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty && !settings.excludedApps.contains(trimmed) {
                        settings.excludedApps.append(trimmed)
                        newAppName = ""
                    }
                }
                .disabled(newAppName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(String(localized: "Browse .app...")) {
                    chooseAppBundle()
                }
            }
        }
        .padding()
    }

    private func chooseAppBundle() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK, let url = panel.url {
            let appName = url.deletingPathExtension().lastPathComponent
            if !settings.excludedApps.contains(appName) {
                settings.excludedApps.append(appName)
            }
        }
    }
}
