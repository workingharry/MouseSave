using System;
using System.Collections.Generic;
using System.Globalization;

namespace MouseSave {
    public static class Localization {
        private static readonly Dictionary<string, string> En = new Dictionary<string, string> {
            { "appName", "MouseSave" },
            { "settingsTitle", "MouseSave Settings" },
            { "general", "General" },
            { "buttons", "Buttons" },
            { "scrolling", "Scrolling" },
            { "exclusions", "Exclusions" },
            { "enableMouseSave", "Enable MouseSave" },
            { "showInMenuBar", "Show in system tray" },
            { "launchAtLogin", "Launch at login" },
            { "language", "Language" },
            { "langAuto", "System Default" },
            { "langEn", "English" },
            { "langZhHant", "繁體中文" },
            { "smoothScrolling", "Enable Smooth Scrolling" },
            { "scrollSpeed", "Scroll Speed / Acceleration" },
            { "scrollFriction", "Inertial Smoothness" },
            { "invertScroll", "Invert Scroll Direction (Natural Scrolling)" },
            { "middleClickAction", "Middle Click Action" },
            { "button4Action", "Side Button 4 (Back)" },
            { "button5Action", "Side Button 5 (Forward)" },
            { "actionDefault", "Default Action" },
            { "actionBack", "Back (Browser / Explorer)" },
            { "actionForward", "Forward (Browser / Explorer)" },
            { "actionTaskView", "Task View (Win + Tab)" },
            { "actionDesktop", "Show Desktop (Win + D)" },
            { "actionCloseWindow", "Close Window (Ctrl + W)" },
            { "actionNone", "Disabled" },
            { "exclusionsTitle", "Application Exclusion List (Game Mode)" },
            { "exclusionsDesc", "When these apps/games are in the foreground, MouseSave is completely paused for raw, precise mouse response." },
            { "addApp", "Browse & Add (.exe)..." },
            { "addRunningApp", "Add Active Process" },
            { "removeApp", "Remove Selected" },
            { "selectExecutable", "Select Executable File (*.exe)" },
            { "appAlreadyExists", "This executable is already in the exclusion list." },
            { "settingsMenu", "Settings…" },
            { "quit", "Quit" },
            { "save", "Save & Close" },
            { "reset", "Reset Defaults" },
            { "statusRunning", "MouseSave is running" },
            { "statusDisabled", "MouseSave is paused" },
            { "statusBypassed", "MouseSave paused (Game / Excluded App active)" }
        };

        private static readonly Dictionary<string, string> ZhHant = new Dictionary<string, string> {
            { "appName", "MouseSave" },
            { "settingsTitle", "MouseSave 設定" },
            { "general", "一般" },
            { "buttons", "按鍵" },
            { "scrolling", "捲動" },
            { "exclusions", "排除名單" },
            { "enableMouseSave", "啟用 MouseSave" },
            { "showInMenuBar", "在系統匣中顯示圖示" },
            { "launchAtLogin", "登入時自動啟動" },
            { "language", "介面語言" },
            { "langAuto", "跟隨系統" },
            { "langEn", "English" },
            { "langZhHant", "繁體中文" },
            { "smoothScrolling", "啟用平滑慣性捲動" },
            { "scrollSpeed", "捲動速度 / 加速度" },
            { "scrollFriction", "平滑阻尼 / 慣性" },
            { "invertScroll", "反轉捲動方向（自然捲動）" },
            { "middleClickAction", "滾輪中鍵動作" },
            { "button4Action", "側鍵 4（後退鍵）" },
            { "button5Action", "側鍵 5（前進鍵）" },
            { "actionDefault", "系統預設行為" },
            { "actionBack", "後退（瀏覽器 / 檔案總管）" },
            { "actionForward", "前進（瀏覽器 / 檔案總管）" },
            { "actionTaskView", "工作檢視 (Win + Tab)" },
            { "actionDesktop", "顯示桌面 (Win + D)" },
            { "actionCloseWindow", "關閉當前視窗 (Ctrl + W)" },
            { "actionNone", "停用此按鍵" },
            { "exclusionsTitle", "應用程式排除名單（遊戲模式）" },
            { "exclusionsDesc", "當這些軟體或遊戲處於前景視窗時，MouseSave 將完全暫停，提供零延遲的原生滑鼠操作。" },
            { "addApp", "瀏覽並新增 (.exe)..." },
            { "addRunningApp", "加入當前運行的行程" },
            { "removeApp", "移除選取項目" },
            { "selectExecutable", "選取應用程式或遊戲執行檔 (*.exe)" },
            { "appAlreadyExists", "該應用程式已在排除名單中。" },
            { "settingsMenu", "設定⋯" },
            { "quit", "結束" },
            { "save", "儲存並關閉" },
            { "reset", "重設為預設值" },
            { "statusRunning", "MouseSave 運行中" },
            { "statusDisabled", "MouseSave 已手動暫停" },
            { "statusBypassed", "MouseSave 已暫停（遊戲/排除軟體運行中）" }
        };

        public static bool IsZhHant() {
            string pref = AppSettings.Shared.Language;
            if (pref == "zh-Hant") return true;
            if (pref == "en") return false;

            string sysCulture = CultureInfo.CurrentUICulture.Name;
            return sysCulture.StartsWith("zh", StringComparison.OrdinalIgnoreCase);
        }

        public static string Get(string key) {
            Dictionary<string, string> dict = IsZhHant() ? ZhHant : En;
            string value;
            if (dict.TryGetValue(key, out value)) {
                return value;
            }
            if (En.TryGetValue(key, out value)) {
                return value;
            }
            return key;
        }
    }
}
