# MouseSave Release v1.1.0

🚀 **MouseSave v1.1.0 - Win11 Fluent Redesign & Hardware Button Detection**

---

### 🌟 新增功能與重點改進 (What's New in v1.1.0)

1. **Windows 11 Fluent Design 風格全新介面**
   - 採用左側導覽列 + 圓角卡片設定佈局，留白充足、層次分明。
   - 智慧支援系統深色 / 淺色模式（監聽 `SystemEvents.UserPreferenceChanged` 即時切換），強調色與系統自動連動。
   - 啟用 DWM 沉浸式深色標題列與 PerMonitorV2 高 DPI 感知，縮放不模糊、不跑版。

2. **智慧按鍵學習與硬體偵測（Hardware Key Learning）**
   - 支援「➕ 偵測按鍵」功能：彈出 5 秒倒數監聽視窗，使用者按下實體按鈕或撥動滾輪時，自動辨識並定位配置。
   - 實體滑鼠點擊時，示意圖即時發出綠光脈衝光暈（Live Hardware Pulse Feedback）。
   - 完美相容雙滑鼠（有側鍵 vs 無側鍵）同時並存使用，即插即用無需手動切換 Profile。

3. **四向水平滾輪（Tilt Wheel）支援**
   - 原生攔截 `WM_MOUSEHWHEEL`（左右撥動滾輪）。
   - 新增分頁切換動作（`Ctrl + Tab` / `Ctrl + Shift + Tab`）、瀏覽器後退 / 前進、顯示桌面等動作。

4. **按鍵設定佈局與視覺化優化**
   - 重整按鍵擺位：按「滾輪組（中鍵、向左推、向右推）」與「側鍵組（前進、後退）」整齊分類。
   - 滑鼠示意圖加入左/右箭頭指示器，點選與點擊反饋一目了然。
   - 修正文字與按鈕重疊問題，邊界與捲軸自適應對齊。

5. **極致輕量與零依賴**
   - 純 .NET Framework 4.0 `csc.exe` 零依賴編譯，單一執行檔僅 **~85 KB**。
   - 閒置 CPU 佔用 **0.0%**，記憶體穩定維持在 **~15MB**。
   - `settings.json` 保持 100% 向下相容。

---

### 📦 下載與安裝 (Download)

- **`MouseSave-v1.1.0-windows-x64.zip`**：解壓縮後雙擊 `MouseSave.exe` 即可直接使用，綠色免安裝。
