import SwiftUI
import Combine

enum NavigationCategory: String, CaseIterable, Identifiable {
    case gestures = "gestures"
    case scrolling = "scrolling"
    case exclusions = "exclusions"
    case general = "general"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gestures:   return "手勢與按鍵"
        case .scrolling:  return "平滑滾動"
        case .exclusions: return "遊戲與排除"
        case .general:    return "一般與系統"
        }
    }

    var systemImage: String {
        switch self {
        case .gestures:   return "hand.draw"
        case .scrolling:  return "arrow.up.and.down.circle"
        case .exclusions: return "gamecontroller"
        case .general:    return "gearshape"
        }
    }
}

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var selectedCategory: NavigationCategory? = .gestures

    var body: some View {
        NavigationSplitView {
            List(NavigationCategory.allCases, selection: $selectedCategory) { category in
                NavigationLink(value: category) {
                    Label(category.title, systemImage: category.systemImage)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.vertical, 3)
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
            .listStyle(.sidebar)
        } detail: {
            Group {
                switch selectedCategory ?? .gestures {
                case .gestures:
                    GesturesAndButtonsTab(settings: settings)
                case .scrolling:
                    SmoothScrollingTab(settings: settings)
                case .exclusions:
                    ExclusionsTab(settings: settings)
                case .general:
                    GeneralTab(settings: settings)
                }
            }
            .frame(minWidth: 460, minHeight: 480)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 680, height: 520)
    }
}

// MARK: - Live Interactive Mouse Canvas

struct LiveMouseCanvasView: View {
    @State private var activeButtons: Set<Int> = []
    @State private var lastGestureText: String = "等待滑鼠操作⋯"
    @State private var gestureArrow: String? = nil
    @State private var gesturePulse: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background subtle glow
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .frame(height: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                HStack(spacing: 36) {
                    // Stylized 2D Vector Mouse
                    ZStack {
                        // Mouse Body Silhouette
                        RoundedRectangle(cornerRadius: 32)
                            .fill(LinearGradient(
                                colors: [Color(white: 0.25), Color(white: 0.16)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .frame(width: 82, height: 120)
                            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)

                        // Left Click Area
                        ButtonShape(isLeft: true)
                            .fill(activeButtons.contains(0) ? Color.cyan : Color.white.opacity(0.05))
                            .frame(width: 36, height: 42)
                            .offset(x: -19, y: -37)

                        // Right Click Area
                        ButtonShape(isLeft: false)
                            .fill(activeButtons.contains(1) ? Color.cyan : Color.white.opacity(0.05))
                            .frame(width: 36, height: 42)
                            .offset(x: 19, y: -37)

                        // Scroll Wheel / Middle Click
                        Capsule()
                            .fill(activeButtons.contains(2) ? Color.cyan : Color.primary.opacity(0.6))
                            .frame(width: 10, height: 26)
                            .offset(y: -35)
                            .shadow(color: activeButtons.contains(2) ? Color.cyan : .clear, radius: 4)

                        // Side Button 4 (Back / Gesture trigger)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(activeButtons.contains(3) ? Color.cyan : Color.gray.opacity(0.7))
                            .frame(width: 5, height: 18)
                            .offset(x: -43, y: -8)
                            .shadow(color: activeButtons.contains(3) ? Color.cyan : .clear, radius: 5)

                        // Side Button 5 (Forward)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(activeButtons.contains(4) ? Color.cyan : Color.gray.opacity(0.7))
                            .frame(width: 5, height: 18)
                            .offset(x: -43, y: -30)
                            .shadow(color: activeButtons.contains(4) ? Color.cyan : .clear, radius: 5)
                    }

                    // Live Status Info & Direction indicator
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle()
                                .fill(gesturePulse ? Color.green : Color.cyan)
                                .frame(width: 8, height: 8)
                            Text("即時手勢與按鍵感應")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                        }

                        HStack(spacing: 8) {
                            if let arrow = gestureArrow {
                                Image(systemName: arrow)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.cyan)
                                    .scaleEffect(gesturePulse ? 1.25 : 1.0)
                            }
                            Text(lastGestureText)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        Text("提示：按住側鍵 4 不放向左右滑動滑鼠，即可模擬三指切換全螢幕桌面")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 2)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mouseSaveButtonEvent)) { notification in
            if let userInfo = notification.userInfo,
               let button = userInfo["button"] as? Int,
               let isDown = userInfo["isDown"] as? Bool {
                withAnimation(.easeInOut(duration: 0.1)) {
                    if isDown {
                        activeButtons.insert(button)
                        if button == 3 {
                            lastGestureText = "側鍵 4 按下（準備手勢或單擊）"
                        } else if button == 4 {
                            lastGestureText = "側鍵 5 按下"
                        } else if button == 2 {
                            lastGestureText = "中鍵按下"
                        }
                    } else {
                        activeButtons.remove(button)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mouseSaveGestureFired)) { notification in
            if let userInfo = notification.userInfo,
               let dx = userInfo["dx"] as? Double,
               let dy = userInfo["dy"] as? Double {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    gesturePulse = true
                    if abs(dx) > abs(dy) {
                        if dx < 0 {
                            gestureArrow = "arrow.left.circle.fill"
                            lastGestureText = "手勢觸發：切換至左桌面 ⇦"
                        } else {
                            gestureArrow = "arrow.right.circle.fill"
                            lastGestureText = "手勢觸發：切換至右桌面 ⇨"
                        }
                    } else {
                        if dy < 0 {
                            gestureArrow = "arrow.up.circle.fill"
                            lastGestureText = "手勢觸發：調度中心 (Mission Control) ⇧"
                        } else {
                            gestureArrow = "arrow.down.circle.fill"
                            lastGestureText = "手勢觸發：應用程式視窗 (App Exposé) ⇩"
                        }
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation {
                        gesturePulse = false
                        gestureArrow = nil
                    }
                }
            }
        }
    }
}

struct ButtonShape: Shape {
    let isLeft: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        if isLeft {
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: 14, height: 14))
        } else {
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: 14, height: 14))
        }
        return path
    }
}

