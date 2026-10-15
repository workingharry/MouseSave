using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Windows.Forms;

namespace MouseSave {
    public class SettingsForm : Form {
        private TabControl _tabControl;
        private TabPage _tabGeneral;
        private TabPage _tabButtons;
        private TabPage _tabScrolling;
        private TabPage _tabExclusions;

        // General controls
        private CheckBox _chkEnabled;
        private CheckBox _chkShowTray;
        private CheckBox _chkLaunchAtLogin;
        private Label _lblLanguage;
        private ComboBox _cboLanguage;

        // Buttons controls
        private Label _lblMiddleClick;
        private ComboBox _cboMiddleClick;
        private Label _lblButton4;
        private ComboBox _cboButton4;
        private Label _lblButton5;
        private ComboBox _cboButton5;

        // Scrolling controls
        private CheckBox _chkSmoothScrolling;
        private Label _lblSpeed;
        private TrackBar _tbSpeed;
        private Label _lblSpeedVal;
        private Label _lblFriction;
        private TrackBar _tbFriction;
        private Label _lblFrictionVal;
        private CheckBox _chkInvertDirection;

        // Exclusions controls
        private Label _lblExclusionDesc;
        private ListBox _lstExclusions;
        private Button _btnAddApp;
        private Button _btnAddActive;
        private Button _btnRemoveApp;

        // Bottom actions
        private Button _btnSave;
        private Button _btnReset;

        public SettingsForm() {
            InitializeComponents();
            LoadValues();
            ApplyLocalization();
        }

