using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace MouseSave.Controls {
    public class ToggleSwitch : Control {
        private bool _checked = false;
        private float _animProgress = 0f; // 0.0 (off) to 1.0 (on)
        private Timer _animTimer;
        private bool _isHovered = false;

        public event EventHandler CheckedChanged;

        public bool Checked {
            get { return _checked; }
            set {
                if (_checked != value) {
                    _checked = value;
                    StartAnimation();
                    if (CheckedChanged != null) {
                        CheckedChanged(this, EventArgs.Empty);
                    }
                }
            }
        }

        public ToggleSwitch() {
            this.SetStyle(
                ControlStyles.UserPaint |
                ControlStyles.AllPaintingInWmPaint |
                ControlStyles.OptimizedDoubleBuffer |
                ControlStyles.ResizeRedraw |
                ControlStyles.SupportsTransparentBackColor, true
            );
            this.Size = new Size(Theme.Scale(44), Theme.Scale(22));
            this.Cursor = Cursors.Hand;
            this.TabStop = true;

            _animTimer = new Timer();
            _animTimer.Interval = 15;
            _animTimer.Tick += AnimTimer_Tick;
        }

        private void StartAnimation() {
            _animTimer.Start();
        }

        private void AnimTimer_Tick(object sender, EventArgs e) {
            float target = _checked ? 1.0f : 0.0f;
            float step = 0.20f; // ~150ms transition
            if (Math.Abs(_animProgress - target) <= step) {
                _animProgress = target;
                _animTimer.Stop();
            } else {
                _animProgress += (_animProgress < target) ? step : -step;
            }
            this.Invalidate();
        }

        protected override void OnClick(EventArgs e) {
            base.OnClick(e);
            this.Focus();
            this.Checked = !this.Checked;
        }

        protected override void OnKeyDown(KeyEventArgs e) {
            base.OnKeyDown(e);
            if (e.KeyCode == Keys.Space || e.KeyCode == Keys.Enter) {
                this.Checked = !this.Checked;
                e.Handled = true;
            }
        }

        protected override void OnMouseEnter(EventArgs e) {
            base.OnMouseEnter(e);
            _isHovered = true;
            this.Invalidate();
        }

        protected override void OnMouseLeave(EventArgs e) {
            base.OnMouseLeave(e);
            _isHovered = false;
            this.Invalidate();
        }

        protected override void OnPaint(PaintEventArgs e) {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            int w = this.Width - 1;
            int h = this.Height - 1;
            Rectangle rect = new Rectangle(0, 0, w, h);
            int radius = h / 2;

            // Interpolate colors
            Color trackOff = Theme.IsDark ? Color.FromArgb(55, 55, 55) : Color.FromArgb(230, 230, 230);
            Color trackOn = _isHovered ? Theme.AccentHoverColor : Theme.AccentColor;
            Color borderOff = Theme.IsDark ? Color.FromArgb(120, 120, 120) : Color.FromArgb(160, 160, 160);

            Color currentTrack = LerpColor(trackOff, trackOn, _animProgress);

            using (GraphicsPath path = Theme.CreateRoundedRectangle(rect, radius)) {
                using (SolidBrush brush = new SolidBrush(currentTrack)) {
                    g.FillPath(brush, path);
                }
                if (_animProgress < 0.99f) {
                    using (Pen pen = new Pen(borderOff, 1.5f)) {
                        g.DrawPath(pen, path);
                    }
                }
            }

            // Knob
            int thumbDiameter = h - Theme.Scale(6);
            int minX = Theme.Scale(3);
            int maxX = w - thumbDiameter - Theme.Scale(3);
            int thumbX = (int)(minX + (maxX - minX) * _animProgress);
            int thumbY = Theme.Scale(3);

            Rectangle thumbRect = new Rectangle(thumbX, thumbY, thumbDiameter, thumbDiameter);
            Color thumbColor = _checked 
                ? (Theme.IsDark ? Color.Black : Color.White)
                : (Theme.IsDark ? Color.FromArgb(210, 210, 210) : Color.FromArgb(90, 90, 90));

            using (SolidBrush thumbBrush = new SolidBrush(thumbColor)) {
                g.FillEllipse(thumbBrush, thumbRect);
            }

            // Focus ring
            if (this.Focused) {
                using (Pen focusPen = new Pen(Theme.AccentColor, 1.5f)) {
                    focusPen.DashStyle = DashStyle.Dot;
                    g.DrawRectangle(focusPen, 0, 0, w, h);
                }
            }
        }

        private static Color LerpColor(Color c1, Color c2, float t) {
            t = Math.Max(0f, Math.Min(1f, t));
            int r = (int)(c1.R + (c2.R - c1.R) * t);
            int g = (int)(c1.G + (c2.G - c1.G) * t);
            int b = (int)(c1.B + (c2.B - c1.B) * t);
            return Color.FromArgb(r, g, b);
        }

        protected override void Dispose(bool disposing) {
            if (disposing && _animTimer != null) {
                _animTimer.Dispose();
                _animTimer = null;
            }
            base.Dispose(disposing);
        }
    }
}
