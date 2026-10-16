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
            { "addApp", "Browse .exe..." },
            { "addRunningApp", "Add Running App" },
            { "removeApp", "Remove Selected" },
            { "selectExecutable", "Select Executable File (*.exe)" },
            { "appAlreadyExists", "This executable is already in the exclusion list." },
            { "settingsMenu", "Settings…" },
            { "quit", "Quit" },
            { "save", "Save & Close" },
            { "reset", "Reset Defaults" },
            { "statusRunning", "MouseSave is running" },
            { "statusDisabled", "MouseSave is paused" },
            { "statusBypassed", "MouseSave paused (Game / Excluded App active)" },
            { "delete", "Delete" },
            { "noExclusionsTitle", "No Excluded Applications" },
            { "noExclusionsDesc", "When games or precision tools are in the foreground, MouseSave automatically bypasses for raw 1:1 hardware control." },
            { "gameModeActiveDesc", "Game Mode Passthrough Active" },
            { "scrollTestHint", "Scroll here to test" },
            { "navGeneral", "General" },
            { "navButtons", "Buttons" },
            { "navScrolling", "Scrolling" },
            { "navExclusions", "Exclusions" },
            { "statusGameMode", "MouseSave: Game Mode Active ({0})" },
            { "tiltLeftAction", "Tilt Wheel Left" },
            { "tiltRightAction", "Tilt Wheel Right" },
            { "detectTitle", "Button Learning & Testing" },
            { "detectButton", "+ Detect" },
            { "pressAnyButton", "Please press any button or tilt the wheel on your mouse..." },
            { "buttonDetected", "Detected: {0}" },
            { "captureTimeout", "No button detected. Make sure the button sends standard mouse events." },
            { "btnMiddle", "Middle Click (Scroll Wheel)" },
            { "btnButton4", "Side Button 4 (Back)" },
            { "btnButton5", "Side Button 5 (Forward)" },
            { "btnTiltLeft", "Tilt Wheel Left" },
            { "btnTiltRight", "Tilt Wheel Right" },
            { "buttonAlreadyMapped", "This button is already configured below." },
            { "noButtonsConfigured", "No custom button rules yet. Click Detect New Button to add." },
            { "actionSwitchTabLeft", "Previous Tab (Ctrl + Shift + Tab)" },
            { "actionSwitchTabRight", "Next Tab (Ctrl + Tab)" },
            { "detectTip", "Click button to detect, or press mouse to test." },
            { "descMiddleClick", "Action performed when clicking the mouse scroll wheel" },
            { "descButton4", "Action for lower thumb side button (Back)" },
            { "descButton5", "Action for upper thumb side button (Forward)" },
            { "descTiltLeft", "Action when tilting the 4-way scroll wheel left" },
            { "descTiltRight", "Action when tilting the 4-way scroll wheel right" }
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
            { "addApp", "瀏覽 .exe..." },
            { "addRunningApp", "加入執行中程式" },
            { "removeApp", "移除選取項目" },
            { "selectExecutable", "選取應用程式或遊戲執行檔 (*.exe)" },
            { "appAlreadyExists", "該應用程式已在排除名單中。" },
            { "settingsMenu", "設定⋯" },
            { "quit", "結束" },
            { "save", "儲存並關閉" },
            { "reset", "重設為預設值" },
            { "statusRunning", "MouseSave 運行中" },
            { "statusDisabled", "MouseSave 已手動暫停" },
            { "statusBypassed", "MouseSave 已暫停（遊戲/排除軟體運行中）" },
            { "delete", "刪除" },
            { "noExclusionsTitle", "尚未排除任何應用程式" },
            { "noExclusionsDesc", "在此新增遊戲或專業繪圖軟體，當其位於前景視窗時 MouseSave 將完全暫停，提供 1:1 原生滑鼠直通操控。" },
            { "gameModeActiveDesc", "遊戲直通模式保護中" },
            { "scrollTestHint", "在此滾動測試手感" },
            { "navGeneral", "一般設定" },
            { "navButtons", "按鍵自訂" },
            { "navScrolling", "平滑捲動" },
            { "navExclusions", "遊戲與排除名單" },
            { "statusGameMode", "MouseSave: 遊戲模式生效中（{0}）" },
            { "tiltLeftAction", "滾輪向左推" },
            { "tiltRightAction", "滾輪向右推" },
            { "detectTitle", "硬體按鍵偵測與學習" },
            { "detectButton", "➕ 偵測按鍵" },
            { "pressAnyButton", "請按下您滑鼠上的任一按鈕或向兩側撥動滾輪..." },
            { "buttonDetected", "已成功辨識：{0}" },
            { "captureTimeout", "未偵測到按鍵，請確認該鍵發送標準滑鼠事件。" },
            { "btnMiddle", "滾輪中鍵 (Middle Click)" },
            { "btnButton4", "側鍵 4（後退鍵 / XButton 1）" },
            { "btnButton5", "側鍵 5（前進鍵 / XButton 2）" },
            { "btnTiltLeft", "四向滾輪向左推 (Tilt Left)" },
            { "btnTiltRight", "四向滾輪向右推 (Tilt Right)" },
            { "buttonAlreadyMapped", "該按鍵已在自訂清單中。" },
            { "noButtonsConfigured", "尚未新增任何按鍵規則，請點擊上方按鈕開始偵測。" },
            { "actionSwitchTabLeft", "切換至左側分頁 (Ctrl + Shift + Tab)" },
            { "actionSwitchTabRight", "切換至右側分頁 (Ctrl + Tab)" },
            { "detectTip", "點擊按鈕進行偵測辨識，或直接點擊滑鼠測試" },
            { "descMiddleClick", "點擊滑鼠滾輪中鍵時執行的動作" },
            { "descButton4", "點擊滑鼠下側鍵（拇指後退鍵）時執行的動作" },
            { "descButton5", "點擊滑鼠上側鍵（拇指前進鍵）時執行的動作" },
            { "descTiltLeft", "向左側撥動四向滾輪時執行的動作" },
            { "descTiltRight", "向右側撥動四向滾輪時執行的動作" }
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
