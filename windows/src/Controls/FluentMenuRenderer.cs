using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace MouseSave.Controls {
    public class FluentMenuRenderer : ToolStripProfessionalRenderer {
        public FluentMenuRenderer() : base(new FluentColorTable()) {
            this.RoundedEdges = true;
        }

        protected override void OnRenderToolStripBackground(ToolStripRenderEventArgs e) {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            Rectangle rect = new Rectangle(0, 0, e.ToolStrip.Width - 1, e.ToolStrip.Height - 1);
            using (SolidBrush b = new SolidBrush(Theme.CardBackground)) {
                g.FillRectangle(b, rect);
            }
        }

        protected override void OnRenderToolStripBorder(ToolStripRenderEventArgs e) {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            Rectangle rect = new Rectangle(0, 0, e.ToolStrip.Width - 1, e.ToolStrip.Height - 1);
            using (Pen p = new Pen(Theme.CardBorder, 1f)) {
                g.DrawRectangle(p, rect);
            }
        }

        protected override void OnRenderMenuItemBackground(ToolStripItemRenderEventArgs e) {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            ToolStripItem item = e.Item;
            if (item.Selected && item.Enabled) {
                Rectangle rect = new Rectangle(Theme.Scale(4), Theme.Scale(2), item.Width - Theme.Scale(8), item.Height - Theme.Scale(4));
                using (GraphicsPath path = Theme.CreateRoundedRectangle(rect, Theme.Scale(4))) {
                    Color selColor = Theme.IsDark ? Color.FromArgb(60, 60, 60) : Color.FromArgb(230, 235, 245);
                    using (SolidBrush b = new SolidBrush(selColor)) {
                        g.FillPath(b, path);
                    }
                }
            }
        }

        protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e) {
            e.TextColor = e.Item.Enabled ? Theme.TextPrimary : Theme.TextSecondary;
            base.OnRenderItemText(e);
        }

        protected override void OnRenderSeparator(ToolStripSeparatorRenderEventArgs e) {
            Graphics g = e.Graphics;
            int y = e.Item.Height / 2;
            using (Pen p = new Pen(Theme.CardBorder, 1f)) {
                g.DrawLine(p, Theme.Scale(12), y, e.Item.Width - Theme.Scale(12), y);
            }
        }

        protected override void OnRenderImageMargin(ToolStripRenderEventArgs e) {
            // No distinct left gutter bar, keep seamless
        }

        protected override void OnRenderItemCheck(ToolStripItemImageRenderEventArgs e) {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            Rectangle rect = new Rectangle(Theme.Scale(6), (e.Item.Height - Theme.Scale(16)) / 2, Theme.Scale(16), Theme.Scale(16));
            using (GraphicsPath path = Theme.CreateRoundedRectangle(rect, Theme.Scale(3))) {
                using (SolidBrush b = new SolidBrush(Theme.AccentColor)) {
                    g.FillPath(b, path);
                }
            }

            // Checkmark
            TextRenderer.DrawText(
                g, Theme.IconCheck, Theme.GetIconFont(8f), rect,
                Theme.IsDark ? Color.Black : Color.White,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter
            );
        }

        private class FluentColorTable : ProfessionalColorTable {
            public override Color MenuBorder { get { return Theme.CardBorder; } }
            public override Color MenuItemBorder { get { return Color.Transparent; } }
            public override Color MenuItemSelected { get { return Theme.ControlHover; } }
            public override Color ToolStripDropDownBackground { get { return Theme.CardBackground; } }
            public override Color ImageMarginGradientBegin { get { return Theme.CardBackground; } }
            public override Color ImageMarginGradientMiddle { get { return Theme.CardBackground; } }
            public override Color ImageMarginGradientEnd { get { return Theme.CardBackground; } }
        }
    }
}