// MARK: - Tab 1: Gestures & Buttons

struct GesturesAndButtonsTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 1. Live Interactive Visualizer
                LiveMouseCanvasView()

                // 2. Gesture Space Switching Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "hand.point.up.left.and.text")
                            .foregroundStyle(Color.cyan)
                        Text("模擬觸控板手勢導航 (Spaces & 桌面切換)")
                            .font(.headline)
                        Spacer()
                        Toggle("", isOn: $settings.gestureEnabled)
                            .labelsHidden()
                    }

                    Text("按住滑鼠指定按鍵不放，朝指定方向滑動滑鼠，即可觸發全螢幕桌面切換或系統調度中心。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    HStack {
                        Text("手勢觸發引導按鍵")
                        Spacer()
                        Picker("", selection: $settings.gestureTriggerButton) {
                            Text("側鍵 4 (後退鍵，推薦)").tag("button4")
                            Text("側鍵 5 (前進鍵)").tag("button5")
                            Text("滾輪中鍵").tag("middle")
                        }
                        .frame(width: 180)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("手勢滑動觸發靈敏度")
                            Spacer()
                            Text(String(format: "%.0f px", settings.gestureThreshold))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.gestureThreshold, in: 25...120, step: 5)
                        Text("數值越小反應越迅速敏捷，越大則可避免手部微晃誤觸（預設 45 px）。")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("桌面切換引擎 (Engine)")
                                .font(.subheadline.bold())
                            Text("合成手勢由 Dock 原生排程；CGS 轉場由 WindowServer 繪製。")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $settings.spaceSwitchEngine) {
                            Text("原生觸控板手勢 (Dock Swipe)").tag("dockSwipe")
                            Text("硬體平滑轉場 (CGS Transition)").tag("cgsTransition")
                        }
                        .frame(width: 210)
                    }

                    Toggle(isOn: $settings.spaceSlideAnimationEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("模擬觸控板平滑滑動轉場動畫")
                                .font(.subheadline.bold())
                            Text("切換桌面具備與 MacBook 觸控板三指橫向滑動相同的 GPU 硬體平滑位移動畫。")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if settings.spaceSlideAnimationEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("滑動轉場過渡速度")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.2f 秒", settings.spaceTransitionDuration))
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $settings.spaceTransitionDuration, in: 0.12...0.40, step: 0.01)
                            HStack {
                                Text("極速 (0.12s)")
                                Spacer()
                                Text("觸控板絲滑 (0.22s)")
                                Spacer()
                                Text("柔和 (0.40s)")
                            }
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        }
                        .padding(.leading, 8)
                    }

                    Divider()

                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        GridRow {
                            Text("← 向左滑動")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("切換至右桌面 (模擬觸控板三指向左滑)")
                                .font(.subheadline.bold())
                        }
                        GridRow {
                            Text("→ 向右滑動")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("切換至左桌面 (模擬觸控板三指向右滑)")
                                .font(.subheadline.bold())
                        }
                        GridRow {
                            Text("↑ 向上滑動")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("調度中心 (Mission Control)")
                                .font(.subheadline.bold())
                        }
                        GridRow {
                            Text("↓ 向下滑動")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("應用程式視窗 (App Exposé)")
                                .font(.subheadline.bold())
                        }
                    }
                    .padding(.top, 4)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)

                // 3. Single-Click Action Mapping Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "cursorarrow.click")
                            .foregroundStyle(Color.cyan)
                        Text("按鍵單擊動作 (原地單擊未滑動時生效)")
                            .font(.headline)
                    }

                    Divider()

                    HStack {
                        Text("側鍵 4 (後退鍵) 單擊")
                        Spacer()
                        Picker("", selection: $settings.button4Action) {
                            Text("瀏覽器上一頁 (Back)").tag("back")
                            Text("調度中心 (Mission Control)").tag("taskView")
                            Text("顯示桌面").tag("desktop")
                            Text("關閉分頁 (Cmd+W)").tag("closeWindow")
                            Text("無動作").tag("none")
                        }
                        .frame(width: 220)
                    }

                    HStack {
                        Text("側鍵 5 (前進鍵) 單擊")
                        Spacer()
                        Picker("", selection: $settings.button5Action) {
                            Text("瀏覽器下一頁 (Forward)").tag("forward")
                            Text("調度中心 (Mission Control)").tag("taskView")
                            Text("顯示桌面").tag("desktop")
                            Text("關閉分頁 (Cmd+W)").tag("closeWindow")
                            Text("無動作").tag("none")
                        }
                        .frame(width: 220)
                    }

                    HStack {
                        Text("滾輪中鍵單擊")
                        Spacer()
                        Picker("", selection: $settings.middleClickAction) {
                            Text("預設動作 (開新分頁)").tag("default")
                            Text("調度中心 (Mission Control)").tag("taskView")
                            Text("顯示桌面").tag("desktop")
                            Text("關閉分頁 (Cmd+W)").tag("closeWindow")
                            Text("無動作").tag("none")
                        }
                        .frame(width: 220)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
            }
            .padding()
        }
    }
}

