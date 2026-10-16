using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Windows.Forms;
using MouseSave.Controls;

namespace MouseSave {
    public class SettingsForm : Form {
        private Panel _leftNav;
        private Panel _rightContent;
        private Panel _bottomBar;
        private Label _lblPageTitle;

        // Navigation state
        private int _selectedPageIndex = 0;
        private Panel[] _pagePanels;
        private NavItem[] _navItems;

        // 1. General Controls
        private ToggleSwitch _swEnabled;
        private ToggleSwitch _swShowTray;
        private ToggleSwitch _swLaunchAtLogin;
        private ComboBox _cboLanguage;

        // 2. Buttons Controls
        private MouseVisualizer _mouseVisualizer;
        private FluentButton _btnDetectButton;
        private ComboBox _cboMiddleClick;
        private ComboBox _cboButton4;
        private ComboBox _cboButton5;
        private ComboBox _cboTiltLeft;
        private ComboBox _cboTiltRight;
        private FluentCard _cardMiddle;
        private FluentCard _cardBtn4;
        private FluentCard _cardBtn5;
        private FluentCard _cardTiltLeft;
        private FluentCard _cardTiltRight;

        // 3. Scrolling Controls
        private ToggleSwitch _swSmoothScrolling;
        private FluentSlider _slSpeed;
        private FluentSlider _slFriction;
        private ToggleSwitch _swInvertDirection;
        private ScrollPreviewBox _scrollPreview;

        // 4. Exclusions Controls
        private ExclusionListView _exclusionList;

        // Bottom Actions
        private FluentButton _btnReset;
        private FluentButton _btnSave;

        public SettingsForm() {
            this.SetStyle(
                ControlStyles.UserPaint |
                ControlStyles.AllPaintingInWmPaint |
                ControlStyles.OptimizedDoubleBuffer |
                ControlStyles.ResizeRedraw, true
            );

            InitializeComponents();
            LoadValues();
            ApplyLocalization();

            MouseHook.ButtonPressed += OnPhysicalButtonPressed;

            Theme.ThemeChanged += delegate {
                if (!this.IsDisposed) {
                    Theme.ApplyWindowStyle(this);
                    ApplyThemeColors();
                    this.Invalidate(true);
                }
            };
        }

        protected override void Dispose(bool disposing) {
            if (disposing) {
                MouseHook.ButtonPressed -= OnPhysicalButtonPressed;
            }
            base.Dispose(disposing);
        }

        private void OnPhysicalButtonPressed(string key) {
            if (this.IsDisposed || !this.Visible) return;
            try {
                this.BeginInvoke((Action)delegate {
                    if (_mouseVisualizer != null && !_mouseVisualizer.IsDisposed) {
                        _mouseVisualizer.TriggerButtonPulse(key);
                    }
                });
            } catch {}
        }

        protected override void OnHandleCreated(EventArgs e) {
            base.OnHandleCreated(e);
            Theme.ApplyWindowStyle(this);
        }

