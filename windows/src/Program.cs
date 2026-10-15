using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Threading;
using System.Windows.Forms;

namespace MouseSave {
    public static class Program {
        private const string MutexName = "MouseSave_SingleInstance_App_Mutex";
        private static Mutex _appMutex;
        private static NotifyIcon _trayIcon;
        private static ContextMenuStrip _trayMenu;
        private static MouseHook _mouseHook;
        private static SettingsForm _settingsForm;

        [STAThread]
        public static void Main(string[] args) {
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

            InitializeTray();

            _mouseHook = new MouseHook();
            _mouseHook.Start();

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
            if (_mouseHook != null) {
                _mouseHook.Dispose();
            }
            if (_trayIcon != null) {
                _trayIcon.Visible = false;
                _trayIcon.Dispose();
            }
            _appMutex.ReleaseMutex();
        }

        private static void InitializeTray() {
            _trayMenu = new ContextMenuStrip();
            UpdateTrayMenu();

            _trayIcon = new NotifyIcon {
                Text = "MouseSave",
                Icon = CreateAppIcon(),
                ContextMenuStrip = _trayMenu,
                Visible = AppSettings.Shared.ShowInMenuBar
            };

            _trayIcon.DoubleClick += delegate {
                ShowSettings();
            };
        }

        private static void UpdateTrayMenu() {
            _trayMenu.Items.Clear();

            AppSettings s = AppSettings.Shared;

            // Header status
            string statusText = s.IsEnabled ? Localization.Get("statusRunning") : Localization.Get("statusDisabled");
            ToolStripMenuItem statusItem = new ToolStripMenuItem(statusText) {
                Enabled = false,
                Font = new Font(_trayMenu.Font, FontStyle.Bold)
            };
            _trayMenu.Items.Add(statusItem);

            // Toggle Enabled
            ToolStripMenuItem toggleItem = new ToolStripMenuItem(Localization.Get("enableMouseSave")) {
                Checked = s.IsEnabled,
                CheckOnClick = true
            };
            toggleItem.Click += delegate {
                s.IsEnabled = toggleItem.Checked;
                s.Save();
                UpdateTrayMenu();
            };
            _trayMenu.Items.Add(toggleItem);

            _trayMenu.Items.Add(new ToolStripSeparator());

            // Settings
            ToolStripMenuItem settingsItem = new ToolStripMenuItem(Localization.Get("settingsMenu"));
            settingsItem.Click += delegate {
                ShowSettings();
            };
            _trayMenu.Items.Add(settingsItem);

            _trayMenu.Items.Add(new ToolStripSeparator());

            // Quit
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

        private static Icon CreateAppIcon() {
            // Generate a crisp vector mouse icon
            using (Bitmap bmp = new Bitmap(32, 32))
            using (Graphics g = Graphics.FromImage(bmp)) {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.Clear(Color.Transparent);

                // Body background
                using (GraphicsPath path = new GraphicsPath()) {
                    path.AddArc(6, 4, 20, 20, 180, 180);
                    path.AddArc(6, 12, 20, 16, 0, 180);
                    path.CloseFigure();

                    using (SolidBrush bodyBrush = new SolidBrush(Color.FromArgb(20, 115, 230))) {
                        g.FillPath(bodyBrush, path);
                    }
                    using (Pen borderPen = new Pen(Color.FromArgb(255, 255, 255), 1.5f)) {
                        g.DrawPath(borderPen, path);
                    }
                }

                // Middle wheel
                using (SolidBrush wheelBrush = new SolidBrush(Color.White)) {
                    g.FillRectangle(wheelBrush, 14, 7, 4, 8);
                }

                IntPtr hIcon = bmp.GetHicon();
                return Icon.FromHandle(hIcon);
            }
        }
    }
}
