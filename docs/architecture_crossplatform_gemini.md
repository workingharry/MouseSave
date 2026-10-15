## 1. System Overview & Component Design

To scale **MouseSave** from a macOS-only utility into a robust, cross-platform desktop application supporting both macOS and Windows, we adopt a **Layered Modular Architecture with a Platform Abstraction Layer (PAL)**.

### Architectural Layers

1. **Presentation Layer (Platform Native)**:
* **macOS**: SwiftUI + AppKit (`MenuBarController`, `SettingsView`).
* **Windows**: WinUI 3 (C# / C++) or WPF with a system tray icon (`NotifyIcon`) and a corresponding three-tab settings window.


2. **Application & State Management Layer**: Reactive state synchronization (`AppSettings`) managing user preferences, feature toggles, and persistence (`UserDefaults` on macOS, JSON in `%APPDATA%` on Windows).
3. **Core Domain & Processing Engine**: High-performance engine handling smooth scrolling mathematical interpolation, button remapping rules, and event filtering.
4. **Platform Abstraction Layer (PAL) & Hook Engine**:
* **macOS**: `CGEventTap` (Quartz Event Services).
* **Windows**: `WH_MOUSE_LL` (Low-Level Mouse Hook via Win32 API `SetWindowsHookEx`).



### Architecture Sequence & Component Diagram

```mermaid
graph TD
    subgraph macOS Platform
        M_UI[macOS SwiftUI / AppKit UI]
        M_Tray[NSStatusItem MenuBar]
        M_Hook[CGEventTap Engine]
    end

    subgraph Windows Platform
        W_UI[Windows WinUI 3 UI]
        W_Tray[System Tray NotifyIcon]
        W_Hook[WH_MOUSE_LL Hook Engine]
    end

    subgraph Shared Core & Abstraction
        PAL[Platform Abstraction Layer Interface]
        Engine[Mouse Processing Engine Core]
        Config[Unified AppSettings & State]
    end

    M_UI --> Config
    W_UI --> Config
    M_Tray --> M_UI
    W_Tray --> W_UI
    
    M_Hook --> PAL
    W_Hook --> PAL
    PAL --> Engine
    Config --> Engine

```

---

## 2. Key Technical Decisions & Trade-offs

### Low-Level Event Interception

* **macOS (`CGEventTap`)**:
* **Pros**: Deep integration with Quartz compositor; allows seamless event modification or suppression.
* **Cons**: Requires explicit macOS Accessibility permissions (`AXIsProcessTrusted`). Unresponsive taps can be disabled automatically by the OS kernel if callbacks exceed timeout thresholds.
* **Mitigation**: Offload heavy event computations to an asynchronous serial dispatch queue and implement a watchdog timer to auto-recreate the event tap if invalidated.


* **Windows (`WH_MOUSE_LL`)**:
* **Pros**: Global low-level mouse hook captures all mouse input system-wide without requiring DLL injection into target processes.
* **Cons**: Requires a running message pump (`GetMessage`/`PeekMessage`). If the hook callback takes longer than ~300ms, Windows will silently unhook it to prevent system freezing.
* **Mitigation**: Process hook messages in under 5ms, offloading post-processing to worker threads using concurrent thread-safe queues.



### Cross-Platform UI vs. Native UI Strategy

* **Decision**: Maintain **native UI frameworks per platform** (SwiftUI for macOS, WinUI 3 for Windows) while sharing core configuration models and event processing logic. This guarantees optimal native look-and-feel, accessibility compliance, and adherence to platform Human Interface Guidelines (HIG).

---

## 3. Step-by-Step Implementation Roadmap

### Milestone 1: Core Abstraction & Interface Contracts

Define platform-agnostic protocols for low-level hooks and settings management.

```swift
// Shared Protocol Definition (Swift / C++ Bridge equivalent)
protocol MouseHookEngineProtocol: AnyObject {
    var isEnabled: Bool { get set }
    func start() throws
    func stop()
    var onScrollEvent: ((Double, Double) -> Void)? { get set }
    var onButtonEvent: ((UInt32, ButtonState) -> Void)? { get set }
}

enum ButtonState {
    case pressed, released
}

```

### Milestone 2: Windows Low-Level Hook (`WH_MOUSE_LL`) Implementation

Implement the Windows hook wrapper using C++/WinRT or C# P/Invoke. Below is the architectural pattern for the Win32 low-level mouse hook:

```csharp
// Windows Native Hook Manager (C# / .NET 8 Reference)
public sealed class WindowsMouseHook : IDisposable {
    private const int WH_MOUSE_LL = 14;
    private const int WM_MOUSEMOVE = 0x0200;
    private const int WM_MOUSEWHEEL = 0x020A;
    private const int WM_XBUTTONDOWN = 0x020B;

    private IntPtr _hookID = IntPtr.Zero;
    private LowLevelMouseProc _proc;

    public event EventHandler<ScrollEventArgs>? ScrollDetected;
    public event EventHandler<ButtonEventArgs>? ButtonDetected;

    public void Start() {
        _proc = HookCallback;
        _hookID = SetHook(_proc);
    }

    private IntPtr SetHook(LowLevelMouseProc proc) {
        using (var curProcess = System.Diagnostics.Process.GetCurrentProcess())
        using (var curModule = curProcess.MainModule) {
            return SetWindowsHookEx(WH_MOUSE_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }

    private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0) {
            // Parse mouse message and dispatch to event handlers safely
        }
        return CallNextHookEx(_hookID, nCode, wParam, lParam);
    }

    public void Dispose() {
        if (_hookID != IntPtr.Zero) {
            UnhookWindowsHookEx(_hookID);
            _hookID = IntPtr.Zero;
        }
    }

    // P/Invoke declarations omitted for brevity
    private delegate IntPtr LowLevelMouseProc(int nCode, IntPtr wParam, IntPtr lParam);
}

```

### Milestone 3: macOS Refactoring (`CGEventTap` Isolation)

Refactor existing macOS event handling out of view controllers into an isolated service conforming to `MouseHookEngineProtocol`.

### Milestone 4: Cross-Platform Packaging & Build Pipeline

* **macOS**: Xcode project configured for Universal Binary (Apple Silicon + Intel) with Hardened Runtime and Notarization scripts.
* **Windows**: MSIX packaging project or Inno Setup installer bundling the .NET 8 / WinUI 3 runtime and registering startup tasks via Windows Registry (`HKCU\Software\Microsoft\Windows\CurrentVersion\Run`).

---

## 4. Resilience, Concurrency & Error Strategy

* **Hook Watchdog & Auto-Recovery**:
If `CGEventTap` enters a disabled state due to system sleep or permission changes, a background monitor detects the state change and initiates exponential backoff reconnection (`1s, 2s, 4s, max 30s`). On Windows, if `WH_MOUSE_LL` fails or times out, the message loop re-registers the hook automatically.
* **Thread Safety & Race Conditions**:
All configuration mutations originating from the three-tab settings view are dispatched across thread boundaries using atomic references or serialized queues (`DispatchQueue` on macOS, `Task` / `lock` primitives on Windows) to prevent data corruption during active hook processing.
* **Resource Leak Prevention**:
Strict adherence to RAII principles. All Win32 handles (`HHOOK`) and CoreFoundation opaque pointers (`CFMachPortRef`) are wrapped in safe disposal scopes to prevent resource leaks during application lifecycle transitions.

---

## 5. Verification & Testing Strategy

* **Unit Testing Suite**:
* Verify smooth scrolling mathematical curves (delta interpolation, friction damping, acceleration limits).
* Validate settings serialization and deserialization across cross-platform JSON schemas.


* **Integration Testing**:
* Test hook latency under heavy CPU loads to ensure event processing stays well below the 16ms frame threshold.
* Validate multi-monitor coordinate translation for absolute mouse positioning and gesture mapping.


* **Edge-Case Validation Checklist**:
* High-DPI scaling adjustments on Windows multi-monitor setups.
* System sleep and wake-from-sleep hook persistence.
* Handling UAC elevation prompts without dropping mouse input responsiveness.



---