        private void InitializeComponents() {
            this.Text = Localization.Get("settingsTitle");
            this.Size = new Size(Theme.Scale(760), Theme.Scale(560));
            this.MinimumSize = new Size(Theme.Scale(680), Theme.Scale(500));
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.Sizable;
            this.MaximizeBox = true;
            this.MinimizeBox = true;
            this.ShowIcon = true;
            this.Font = Theme.GetTextFont(9.5f, FontStyle.Regular);

            // Left Navigation Bar
            _leftNav = new Panel {
                Dock = DockStyle.Left,
                Width = Theme.Scale(200),
                BackColor = Theme.NavBackground
            };
            _leftNav.Paint += LeftNav_Paint;

            // Nav header (App title & version)
            Label lblApp = new Label {
                Text = "MouseSave",
                Location = new Point(Theme.Scale(20), Theme.Scale(22)),
                AutoSize = true,
                Font = Theme.GetTextFont(12f, FontStyle.Bold),
                ForeColor = Theme.TextPrimary
            };
            Label lblVer = new Label {
                Text = "v1.0.0 • Win11 Fluent",
                Location = new Point(Theme.Scale(20), Theme.Scale(44)),
                AutoSize = true,
                Font = Theme.GetTextFont(8f, FontStyle.Regular),
                ForeColor = Theme.TextSecondary
            };
            _leftNav.Controls.Add(lblApp);
            _leftNav.Controls.Add(lblVer);

            // Nav buttons
            string[] navTitles = new string[] {
                Localization.Get("navGeneral"),
                Localization.Get("navButtons"),
                Localization.Get("navScrolling"),
                Localization.Get("navExclusions")
            };
            string[] navIcons = new string[] {
                Theme.IconSettings,
                Theme.IconMouse,
                Theme.IconScroll,
                Theme.IconGame
            };

            _navItems = new NavItem[4];
            int navY = Theme.Scale(75);
            for (int i = 0; i < 4; i++) {
                int pageIdx = i;
                NavItem item = new NavItem(navIcons[i], navTitles[i], i == 0) {
                    Location = new Point(Theme.Scale(10), navY),
                    Size = new Size(_leftNav.Width - Theme.Scale(20), Theme.Scale(40))
                };
                item.Click += delegate { SwitchPage(pageIdx); };
                _leftNav.Controls.Add(item);
                _navItems[i] = item;
                navY += Theme.Scale(44);
            }

            this.Controls.Add(_leftNav);

            // Bottom Bar
            _bottomBar = new Panel {
                Dock = DockStyle.Bottom,
                Height = Theme.Scale(54),
                BackColor = Theme.BackgroundColor
            };
            _bottomBar.Paint += delegate(object sender, PaintEventArgs e) {
                // Top border separator line
                using (Pen p = new Pen(Theme.CardBorder, 1f)) {
                    e.Graphics.DrawLine(p, 0, 0, _bottomBar.Width, 0);
                }
            };

            _btnReset = new FluentButton {
                Text = Localization.Get("reset"),
                Location = new Point(Theme.Scale(16), Theme.Scale(11)),
                Width = Theme.Scale(130),
                Height = Theme.Scale(32),
                IsAccent = false
            };
            _btnReset.Click += delegate { ResetToDefaults(); };

            _btnSave = new FluentButton {
                Text = Localization.Get("save"),
                Location = new Point(_bottomBar.Width - Theme.Scale(146), Theme.Scale(11)),
                Width = Theme.Scale(130),
                Height = Theme.Scale(32),
                Anchor = AnchorStyles.Right | AnchorStyles.Top,
                IsAccent = true
            };
            _btnSave.Click += delegate { SaveValues(); this.Hide(); };

            _bottomBar.Controls.Add(_btnReset);
            _bottomBar.Controls.Add(_btnSave);
            this.Controls.Add(_leftNav);
            this.Controls.Add(_bottomBar);

            // Right Content Area
            _rightContent = new Panel {
                Dock = DockStyle.Fill,
                BackColor = Theme.BackgroundColor,
                Padding = new Padding(Theme.Scale(24), Theme.Scale(16), Theme.Scale(24), Theme.Scale(16))
            };
            this.Controls.Add(_rightContent);
            _rightContent.BringToFront();

            // Page Header Title Panel
            Panel pnlHeader = new Panel {
                Dock = DockStyle.Top,
                Height = Theme.Scale(42),
                BackColor = Color.Transparent
            };
            _lblPageTitle = new Label {
                Location = new Point(0, Theme.Scale(4)),
                AutoSize = true,
                Font = Theme.GetTextFont(14f, FontStyle.Bold),
                ForeColor = Theme.TextPrimary
            };
            pnlHeader.Controls.Add(_lblPageTitle);
            _rightContent.Controls.Add(pnlHeader);

            // Container for pages
            Panel pnlPages = new Panel {
                Dock = DockStyle.Fill,
                BackColor = Color.Transparent
            };
            _rightContent.Controls.Add(pnlPages);
            pnlPages.BringToFront();

            // Build Pages
            BuildPagePanels(pnlPages);
            SwitchPage(0);
        }

        private void BuildPagePanels(Panel container) {
            _pagePanels = new Panel[4];
            for (int i = 0; i < 4; i++) {
                Panel p = new Panel {
                    Dock = DockStyle.Fill,
                    AutoScroll = true,
                    Visible = false,
                    Padding = new Padding(0, 0, Theme.Scale(8), 0)
                };
                container.Controls.Add(p);
                _pagePanels[i] = p;
            }

            // 1. General Page
            BuildGeneralPage(_pagePanels[0]);
            // 2. Buttons Page
            BuildButtonsPage(_pagePanels[1]);
            // 3. Scrolling Page
            BuildScrollingPage(_pagePanels[2]);
            // 4. Exclusions Page
            BuildExclusionsPage(_pagePanels[3]);
        }

        private void BuildGeneralPage(Panel p) {
            int y = 0;
            int cardGap = Theme.Scale(10);
            int cardW = p.Width - Theme.Scale(16);

            _swEnabled = new ToggleSwitch();
            FluentCard card1 = new FluentCard {
                Location = new Point(0, y),
                Width = cardW,
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right,
                Title = Localization.Get("enableMouseSave"),
                Description = Localization.Get("appName") + " background smooth physics & side button engine",
                RightControl = _swEnabled
            };
            p.Controls.Add(card1);
            y += card1.Height + cardGap;

            _swShowTray = new ToggleSwitch();
            FluentCard card2 = new FluentCard {
                Location = new Point(0, y),
                Width = cardW,
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right,
                Title = Localization.Get("showInMenuBar"),
                Description = "Keep MouseSave accessible in the Windows taskbar system notification tray",
                RightControl = _swShowTray
            };
            p.Controls.Add(card2);
            y += card2.Height + cardGap;

            _swLaunchAtLogin = new ToggleSwitch();
            FluentCard card3 = new FluentCard {
                Location = new Point(0, y),
                Width = cardW,
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right,
                Title = Localization.Get("launchAtLogin"),
                Description = "Automatically start MouseSave in the background when signing into Windows",
                RightControl = _swLaunchAtLogin
            };
            p.Controls.Add(card3);
            y += card3.Height + cardGap;

            _cboLanguage = new ComboBox {
                Width = Theme.Scale(160),
                DropDownStyle = ComboBoxStyle.DropDownList,
                Font = Theme.GetTextFont(9f, FontStyle.Regular),
                FlatStyle = FlatStyle.Flat,
                BackColor = Theme.CardBackground,
                ForeColor = Theme.TextPrimary
            };
            _cboLanguage.Items.AddRange(new object[] { "System Default", "English", "繁體中文" });
            _cboLanguage.SelectedIndexChanged += delegate {
                string selected = "auto";
                if (_cboLanguage.SelectedIndex == 1) selected = "en";
                else if (_cboLanguage.SelectedIndex == 2) selected = "zh-Hant";
                
                if (AppSettings.Shared.Language != selected) {
                    AppSettings.Shared.Language = selected;
                    ApplyLocalization();
                }
            };

            FluentCard card4 = new FluentCard {
                Location = new Point(0, y),
                Width = cardW,
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right,
                Title = Localization.Get("language"),
                Description = "Select interface display language",
                RightControl = _cboLanguage
            };
            p.Controls.Add(card4);
        }

