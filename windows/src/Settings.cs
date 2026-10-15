using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace MouseSave {
    public class ScrollingSettings {
        public bool SmoothScrolling { get; set; }
        public double Friction { get; set; }
        public double Acceleration { get; set; }
        public bool InvertDirection { get; set; }

        public ScrollingSettings() {
            SmoothScrolling = true;
            Friction = 0.88;
            Acceleration = 1.25;
            InvertDirection = false;
        }
    }

    public class ButtonSettings {
        public string MiddleClickAction { get; set; }
        public string Button4Action { get; set; }
        public string Button5Action { get; set; }

        public ButtonSettings() {
            MiddleClickAction = "default";
            Button4Action = "back";
            Button5Action = "forward";
        }
    }

    public class AppSettings {
        private static AppSettings _shared;
        public static AppSettings Shared {
            get {
                if (_shared == null) {
                    _shared = Load();
                }
                return _shared;
            }
        }

        public bool IsEnabled { get; set; }
        public bool ShowInMenuBar { get; set; }
        public bool LaunchAtLogin { get; set; }
        public string Language { get; set; }
        public List<string> ExcludedApps { get; set; }
        public ScrollingSettings Scrolling { get; set; }
        public ButtonSettings Buttons { get; set; }

        public AppSettings() {
            IsEnabled = true;
            ShowInMenuBar = true;
            LaunchAtLogin = false;
            Language = "auto";
            ExcludedApps = new List<string> {
                "cs2.exe",
                "valorant.exe",
                "League of Legends.exe",
                "Overwatch.exe",
                "Apex.exe",
                "Blender.exe"
            };
            Scrolling = new ScrollingSettings();
            Buttons = new ButtonSettings();
        }

        public static string GetSettingsPath() {
            string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string dir = Path.Combine(appData, "MouseSave");
            if (!Directory.Exists(dir)) {
                Directory.CreateDirectory(dir);
            }
            return Path.Combine(dir, "settings.json");
        }

        public void Save() {
            try {
                string path = GetSettingsPath();
                StringBuilder sb = new StringBuilder();
                sb.AppendLine("{");
                sb.AppendLine(string.Format("  \"isEnabled\": {0},", IsEnabled.ToString().ToLower()));
                sb.AppendLine(string.Format("  \"showInMenuBar\": {0},", ShowInMenuBar.ToString().ToLower()));
                sb.AppendLine(string.Format("  \"launchAtLogin\": {0},", LaunchAtLogin.ToString().ToLower()));
                sb.AppendLine(string.Format("  \"language\": \"{0}\",", Language));
                
                // Excluded Apps array
                sb.AppendLine("  \"excludedApps\": [");
                if (ExcludedApps != null && ExcludedApps.Count > 0) {
                    for (int i = 0; i < ExcludedApps.Count; i++) {
                        string app = ExcludedApps[i].Replace("\"", "\\\"");
                        string comma = (i < ExcludedApps.Count - 1) ? "," : "";
                        sb.AppendLine(string.Format("    \"{0}\"{1}", app, comma));
                    }
                }
                sb.AppendLine("  ],");

                sb.AppendLine("  \"scrolling\": {");
                sb.AppendLine(string.Format("    \"smoothScrolling\": {0},", Scrolling.SmoothScrolling.ToString().ToLower()));
                sb.AppendLine(string.Format("    \"friction\": {0:0.00},", Scrolling.Friction));
                sb.AppendLine(string.Format("    \"acceleration\": {0:0.00},", Scrolling.Acceleration));
                sb.AppendLine(string.Format("    \"invertDirection\": {0}", Scrolling.InvertDirection.ToString().ToLower()));
                sb.AppendLine("  },");
                sb.AppendLine("  \"buttons\": {");
                sb.AppendLine(string.Format("    \"middleClickAction\": \"{0}\",", Buttons.MiddleClickAction));
                sb.AppendLine(string.Format("    \"button4Action\": \"{0}\",", Buttons.Button4Action));
                sb.AppendLine(string.Format("    \"button5Action\": \"{0}\"", Buttons.Button5Action));
                sb.AppendLine("  }");
                sb.AppendLine("}");

                File.WriteAllText(path, sb.ToString(), Encoding.UTF8);
            } catch (Exception ex) {
                System.Diagnostics.Debug.WriteLine("[MouseSave] Save error: " + ex.Message);
            }
        }

        public static AppSettings Load() {
            AppSettings settings = new AppSettings();
            try {
                string path = GetSettingsPath();
                if (File.Exists(path)) {
                    string json = File.ReadAllText(path, Encoding.UTF8);

                    settings.IsEnabled = ExtractBool(json, "isEnabled", true);
                    settings.ShowInMenuBar = ExtractBool(json, "showInMenuBar", true);
                    settings.LaunchAtLogin = ExtractBool(json, "launchAtLogin", false);
                    settings.Language = ExtractString(json, "language", "auto");

                    List<string> apps = ExtractStringList(json, "excludedApps");
                    if (apps != null && apps.Count > 0) {
                        settings.ExcludedApps = apps;
                    }

                    settings.Scrolling.SmoothScrolling = ExtractBool(json, "smoothScrolling", true);
                    settings.Scrolling.Friction = ExtractDouble(json, "friction", 0.88);
                    settings.Scrolling.Acceleration = ExtractDouble(json, "acceleration", 1.25);
                    settings.Scrolling.InvertDirection = ExtractBool(json, "invertDirection", false);

                    settings.Buttons.MiddleClickAction = ExtractString(json, "middleClickAction", "default");
                    settings.Buttons.Button4Action = ExtractString(json, "button4Action", "back");
                    settings.Buttons.Button5Action = ExtractString(json, "button5Action", "forward");
                }
            } catch (Exception ex) {
                System.Diagnostics.Debug.WriteLine("[MouseSave] Load error: " + ex.Message);
            }
            return settings;
        }

        private static bool ExtractBool(string json, string key, bool defaultValue) {
            string pattern = "\"" + key + "\"\\s*:\\s*(true|false)";
            var match = System.Text.RegularExpressions.Regex.Match(json, pattern, System.Text.RegularExpressions.RegexOptions.IgnoreCase);
            if (match.Success) {
                return bool.Parse(match.Groups[1].Value);
            }
            return defaultValue;
        }

        private static string ExtractString(string json, string key, string defaultValue) {
            string pattern = "\"" + key + "\"\\s*:\\s*\"([^\"]*)\"";
            var match = System.Text.RegularExpressions.Regex.Match(json, pattern);
            if (match.Success) {
                return match.Groups[1].Value;
            }
            return defaultValue;
        }

        private static double ExtractDouble(string json, string key, double defaultValue) {
            string pattern = "\"" + key + "\"\\s*:\\s*([0-9.]+)";
            var match = System.Text.RegularExpressions.Regex.Match(json, pattern);
            if (match.Success) {
                double val;
                if (double.TryParse(match.Groups[1].Value, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out val)) {
                    return val;
                }
            }
            return defaultValue;
        }

        private static List<string> ExtractStringList(string json, string key) {
            List<string> result = new List<string>();
            string pattern = "\"" + key + "\"\\s*:\\s*\\[([^\\]]*)\\]";
            var match = System.Text.RegularExpressions.Regex.Match(json, pattern);
            if (match.Success) {
                string arrayBody = match.Groups[1].Value;
                var itemMatches = System.Text.RegularExpressions.Regex.Matches(arrayBody, "\"([^\"]*)\"");
                foreach (System.Text.RegularExpressions.Match im in itemMatches) {
                    string val = im.Groups[1].Value.Trim();
                    if (!string.IsNullOrEmpty(val)) {
                        result.Add(val);
                    }
                }
            }
            return result;
        }
    }
}
