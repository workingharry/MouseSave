using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Windows.Forms;

namespace MouseSave.Controls {
    public class ExclusionListView : UserControl {
        public event EventHandler<string> AppRemoved;
        public event EventHandler BrowseRequested;
        public event EventHandler ActiveProcessRequested;

        private List<string> _items = new List<string>();
        private List<string> _filtered = new List<string>();
        private Dictionary<string, Image> _iconCache = new Dictionary<string, Image>(StringComparer.OrdinalIgnoreCase);

        private TextBox _txtSearch;
        private FluentButton _btnBrowse;
        private FluentButton _btnActive;
        private Panel _listContainer;

        public List<string> Items {
            get { return _items; }
        }

        public ExclusionListView() {
            this.SetStyle(
                ControlStyles.UserPaint |
                ControlStyles.AllPaintingInWmPaint |
                ControlStyles.OptimizedDoubleBuffer |
                ControlStyles.ResizeRedraw |
                ControlStyles.SupportsTransparentBackColor, true
            );
            this.Size = new Size(Theme.Scale(460), Theme.Scale(280));
            InitializeUI();
        }

        private void InitializeUI() {
            this.Controls.Clear();

            // 1. Search Box
            _txtSearch = new TextBox {
                Location = new Point(0, 0),
                Width = Theme.Scale(180),
                Height = Theme.Scale(28),
                Font = Theme.GetTextFont(9f, FontStyle.Regular),
                BorderStyle = BorderStyle.FixedSingle,
                BackColor = Theme.ControlFill,
                ForeColor = Theme.TextPrimary
            };
            _txtSearch.TextChanged += delegate {
                FilterItems();
            };

            // 2. Buttons
            _btnBrowse = new FluentButton {
                Text = Localization.Get("addApp"),
                Location = new Point(Theme.Scale(190), 0),
                Width = Theme.Scale(125),
                Height = Theme.Scale(28),
                IsAccent = false
            };
            _btnBrowse.Click += delegate {
                if (BrowseRequested != null) BrowseRequested(this, EventArgs.Empty);
            };

            _btnActive = new FluentButton {
                Text = Localization.Get("addRunningApp"),
                Location = new Point(Theme.Scale(324), 0),
                Width = Theme.Scale(135),
                Height = Theme.Scale(28),
                IsAccent = true
            };
            _btnActive.Click += delegate {
                if (ActiveProcessRequested != null) ActiveProcessRequested(this, EventArgs.Empty);
            };

            this.Controls.Add(_txtSearch);
            this.Controls.Add(_btnBrowse);
            this.Controls.Add(_btnActive);

            // 3. List Container
            _listContainer = new Panel {
                Location = new Point(0, Theme.Scale(36)),
                Size = new Size(this.Width, this.Height - Theme.Scale(36)),
                Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right,
                AutoScroll = true
            };
            this.Controls.Add(_listContainer);
        }

        public void SetItems(IEnumerable<string> items) {
            _items.Clear();
            if (items != null) {
                _items.AddRange(items);
            }
            FilterItems();
        }

        private void FilterItems() {
            string query = (_txtSearch.Text ?? "").Trim();
            _filtered.Clear();

            for (int i = 0; i < _items.Count; i++) {
                string item = _items[i];
                if (string.IsNullOrEmpty(query) || item.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0) {
                    _filtered.Add(item);
                }
            }
            RebuildListUI();
        }

        private void RebuildListUI() {
            _listContainer.SuspendLayout();
            _listContainer.Controls.Clear();

            if (_filtered.Count == 0) {
                // Empty state card
                Panel emptyCard = new Panel {
                    Dock = DockStyle.Fill
                };
                emptyCard.Paint += EmptyCard_Paint;
                _listContainer.Controls.Add(emptyCard);
            } else {
                int itemH = Theme.Scale(48);
                int y = 0;
                for (int i = 0; i < _filtered.Count; i++) {
                    string app = _filtered[i];
                    Panel row = CreateRowPanel(app, y, itemH);
                    _listContainer.Controls.Add(row);
                    y += itemH + Theme.Scale(6);
                }
            }

            _listContainer.ResumeLayout();
        }