        private void BuildButtonsPage(Panel p) {
            int y = 0;
            int cardGap = Theme.Scale(10);
            int cardW = p.Width - Theme.Scale(16);

            // 1. Detection Bar & Hardware Help Card
            Panel headerCard = new Panel {
                Location = new Point(0, y),
                Width = cardW,
                Height = Theme.Scale(50),
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right,
                BackColor = Theme.CardBackground
            };
            headerCard.Paint += delegate(object s, PaintEventArgs e) {
                e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
                using (GraphicsPath path = Theme.CreateRoundedRectangle(headerCard.ClientRectangle, Theme.Scale(8)))
                using (Pen pen = new Pen(Theme.CardBorder, 1f)) {
                    e.Graphics.DrawPath(pen, path);
                }
            };

            Label lblHelp = new Label {
                Text = Localization.Get("detectTip"),
                Location = new Point(Theme.Scale(14), Theme.Scale(8)),
                Size = new Size(cardW - Theme.Scale(190), Theme.Scale(34)),
                Font = Theme.GetTextFont(8.8f, FontStyle.Regular),
                ForeColor = Theme.TextSecondary,
                TextAlign = ContentAlignment.MiddleLeft,
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right
            };
            headerCard.Controls.Add(lblHelp);

            _btnDetectButton = new FluentButton {
                Text = Localization.Get("detectButton"),
                Location = new Point(cardW - Theme.Scale(170), Theme.Scale(9)),
                Size = new Size(Theme.Scale(158), Theme.Scale(32)),
                Anchor = AnchorStyles.Top | AnchorStyles.Right,
                IsAccent = true
            };
            _btnDetectButton.Click += delegate {
                StartButtonDetection();
            };
            headerCard.Controls.Add(_btnDetectButton);

            p.Controls.Add(headerCard);
            y += headerCard.Height + cardGap;

            // 2. Visualizer diagram
            _mouseVisualizer = new MouseVisualizer {
                Location = new Point(0, y),
                Width = cardW,
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right
            };
            _mouseVisualizer.ButtonSelected += delegate(object sender, string btnId) {
                HighlightButtonCard(btnId);
            };
            p.Controls.Add(_mouseVisualizer);
            y += _mouseVisualizer.Height + cardGap;

            // 3. Middle Click
            _cboMiddleClick = CreateActionComboBox();
            _cboMiddleClick.SelectedIndexChanged += delegate {
                _mouseVisualizer.MiddleActionText = _cboMiddleClick.Text;
            };
            _cardMiddle = new FluentCard {
                Location = new Point(0, y),
                Width = cardW,
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right,
                Title = Localization.Get("middleClickAction"),
                Description = Localization.Get("descMiddleClick"),
                RightControl = _cboMiddleClick
            };
            p.Controls.Add(_cardMiddle);
            y += _cardMiddle.Height + cardGap;

            // 4. Side Button 5
            _cboButton5 = CreateActionComboBox();
            _cboButton5.SelectedIndexChanged += delegate {
                _mouseVisualizer.Button5ActionText = _cboButton5.Text;
            };
            _cardBtn5 = new FluentCard {
                Location = new Point(0, y),
                Width = cardW,
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right,
                Title = Localization.Get("button5Action"),
                Description = Localization.Get("descButton5"),
                RightControl = _cboButton5
            };
            p.Controls.Add(_cardBtn5);
            y += _cardBtn5.Height + cardGap;

            // 5. Side Button 4
            _cboButton4 = CreateActionComboBox();
            _cboButton4.SelectedIndexChanged += delegate {
                _mouseVisualizer.Button4ActionText = _cboButton4.Text;
            };
            _cardBtn4 = new FluentCard {
                Location = new Point(0, y),
                Width = cardW,
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right,
                Title = Localization.Get("button4Action"),
                Description = Localization.Get("descButton4"),
                RightControl = _cboButton4
            };
            p.Controls.Add(_cardBtn4);
            y += _cardBtn4.Height + cardGap;

            // 6. Tilt Wheel Left
            _cboTiltLeft = CreateActionComboBox();
            _cboTiltLeft.SelectedIndexChanged += delegate {
                _mouseVisualizer.TiltLeftActionText = _cboTiltLeft.Text;
            };
            _cardTiltLeft = new FluentCard {
                Location = new Point(0, y),
                Width = cardW,
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right,
                Title = Localization.Get("tiltLeftAction"),
                Description = Localization.Get("descTiltLeft"),
                RightControl = _cboTiltLeft
            };
            p.Controls.Add(_cardTiltLeft);
            y += _cardTiltLeft.Height + cardGap;

            // 7. Tilt Wheel Right
            _cboTiltRight = CreateActionComboBox();
            _cboTiltRight.SelectedIndexChanged += delegate {
                _mouseVisualizer.TiltRightActionText = _cboTiltRight.Text;
            };
            _cardTiltRight = new FluentCard {
                Location = new Point(0, y),
                Width = cardW,
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right,
                Title = Localization.Get("tiltRightAction"),
                Description = Localization.Get("descTiltRight"),
                RightControl = _cboTiltRight
            };
            p.Controls.Add(_cardTiltRight);
            y += _cardTiltRight.Height + cardGap;
        }