        private void InitializeComponents() {
            this.Text = Localization.Get("settingsTitle");
            this.Size = new Size(500, 420);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.MinimizeBox = true;
            this.ShowIcon = true;
            this.Font = new Font("Segoe UI", 9.5f, FontStyle.Regular);

            _tabControl = new TabControl {
                Dock = DockStyle.Top,
                Height = 315
            };

            // 1. General Tab
            _tabGeneral = new TabPage();
            _chkEnabled = new CheckBox { Text = "Enable MouseSave", Location = new Point(25, 20), AutoSize = true };
            _chkShowTray = new CheckBox { Text = "Show in system tray", Location = new Point(25, 55), AutoSize = true };
            _chkLaunchAtLogin = new CheckBox { Text = "Launch at login", Location = new Point(25, 90), AutoSize = true };
            
            _lblLanguage = new Label { Text = "Language:", Location = new Point(25, 135), AutoSize = true };
            _cboLanguage = new ComboBox { Location = new Point(170, 132), Width = 180, DropDownStyle = ComboBoxStyle.DropDownList };
            _cboLanguage.Items.AddRange(new object[] { "System Default", "English", "繁體中文" });

            _tabGeneral.Controls.AddRange(new Control[] { _chkEnabled, _chkShowTray, _chkLaunchAtLogin, _lblLanguage, _cboLanguage });

            // 2. Buttons Tab
            _tabButtons = new TabPage();
            _lblMiddleClick = new Label { Text = "Middle Click Action:", Location = new Point(25, 25), AutoSize = true };
            _cboMiddleClick = new ComboBox { Location = new Point(200, 22), Width = 200, DropDownStyle = ComboBoxStyle.DropDownList };

            _lblButton4 = new Label { Text = "Side Button 4 (Back):", Location = new Point(25, 75), AutoSize = true };
            _cboButton4 = new ComboBox { Location = new Point(200, 72), Width = 200, DropDownStyle = ComboBoxStyle.DropDownList };

            _lblButton5 = new Label { Text = "Side Button 5 (Forward):", Location = new Point(25, 125), AutoSize = true };
            _cboButton5 = new ComboBox { Location = new Point(200, 122), Width = 200, DropDownStyle = ComboBoxStyle.DropDownList };

            _tabButtons.Controls.AddRange(new Control[] { _lblMiddleClick, _cboMiddleClick, _lblButton4, _cboButton4, _lblButton5, _cboButton5 });

            // 3. Scrolling Tab
            _tabScrolling = new TabPage();
            _chkSmoothScrolling = new CheckBox { Text = "Enable Smooth Scrolling", Location = new Point(25, 15), AutoSize = true };

            _lblSpeed = new Label { Text = "Scroll Speed:", Location = new Point(25, 55), AutoSize = true };
            _tbSpeed = new TrackBar { Location = new Point(140, 50), Width = 220, Minimum = 5, Maximum = 30, TickFrequency = 5 };
            _lblSpeedVal = new Label { Location = new Point(370, 55), AutoSize = true };

            _lblFriction = new Label { Text = "Smoothness:", Location = new Point(25, 105), AutoSize = true };
            _tbFriction = new TrackBar { Location = new Point(140, 100), Width = 220, Minimum = 70, Maximum = 98, TickFrequency = 5 };
            _lblFrictionVal = new Label { Location = new Point(370, 105), AutoSize = true };

            _chkInvertDirection = new CheckBox { Text = "Invert Scroll Direction", Location = new Point(25, 160), AutoSize = true };

            _tabScrolling.Controls.AddRange(new Control[] { 
                _chkSmoothScrolling, _lblSpeed, _tbSpeed, _lblSpeedVal, 
                _lblFriction, _tbFriction, _lblFrictionVal, _chkInvertDirection 
            });

            // 4. Exclusions Tab
            _tabExclusions = new TabPage();
            _lblExclusionDesc = new Label {
                Location = new Point(20, 12),
                Size = new Size(440, 36),
                ForeColor = Color.FromArgb(80, 80, 80)
            };

            _lstExclusions = new ListBox {
                Location = new Point(20, 52),
                Size = new Size(280, 215),
                IntegralHeight = false
            };

            _btnAddApp = new Button {
                Location = new Point(315, 52),
                Size = new Size(150, 32)
            };
            _btnAddApp.Click += delegate { BrowseAndAddApp(); };

            _btnAddActive = new Button {
                Location = new Point(315, 94),
                Size = new Size(150, 32)
            };
            _btnAddActive.Click += delegate { AddActiveProcess(); };

            _btnRemoveApp = new Button {
                Location = new Point(315, 136),
                Size = new Size(150, 32)
            };
            _btnRemoveApp.Click += delegate { RemoveSelectedApp(); };

            _tabExclusions.Controls.AddRange(new Control[] {
                _lblExclusionDesc, _lstExclusions, _btnAddApp, _btnAddActive, _btnRemoveApp
            });

            _tabControl.TabPages.AddRange(new TabPage[] { _tabGeneral, _tabButtons, _tabScrolling, _tabExclusions });
            this.Controls.Add(_tabControl);

            // Bottom Buttons
            _btnReset = new Button {
                Text = "Reset Defaults",
                Location = new Point(25, 330),
                Size = new Size(130, 32)
            };
            _btnReset.Click += delegate { ResetToDefaults(); };

            _btnSave = new Button {
                Text = "Save & Close",
                Location = new Point(325, 330),
                Size = new Size(140, 32),
                BackColor = SystemColors.Highlight,
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat
            };
            _btnSave.Click += delegate { SaveValues(); this.Hide(); };

            this.Controls.Add(_btnReset);
            this.Controls.Add(_btnSave);

            // Event bindings
            _tbSpeed.Scroll += delegate { _lblSpeedVal.Text = string.Format("{0:0.0}x", _tbSpeed.Value / 10.0); };
            _tbFriction.Scroll += delegate { _lblFrictionVal.Text = string.Format("{0}%", _tbFriction.Value); };

            _cboLanguage.SelectedIndexChanged += delegate {
                string selected = "auto";
                if (_cboLanguage.SelectedIndex == 1) selected = "en";
                else if (_cboLanguage.SelectedIndex == 2) selected = "zh-Hant";
                
                if (AppSettings.Shared.Language != selected) {
                    AppSettings.Shared.Language = selected;
                    ApplyLocalization();
                }
            };
        }

