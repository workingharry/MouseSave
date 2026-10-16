using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace MouseSave.Controls {
    public class FluentButton : Button {
        private bool _isHovered = false;
        private bool _isPressed = false;
        private bool _isAccent = false;

        public bool IsAccent {
            get { return _isAccent; }
            set { _isAccent = value; Invalidate(); }
        }

        public FluentButton() {
            this.SetStyle(
                ControlStyles.UserPaint |
                ControlStyles.AllPaintingInWmPaint |
                ControlStyles.OptimizedDoubleBuffer |
                ControlStyles.ResizeRedraw |
                ControlStyles.SupportsTransparentBackColor, true
            );
            this.FlatStyle = FlatStyle.Flat;
            this.FlatAppearance.BorderSize = 0;
            this.Cursor = Cursors.Hand;
            this.Size = new Size(Theme.Scale(120), Theme.Scale(32));
            this.Font = Theme.GetTextFont(9.5f, FontStyle.Regular);
        }

        protected override void OnMouseEnter(EventArgs e) {
            base.OnMouseEnter(e);
            _isHovered = true;
            Invalidate();
        }

        protected override void OnMouseLeave(EventArgs e) {
            base.OnMouseLeave(e);
            _isHovered = false;
            _isPressed = false;
            Invalidate();
        }

        protected override void OnMouseDown(MouseEventArgs mevent) {
            base.OnMouseDown(mevent);
            if (mevent.Button == MouseButtons.Left) {
                _isPressed = true;
                Invalidate();
            }
        }

        protected override void OnMouseUp(MouseEventArgs mevent) {
            base.OnMouseUp(mevent);
            _isPressed = false;
            Invalidate();
        }

        protected override void OnPaint(PaintEventArgs pevent) {
            Graphics g = pevent.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            int w = this.Width - 1;
            int h = this.Height - 1;
            Rectangle rect = new Rectangle(0, 0, w, h);
            int radius = Theme.Scale(5);

            Color bg;
            Color border;
            Color text;

            if (!this.Enabled) {
                bg = Theme.IsDark ? Color.FromArgb(40, 40, 40) : Color.FromArgb(235, 235, 235);
                border = Theme.IsDark ? Color.FromArgb(55, 55, 55) : Color.FromArgb(220, 220, 220);
                text = Theme.IsDark ? Color.FromArgb(100, 100, 100) : Color.FromArgb(160, 160, 160);
            } else if (_isAccent) {
                if (_isPressed) {
                    bg = ControlPaint.Dark(Theme.AccentColor, 0.1f);
                } else if (_isHovered) {
                    bg = Theme.AccentHoverColor;
                } else {
                    bg = Theme.AccentColor;
                }
                border = bg;
                text = Theme.IsDark ? Color.Black : Color.White;
            } else {
                if (_isPressed) {
                    bg = Theme.IsDark ? Color.FromArgb(45, 45, 45) : Color.FromArgb(230, 230, 230);
                } else if (_isHovered) {
                    bg = Theme.ControlHover;
                } else {
                    bg = Theme.ControlFill;
                }
                border = Theme.ControlBorder;
                text = Theme.TextPrimary;
            }

            using (GraphicsPath path = Theme.CreateRoundedRectangle(rect, radius)) {
                using (SolidBrush brush = new SolidBrush(bg)) {
                    g.FillPath(brush, path);
                }
                using (Pen pen = new Pen(border, 1f)) {
                    g.DrawPath(pen, path);
                }
            }

            // Draw Text
            TextRenderer.DrawText(
                g, this.Text, this.Font, rect, text,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine
            );

            // Focus ring
            if (this.Focused && this.Enabled) {
                using (Pen focusPen = new Pen(Theme.AccentColor, 1.5f)) {
                    focusPen.DashStyle = DashStyle.Dot;
                    Rectangle focusRect = new Rectangle(2, 2, w - 4, h - 4);
                    using (GraphicsPath focusPath = Theme.CreateRoundedRectangle(focusRect, radius - 1)) {
                        g.DrawPath(focusPen, focusPath);
                    }
                }
            }
        }
    }
}