        private void StartButtonDetection() {
            Form dlg = new Form {
                Text = Localization.Get("detectButton"),
                Size = new Size(Theme.Scale(420), Theme.Scale(220)),
                StartPosition = FormStartPosition.CenterParent,
                FormBorderStyle = FormBorderStyle.FixedDialog,
                MaximizeBox = false,
                MinimizeBox = false,
                BackColor = Theme.BackgroundColor,
                ForeColor = Theme.TextPrimary
            };
            Theme.ApplyWindowStyle(dlg);

            Label lblMsg = new Label {
                Text = Localization.Get("pressAnyButton") + "\n\n(5s)",
                Dock = DockStyle.Fill,
                TextAlign = ContentAlignment.MiddleCenter,
                Font = Theme.GetTextFont(10.5f, FontStyle.Regular),
                ForeColor = Theme.TextPrimary
            };
            dlg.Controls.Add(lblMsg);

            int remainingSeconds = 5;
            Timer countdownTimer = new Timer { Interval = 1000 };

            MouseHook.OnButtonCaptured = delegate(string key) {
                if (dlg.IsDisposed) return;
                try {
                    dlg.BeginInvoke((Action)delegate {
                        countdownTimer.Stop();
                        countdownTimer.Dispose();
                        MouseHook.IsCapturingButton = false;
                        MouseHook.OnButtonCaptured = null;
                        dlg.Close();

                        string friendlyName = GetButtonFriendlyName(key);
                        MessageBox.Show(
                            string.Format(Localization.Get("buttonDetected"), friendlyName),
                            "MouseSave",
                            MessageBoxButtons.OK,
                            MessageBoxIcon.Information
                        );

                        HighlightButtonCard(key);
                    });
                } catch {}
            };

            countdownTimer.Tick += delegate {
                remainingSeconds--;
                if (remainingSeconds <= 0) {
                    countdownTimer.Stop();
                    countdownTimer.Dispose();
                    MouseHook.IsCapturingButton = false;
                    MouseHook.OnButtonCaptured = null;
                    if (!dlg.IsDisposed) {
                        dlg.Close();
                        MessageBox.Show(
                            Localization.Get("captureTimeout"),
                            "MouseSave",
                            MessageBoxButtons.OK,
                            MessageBoxIcon.Information
                        );
                    }
                } else {
                    lblMsg.Text = Localization.Get("pressAnyButton") + "\n\n(" + remainingSeconds + "s)";
                }
            };

            dlg.FormClosing += delegate {
                countdownTimer.Stop();
                countdownTimer.Dispose();
                MouseHook.IsCapturingButton = false;
                MouseHook.OnButtonCaptured = null;
            };

            MouseHook.IsCapturingButton = true;
            countdownTimer.Start();
            dlg.ShowDialog(this);
        }

        private string GetButtonFriendlyName(string key) {
            switch (key) {
                case "middle": return Localization.Get("btnMiddle");
                case "button4": return Localization.Get("btnButton4");
                case "button5": return Localization.Get("btnButton5");
                case "tiltLeft": return Localization.Get("btnTiltLeft");
                case "tiltRight": return Localization.Get("btnTiltRight");
                default: return key;
            }
        }

        private void HighlightButtonCard(string key) {
            if (_mouseVisualizer != null) {
                _mouseVisualizer.TriggerButtonPulse(key);
            }
            switch (key) {
                case "middle":
                    if (_cboMiddleClick != null) _cboMiddleClick.Focus();
                    break;
                case "button4":
                    if (_cboButton4 != null) _cboButton4.Focus();
                    break;
                case "button5":
                    if (_cboButton5 != null) _cboButton5.Focus();
                    break;
                case "tiltLeft":
                    if (_cboTiltLeft != null) _cboTiltLeft.Focus();
                    break;
                case "tiltRight":
                    if (_cboTiltRight != null) _cboTiltRight.Focus();
                    break;
            }
        }