        private void LoadValues() {
            AppSettings s = AppSettings.Shared;
            _chkEnabled.Checked = s.IsEnabled;
            _chkShowTray.Checked = s.ShowInMenuBar;
            _chkLaunchAtLogin.Checked = StartupHelper.IsStartupEnabled();

            if (s.Language == "en") _cboLanguage.SelectedIndex = 1;
            else if (s.Language == "zh-Hant") _cboLanguage.SelectedIndex = 2;
            else _cboLanguage.SelectedIndex = 0;

            PopulateActionCombos();

            _chkSmoothScrolling.Checked = s.Scrolling.SmoothScrolling;
            int speedVal = (int)Math.Round(s.Scrolling.Acceleration * 10);
            _tbSpeed.Value = Math.Max(5, Math.Min(30, speedVal));
            _lblSpeedVal.Text = string.Format("{0:0.0}x", _tbSpeed.Value / 10.0);

            int frictionVal = (int)Math.Round(s.Scrolling.Friction * 100);
            _tbFriction.Value = Math.Max(70, Math.Min(98, frictionVal));
            _lblFrictionVal.Text = string.Format("{0}%", _tbFriction.Value);

            _chkInvertDirection.Checked = s.Scrolling.InvertDirection;

            // Load Exclusions
            _lstExclusions.Items.Clear();
            if (s.ExcludedApps != null) {
                foreach (string app in s.ExcludedApps) {
                    _lstExclusions.Items.Add(app);
                }
            }
        }

        private void BrowseAndAddApp() {
            using (OpenFileDialog ofd = new OpenFileDialog()) {
                ofd.Title = Localization.Get("selectExecutable");
                ofd.Filter = "Executable files (*.exe)|*.exe|All files (*.*)|*.*";
                ofd.InitialDirectory = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);

                if (ofd.ShowDialog() == DialogResult.OK) {
                    string fileName = Path.GetFileName(ofd.FileName);
                    AddExclusionItem(fileName);
                }
            }
        }

