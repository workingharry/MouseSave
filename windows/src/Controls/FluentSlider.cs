using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace MouseSave.Controls {
    public class FluentSlider : Control {
        private int _minimum = 0;
        private int _maximum = 100;
        private int _value = 50;
        private bool _isDragging = false;
        private bool _isHovered = false;
        private double _displayMultiplier = 1.0;
        private string _valueFormat = "{0}";

        public event EventHandler ValueChanged;

        public int Minimum {
            get { return _minimum; }
            set { _minimum = value; Invalidate(); }
        }

        public int Maximum {
            get { return _maximum; }
            set { _maximum = value; Invalidate(); }
        }

        public int Value {
            get { return _value; }
            set {
                int clamped = Math.Max(_minimum, Math.Min(_maximum, value));
                if (_value != clamped) {
                    _value = clamped;
                    Invalidate();
                    if (ValueChanged != null) {
                        ValueChanged(this, EventArgs.Empty);
                    }
                }
            }
        }

        public double DisplayMultiplier {
            get { return _displayMultiplier; }
            set { _displayMultiplier = value; Invalidate(); }
        }

        public string ValueFormat {
            get { return _valueFormat; }
            set { _valueFormat = value; Invalidate(); }
        }

        public FluentSlider() {
            this.SetStyle(
                ControlStyles.UserPaint |
                ControlStyles.AllPaintingInWmPaint |
                ControlStyles.OptimizedDoubleBuffer |
                ControlStyles.ResizeRedraw |
                ControlStyles.SupportsTransparentBackColor, true
            );
            this.Size = new Size(Theme.Scale(240), Theme.Scale(32));
            this.Cursor = Cursors.Hand;
            this.TabStop = true;
        }

        protected override void OnMouseDown(MouseEventArgs e) {
            base.OnMouseDown(e);
            if (e.Button == MouseButtons.Left) {
                _isDragging = true;
                this.Focus();
                UpdateValueFromMouse(e.X);
            }
        }

        protected override void OnMouseMove(MouseEventArgs e) {
            base.OnMouseMove(e);
            if (_isDragging) {
                UpdateValueFromMouse(e.X);
            }
        }

        protected override void OnMouseUp(MouseEventArgs e) {
            base.OnMouseUp(e);
            _isDragging = false;
            Invalidate();
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

        protected override void OnKeyDown(KeyEventArgs e) {
            base.OnKeyDown(e);
            int step = Math.Max(1, (_maximum - _minimum) / 20);
            if (e.KeyCode == Keys.Left || e.KeyCode == Keys.Down) {
                this.Value -= step;
                e.Handled = true;
            } else if (e.KeyCode == Keys.Right || e.KeyCode == Keys.Up) {
                this.Value += step;
                e.Handled = true;
            } else if (e.KeyCode == Keys.Home) {
                this.Value = _minimum;
                e.Handled = true;
            } else if (e.KeyCode == Keys.End) {
                this.Value = _maximum;
                e.Handled = true;
            }
        }

        private void UpdateValueFromMouse(int mouseX) {
            int trackLeft = Theme.Scale(10);
            int trackRight = this.Width - Theme.Scale(60);
            int trackWidth = trackRight - trackLeft;

            if (trackWidth <= 0) return;

            float ratio = (float)(mouseX - trackLeft) / trackWidth;
            ratio = Math.Max(0f, Math.Min(1f, ratio));
            this.Value = (int)Math.Round(_minimum + ratio * (_maximum - _minimum));
        }

        protected override void OnPaint(PaintEventArgs e) {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            int trackLeft = Theme.Scale(10);
            int trackRight = this.Width - Theme.Scale(60);
            int trackWidth = trackRight - trackLeft;
            int trackY = this.Height / 2;
            int trackThickness = Theme.Scale(4);

            float ratio = (_maximum > _minimum) ? (float)(_value - _minimum) / (_maximum - _minimum) : 0f;
            int thumbX = trackLeft + (int)(ratio * trackWidth);

            // Draw full background track
            Rectangle bgTrack = new Rectangle(trackLeft, trackY - trackThickness / 2, trackWidth, trackThickness);
            Color trackBgColor = Theme.IsDark ? Color.FromArgb(65, 65, 65) : Color.FromArgb(220, 220, 220);
            using (GraphicsPath path = Theme.CreateRoundedRectangle(bgTrack, trackThickness / 2))
            using (SolidBrush brush = new SolidBrush(trackBgColor)) {
                g.FillPath(brush, path);
            }

            // Draw active accent track
            int activeWidth = thumbX - trackLeft;
            if (activeWidth > 0) {
                Rectangle activeTrack = new Rectangle(trackLeft, trackY - trackThickness / 2, activeWidth, trackThickness);
                using (GraphicsPath path = Theme.CreateRoundedRectangle(activeTrack, trackThickness / 2))
                using (SolidBrush brush = new SolidBrush(Theme.AccentColor)) {
                    g.FillPath(brush, path);
                }
            }

            // Draw Thumb
            int thumbRadius = _isDragging ? Theme.Scale(8) : (_isHovered ? Theme.Scale(7) : Theme.Scale(6));
            Rectangle thumbRect = new Rectangle(thumbX - thumbRadius, trackY - thumbRadius, thumbRadius * 2, thumbRadius * 2);

            using (SolidBrush thumbBrush = new SolidBrush(Theme.AccentColor)) {
                g.FillEllipse(thumbBrush, thumbRect);
            }
            Color thumbBorder = Theme.IsDark ? Color.FromArgb(32, 32, 32) : Color.White;
            using (Pen borderPen = new Pen(thumbBorder, 2f)) {
                g.DrawEllipse(borderPen, thumbRect);
            }

            // Draw Value Text
            string displayVal = string.Format(_valueFormat, _value * _displayMultiplier);
            Rectangle textRect = new Rectangle(this.Width - Theme.Scale(55), 0, Theme.Scale(50), this.Height);
            TextRenderer.DrawText(
                g, displayVal, Theme.GetTextFont(9f, FontStyle.Bold), textRect,
                Theme.TextPrimary,
                TextFormatFlags.Left | TextFormatFlags.VerticalCenter
            );

            // Focus ring
            if (this.Focused) {
                using (Pen focusPen = new Pen(Theme.AccentColor, 1f)) {
                    focusPen.DashStyle = DashStyle.Dot;
                    g.DrawRectangle(focusPen, trackLeft - 4, trackY - 12, trackWidth + 8, 24);
                }
            }
        }
    }
}