        private void BuildScrollingPage(Panel p) {
            int y = 0;
            int cardGap = Theme.Scale(10);
            int cardW = p.Width - Theme.Scale(16);

            _swSmoothScrolling = new ToggleSwitch();
            FluentCard cardSmooth = new FluentCard {
                Location = new Point(0, y),
                Width = cardW,
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right,
                Title = Localization.Get("smoothScrolling"),
                Description = "Physics decay interpolation for buttery smooth web and document scrolling",
                RightControl = _swSmoothScrolling
            };
            p.Controls.Add(cardSmooth);
            y += cardSmooth.Height + cardGap;

            _slSpeed = new FluentSlider {
                Minimum = 5,
                Maximum = 30,
                DisplayMultiplier = 0.1,
                ValueFormat = "{0:0.0}x",
                Width = Theme.Scale(240)
            };
            FluentCard cardSpeed = new FluentCard {
                Location = new Point(0, y),
                Width = cardW,
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right,
                Title = Localization.Get("scrollSpeed"),
                Description = "Velocity acceleration multiplier applied per wheel tick",
                RightControl = _slSpeed
            };
            p.Controls.Add(cardSpeed);
            y += cardSpeed.Height + cardGap;

            _slFriction = new FluentSlider {
                Minimum = 70,
                Maximum = 98,
                DisplayMultiplier = 1.0,
                ValueFormat = "{0}%",
                Width = Theme.Scale(240)
            };
            FluentCard cardFriction = new FluentCard {
                Location = new Point(0, y),
                Width = cardW,
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right,
                Title = Localization.Get("scrollFriction"),
                Description = "Momentum retention smoothness (higher = longer glide)",
                RightControl = _slFriction
            };
            p.Controls.Add(cardFriction);
            y += cardFriction.Height + cardGap;

            _swInvertDirection = new ToggleSwitch();
            FluentCard cardInvert = new FluentCard {
                Location = new Point(0, y),
                Width = cardW,
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right,
                Title = Localization.Get("invertScroll"),
                Description = "Invert wheel direction to match trackpad natural scrolling",
                RightControl = _swInvertDirection
            };
            p.Controls.Add(cardInvert);
            y += cardInvert.Height + cardGap;

            // Live Test Area
            _scrollPreview = new ScrollPreviewBox {
                Location = new Point(0, y),
                Width = cardW,
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right
            };
            p.Controls.Add(_scrollPreview);
        }

        private void BuildExclusionsPage(Panel p) {
            int y = 0;
            int cardGap = Theme.Scale(10);
            int cardW = p.Width - Theme.Scale(16);

            // Description card
            Panel descCard = new Panel {
                Location = new Point(0, y),
                Size = new Size(cardW, Theme.Scale(54)),
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right
            };
            descCard.Paint += delegate(object sender, PaintEventArgs e) {
                Rectangle rect = new Rectangle(0, 0, descCard.Width - 1, descCard.Height - 1);
                using (GraphicsPath path = Theme.CreateRoundedRectangle(rect, Theme.Scale(6))) {
                    using (SolidBrush b = new SolidBrush(Theme.CardBackground)) {
                        e.Graphics.FillPath(b, path);
                    }
                    using (Pen pen = new Pen(Theme.CardBorder, 1f)) {
                        e.Graphics.DrawPath(pen, path);
                    }
                }
                Rectangle textRect = new Rectangle(Theme.Scale(14), Theme.Scale(8), descCard.Width - Theme.Scale(28), descCard.Height - Theme.Scale(16));
                TextRenderer.DrawText(
                    e.Graphics, Localization.Get("exclusionsDesc"), Theme.GetTextFont(8.5f, FontStyle.Regular), textRect,
                    Theme.TextSecondary,
                    TextFormatFlags.Left | TextFormatFlags.WordBreak
                );
            };
            p.Controls.Add(descCard);
            y += descCard.Height + cardGap;

            // Exclusion List
            _exclusionList = new ExclusionListView {
                Location = new Point(0, y),
                Size = new Size(cardW, p.Height - y - Theme.Scale(10)),
                Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right
            };
            _exclusionList.BrowseRequested += delegate { BrowseAndAddApp(); };
            _exclusionList.ActiveProcessRequested += delegate { AddActiveProcess(); };
            _exclusionList.AppRemoved += delegate(object sender, string appName) {
                RemoveExclusionItem(appName);
            };
            p.Controls.Add(_exclusionList);
        }

        private ComboBox CreateActionComboBox() {
            ComboBox cbo = new ComboBox {
                Width = Theme.Scale(200),
                DropDownStyle = ComboBoxStyle.DropDownList,
                Font = Theme.GetTextFont(9f, FontStyle.Regular),
                FlatStyle = FlatStyle.Flat,
                BackColor = Theme.CardBackground,
                ForeColor = Theme.TextPrimary
            };
            return cbo;
        }

