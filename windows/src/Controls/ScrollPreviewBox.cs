using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace MouseSave.Controls {
    public class ScrollPreviewBox : Control {
        private float _scrollOffsetY = 0f;
        private const int TotalContentHeight = 600;

        public ScrollPreviewBox() {
            this.SetStyle(
                ControlStyles.UserPaint |
                ControlStyles.AllPaintingInWmPaint |
                ControlStyles.OptimizedDoubleBuffer |
                ControlStyles.ResizeRedraw |
                ControlStyles.Selectable |
                ControlStyles.SupportsTransparentBackColor, true
            );
            this.Size = new Size(Theme.Scale(460), Theme.Scale(140));
            this.Cursor = Cursors.Default;
        }

        protected override void OnMouseEnter(EventArgs e) {
            base.OnMouseEnter(e);
            this.Focus();
        }

        protected override void OnMouseWheel(MouseEventArgs e) {
            base.OnMouseWheel(e);
            // Internal scroll feedback
            int maxScroll = Math.Max(0, TotalContentHeight - this.Height);
            _scrollOffsetY -= (e.Delta / 120.0f) * Theme.Scale(36);
            _scrollOffsetY = Math.Max(0f, Math.Min(maxScroll, _scrollOffsetY));
            Invalidate();
        }

        protected override void OnPaint(PaintEventArgs e) {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            int w = this.Width - 1;
            int h = this.Height - 1;
            Rectangle rect = new Rectangle(0, 0, w, h);
            int radius = Theme.Scale(8);

            // Background & Border
            using (GraphicsPath path = Theme.CreateRoundedRectangle(rect, radius)) {
                using (SolidBrush brush = new SolidBrush(Theme.IsDark ? Color.FromArgb(28, 28, 28) : Color.FromArgb(248, 248, 248))) {
                    g.FillPath(brush, path);
                }
                using (Pen pen = new Pen(Theme.CardBorder, 1f)) {
                    g.DrawPath(pen, path);
                }
            }

            // Clip region for scrolling items
            GraphicsState state = g.Save();
            using (GraphicsPath clipPath = Theme.CreateRoundedRectangle(new Rectangle(2, 2, w - 4, h - 4), radius - 1)) {
                g.SetClip(clipPath);

                int startY = Theme.Scale(10) - (int)_scrollOffsetY;
                string[] items = new string[] {
                    "1. Smooth Physics Simulation (流體物理模擬)",
                    "2. Inertial Momentum & Friction (阻尼與動量衰減)",
                    "3. Zero Jitter Subpixel Precision (次像素防抖動)",
                    "4. Low Latency Native Hook (極低延遲系統勾點)",
                    "5. Responsive Velocity Curve (自適應加速度曲線)",
                    "6. Application Exclusion Passthrough (遊戲模式直通)",
                    "7. Natural Direction Inversion (自然方向反轉)",
                    "8. Try scrolling fast and slow here! (在此感受滾動手感)"
                };

                for (int i = 0; i < items.Length; i++) {
                    int itemY = startY + i * Theme.Scale(36);
                    if (itemY + Theme.Scale(30) < 0 || itemY > h) continue;

                    Rectangle itemRect = new Rectangle(Theme.Scale(14), itemY, w - Theme.Scale(36), Theme.Scale(28));
                    Color itemBg = Theme.IsDark ? Color.FromArgb(40, 40, 40) : Color.White;
                    using (GraphicsPath itemPath = Theme.CreateRoundedRectangle(itemRect, Theme.Scale(5))) {
                        using (SolidBrush b = new SolidBrush(itemBg)) {
                            g.FillPath(b, itemPath);
                        }
                    }

                    // Dot icon
                    Rectangle dotRect = new Rectangle(Theme.Scale(22), itemY + Theme.Scale(10), Theme.Scale(8), Theme.Scale(8));
                    using (SolidBrush dotBrush = new SolidBrush(Theme.AccentColor)) {
                        g.FillEllipse(dotBrush, dotRect);
                    }

                    // Item text
                    Rectangle textRect = new Rectangle(Theme.Scale(38), itemY, itemRect.Width - Theme.Scale(42), itemRect.Height);
                    TextRenderer.DrawText(
                        g, items[i], Theme.GetTextFont(9f, FontStyle.Regular), textRect,
                        Theme.TextPrimary,
                        TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.WordEllipsis
                    );
                }
            }
            g.Restore(state);

            // Scrollbar track
            int maxScrollRange = Math.Max(1, TotalContentHeight - this.Height);
            float scrollRatio = _scrollOffsetY / maxScrollRange;
            int barTrackH = h - Theme.Scale(20);
            int barThumbH = Math.Max(Theme.Scale(20), (int)(barTrackH * ((float)h / TotalContentHeight)));
            int barThumbY = Theme.Scale(10) + (int)(scrollRatio * (barTrackH - barThumbH));

            Rectangle thumbRect = new Rectangle(w - Theme.Scale(8), barThumbY, Theme.Scale(4), barThumbH);
            using (GraphicsPath thumbPath = Theme.CreateRoundedRectangle(thumbRect, 2))
            using (SolidBrush thumbBrush = new SolidBrush(Theme.IsDark ? Color.FromArgb(90, 90, 90) : Color.FromArgb(190, 190, 190))) {
                g.FillPath(thumbBrush, thumbPath);
            }

            // Bottom pill indicator: "Scroll here to test"
            string hint = Localization.Get("scrollTestHint");
            Size hintSize = TextRenderer.MeasureText(hint, Theme.GetTextFont(8f, FontStyle.Regular));
            Rectangle hintPill = new Rectangle(w - hintSize.Width - Theme.Scale(28), h - Theme.Scale(24), hintSize.Width + Theme.Scale(14), Theme.Scale(18));
            using (GraphicsPath pillPath = Theme.CreateRoundedRectangle(hintPill, Theme.Scale(9))) {
                using (SolidBrush pb = new SolidBrush(Theme.IsDark ? Color.FromArgb(60, 60, 60) : Color.FromArgb(220, 220, 220))) {
                    g.FillPath(pb, pillPath);
                }
            }
            TextRenderer.DrawText(g, hint, Theme.GetTextFont(8f, FontStyle.Regular), hintPill, Theme.TextSecondary, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
        }
    }
}
