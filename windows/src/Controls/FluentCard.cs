using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace MouseSave.Controls {
    public class FluentCard : Panel {
        private string _title = string.Empty;
        private string _description = string.Empty;
        private Control _rightControl;

        public string Title {
            get { return _title; }
            set { _title = value; Invalidate(); }
        }

        public string Description {
            get { return _description; }
            set { _description = value; Invalidate(); }
        }

        public Control RightControl {
            get { return _rightControl; }
            set {
                if (_rightControl != null) {
                    this.Controls.Remove(_rightControl);
                }
                _rightControl = value;
                if (_rightControl != null) {
                    this.Controls.Add(_rightControl);
                    LayoutRightControl();
                }
                Invalidate();
            }
        }

        public FluentCard() {
            this.SetStyle(
                ControlStyles.UserPaint |
                ControlStyles.AllPaintingInWmPaint |
                ControlStyles.OptimizedDoubleBuffer |
                ControlStyles.ResizeRedraw |
                ControlStyles.SupportsTransparentBackColor, true
            );
            this.Size = new Size(Theme.Scale(460), Theme.Scale(64));
            this.Padding = new Padding(Theme.Scale(16), Theme.Scale(12), Theme.Scale(16), Theme.Scale(12));
        }

        protected override void OnResize(EventArgs eventargs) {
            base.OnResize(eventargs);
            LayoutRightControl();
        }

        private void LayoutRightControl() {
            if (_rightControl != null) {
                int rightMargin = Theme.Scale(16);
                int x = this.Width - _rightControl.Width - rightMargin;
                int y = (this.Height - _rightControl.Height) / 2;
                _rightControl.Location = new Point(x, y);
            }
        }

        protected override void OnPaint(PaintEventArgs e) {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            int w = this.Width - 1;
            int h = this.Height - 1;
            Rectangle rect = new Rectangle(0, 0, w, h);
            int radius = Theme.Scale(8);

            // Draw Card Body
            using (GraphicsPath path = Theme.CreateRoundedRectangle(rect, radius)) {
                using (SolidBrush brush = new SolidBrush(Theme.CardBackground)) {
                    g.FillPath(brush, path);
                }
                using (Pen pen = new Pen(Theme.CardBorder, 1f)) {
                    g.DrawPath(pen, path);
                }
            }

            // Text Layout
            int textLeft = Theme.Scale(16);
            int textRightLimit = (_rightControl != null) ? _rightControl.Left - Theme.Scale(12) : this.Width - Theme.Scale(16);
            int textWidth = Math.Max(10, textRightLimit - textLeft);

            if (string.IsNullOrEmpty(_description)) {
                // Single line vertically centered
                Rectangle titleRect = new Rectangle(textLeft, 0, textWidth, this.Height);
                TextRenderer.DrawText(
                    g, _title, Theme.GetTextFont(10f, FontStyle.Regular), titleRect,
                    Theme.TextPrimary,
                    TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.WordEllipsis
                );
            } else {
                // Two lines: Title + Description
                int titleY = Theme.Scale(12);
                Rectangle titleRect = new Rectangle(textLeft, titleY, textWidth, Theme.Scale(20));
                TextRenderer.DrawText(
                    g, _title, Theme.GetTextFont(10f, FontStyle.Regular), titleRect,
                    Theme.TextPrimary,
                    TextFormatFlags.Left | TextFormatFlags.Top | TextFormatFlags.WordEllipsis
                );

                int descY = titleY + Theme.Scale(20);
                Rectangle descRect = new Rectangle(textLeft, descY, textWidth, Theme.Scale(20));
                TextRenderer.DrawText(
                    g, _description, Theme.GetTextFont(8.5f, FontStyle.Regular), descRect,
                    Theme.TextSecondary,
                    TextFormatFlags.Left | TextFormatFlags.Top | TextFormatFlags.WordEllipsis
                );
            }
        }
    }
}
