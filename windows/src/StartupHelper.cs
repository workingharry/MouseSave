using System;
using System.IO;
using System.Windows.Forms;
using Microsoft.Win32;

namespace MouseSave {
    public static class StartupHelper {
        private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
        private const string AppName = "MouseSave";

        public static bool IsStartupEnabled() {
            try {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(RunKeyPath, false)) {
                    if (key != null) {
                        object value = key.GetValue(AppName);
                        return value != null;
                    }
                }
            } catch (Exception ex) {
                System.Diagnostics.Debug.WriteLine("[MouseSave] Check startup error: " + ex.Message);
            }
            return false;
        }

        public static void SetStartup(bool enable) {
            try {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(RunKeyPath, true)) {
                    if (key != null) {
                        if (enable) {
                            string exePath = Application.ExecutablePath;
                            key.SetValue(AppName, "\"" + exePath + "\" --minimized");
                        } else {
                            key.DeleteValue(AppName, false);
                        }
                    }
                }
            } catch (Exception ex) {
                System.Diagnostics.Debug.WriteLine("[MouseSave] Set startup error: " + ex.Message);
            }
        }
    }
}