// MARK: - Tab 2: Smooth Scrolling

struct SmoothScrollingTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Trackpad Bypass Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(Color.green)
                        Text("MacBook 內建觸控板硬隔離保護")
                            .font(.headline)
                        Spacer()
                        Toggle("", isOn: $settings.trackpadBypass)
                            .labelsHidden()
                    }

                    Text("啟用後，自動檢測並略過觸控板的連續手勢事件。反轉方向與平滑滾動將 100% 僅作用於外接實體滑鼠，內建觸控板維持原生自然手感。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)

                // Scrolling Behavior Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "arrow.up.and.down")
                            .foregroundStyle(Color.cyan)
                        Text("外接滑鼠滾輪調校")
                            .font(.headline)
                    }

                    Divider()

                    Toggle(isOn: $settings.invertScrollDirection) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("反轉外接滑鼠滾動方向 (自然捲動)")
                                .font(.subheadline)
                            Text("讓傳統滾輪行為與 Windows 一致，但保持觸控板自然滾動不變。")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    Toggle(isOn: $settings.smoothScrolling) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("啟用平滑滾動 (隨需物理引擎)")
                                .font(.subheadline)
                            Text("平時 0% CPU 靜止，滾動時啟動慣性物理模擬，消除傳統滾輪的突兀跳躍感。")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if settings.smoothScrolling {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("滾動加速度 (速度倍率)")
                                Spacer()
                                Text(String(format: "%.1fx", settings.scrollAcceleration))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $settings.scrollAcceleration, in: 0.5...3.0, step: 0.1)
                        }
                        .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("慣性阻尼 / 絲滑度")
                                Spacer()
                                Text(String(format: "%.0f%%", settings.scrollFriction * 100))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $settings.scrollFriction, in: 0.70...0.98, step: 0.02)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
            }
            .padding()
        }
    }
}