        private void SwitchPage(int index) {
            _selectedPageIndex = index;
            for (int i = 0; i < 4; i++) {
                _navItems[i].IsSelected = (i == index);
                _pagePanels[i].Visible = (i == index);
            }

            string[] titles = new string[] {
                Localization.Get("general"),
                Localization.Get("buttons"),
                Localization.Get("scrolling"),
                Localization.Get("exclusions")
            };
            _lblPageTitle.Text = titles[index];
            _rightContent.Invalidate();
        }

        private void LeftNav_Paint(object sender, PaintEventArgs e) {
            // Right border separator between left nav and right content
            using (Pen p = new Pen(Theme.CardBorder, 1f)) {
                e.Graphics.DrawLine(p, _leftNav.Width - 1, 0, _leftNav.Width - 1, _leftNav.Height);
            }
        }

        private void ApplyThemeColors() {
            _leftNav.BackColor = Theme.NavBackground;
            _rightContent.BackColor = Theme.BackgroundColor;
            _bottomBar.BackColor = Theme.BackgroundColor;
            _lblPageTitle.ForeColor = Theme.TextPrimary;

            Color cboBg = Theme.CardBackground;
            Color cboFg = Theme.TextPrimary;

            if (_cboLanguage != null) { _cboLanguage.BackColor = cboBg; _cboLanguage.ForeColor = cboFg; }
            if (_cboMiddleClick != null) { _cboMiddleClick.BackColor = cboBg; _cboMiddleClick.ForeColor = cboFg; }
            if (_cboButton4 != null) { _cboButton4.BackColor = cboBg; _cboButton4.ForeColor = cboFg; }
            if (_cboButton5 != null) { _cboButton5.BackColor = cboBg; _cboButton5.ForeColor = cboFg; }
            if (_cboTiltLeft != null) { _cboTiltLeft.BackColor = cboBg; _cboTiltLeft.ForeColor = cboFg; }
            if (_cboTiltRight != null) { _cboTiltRight.BackColor = cboBg; _cboTiltRight.ForeColor = cboFg; }
        }

        private void LoadValues() {
            AppSettings s = AppSettings.Shared;
            _swEnabled.Checked = s.IsEnabled;
            _swShowTray.Checked = s.ShowInMenuBar;
            _swLaunchAtLogin.Checked = StartupHelper.IsStartupEnabled();

            if (s.Language == "en") _cboLanguage.SelectedIndex = 1;
            else if (s.Language == "zh-Hant") _cboLanguage.SelectedIndex = 2;
            else _cboLanguage.SelectedIndex = 0;

            PopulateActionCombos();

            _swSmoothScrolling.Checked = s.Scrolling.SmoothScrolling;
            int speedVal = (int)Math.Round(s.Scrolling.Acceleration * 10);
            _slSpeed.Value = Math.Max(5, Math.Min(30, speedVal));

            int frictionVal = (int)Math.Round(s.Scrolling.Friction * 100);
            _slFriction.Value = Math.Max(70, Math.Min(98, frictionVal));

            _swInvertDirection.Checked = s.Scrolling.InvertDirection;

            // Load Exclusions
            _exclusionList.SetItems(s.ExcludedApps);
        }

        private static readonly string[] ActionKeys = new string[] {
            "default",
            "taskView",
            "desktop",
            "closeWindow",
            "switchTabLeft",
            "switchTabRight",
            "back",
            "forward",
            "none"
        };

        private void PopulateActionCombos() {
            var actions = new[] {
                new { Key = "default", Label = Localization.Get("actionDefault") },
                new { Key = "taskView", Label = Localization.Get("actionTaskView") },
                new { Key = "desktop", Label = Localization.Get("actionDesktop") },
                new { Key = "closeWindow", Label = Localization.Get("actionCloseWindow") },
                new { Key = "switchTabLeft", Label = Localization.Get("actionSwitchTabLeft") },
                new { Key = "switchTabRight", Label = Localization.Get("actionSwitchTabRight") },
                new { Key = "back", Label = Localization.Get("actionBack") },
                new { Key = "forward", Label = Localization.Get("actionForward") },
                new { Key = "none", Label = Localization.Get("actionNone") }
            };

            PopulateOneCombo(_cboMiddleClick, actions, AppSettings.Shared.Buttons.MiddleClickAction);
            PopulateOneCombo(_cboButton4, actions, AppSettings.Shared.Buttons.Button4Action);
            PopulateOneCombo(_cboButton5, actions, AppSettings.Shared.Buttons.Button5Action);
            PopulateOneCombo(_cboTiltLeft, actions, AppSettings.Shared.Buttons.TiltLeftAction);
            PopulateOneCombo(_cboTiltRight, actions, AppSettings.Shared.Buttons.TiltRightAction);

            if (_mouseVisualizer != null) {
                _mouseVisualizer.MiddleActionText = _cboMiddleClick.Text;
                _mouseVisualizer.Button4ActionText = _cboButton4.Text;
                _mouseVisualizer.Button5ActionText = _cboButton5.Text;
                _mouseVisualizer.TiltLeftActionText = _cboTiltLeft.Text;
                _mouseVisualizer.TiltRightActionText = _cboTiltRight.Text;
            }
        }

