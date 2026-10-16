using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Reflection;
using System.Threading;
using System.Windows.Forms;
using MouseSave.Controls;

[assembly: AssemblyTitle("MouseSave")]
[assembly: AssemblyProduct("MouseSave")]
[assembly: AssemblyVersion("1.1.0.0")]
[assembly: AssemblyFileVersion("1.1.0.0")]

namespace MouseSave {
    public static class Program {
        private const string MutexName = "MouseSave_SingleInstance_App_Mutex";
        private static Mutex _appMutex;
        private static NotifyIcon _trayIcon;
        private static ContextMenuStrip _trayMenu;
        private static MouseHook _mouseHook;
        private static SettingsForm _settingsForm;
        private static System.Windows.Forms.Timer _statusTimer;

        [STAThread]
        public static void Main(string[] args) {
            try {
                bool createdNew;
                _appMutex = new Mutex(true, MutexName, out createdNew);

                if (!createdNew) {
                    MessageBox.Show(
                        "MouseSave is already running in the system tray.",
                        "MouseSave",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Information
                    );
                    return;
                }

                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);

                _mouseHook = new MouseHook();
                _mouseHook.Start();

                InitializeTray();

                bool startMinimized = false;
                foreach (string arg in args) {
                    if (arg.Equals("--minimized", StringComparison.OrdinalIgnoreCase)) {
                        startMinimized = true;
                        break;
                    }
                }

                if (!startMinimized) {
                    ShowSettings();
                }

                Application.Run();

                // Clean exit
                if (_statusTimer != null) {
                    _statusTimer.Stop();
                    _statusTimer.Dispose();
                }
                if (_mouseHook != null) {
                    _mouseHook.Dispose();
                }
                if (_trayIcon != null) {
                    _trayIcon.Visible = false;
                    _trayIcon.Dispose();
                }
                _appMutex.ReleaseMutex();
            } catch (Exception ex) {
                MessageBox.Show(ex.Message, "MouseSave Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private static void InitializeTray() {
            _trayMenu = new ContextMenuStrip();
            _trayMenu.Renderer = new FluentMenuRenderer();
            _trayMenu.Opening += delegate {
                UpdateTrayMenu();
            };

            _trayIcon = new NotifyIcon {
                Text = "MouseSave",
                Icon = CreateAppIcon(32),
                ContextMenuStrip = _trayMenu,
                Visible = AppSettings.Shared.ShowInMenuBar
            };

            _trayIcon.DoubleClick += delegate {
                ShowSettings();
            };

            UpdateTrayMenu();

            // Periodic status update timer (1s)
            _statusTimer = new System.Windows.Forms.Timer();
            _statusTimer.Interval = 1000;
            _statusTimer.Tick += delegate {
                UpdateTrayTooltip();
            };
            _statusTimer.Start();
        }

        private static string GetCurrentStatus(out bool isBypassed) {
            AppSettings s = AppSettings.Shared;
            isBypassed = false;
            if (!s.IsEnabled) {
                return Localization.Get("statusDisabled");
            }
            if (_mouseHook != null && _mouseHook.IsForegroundExcluded()) {
                isBypassed = true;
                string proc = _mouseHook.GetForegroundProcessName();
                return string.Format(Localization.Get("statusGameMode"), proc);
            }
            return Localization.Get("statusRunning");
        }

        private static void UpdateTrayTooltip() {
            if (_trayIcon == null) return;
            bool isBypassed;
            string status = GetCurrentStatus(out isBypassed);
            if (status.Length > 63) {
                status = status.Substring(0, 60) + "...";
            }
            try {
                _trayIcon.Text = status;
            } catch {}
        }

        private static void UpdateTrayMenu() {
            _trayMenu.Items.Clear();

            AppSettings s = AppSettings.Shared;
            bool isBypassed;
            string statusText = GetCurrentStatus(out isBypassed);

            // 1. Header status
            ToolStripMenuItem statusItem = new ToolStripMenuItem(statusText) {
                Enabled = false,
                Font = Theme.GetTextFont(9f, FontStyle.Bold)
            };
            _trayMenu.Items.Add(statusItem);

            _trayMenu.Items.Add(new ToolStripSeparator());

            // 2. Toggle Enabled
            ToolStripMenuItem toggleItem = new ToolStripMenuItem(Localization.Get("enableMouseSave")) {
                Checked = s.IsEnabled,
                CheckOnClick = true
            };
            toggleItem.Click += delegate {
                s.IsEnabled = toggleItem.Checked;
                s.Save();
                UpdateTrayMenu();
                UpdateTrayTooltip();
            };
            _trayMenu.Items.Add(toggleItem);

            _trayMenu.Items.Add(new ToolStripSeparator());

            // 3. Settings
            ToolStripMenuItem settingsItem = new ToolStripMenuItem(Localization.Get("settingsMenu"));
            settingsItem.Click += delegate {
                ShowSettings();
            };
            _trayMenu.Items.Add(settingsItem);

            _trayMenu.Items.Add(new ToolStripSeparator());

            // 4. Quit
            ToolStripMenuItem quitItem = new ToolStripMenuItem(Localization.Get("quit"));
            quitItem.Click += delegate {
                Application.Exit();
            };
            _trayMenu.Items.Add(quitItem);
        }

        private static void ShowSettings() {
            if (_settingsForm == null || _settingsForm.IsDisposed) {
                _settingsForm = new SettingsForm();
            }
            _settingsForm.Show();
            _settingsForm.WindowState = FormWindowState.Normal;
            _settingsForm.BringToFront();
            _settingsForm.Activate();
        }

        private static Icon CreateAppIcon(int size) {
            using (Bitmap bmp = new Bitmap(size, size))
            using (Graphics g = Graphics.FromImage(bmp)) {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.Clear(Color.Transparent);

                int pad = Math.Max(2, size / 16);
                int w = size - pad * 2;
                int h = size - pad * 2;

                Rectangle rect = new Rectangle(pad, pad, w, h);
                int radius = w / 2;

                // Mouse body
                using (GraphicsPath path = Theme.CreateRoundedRectangle(rect, radius)) {
                    Color fill = Theme.AccentColor;
                    using (SolidBrush b = new SolidBrush(fill)) {
                        g.FillPath(b, path);
                    }
                    using (Pen p = new Pen(Color.White, Math.Max(1.2f, size / 20f))) {
                        g.DrawPath(p, path);
                    }
                }

                // Middle wheel
                int wheelW = Math.Max(3, size / 8);
                int wheelH = Math.Max(5, size / 4);
                int wheelX = (size - wheelW) / 2;
                int wheelY = pad + size / 8;
                Rectangle wheelRect = new Rectangle(wheelX, wheelY, wheelW, wheelH);
                using (GraphicsPath wheelPath = Theme.CreateRoundedRectangle(wheelRect, wheelW / 2))
                using (SolidBrush wb = new SolidBrush(Color.White)) {
                    g.FillPath(wb, wheelPath);
                }

                IntPtr hIcon = bmp.GetHicon();
                return Icon.FromHandle(hIcon);
            }
        }
    }
}
