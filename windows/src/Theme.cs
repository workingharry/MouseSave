using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using Microsoft.Win32;

namespace MouseSave {
    public static class Theme {
        // DWM Window Attributes
        public const int DWMWA_USE_IMMERSIVE_DARK_MODE_BEFORE_20H1 = 19;
        public const int DWMWA_USE_IMMERSIVE_DARK_MODE = 20;
        public const int DWMWA_WINDOW_CORNER_PREFERENCE = 33;
        public const int DWMWA_SYSTEMBACKDROP_TYPE = 38;

        public const int DWMWCP_ROUND = 2;
        public const int DWMSBT_MAINWINDOW = 2; // Mica

        [DllImport("dwmapi.dll")]
        public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

        [DllImport("gdi32.dll")]
        public static extern int GetDeviceCaps(IntPtr hdc, int nIndex);

        private const int LOGPIXELSX = 88;

        public static event EventHandler ThemeChanged;

        public static bool IsDark { get; private set; }
        public static Color AccentColor { get; private set; }
        public static Color AccentHoverColor { get; private set; }

        public static Color BackgroundColor { get; private set; }
        public static Color CardBackground { get; private set; }
        public static Color CardBorder { get; private set; }
        public static Color TextPrimary { get; private set; }
        public static Color TextSecondary { get; private set; }
        public static Color ControlFill { get; private set; }
        public static Color ControlHover { get; private set; }
        public static Color ControlBorder { get; private set; }
        public static Color NavBackground { get; private set; }
        public static Color NavSelected { get; private set; }

        public static float DpiScaleFactor { get; private set; }

        // Segoe Fluent Icons / Segoe MDL2 glyphs
        public const string IconSettings = "\uE713";
        public const string IconMouse = "\uE962";
        public const string IconScroll = "\uE8CB";
        public const string IconGame = "\uE7FC";
        public const string IconSearch = "\uE721";
        public const string IconDelete = "\uE74D";
        public const string IconAdd = "\uE710";
        public const string IconApp = "\uE71D";
        public const string IconShield = "\uEA18";
        public const string IconCheck = "\uE73E";

        public static string IconFontFamily { get; private set; }
        public static string TextFontFamily { get; private set; }

        static Theme() {
            DpiScaleFactor = 1.0f;
            try {
                using (Graphics g = Graphics.FromHwnd(IntPtr.Zero)) {
                    DpiScaleFactor = g.DpiX / 96.0f;
                }
            } catch {
                DpiScaleFactor = 1.0f;
            }

            DetermineFonts();
            RefreshTheme();

            SystemEvents.UserPreferenceChanged += delegate(object sender, UserPreferenceChangedEventArgs e) {
                if (e.Category == UserPreferenceCategory.General || e.Category == UserPreferenceCategory.Color) {
                    RefreshTheme();
                    if (ThemeChanged != null) {
                        ThemeChanged(null, EventArgs.Empty);
                    }
                }
            };
        }

        private static void DetermineFonts() {
            TextFontFamily = "Segoe UI";
            foreach (FontFamily ff in FontFamily.Families) {
                if (ff.Name.Equals("Segoe UI Variable Text", StringComparison.OrdinalIgnoreCase)) {
                    TextFontFamily = "Segoe UI Variable Text";
                    break;
                }
            }

            IconFontFamily = "Segoe UI Symbol";
            foreach (FontFamily ff in FontFamily.Families) {
                if (ff.Name.Equals("Segoe Fluent Icons", StringComparison.OrdinalIgnoreCase)) {
                    IconFontFamily = "Segoe Fluent Icons";
                    break;
                }
                if (ff.Name.Equals("Segoe MDL2 Assets", StringComparison.OrdinalIgnoreCase)) {
                    IconFontFamily = "Segoe MDL2 Assets";
                }
            }
        }

        public static void RefreshTheme() {
            SetTheme(QueryIsDarkTheme());
        }