        private Panel CreateRowPanel(string appName, int y, int height) {
            int rowW = _listContainer.ClientSize.Width - Theme.Scale(4);
            if (rowW < 100) rowW = _listContainer.Width - Theme.Scale(24);

            Panel panel = new Panel {
                Location = new Point(0, y),
                Size = new Size(rowW, height),
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right,
                Cursor = Cursors.Default
            };

            Image icon = GetAppIcon(appName);

            // Delete button on the right
            FluentButton btnDel = new FluentButton {
                Text = Localization.Get("delete"),
                Location = new Point(panel.Width - Theme.Scale(70), (height - Theme.Scale(26)) / 2),
                Size = new Size(Theme.Scale(60), Theme.Scale(26)),
                Anchor = AnchorStyles.Right | AnchorStyles.Top
            };
            btnDel.Click += delegate {
                if (AppRemoved != null) {
                    AppRemoved(this, appName);
                }
            };
            panel.Controls.Add(btnDel);

            panel.Paint += delegate(object sender, PaintEventArgs e) {
                Graphics g = e.Graphics;
                g.SmoothingMode = SmoothingMode.AntiAlias;

                Rectangle rect = new Rectangle(0, 0, panel.Width - 1, panel.Height - 1);
                using (GraphicsPath path = Theme.CreateRoundedRectangle(rect, Theme.Scale(6))) {
                    using (SolidBrush b = new SolidBrush(Theme.CardBackground)) {
                        g.FillPath(b, path);
                    }
                    using (Pen p = new Pen(Theme.CardBorder, 1f)) {
                        g.DrawPath(p, path);
                    }
                }

                // Draw Icon
                int iconSize = Theme.Scale(24);
                int iconX = Theme.Scale(12);
                int iconY = (panel.Height - iconSize) / 2;
                if (icon != null) {
                    g.DrawImage(icon, iconX, iconY, iconSize, iconSize);
                }

                // Draw Text
                int textX = iconX + iconSize + Theme.Scale(10);
                int textW = btnDel.Left - textX - Theme.Scale(10);

                Rectangle titleRect = new Rectangle(textX, Theme.Scale(8), textW, Theme.Scale(18));
                TextRenderer.DrawText(
                    g, appName, Theme.GetTextFont(9.5f, FontStyle.Bold), titleRect,
                    Theme.TextPrimary,
                    TextFormatFlags.Left | TextFormatFlags.SingleLine | TextFormatFlags.WordEllipsis
                );

                Rectangle subRect = new Rectangle(textX, Theme.Scale(26), textW, Theme.Scale(16));
                TextRenderer.DrawText(
                    g, Localization.Get("gameModeActiveDesc"), Theme.GetTextFont(8f, FontStyle.Regular), subRect,
                    Theme.TextSecondary,
                    TextFormatFlags.Left | TextFormatFlags.SingleLine | TextFormatFlags.WordEllipsis
                );
            };

            return panel;
        }

        private Image GetAppIcon(string appName) {
            Image cached;
            if (_iconCache.TryGetValue(appName, out cached)) {
                return cached;
            }

            try {
                // If it's a full path or exists
                if (File.Exists(appName)) {
                    using (Icon ico = Icon.ExtractAssociatedIcon(appName)) {
                        if (ico != null) {
                            cached = ico.ToBitmap();
                            _iconCache[appName] = cached;
                            return cached;
                        }
                    }
                }
            } catch {}

            // Create fallback vector icon
            Bitmap bmp = new Bitmap(32, 32);
            using (Graphics g = Graphics.FromImage(bmp)) {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.Clear(Color.Transparent);
                using (GraphicsPath p = Theme.CreateRoundedRectangle(new Rectangle(2, 2, 27, 27), 6)) {
                    using (SolidBrush b = new SolidBrush(Theme.IsDark ? Color.FromArgb(70, 70, 70) : Color.FromArgb(220, 220, 220))) {
                        g.FillPath(b, p);
                    }
                }
                TextRenderer.DrawText(
                    g, Theme.IconGame, Theme.GetIconFont(11f), new Rectangle(0, 0, 32, 32),
                    Theme.TextPrimary,
                    TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter
                );
            }
            _iconCache[appName] = bmp;
            return bmp;
        }

        private void EmptyCard_Paint(object sender, PaintEventArgs e) {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            Panel pnl = sender as Panel;
            if (pnl == null) return;

            Rectangle rect = new Rectangle(Theme.Scale(10), Theme.Scale(10), pnl.Width - Theme.Scale(20), pnl.Height - Theme.Scale(20));
            using (GraphicsPath path = Theme.CreateRoundedRectangle(rect, Theme.Scale(8))) {
                using (SolidBrush b = new SolidBrush(Theme.IsDark ? Color.FromArgb(28, 28, 28) : Color.FromArgb(248, 248, 248))) {
                    g.FillPath(b, path);
                }
                using (Pen p = new Pen(Theme.CardBorder, 1f)) {
                    p.DashStyle = DashStyle.Dash;
                    g.DrawPath(p, path);
                }
            }

            // Shield / Game icon
            int iconY = rect.Top + Theme.Scale(30);
            Rectangle iconRect = new Rectangle(rect.Left, iconY, rect.Width, Theme.Scale(36));
            TextRenderer.DrawText(
                g, Theme.IconShield, Theme.GetIconFont(24f), iconRect,
                Theme.AccentColor,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter
            );

            // Empty text
            Rectangle textRect = new Rectangle(rect.Left + Theme.Scale(20), iconY + Theme.Scale(42), rect.Width - Theme.Scale(40), Theme.Scale(24));
            TextRenderer.DrawText(
                g, Localization.Get("noExclusionsTitle"), Theme.GetTextFont(10.5f, FontStyle.Bold), textRect,
                Theme.TextPrimary,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter
            );

            Rectangle descRect = new Rectangle(rect.Left + Theme.Scale(20), iconY + Theme.Scale(68), rect.Width - Theme.Scale(40), Theme.Scale(40));
            TextRenderer.DrawText(
                g, Localization.Get("noExclusionsDesc"), Theme.GetTextFont(8.5f, FontStyle.Regular), descRect,
                Theme.TextSecondary,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.Top | TextFormatFlags.WordBreak
            );
        }
    }
}
