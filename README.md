# 🖱️ MouseSave (Cross-Platform: macOS & Windows)

[![Release](https://img.shields.io/badge/release-v1.1.0-blue.svg)](https://github.com/workingharry/MouseSave/releases)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS-lightgrey.svg)](https://github.com/workingharry/MouseSave)

**MouseSave** is an ultra-lightweight, native menu-bar and system-tray utility for both **macOS** and **Windows**. It transforms ordinary mice into productivity powerhouses by adding smooth inertial scrolling, customizable side buttons (Buttons 4 & 5), 4-way tilt wheel navigation, independent scroll direction control, and **per-application exclusion / Game Mode**.

---

## 🌟 Key Features

| Feature | macOS | Windows |
| :--- | :--- | :--- |
| **Smooth Inertial Scrolling** | Pixel-level decay interpolation via `CGEventTap` | High-frequency physical decay via `WH_MOUSE_LL` |
| **App Exclusion / Game Mode** | 🎮 Automatically bypasses MouseSave in specified apps (CS2, LoL, Blender, CAD) | 🎮 Automatically bypasses MouseSave in specified apps (CS2, LoL, Blender, CAD) |
| **Hardware Key Detection** | Real-time button listener | ➕ Real-time button learning dialog & live pulse visualizer |
| **4-Way Tilt Wheel** | Horizontal wheel swipe support | Horizontal wheel swipe & tab navigation (`Ctrl+Tab` / `Ctrl+Shift+Tab`) |
| **Side Buttons Remapping** | Buttons 4 & 5 mapped to Back/Forward, Mission Control, Show Desktop | Buttons 4 & 5 mapped to Back/Forward, Task View (`Win+Tab`), Desktop (`Win+D`), Close Window (`Ctrl+W`) |
| **Middle Click Action** | Custom middle-click remapping | Custom middle-click remapping |
| **Natural Scrolling** | Invert mouse scroll direction independently | Invert mouse scroll direction independently |
| **System Tray / Menu Bar** | Native `NSStatusItem` in macOS Menu Bar | Fluent Win11 Native `NotifyIcon` & Context Menu |
| **Launch at Login** | `SMAppService` / Login Items | Windows Registry (`HKCU\Software\Microsoft\Windows\CurrentVersion\Run`) |
| **Localization** | English & 繁體中文 (Traditional Chinese) | English & 繁體中文 (Traditional Chinese) |
| **Memory Footprint** | ~15MB RAM | ~15MB RAM (~85KB standalone binary) |

---

## 🎮 Game Mode & Application Exclusion

When competitive games or precision workstation software (such as FPS games, MOBA, Blender, CAD) are in the foreground, inertial scrolling can cause unintended weapon cycling or erratic zoom increments. 

MouseSave includes an **Exclusion List**:
- Whenever an excluded app (e.g. `cs2.exe`, `valorant.exe`, `League of Legends.exe`, `Blender.exe`) is active in the foreground, MouseSave **completely pauses**:
  - Smooth scrolling is bypassed (returns to discrete 1:1 hardware notches).
  - Side buttons and middle click return to raw hardware events for native game keybinds.
  - Zero added latency (< 0.05ms HWND micro-cache detection).
- You can easily add running applications or browse for `.exe` / `.app` files directly in the **Exclusions** settings tab.

---

## 📁 Project Architecture

```
e:\Build\MouseSave/
├── MouseSave/                      # 🍏 macOS Native App (Swift & SwiftUI)
│   ├── MouseSaveApp.swift          # App delegate & lifecycle management
│   ├── MenuBarController.swift     # Status item in macOS menu bar & context menu
│   ├── Helpers/
│   │   ├── MouseHookHelper.swift   # CGEventTap Quartz event interception, physics loop & active app observer
│   │   └── AccessibilityHelper.swift# Permission check & prompt
│   ├── Models/
│   │   └── Settings.swift          # AppSettings observable model (UserDefaults + excludedApps)
│   ├── Views/
│   │   └── SettingsView.swift      # 4-tab settings window (General, Buttons, Scrolling, Exclusions)
│   ├── Resources/
│   │   └── Localizable.xcstrings   # Bilingual localization (en, zh-Hant)
│   └── MouseSave.xcodeproj/        # Xcode project configuration
│
├── windows/                        # 🪟 Windows Native App (C# / Win32)
│   ├── src/
│   │   ├── Program.cs              # Entry point, single-instance mutex & tray icon
│   │   ├── MouseHook.cs            # WH_MOUSE_LL low-level hook & Win32 foreground exclusion cache
│   │   ├── Settings.cs             # AppSettings model & JSON persistence (%APPDATA%)
│   │   ├── SettingsForm.cs         # Native 4-tab settings GUI window (General, Buttons, Scrolling, Exclusions)
│   │   ├── StartupHelper.cs        # Registry-based auto-start management
│   │   └── Localization.cs         # Bilingual localization dictionary
│   ├── build.bat                   # ⚡ Zero-dependency 1-second build script (csc.exe)
│   ├── build.ps1                   # PowerShell automated build script
│   ├── MouseSave.csproj            # Modern .NET 8 SDK project file
│   └── bin/
│       └── MouseSave.exe           # Standalone native executable (~40KB)
│
├── shared/                         # 🌐 Shared Cross-Platform Specifications
│   ├── schema/
│   │   └── settings.schema.json    # Standard JSON schema for settings
│   └── locales/
│       └── translations.json       # Canonical multilingual UI dictionary
│
└── docs/                           # 📚 Architecture & Implementation Plans
    ├── PLAN-app-exclusion-smooth-scroll.md # App exclusion & game mode design
    ├── PLAN-mousesave-crossplatform.md    # Multi-platform architecture plan
    └── architecture_crossplatform_gemini.md# Gemini Web Copilot blueprint
```

---

## 🚀 How to Build & Run

### 🪟 Windows

Build and run **MouseSave for Windows** in under 2 seconds without installing any heavyweight SDKs:

#### Option A: One-Click Zero-Dependency Build (Recommended)
Double-click `windows\build.bat` or run in PowerShell:
```powershell
.\windows\build.ps1
```
The standalone executable is located at:
```
windows\bin\MouseSave.exe
```

#### Option B: Using .NET 8 SDK (for developers)
```bash
cd windows
dotnet build
dotnet run
```

---

### 🍏 macOS

#### Building via Xcode:
1. Open `MouseSave.xcodeproj` in Xcode.
2. Select the `MouseSave` target.
3. Press `Cmd + R` to build and launch.

#### Building via Command Line:
```bash
xcodebuild -project MouseSave.xcodeproj -scheme MouseSave -configuration Release build
```

> **Note on macOS Permissions**:  
> macOS requires **Accessibility permission** to intercept mouse events via Quartz Event Services. When prompted on first launch, click **Open System Settings** and grant access in **System Settings > Privacy & Security > Accessibility**.

---

## ⚙️ Configuration File Location

- **Windows**: `%APPDATA%\MouseSave\settings.json`
- **macOS**: `~/Library/Preferences/com.mousesave.plist` and `~/Library/Application Support/MouseSave/`

---

## 🛡️ License

MIT License. Free and open source for personal and commercial productivity.