        public static void SetTheme(bool dark) {
            IsDark = dark;
            AccentColor = QueryAccentColor(IsDark);
            AccentHoverColor = ControlPaint.Light(AccentColor, 0.15f);

            if (IsDark) {
                BackgroundColor = Color.FromArgb(32, 32, 32);
                CardBackground = Color.FromArgb(43, 43, 43);
                CardBorder = Color.FromArgb(58, 58, 58);
                TextPrimary = Color.FromArgb(255, 255, 255);
                TextSecondary = Color.FromArgb(160, 160, 160);
                ControlFill = Color.FromArgb(50, 50, 50);
                ControlHover = Color.FromArgb(62, 62, 62);
                ControlBorder = Color.FromArgb(70, 70, 70);
                NavBackground = Color.FromArgb(28, 28, 28);
                NavSelected = Color.FromArgb(48, 48, 48);
            } else {
                BackgroundColor = Color.FromArgb(243, 243, 243);
                CardBackground = Color.FromArgb(255, 255, 255);
                CardBorder = Color.FromArgb(229, 229, 229);
                TextPrimary = Color.FromArgb(26, 26, 26);
                TextSecondary = Color.FromArgb(92, 92, 92);
                ControlFill = Color.FromArgb(250, 250, 250);
                ControlHover = Color.FromArgb(240, 240, 240);
                ControlBorder = Color.FromArgb(210, 210, 210);
                NavBackground = Color.FromArgb(238, 238, 238);
                NavSelected = Color.FromArgb(255, 255, 255);
            }

            if (ThemeChanged != null) {
                ThemeChanged(null, EventArgs.Empty);
            }
        }

        private static bool QueryIsDarkTheme() {
            try {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize")) {
                    if (key != null) {
                        object val = key.GetValue("AppsUseLightTheme");
                        if (val is int) {
                            return ((int)val) == 0;
                        }
                    }
                }
            } catch {}
            return false;
        }

        private static Color QueryAccentColor(bool dark) {
            try {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\DWM")) {
                    if (key != null) {
                        object val = key.GetValue("AccentColor");
                        if (val is int) {
                            int abgr = (int)val;
                            int r = abgr & 0xFF;
                            int g = (abgr >> 8) & 0xFF;
                            int b = (abgr >> 16) & 0xFF;
                            return Color.FromArgb(r, g, b);
                        }
                    }
                }
            } catch {}
            return dark ? Color.FromArgb(76, 194, 255) : Color.FromArgb(0, 120, 212);
        }

        public static int Scale(int pixels) {
            return (int)Math.Round(pixels * DpiScaleFactor);
        }

        public static Font GetTextFont(float sizePt, FontStyle style) {
            return new Font(TextFontFamily, sizePt, style);
        }

        public static Font GetIconFont(float sizePt) {
            return new Font(IconFontFamily, sizePt, FontStyle.Regular);
        }

        public static void ApplyWindowStyle(Form form) {
            if (form == null || form.IsDisposed) return;

            try {
                IntPtr handle = form.Handle;

                // 1. Immersive dark mode for titlebar
                int darkMode = IsDark ? 1 : 0;
                int hr = DwmSetWindowAttribute(handle, DWMWA_USE_IMMERSIVE_DARK_MODE, ref darkMode, sizeof(int));
                if (hr != 0) {
                    DwmSetWindowAttribute(handle, DWMWA_USE_IMMERSIVE_DARK_MODE_BEFORE_20H1, ref darkMode, sizeof(int));
                }

                // 2. Rounded corners (Windows 11)
                int cornerPref = DWMWCP_ROUND;
                DwmSetWindowAttribute(handle, DWMWA_WINDOW_CORNER_PREFERENCE, ref cornerPref, sizeof(int));

                // 3. System Backdrop (Mica)
                int backdrop = DWMSBT_MAINWINDOW;
                DwmSetWindowAttribute(handle, DWMWA_SYSTEMBACKDROP_TYPE, ref backdrop, sizeof(int));
            } catch {}
        }

        public static GraphicsPath CreateRoundedRectangle(Rectangle bounds, int radius) {
            GraphicsPath path = new GraphicsPath();
            if (radius <= 0) {
                path.AddRectangle(bounds);
                return path;
            }

            int diameter = radius * 2;
            Size size = new Size(diameter, diameter);
            Rectangle arc = new Rectangle(bounds.Location, size);

            // top-left
            path.AddArc(arc, 180, 90);
            // top-right
            arc.X = bounds.Right - diameter;
            path.AddArc(arc, 270, 90);
            // bottom-right
            arc.Y = bounds.Bottom - diameter;
            path.AddArc(arc, 0, 90);
            // bottom-left
            arc.X = bounds.Left;
            path.AddArc(arc, 90, 90);

            path.CloseFigure();
            return path;
        }
    }
}