        private void PopulateOneCombo(ComboBox cbo, dynamic actions, string selectedKey) {
            cbo.Items.Clear();
            int selectedIdx = 0;
            int idx = 0;
            foreach (var item in actions) {
                cbo.Items.Add(item.Label);
                if (item.Key == selectedKey) {
                    selectedIdx = idx;
                }
                idx++;
            }
            cbo.SelectedIndex = selectedIdx;
        }

        private string GetKeyFromIndex(int index) {
            if (index >= 0 && index < ActionKeys.Length) return ActionKeys[index];
            return "default";
        }

        private void SaveValues() {
            AppSettings s = AppSettings.Shared;
            s.IsEnabled = _swEnabled.Checked;
            s.ShowInMenuBar = _swShowTray.Checked;
            s.LaunchAtLogin = _swLaunchAtLogin.Checked;

            StartupHelper.SetStartup(s.LaunchAtLogin);

            s.Buttons.MiddleClickAction = GetKeyFromIndex(_cboMiddleClick.SelectedIndex);
            s.Buttons.Button4Action = GetKeyFromIndex(_cboButton4.SelectedIndex);
            s.Buttons.Button5Action = GetKeyFromIndex(_cboButton5.SelectedIndex);
            s.Buttons.TiltLeftAction = GetKeyFromIndex(_cboTiltLeft.SelectedIndex);
            s.Buttons.TiltRightAction = GetKeyFromIndex(_cboTiltRight.SelectedIndex);

            s.Scrolling.SmoothScrolling = _swSmoothScrolling.Checked;
            s.Scrolling.Acceleration = _slSpeed.Value / 10.0;
            s.Scrolling.Friction = _slFriction.Value / 100.0;
            s.Scrolling.InvertDirection = _swInvertDirection.Checked;

            s.ExcludedApps = new List<string>(_exclusionList.Items);
            s.Save();
        }

        private void ResetToDefaults() {
            AppSettings s = new AppSettings();
            _swEnabled.Checked = s.IsEnabled;
            _swShowTray.Checked = s.ShowInMenuBar;
            _swLaunchAtLogin.Checked = false;
            _swSmoothScrolling.Checked = s.Scrolling.SmoothScrolling;
            _slSpeed.Value = (int)(s.Scrolling.Acceleration * 10);
            _slFriction.Value = (int)(s.Scrolling.Friction * 100);
            _swInvertDirection.Checked = s.Scrolling.InvertDirection;
            _cboMiddleClick.SelectedIndex = 0;
            _cboButton4.SelectedIndex = 0;
            _cboButton5.SelectedIndex = 0;
            _cboTiltLeft.SelectedIndex = 0;
            _cboTiltRight.SelectedIndex = 0;

            _exclusionList.SetItems(s.ExcludedApps);
            SaveValues();
        }

        private void BrowseAndAddApp() {
            using (OpenFileDialog ofd = new OpenFileDialog()) {
                ofd.Title = Localization.Get("selectExecutable");
                ofd.Filter = "Executable files (*.exe)|*.exe|All files (*.*)|*.*";
                ofd.InitialDirectory = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);

                if (ofd.ShowDialog(this) == DialogResult.OK) {
                    string fileName = Path.GetFileName(ofd.FileName);
                    AddExclusionItem(fileName);
                }
            }
        }