        private void AddActiveProcess() {
            try {
                // Show a dialog with running non-system processes
                Form selectForm = new Form {
                    Text = Localization.Get("addRunningApp"),
                    Size = new Size(360, 420),
                    StartPosition = FormStartPosition.CenterParent,
                    FormBorderStyle = FormBorderStyle.FixedDialog,
                    MaximizeBox = false,
                    MinimizeBox = false
                };

                ListBox list = new ListBox {
                    Dock = DockStyle.Top,
                    Height = 320
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

                Button btnAdd = new Button {
                    Text = Localization.Get("addApp"),
                    Dock = DockStyle.Bottom,
                    Height = 35
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

            foreach (var item in _lstExclusions.Items) {
                if (string.Equals(item.ToString(), appName, StringComparison.OrdinalIgnoreCase)) {
                    MessageBox.Show(Localization.Get("appAlreadyExists"), "MouseSave", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return;
                }
            }

            _lstExclusions.Items.Add(appName);
            SaveValues();
        }

        private void RemoveSelectedApp() {
            if (_lstExclusions.SelectedIndex >= 0) {
                _lstExclusions.Items.RemoveAt(_lstExclusions.SelectedIndex);
                SaveValues();
            }
        }

        private void PopulateActionCombos() {
            var actions = new[] {
                new { Key = "default", Label = Localization.Get("actionDefault") },
                new { Key = "taskView", Label = Localization.Get("actionTaskView") },
                new { Key = "desktop", Label = Localization.Get("actionDesktop") },
                new { Key = "closeWindow", Label = Localization.Get("actionCloseWindow") },
                new { Key = "none", Label = Localization.Get("actionNone") }
            };

            PopulateOneCombo(_cboMiddleClick, actions, AppSettings.Shared.Buttons.MiddleClickAction);
            PopulateOneCombo(_cboButton4, actions, AppSettings.Shared.Buttons.Button4Action);
            PopulateOneCombo(_cboButton5, actions, AppSettings.Shared.Buttons.Button5Action);
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
            switch (index) {
                case 1: return "taskView";
                case 2: return "desktop";
                case 3: return "closeWindow";
                case 4: return "none";
                default: return "default";
            }
        }

        private void SaveValues() {
            AppSettings s = AppSettings.Shared;
            s.IsEnabled = _chkEnabled.Checked;
            s.ShowInMenuBar = _chkShowTray.Checked;
            s.LaunchAtLogin = _chkLaunchAtLogin.Checked;

            StartupHelper.SetStartup(s.LaunchAtLogin);

            s.Buttons.MiddleClickAction = GetKeyFromIndex(_cboMiddleClick.SelectedIndex);
            s.Buttons.Button4Action = GetKeyFromIndex(_cboButton4.SelectedIndex);
            s.Buttons.Button5Action = GetKeyFromIndex(_cboButton5.SelectedIndex);

            s.Scrolling.SmoothScrolling = _chkSmoothScrolling.Checked;
            s.Scrolling.Acceleration = _tbSpeed.Value / 10.0;
            s.Scrolling.Friction = _tbFriction.Value / 100.0;
            s.Scrolling.InvertDirection = _chkInvertDirection.Checked;

            List<string> exclusions = new List<string>();
            foreach (var item in _lstExclusions.Items) {
                exclusions.Add(item.ToString());
            }
            s.ExcludedApps = exclusions;

            s.Save();
        }

        private void ResetToDefaults() {
            AppSettings s = new AppSettings();
            _chkEnabled.Checked = s.IsEnabled;
            _chkShowTray.Checked = s.ShowInMenuBar;
            _chkLaunchAtLogin.Checked = false;
            _chkSmoothScrolling.Checked = s.Scrolling.SmoothScrolling;
            _tbSpeed.Value = (int)(s.Scrolling.Acceleration * 10);
            _lblSpeedVal.Text = string.Format("{0:0.0}x", _tbSpeed.Value / 10.0);
            _tbFriction.Value = (int)(s.Scrolling.Friction * 100);
            _lblFrictionVal.Text = string.Format("{0}%", _tbFriction.Value);
            _chkInvertDirection.Checked = s.Scrolling.InvertDirection;
            _cboMiddleClick.SelectedIndex = 0;
            _cboButton4.SelectedIndex = 0;
            _cboButton5.SelectedIndex = 0;

            _lstExclusions.Items.Clear();
            foreach (string app in s.ExcludedApps) {
                _lstExclusions.Items.Add(app);
            }

            SaveValues();
        }

        private void ApplyLocalization() {
            this.Text = Localization.Get("settingsTitle");
            _tabGeneral.Text = Localization.Get("general");
            _tabButtons.Text = Localization.Get("buttons");
            _tabScrolling.Text = Localization.Get("scrolling");
            _tabExclusions.Text = Localization.Get("exclusions");

            _chkEnabled.Text = Localization.Get("enableMouseSave");
            _chkShowTray.Text = Localization.Get("showInMenuBar");
            _chkLaunchAtLogin.Text = Localization.Get("launchAtLogin");
            _lblLanguage.Text = Localization.Get("language") + ":";

            _lblMiddleClick.Text = Localization.Get("middleClickAction") + ":";
            _lblButton4.Text = Localization.Get("button4Action") + ":";
            _lblButton5.Text = Localization.Get("button5Action") + ":";

            _chkSmoothScrolling.Text = Localization.Get("smoothScrolling");
            _lblSpeed.Text = Localization.Get("scrollSpeed") + ":";
            _lblFriction.Text = Localization.Get("scrollFriction") + ":";
            _chkInvertDirection.Text = Localization.Get("invertScroll");

            _lblExclusionDesc.Text = Localization.Get("exclusionsDesc");
            _btnAddApp.Text = Localization.Get("addApp");
            _btnAddActive.Text = Localization.Get("addRunningApp");
            _btnRemoveApp.Text = Localization.Get("removeApp");

            _btnReset.Text = Localization.Get("reset");
            _btnSave.Text = Localization.Get("save");

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
    }
}
