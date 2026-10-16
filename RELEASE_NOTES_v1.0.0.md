# MouseSave Release v1.0.0

🎉 **MouseSave v1.0.0 - Official First Release (macOS & Windows)**

MouseSave is an ultra-lightweight, native menu-bar and system-tray utility for both **macOS** and **Windows** that adds smooth inertial scrolling, customizable mouse side buttons (Buttons 4 & 5), natural scroll inversion, and an automated **Game Mode & App Exclusion List**.

---

## 🌟 Highlights & New Features

### 1. 🍏 macOS Native App (Swift 5 / SwiftUI)
- Native menu bar status item (`NSStatusItem`) with custom menu and settings.
- Quartz Event Services (`CGEventTap`) low-level hook for smooth inertial scrolling and side-button gestures.
- Automatic watchdog timer that recovers the tap from sleep or timeout.
- 4-tab modern SwiftUI settings interface (General, Buttons, Scrolling, Exclusions).
- Accessibility permission validation (`AXIsProcessTrustedWithOptions`) with direct shortcut to System Settings.

### 2. 🪟 Windows Native App (C# Win32 / .NET)
- Native system notification tray icon (`NotifyIcon`) with status and controls.
- Win32 `SetWindowsHookExW(WH_MOUSE_LL)` low-level mouse hook.
- High-frequency physical decay (~16ms ticks) for fluid scrolling physics.
- 4-tab native Windows Forms settings GUI with Segoe UI styling.
- Zero-dependency compilation: compiles into a standalone ~40KB `.exe` using Windows built-in `csc.exe` or `.NET 8`.
- Registry-based auto-start (`HKCU\Software\Microsoft\Windows\CurrentVersion\Run`).

### 3. 🎮 Game Mode & Application Exclusion List
- High-performance foreground window detection (< 0.05ms HWND micro-cache on Windows, `NSWorkspace` notifications on macOS).
- Automatically completely pauses MouseSave when specified games/apps (e.g., `cs2.exe`, `valorant.exe`, `League of Legends.exe`, `Blender.exe`) are in the foreground.
- Zero added latency and 1:1 hardware wheel ticks for discrete weapon switching and precision zoom.
- Interactive UI to add running processes or browse executables.

### 4. 🌐 Localization
- Full English and Traditional Chinese (繁體中文 `zh-Hant`) support.

---

## 📦 Release Assets

- **`MouseSave-v1.0.0-windows-x64.zip`**: Standalone Windows executable package (~21KB). No installation needed; just extract and run `MouseSave.exe`.
- **Source Code (`.zip` / `.tar.gz`)**: Full multi-platform source code including the Xcode project and C# Win32 source.