        private void AddActiveProcess() {
            try {
                Form selectForm = new Form {
                    Text = Localization.Get("addRunningApp"),
                    Size = new Size(Theme.Scale(380), Theme.Scale(450)),
                    StartPosition = FormStartPosition.CenterParent,
                    FormBorderStyle = FormBorderStyle.FixedDialog,
                    MaximizeBox = false,
                    MinimizeBox = false,
                    BackColor = Theme.BackgroundColor,
                    Font = Theme.GetTextFont(9f, FontStyle.Regular)
                };
                Theme.ApplyWindowStyle(selectForm);

                ListBox list = new ListBox {
                    Dock = DockStyle.Top,
                    Height = Theme.Scale(330),
                    IntegralHeight = false,
                    Font = Theme.GetTextFont(9.5f, FontStyle.Regular)
                };

                HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                System.Diagnostics.Process[] processes = System.Diagnostics.Process.GetProcesses();
                foreach (var p in processes) {
                    try {
                        if (p.Id <= 4 || string.IsNullOrEmpty(p.MainWindowTitle)) continue;
                        string name = p.ProcessName + ".exe";
                        if (name.Equals("MouseSave.exe", StringComparison.OrdinalIgnoreCase)) continue;
                        if (!seen.Contains(name)) {
                            seen.Add(name);
                            list.Items.Add(name);
                        }
                    } catch {}
                }

                FluentButton btnAdd = new FluentButton {
                    Text = Localization.Get("addApp"),
                    Dock = DockStyle.Bottom,
                    Height = Theme.Scale(38),
                    IsAccent = true
                };
                btnAdd.Click += delegate {
                    if (list.SelectedItem != null) {
                        AddExclusionItem(list.SelectedItem.ToString());
                        selectForm.Close();
                    }
                };

                selectForm.Controls.Add(list);
                selectForm.Controls.Add(btnAdd);
                selectForm.ShowDialog(this);
            } catch (Exception ex) {
                MessageBox.Show(ex.Message, "MouseSave", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void AddExclusionItem(string appName) {
            if (string.IsNullOrEmpty(appName)) return;

            foreach (var item in _exclusionList.Items) {
                if (string.Equals(item, appName, StringComparison.OrdinalIgnoreCase)) {
                    MessageBox.Show(Localization.Get("appAlreadyExists"), "MouseSave", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return;
                }
            }

            _exclusionList.Items.Add(appName);
            _exclusionList.SetItems(_exclusionList.Items);
            SaveValues();
        }

        private void RemoveExclusionItem(string appName) {
            _exclusionList.Items.Remove(appName);
            _exclusionList.SetItems(_exclusionList.Items);
            SaveValues();
        }

        private void ApplyLocalization() {
            this.Text = Localization.Get("settingsTitle");
            string[] navTitles = new string[] {
                Localization.Get("navGeneral"),
                Localization.Get("navButtons"),
                Localization.Get("navScrolling"),
                Localization.Get("navExclusions")
            };
            for (int i = 0; i < 4; i++) {
                _navItems[i].ItemTitle = navTitles[i];
            }

            _btnReset.Text = Localization.Get("reset");
            _btnSave.Text = Localization.Get("save");

            SwitchPage(_selectedPageIndex);
            PopulateActionCombos();
        }

        protected override void OnFormClosing(FormClosingEventArgs e) {
            if (e.CloseReason == CloseReason.UserClosing) {
                e.Cancel = true;
                SaveValues();
                this.Hide();
            } else {
                base.OnFormClosing(e);
            }
        }

        // Custom Left Nav Item Control
        private class NavItem : Control {
            private string _icon;
            private string _title;
            private bool _isSelected;
            private bool _isHovered;

            public string ItemTitle {
                get { return _title; }
                set { _title = value; Invalidate(); }
            }

            public bool IsSelected {
                get { return _isSelected; }
                set { _isSelected = value; Invalidate(); }
            }

            public NavItem(string icon, string title, bool isSelected) {
                this.SetStyle(
                    ControlStyles.UserPaint |
                    ControlStyles.AllPaintingInWmPaint |
                    ControlStyles.OptimizedDoubleBuffer |
                    ControlStyles.ResizeRedraw |
                    ControlStyles.SupportsTransparentBackColor, true
                );
                _icon = icon;
                _title = title;
                _isSelected = isSelected;
                this.Cursor = Cursors.Hand;
            }

            protected override void OnMouseEnter(EventArgs e) {
                base.OnMouseEnter(e);
                _isHovered = true;
                Invalidate();
            }

            protected override void OnMouseLeave(EventArgs e) {
                base.OnMouseLeave(e);
                _isHovered = false;
                Invalidate();
            }

            protected override void OnPaint(PaintEventArgs e) {
                Graphics g = e.Graphics;
                g.SmoothingMode = SmoothingMode.AntiAlias;

                int w = this.Width;
                int h = this.Height;

                // Background pill
                if (_isSelected) {
                    Rectangle pillRect = new Rectangle(0, 0, w, h);
                    using (GraphicsPath path = Theme.CreateRoundedRectangle(pillRect, Theme.Scale(5))) {
                        using (SolidBrush b = new SolidBrush(Theme.NavSelected)) {
                            g.FillPath(b, path);
                        }
                    }
                    // Accent Indicator Bar on the left
                    Rectangle barRect = new Rectangle(0, Theme.Scale(8), Theme.Scale(3), h - Theme.Scale(16));
                    using (GraphicsPath barPath = Theme.CreateRoundedRectangle(barRect, 1))
                    using (SolidBrush barBrush = new SolidBrush(Theme.AccentColor)) {
                        g.FillPath(barBrush, barPath);
                    }
                } else if (_isHovered) {
                    Rectangle pillRect = new Rectangle(0, 0, w, h);
                    using (GraphicsPath path = Theme.CreateRoundedRectangle(pillRect, Theme.Scale(5))) {
                        using (SolidBrush b = new SolidBrush(Theme.ControlHover)) {
                            g.FillPath(b, path);
                        }
                    }
                }

                // Draw Icon
                Rectangle iconRect = new Rectangle(Theme.Scale(12), 0, Theme.Scale(24), h);
                TextRenderer.DrawText(
                    g, _icon, Theme.GetIconFont(11f), iconRect,
                    _isSelected ? Theme.AccentColor : Theme.TextPrimary,
                    TextFormatFlags.Left | TextFormatFlags.VerticalCenter
                );

                // Draw Text
                Rectangle textRect = new Rectangle(Theme.Scale(42), 0, w - Theme.Scale(46), h);
                TextRenderer.DrawText(
                    g, _title, Theme.GetTextFont(9.5f, _isSelected ? FontStyle.Bold : FontStyle.Regular), textRect,
                    _isSelected ? Theme.TextPrimary : Theme.TextSecondary,
                    TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.WordEllipsis
                );
            }
        }
    }
}
