using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace MouseSave {
    public class MouseHook : IDisposable {
        private const int WH_MOUSE_LL = 14;
        private const int WM_MOUSEWHEEL = 0x020A;
        private const int WM_MOUSEHWHEEL = 0x020E;
        private const int WM_MBUTTONDOWN = 0x0207;
        private const int WM_MBUTTONUP = 0x0208;
        private const int WM_XBUTTONDOWN = 0x020B;
        private const int WM_XBUTTONUP = 0x020C;

        private const int XBUTTON1 = 0x0001;
        private const int XBUTTON2 = 0x0002;

        private const uint MOUSEEVENTF_WHEEL = 0x0800;
        private const uint KEYEVENTF_KEYUP = 0x0002;
        private const uint KEYEVENTF_EXTENDEDKEY = 0x0001;

        private const byte VK_LWIN = 0x5B;
        private const byte VK_TAB = 0x09;
        private const byte VK_D = 0x44;
        private const byte VK_W = 0x57;
        private const byte VK_CONTROL = 0x11;
        private const byte VK_SHIFT = 0x10;
        private const byte VK_MENU = 0x12; // Alt
        private const byte VK_LEFT = 0x25;
        private const byte VK_RIGHT = 0x27;

        public static Action<string> OnButtonCaptured;
        public static volatile bool IsCapturingButton = false;
        public static event Action<string> ButtonPressed;

        private const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;

        // Signature tag to identify events synthesized by MouseSave itself
        private static readonly UIntPtr SYNTHESIZED_EXTRA_INFO = new UIntPtr(0x53415645); // 'SAVE'

        [StructLayout(LayoutKind.Sequential)]
        private struct POINT {
            public int x;
            public int y;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct MSLLHOOKSTRUCT {
            public POINT pt;
            public uint mouseData;
            public uint flags;
            public uint time;
            public UIntPtr dwExtraInfo;
        }

        private delegate IntPtr LowLevelMouseProc(int nCode, IntPtr wParam, IntPtr lParam);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelMouseProc lpfn, IntPtr hMod, uint dwThreadId);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool UnhookWindowsHookEx(IntPtr hhk);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr GetModuleHandle(string lpModuleName);

        [DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr OpenProcess(uint processAccess, bool bInheritHandle, uint processId);

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        private static extern bool QueryFullProcessImageName(IntPtr hProcess, uint dwFlags, StringBuilder lpExeName, ref uint lpdwSize);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CloseHandle(IntPtr hObject);

        [DllImport("user32.dll")]
        private static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);

        [DllImport("user32.dll")]
        private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

        private IntPtr _hookId = IntPtr.Zero;
        private LowLevelMouseProc _proc;

        // Smooth scroll physics state
        private double _scrollVelocity = 0.0;
        private readonly object _scrollLock = new object();
        private System.Threading.Timer _physicsTimer;
        private volatile bool _isRunning = false;

        // Micro-cache for foreground process detection (< 0.05ms check)
        private IntPtr _cachedHwnd = IntPtr.Zero;
        private string _cachedProcessName = string.Empty;
        private int _cachedTick = 0;
        private const int CacheTtlMs = 250;

        public MouseHook() {
            _proc = HookCallback;
        }

        public void Start() {
            if (_hookId != IntPtr.Zero) return;

            using (Process curProcess = Process.GetCurrentProcess())
            using (ProcessModule curModule = curProcess.MainModule) {
                _hookId = SetWindowsHookEx(WH_MOUSE_LL, _proc, GetModuleHandle(curModule.ModuleName), 0);
            }

            _isRunning = true;
            _physicsTimer = new System.Threading.Timer(PhysicsTick, null, 16, 16);
            Debug.WriteLine("[MouseSave] Low-level mouse hook registered: " + (_hookId != IntPtr.Zero));
        }

        public void Stop() {
            _isRunning = false;
            if (_physicsTimer != null) {
                _physicsTimer.Dispose();
                _physicsTimer = null;
            }

            if (_hookId != IntPtr.Zero) {
                UnhookWindowsHookEx(_hookId);
                _hookId = IntPtr.Zero;
                Debug.WriteLine("[MouseSave] Low-level mouse hook removed.");
            }
        }

        private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
            if (nCode >= 0) {
                MSLLHOOKSTRUCT hookStruct = (MSLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(MSLLHOOKSTRUCT));

                // 1. Ignore events synthesized by MouseSave itself
                if (hookStruct.dwExtraInfo == SYNTHESIZED_EXTRA_INFO) {
                    return CallNextHookEx(_hookId, nCode, wParam, lParam);
                }

                AppSettings settings = AppSettings.Shared;
                if (!settings.IsEnabled) {
                    return CallNextHookEx(_hookId, nCode, wParam, lParam);
                }

                // 2. Game Mode / Exclusion Check:
                // If the foreground window belongs to an excluded application/game,
                // completely bypass MouseSave and pass all raw events through without latency!
                if (IsForegroundExcluded()) {
                    return CallNextHookEx(_hookId, nCode, wParam, lParam);
                }

                int msg = wParam.ToInt32();

                // 3. Mouse Wheel Interception
                if (msg == WM_MOUSEWHEEL) {
                    short rawDelta = (short)((hookStruct.mouseData >> 16) & 0xffff);
                    bool handled = HandleMouseWheel(rawDelta, settings.Scrolling);
                    if (handled) {
                        return (IntPtr)1; // Suppress raw event
                    }
                }
                // 4. Horizontal / Tilt Wheel Interception
                else if (msg == WM_MOUSEHWHEEL) {
                    short hDelta = (short)((hookStruct.mouseData >> 16) & 0xffff);
                    string tiltKey = (hDelta < 0) ? "tiltLeft" : "tiltRight";
                    if (ButtonPressed != null) ButtonPressed(tiltKey);

                    if (IsCapturingButton && OnButtonCaptured != null) {
                        Action<string> cb = OnButtonCaptured;
                        IsCapturingButton = false;
                        OnButtonCaptured = null;
                        cb(tiltKey);
                        return (IntPtr)1;
                    }

                    string tiltAction = (hDelta < 0) ? settings.Buttons.TiltLeftAction : settings.Buttons.TiltRightAction;
                    if (HandleButtonAction(tiltAction)) {
                        return (IntPtr)1;
                    }
                }
                // 5. Middle Button Interception
                else if (msg == WM_MBUTTONDOWN) {
                    if (ButtonPressed != null) ButtonPressed("middle");

                    if (IsCapturingButton && OnButtonCaptured != null) {
                        Action<string> cb = OnButtonCaptured;
                        IsCapturingButton = false;
                        OnButtonCaptured = null;
                        cb("middle");
                        return (IntPtr)1;
                    }

                    if (HandleButtonAction(settings.Buttons.MiddleClickAction)) {
                        return (IntPtr)1;
                    }
                }
                // 6. Side Buttons (XButton 1 & 2) Interception
                else if (msg == WM_XBUTTONDOWN) {
                    int xButton = (int)((hookStruct.mouseData >> 16) & 0xffff);
                    string btnKey = (xButton == XBUTTON1) ? "button4" : "button5";
                    if (ButtonPressed != null) ButtonPressed(btnKey);

                    if (IsCapturingButton && OnButtonCaptured != null) {
                        Action<string> cb = OnButtonCaptured;
                        IsCapturingButton = false;
                        OnButtonCaptured = null;
                        cb(btnKey);
                        return (IntPtr)1;
                    }

                    string action = (xButton == XBUTTON1) 
                        ? settings.Buttons.Button4Action 
                        : settings.Buttons.Button5Action;

                    if (HandleButtonAction(action)) {
                        return (IntPtr)1;
                    }
                }
            }

            return CallNextHookEx(_hookId, nCode, wParam, lParam);
        }

        /// <summary>
        /// High-performance check if current foreground process is in ExcludedApps (< 0.05ms)
        /// </summary>
        public bool IsForegroundExcluded() {
            try {
                string procName = GetForegroundProcessName();
                if (string.IsNullOrEmpty(procName)) return false;

                List<string> excluded = AppSettings.Shared.ExcludedApps;
                if (excluded == null || excluded.Count == 0) return false;

                for (int i = 0; i < excluded.Count; i++) {
                    string item = excluded[i];
                    if (string.IsNullOrEmpty(item)) continue;

                    // Match either full filename (cs2.exe) or base name (cs2)
                    if (string.Equals(procName, item, StringComparison.OrdinalIgnoreCase)) {
                        return true;
                    }
                    if (string.Equals(Path.GetFileNameWithoutExtension(procName), Path.GetFileNameWithoutExtension(item), StringComparison.OrdinalIgnoreCase)) {
                        return true;
                    }
                }
            } catch (Exception ex) {
                Debug.WriteLine("[MouseSave] Exclusion check error: " + ex.Message);
            }

            return false;
        }

        public string GetForegroundProcessName() {
            IntPtr hwnd = GetForegroundWindow();
            if (hwnd == IntPtr.Zero) return string.Empty;

            int currentTick = Environment.TickCount;

            // Micro-cache check (valid for 250ms per HWND)
            if (hwnd == _cachedHwnd && unchecked(currentTick - _cachedTick) < CacheTtlMs) {
                return _cachedProcessName;
            }

            uint processId = 0;
            GetWindowThreadProcessId(hwnd, out processId);
            if (processId == 0) return string.Empty;

            string processName = string.Empty;
            IntPtr hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, processId);
            if (hProcess != IntPtr.Zero) {
                try {
                    StringBuilder sb = new StringBuilder(1024);
                    uint size = (uint)sb.Capacity;
                    if (QueryFullProcessImageName(hProcess, 0, sb, ref size)) {
                        processName = Path.GetFileName(sb.ToString());
                    }
                } finally {
                    CloseHandle(hProcess);
                }
            }

            // Fallback to Process class if QueryFullProcessImageName failed
            if (string.IsNullOrEmpty(processName)) {
                try {
                    using (Process p = Process.GetProcessById((int)processId)) {
                        processName = p.ProcessName + ".exe";
                    }
                } catch {
                    processName = string.Empty;
                }
            }

            _cachedHwnd = hwnd;
            _cachedProcessName = processName;
            _cachedTick = currentTick;

            return processName;
        }

        private bool HandleMouseWheel(short rawDelta, ScrollingSettings config) {
            if (rawDelta == 0) return false;

            double direction = (rawDelta > 0) ? 1.0 : -1.0;
            if (config.InvertDirection) {
                direction = -direction;
            }

            if (!config.SmoothScrolling) {
                // If smooth scrolling is disabled, but inverted: synthesize inverted tick
                if (config.InvertDirection) {
                    int invertedDelta = (int)(direction * Math.Abs(rawDelta));
                    mouse_event(MOUSEEVENTF_WHEEL, 0, 0, (uint)invertedDelta, SYNTHESIZED_EXTRA_INFO);
                    return true;
                }
                return false; // Let OS handle naturally
            }

            // Smooth inertial scrolling calculation
            double impulse = direction * Math.Abs(rawDelta) * config.Acceleration;
            lock (_scrollLock) {
                _scrollVelocity += impulse;
            }

            return true;
        }

        private void PhysicsTick(object state) {
            if (!_isRunning) return;

            double currentVelocity = 0.0;
            ScrollingSettings config = AppSettings.Shared.Scrolling;

            lock (_scrollLock) {
                if (Math.Abs(_scrollVelocity) < 1.0) {
                    _scrollVelocity = 0.0;
                    return;
                }

                currentVelocity = _scrollVelocity;
                _scrollVelocity *= config.Friction;
            }

            int step = (int)Math.Round(currentVelocity * 0.25);
            if (step != 0) {
                mouse_event(MOUSEEVENTF_WHEEL, 0, 0, (uint)step, SYNTHESIZED_EXTRA_INFO);
            }
        }

        private bool HandleButtonAction(string action) {
            if (string.IsNullOrEmpty(action) || action == "default") {
                return false; // Let standard behavior pass through
            }

            if (action == "none") {
                return true; // Suppress
            }

            if (action == "taskView") {
                // Trigger Win + Tab
                ThreadPool.QueueUserWorkItem(delegate {
                    keybd_event(VK_LWIN, 0, KEYEVENTF_EXTENDEDKEY, UIntPtr.Zero);
                    keybd_event(VK_TAB, 0, 0, UIntPtr.Zero);
                    keybd_event(VK_TAB, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
                    keybd_event(VK_LWIN, 0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, UIntPtr.Zero);
                });
                return true;
            }

            if (action == "desktop") {
                // Trigger Win + D
                ThreadPool.QueueUserWorkItem(delegate {
                    keybd_event(VK_LWIN, 0, KEYEVENTF_EXTENDEDKEY, UIntPtr.Zero);
                    keybd_event(VK_D, 0, 0, UIntPtr.Zero);
                    keybd_event(VK_D, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
                    keybd_event(VK_LWIN, 0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, UIntPtr.Zero);
                });
                return true;
            }

            if (action == "closeWindow") {
                // Trigger Ctrl + W
                ThreadPool.QueueUserWorkItem(delegate {
                    keybd_event(VK_CONTROL, 0, 0, UIntPtr.Zero);
                    keybd_event(VK_W, 0, 0, UIntPtr.Zero);
                    keybd_event(VK_W, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
                    keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
                });
                return true;
            }

            if (action == "switchTabLeft") {
                // Trigger Ctrl + Shift + Tab
                ThreadPool.QueueUserWorkItem(delegate {
                    keybd_event(VK_CONTROL, 0, 0, UIntPtr.Zero);
                    keybd_event(VK_SHIFT, 0, 0, UIntPtr.Zero);
                    keybd_event(VK_TAB, 0, 0, UIntPtr.Zero);
                    keybd_event(VK_TAB, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
                    keybd_event(VK_SHIFT, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
                    keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
                });
                return true;
            }

            if (action == "switchTabRight") {
                // Trigger Ctrl + Tab
                ThreadPool.QueueUserWorkItem(delegate {
                    keybd_event(VK_CONTROL, 0, 0, UIntPtr.Zero);
                    keybd_event(VK_TAB, 0, 0, UIntPtr.Zero);
                    keybd_event(VK_TAB, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
                    keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
                });
                return true;
            }

            if (action == "back") {
                // Trigger Alt + Left
                ThreadPool.QueueUserWorkItem(delegate {
                    keybd_event(VK_MENU, 0, 0, UIntPtr.Zero);
                    keybd_event(VK_LEFT, 0, 0, UIntPtr.Zero);
                    keybd_event(VK_LEFT, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
                    keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
                });
                return true;
            }

            if (action == "forward") {
                // Trigger Alt + Right
                ThreadPool.QueueUserWorkItem(delegate {
                    keybd_event(VK_MENU, 0, 0, UIntPtr.Zero);
                    keybd_event(VK_RIGHT, 0, 0, UIntPtr.Zero);
                    keybd_event(VK_RIGHT, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
                    keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
                });
                return true;
            }

            return false;
        }

        public void Dispose() {
            Stop();
        }
    }
}