// MARK: - Tab 3: Exclusions (Game Mode)

struct ExclusionsTab: View {
    @ObservedObject var settings: AppSettings
    @State private var newAppName: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "gamecontroller.fill")
                            .foregroundStyle(Color.orange)
                        Text("應用程式排除名單 (遊戲與專業軟體模式)")
                            .font(.headline)
                    }

                    Text("當以下應用程式（如射擊遊戲、3D 建模工具）位於最前端時，MouseSave 會自動完全暫停攔截，確保滑鼠擁有 100% 純原生未修改的高回報率與精確度。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    VStack(spacing: 6) {
                        ForEach(settings.excludedApps, id: \.self) { app in
                            HStack {
                                Image(systemName: "app.fill")
                                    .foregroundStyle(.secondary)
                                Text(app)
                                    .font(.subheadline)
                                Spacer()
                                Button(role: .destructive) {
                                    if let idx = settings.excludedApps.firstIndex(of: app) {
                                        settings.excludedApps.remove(at: idx)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(6)
                        }
                    }

                    HStack {
                        TextField("輸入進程名稱（例如 cs2）", text: $newAppName)
                            .textFieldStyle(.roundedBorder)

                        Button("手動新增") {
                            let trimmed = newAppName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty && !settings.excludedApps.contains(trimmed) {
                                settings.excludedApps.append(trimmed)
                                newAppName = ""
                            }
                        }
                        .disabled(newAppName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button("瀏覽 .app 檔案…") {
                            chooseAppBundle()
                        }
                    }
                    .padding(.top, 4)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
            }
            .padding()
        }
    }

    private func chooseAppBundle() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK, let url = panel.url {
            let appName = url.deletingPathExtension().lastPathComponent
            if !settings.excludedApps.contains(appName) {
                settings.excludedApps.append(appName)
            }
        }
    }
}

// MARK: - Tab 4: General Tab

struct GeneralTab: View {
    @ObservedObject var settings: AppSettings
    @State private var isAccessibilityGranted: Bool = AXIsProcessTrusted()
    @State private var timer: Timer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Permission Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(isAccessibilityGranted ? Color.green : Color.orange)
                        Text("macOS 輔助使用權限狀態")
                            .font(.headline)
                        Spacer()
                        Text(isAccessibilityGranted ? "已授權生效" : "尚未授權")
                            .font(.subheadline.bold())
                            .foregroundStyle(isAccessibilityGranted ? Color.green : Color.red)
                    }

                    if isAccessibilityGranted {
                        Text("MouseSave 目前已具備底層 Quartz EventTap 監聽與修改滑鼠事件的完整權限。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("請前往 macOS「系統設定 ➔ 隱私權與安全性 ➔ 輔助使用」，勾選允許 MouseSave。")
                                .font(.caption)
                                .foregroundStyle(.red)

                            Button("一鍵開啟系統設定…") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)

                // General Preferences Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Color.cyan)
                        Text("系統與常駐偏好")
                            .font(.headline)
                    }

                    Divider()

                    Toggle("啟用 MouseSave 功能攔截", isOn: $settings.isEnabled)
                    Toggle("在頂部選單列顯示圖示", isOn: $settings.showInMenuBar)
                    Toggle("開機時自動啟動 (Launch at login)", isOn: $settings.launchAtLogin)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)

                // About Card
                HStack(spacing: 16) {
                    Image(nsImage: NSImage(named: "AppIcon") ?? NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: nil)!)
                        .resizable()
                        .frame(width: 48, height: 48)
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("MouseSave v1.2.0")
                            .font(.headline)
                        Text("開源、純淨、零遙測的 macOS 現代滑鼠增強工具。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                .cornerRadius(12)
            }
            .padding()
        }
        .onAppear {
            checkPermission()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                checkPermission()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func checkPermission() {
        let trusted = AXIsProcessTrusted()
        if isAccessibilityGranted != trusted {
            isAccessibilityGranted = trusted
            if trusted && settings.isEnabled {
                MouseHookHelper.shared.start()
            }
        }
    }
}
