using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace MouseSave.Controls {
    public class MouseVisualizer : Control {
        public event EventHandler<string> ButtonSelected;

        private string _hoveredButton = string.Empty;
        private string _selectedButton = "middle";
        private string _pulsingButton = string.Empty;
        private Timer _pulseTimer;

        private string _middleActionText = "Default";
        private string _button4ActionText = "Default";
        private string _button5ActionText = "Default";
        private string _tiltLeftActionText = "Default";
        private string _tiltRightActionText = "Default";

        public void TriggerButtonPulse(string buttonKey) {
            _pulsingButton = buttonKey;
            Invalidate();
            if (_pulseTimer == null) {
                _pulseTimer = new Timer();
                _pulseTimer.Interval = 250;
                _pulseTimer.Tick += delegate {
                    _pulsingButton = string.Empty;
                    if (_pulseTimer != null) _pulseTimer.Stop();
                    Invalidate();
                };
            }
            _pulseTimer.Stop();
            _pulseTimer.Start();
        }

        public string SelectedButton {
            get { return _selectedButton; }
            set { _selectedButton = value; Invalidate(); }
        }

        public string MiddleActionText {
            get { return _middleActionText; }
            set { _middleActionText = value; Invalidate(); }
        }

        public string Button4ActionText {
            get { return _button4ActionText; }
            set { _button4ActionText = value; Invalidate(); }
        }

        public string Button5ActionText {
            get { return _button5ActionText; }
            set { _button5ActionText = value; Invalidate(); }
        }

        public string TiltLeftActionText {
            get { return _tiltLeftActionText; }
            set { _tiltLeftActionText = value; Invalidate(); }
        }

        public string TiltRightActionText {
            get { return _tiltRightActionText; }
            set { _tiltRightActionText = value; Invalidate(); }
        }

        public MouseVisualizer() {
            this.SetStyle(
                ControlStyles.UserPaint |
                ControlStyles.AllPaintingInWmPaint |
                ControlStyles.OptimizedDoubleBuffer |
                ControlStyles.ResizeRedraw |
                ControlStyles.SupportsTransparentBackColor, true
            );
            this.Size = new Size(Theme.Scale(460), Theme.Scale(170));
            this.Cursor = Cursors.Hand;
        }

        protected override void OnMouseMove(MouseEventArgs e) {
            base.OnMouseMove(e);
            string found = HitTest(e.Location);
            if (_hoveredButton != found) {
                _hoveredButton = found;
                Invalidate();
            }
        }

        protected override void OnMouseLeave(EventArgs e) {
            base.OnMouseLeave(e);
            _hoveredButton = string.Empty;
            Invalidate();
        }

        protected override void OnMouseClick(MouseEventArgs e) {
            base.OnMouseClick(e);
            string hit = HitTest(e.Location);
            if (!string.IsNullOrEmpty(hit)) {
                _selectedButton = hit;
                Invalidate();
                if (ButtonSelected != null) {
                    ButtonSelected(this, hit);
                }
            }
        }

        private string HitTest(Point pt) {
            // Mouse center is at (Theme.Scale(100), Theme.Scale(85))
            int cx = Theme.Scale(100);
            int cy = Theme.Scale(85);

            // Wheel area: cx-8 to cx+8, cy-48 to cy-16
            Rectangle wheelRect = new Rectangle(cx - Theme.Scale(8), cy - Theme.Scale(48), Theme.Scale(16), Theme.Scale(32));
            if (wheelRect.Contains(pt)) return "middle";

            // Tilt Left area (Left of wheel)
            Rectangle tiltLeftRect = new Rectangle(cx - Theme.Scale(21), cy - Theme.Scale(43), Theme.Scale(11), Theme.Scale(22));
            if (tiltLeftRect.Contains(pt)) return "tiltLeft";

            // Tilt Right area (Right of wheel)
            Rectangle tiltRightRect = new Rectangle(cx + Theme.Scale(10), cy - Theme.Scale(43), Theme.Scale(11), Theme.Scale(22));
            if (tiltRightRect.Contains(pt)) return "tiltRight";

            // Side button 5 (Forward, upper thumb): cx-46 to cx-32, cy-25 to cy-2
            Rectangle btn5Rect = new Rectangle(cx - Theme.Scale(46), cy - Theme.Scale(25), Theme.Scale(18), Theme.Scale(22));
            if (btn5Rect.Contains(pt)) return "button5";

            // Side button 4 (Back, lower thumb): cx-46 to cx-32, cy+2 to cy+25
            Rectangle btn4Rect = new Rectangle(cx - Theme.Scale(46), cy + Theme.Scale(2), Theme.Scale(18), Theme.Scale(22));
            if (btn4Rect.Contains(pt)) return "button4";

            return string.Empty;
        }

        protected override void OnPaint(PaintEventArgs e) {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            int cx = Theme.Scale(100);
            int cy = Theme.Scale(85);

            // Mouse body outline
            int mw = Theme.Scale(72);
            int mh = Theme.Scale(126);
            Rectangle mouseBounds = new Rectangle(cx - mw / 2, cy - mh / 2, mw, mh);

            Color bodyFill = Theme.IsDark ? Color.FromArgb(48, 48, 48) : Color.FromArgb(245, 245, 245);
            Color bodyBorder = Theme.IsDark ? Color.FromArgb(75, 75, 75) : Color.FromArgb(200, 200, 200);

            using (GraphicsPath mousePath = Theme.CreateRoundedRectangle(mouseBounds, Theme.Scale(26))) {
                using (SolidBrush brush = new SolidBrush(bodyFill)) {
                    g.FillPath(brush, mousePath);
                }
                using (Pen pen = new Pen(bodyBorder, 1.5f)) {
                    g.DrawPath(pen, mousePath);
                }
            }

            // Divider line between buttons and palm rest
            int splitY = cy - Theme.Scale(10);
            using (Pen pen = new Pen(bodyBorder, 1f)) {
                g.DrawLine(pen, cx - mw / 2 + Theme.Scale(4), splitY, cx + mw / 2 - Theme.Scale(4), splitY);
                // Center split between L and R button
                g.DrawLine(pen, cx, cy - mh / 2 + Theme.Scale(4), cx, splitY);
            }

            // 1. Wheel (Middle Button)
            Rectangle wheelRect = new Rectangle(cx - Theme.Scale(8), cy - Theme.Scale(48), Theme.Scale(16), Theme.Scale(32));
            DrawInteractiveButton(g, wheelRect, "middle", Theme.Scale(6));

            // 2. Tilt Left & Tilt Right buttons / arrows beside the wheel
            Rectangle tiltLeftRect = new Rectangle(cx - Theme.Scale(21), cy - Theme.Scale(43), Theme.Scale(11), Theme.Scale(22));
            DrawInteractiveButton(g, tiltLeftRect, "tiltLeft", Theme.Scale(3));
            DrawTiltArrow(g, tiltLeftRect, true, _selectedButton == "tiltLeft" || _pulsingButton == "tiltLeft");

            Rectangle tiltRightRect = new Rectangle(cx + Theme.Scale(10), cy - Theme.Scale(43), Theme.Scale(11), Theme.Scale(22));
            DrawInteractiveButton(g, tiltRightRect, "tiltRight", Theme.Scale(3));
            DrawTiltArrow(g, tiltRightRect, false, _selectedButton == "tiltRight" || _pulsingButton == "tiltRight");

            // 3. Side Button 5 (Forward)
            Rectangle btn5Rect = new Rectangle(cx - mw / 2 - Theme.Scale(6), cy - Theme.Scale(25), Theme.Scale(10), Theme.Scale(20));
            DrawInteractiveButton(g, btn5Rect, "button5", Theme.Scale(4));

            // 4. Side Button 4 (Back)
            Rectangle btn4Rect = new Rectangle(cx - mw / 2 - Theme.Scale(6), cy + Theme.Scale(2), Theme.Scale(10), Theme.Scale(20));
            DrawInteractiveButton(g, btn4Rect, "button4", Theme.Scale(4));

            // Leader lines and info cards on the right side
            int labelLeft = Theme.Scale(185);

            DrawIndicatorCard(g, labelLeft, Theme.Scale(12), "middle", Localization.Get("middleClickAction"), _middleActionText, wheelRect.Right, wheelRect.Top + wheelRect.Height / 2);
            DrawIndicatorCard(g, labelLeft, Theme.Scale(50), "tiltLeft", Localization.Get("tiltLeftAction"), _tiltLeftActionText, tiltLeftRect.Left, tiltLeftRect.Top + tiltLeftRect.Height / 2);
            DrawIndicatorCard(g, labelLeft, Theme.Scale(88), "button5", Localization.Get("button5Action"), _button5ActionText, btn5Rect.Left, btn5Rect.Top + btn5Rect.Height / 2);
            DrawIndicatorCard(g, labelLeft, Theme.Scale(126), "button4", Localization.Get("button4Action"), _button4ActionText, btn4Rect.Left, btn4Rect.Top + btn4Rect.Height / 2);
        }

        private void DrawTiltArrow(Graphics g, Rectangle r, bool isLeft, bool active) {
            Color arrowColor = active ? Color.White : (Theme.IsDark ? Color.FromArgb(170, 170, 170) : Color.FromArgb(100, 100, 100));
            int midY = r.Y + r.Height / 2;
            Point[] pts;
            if (isLeft) {
                pts = new Point[] {
                    new Point(r.X + Theme.Scale(2), midY),
                    new Point(r.Right - Theme.Scale(2), midY - Theme.Scale(4)),
                    new Point(r.Right - Theme.Scale(2), midY + Theme.Scale(4))
                };
            } else {
                pts = new Point[] {
                    new Point(r.Right - Theme.Scale(2), midY),
                    new Point(r.X + Theme.Scale(2), midY - Theme.Scale(4)),
                    new Point(r.X + Theme.Scale(2), midY + Theme.Scale(4))
                };
            }
            using (SolidBrush b = new SolidBrush(arrowColor)) {
                g.FillPolygon(b, pts);
            }
        }

        private void DrawInteractiveButton(Graphics g, Rectangle rect, string btnId, int radius) {
            bool isSel = (_selectedButton == btnId);
            bool isHov = (_hoveredButton == btnId);
            bool isPulse = (_pulsingButton == btnId);

            Color fill = isPulse ? Color.FromArgb(0, 204, 106)
                       : (isSel ? Theme.AccentColor 
                       : (isHov ? Theme.AccentHoverColor 
                       : (Theme.IsDark ? Color.FromArgb(70, 70, 70) : Color.FromArgb(215, 215, 215))));
            Color border = isPulse ? Color.White : (isSel ? Theme.AccentHoverColor : (Theme.IsDark ? Color.FromArgb(100, 100, 100) : Color.FromArgb(180, 180, 180)));

            using (GraphicsPath path = Theme.CreateRoundedRectangle(rect, radius)) {
                using (SolidBrush b = new SolidBrush(fill)) {
                    g.FillPath(b, path);
                }
                using (Pen p = new Pen(border, 1.5f)) {
                    g.DrawPath(p, path);
                }
            }
        }

        private void DrawIndicatorCard(Graphics g, int x, int y, string btnId, string title, string action, int targetX, int targetY) {
            bool isSel = (_selectedButton == btnId);
            int cardW = Theme.Scale(250);
            int cardH = Theme.Scale(38);
            Rectangle rect = new Rectangle(x, y, cardW, cardH);

            Color bg = isSel ? (Theme.IsDark ? Color.FromArgb(50, 50, 50) : Color.FromArgb(235, 243, 252)) : Theme.CardBackground;
            Color border = isSel ? Theme.AccentColor : Theme.CardBorder;

            using (GraphicsPath path = Theme.CreateRoundedRectangle(rect, Theme.Scale(6))) {
                using (SolidBrush b = new SolidBrush(bg)) {
                    g.FillPath(b, path);
                }
                using (Pen p = new Pen(border, isSel ? 1.5f : 1f)) {
                    g.DrawPath(p, path);
                }
            }

            // Connection line
            using (Pen linePen = new Pen(isSel ? Theme.AccentColor : (Theme.IsDark ? Color.FromArgb(80, 80, 80) : Color.FromArgb(200, 200, 200)), isSel ? 1.5f : 1f)) {
                linePen.DashStyle = isSel ? DashStyle.Solid : DashStyle.Dot;
                g.DrawLine(linePen, x - Theme.Scale(6), y + cardH / 2, targetX + (targetX < x ? Theme.Scale(4) : -Theme.Scale(4)), targetY);
            }

            // Text
            Rectangle titleRect = new Rectangle(x + Theme.Scale(10), y + Theme.Scale(4), cardW - Theme.Scale(20), Theme.Scale(14));
            TextRenderer.DrawText(g, title, Theme.GetTextFont(8f, FontStyle.Regular), titleRect, Theme.TextSecondary, TextFormatFlags.Left | TextFormatFlags.WordEllipsis);

            Rectangle actionRect = new Rectangle(x + Theme.Scale(10), y + Theme.Scale(18), cardW - Theme.Scale(20), Theme.Scale(16));
            TextRenderer.DrawText(g, action, Theme.GetTextFont(9f, FontStyle.Bold), actionRect, isSel ? Theme.AccentColor : Theme.TextPrimary, TextFormatFlags.Left | TextFormatFlags.WordEllipsis);
        }
    }
}
