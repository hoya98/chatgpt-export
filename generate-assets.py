#!/usr/bin/env python3
"""Generate all icons and store assets for ChatGPT Export."""

from PIL import Image, ImageDraw, ImageFont
import math
import os

OUT = "/Users/marc/Projects/chatgpt-export"

# Colors
BG_DARK = (26, 26, 46)        # #1a1a2e
BG_MID = (22, 33, 62)         # #16213e
GREEN = (16, 185, 129)        # #10b981
GREEN_DARK = (5, 150, 105)    # #0596693
WHITE = (255, 255, 255)
GRAY = (156, 163, 175)        # #9ca3af
LIGHT_GRAY = (209, 213, 219)

# Font helpers
def get_font(size, bold=False):
    if bold:
        try:
            return ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", size)
        except:
            return ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", size)
    try:
        return ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", size)
    except:
        return ImageFont.load_default()


def draw_rounded_rect(draw, bbox, radius, fill):
    """Draw a rounded rectangle."""
    x0, y0, x1, y1 = bbox
    draw.rectangle([x0 + radius, y0, x1 - radius, y1], fill=fill)
    draw.rectangle([x0, y0 + radius, x1, y1 - radius], fill=fill)
    draw.pieslice([x0, y0, x0 + 2*radius, y0 + 2*radius], 180, 270, fill=fill)
    draw.pieslice([x1 - 2*radius, y0, x1, y0 + 2*radius], 270, 360, fill=fill)
    draw.pieslice([x0, y1 - 2*radius, x0 + 2*radius, y1], 90, 180, fill=fill)
    draw.pieslice([x1 - 2*radius, y1 - 2*radius, x1, y1], 0, 90, fill=fill)


def draw_icon(size, padding_ratio=0.12):
    """Draw the app icon at given size."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    pad = int(size * padding_ratio)
    cx, cy = size // 2, size // 2
    r = (size - 2 * pad) // 2

    # Green circle
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=GREEN)

    # Download arrow
    arrow_w = int(r * 0.55)
    arrow_h = int(r * 0.4)
    shaft_w = int(r * 0.22)
    head_extra = int(r * 0.18)

    # Arrow shaft
    shaft_top = cy - int(r * 0.35)
    shaft_bottom = cy + int(r * 0.05)
    draw.rectangle([
        cx - shaft_w, shaft_top,
        cx + shaft_w, shaft_bottom
    ], fill=WHITE)

    # Arrow head (triangle pointing down)
    head_top = shaft_bottom - int(r * 0.05)
    head_bottom = cy + int(r * 0.35)
    draw.polygon([
        (cx - arrow_w, head_top),
        (cx + arrow_w, head_top),
        (cx, head_bottom)
    ], fill=WHITE)

    # Tray/base line
    tray_y = cy + int(r * 0.5)
    tray_w = int(r * 0.5)
    line_w = max(2, int(r * 0.06))
    draw.rectangle([
        cx - tray_w, tray_y - line_w,
        cx + tray_w, tray_y + line_w
    ], fill=WHITE)
    # Tray sides
    tray_h = int(r * 0.15)
    draw.rectangle([
        cx - tray_w, tray_y - tray_h,
        cx - tray_w + line_w * 2, tray_y + line_w
    ], fill=WHITE)
    draw.rectangle([
        cx + tray_w - line_w * 2, tray_y - tray_h,
        cx + tray_w, tray_y + line_w
    ], fill=WHITE)

    return img


# ── 1. Extension Icons ──────────────────────────────────────────────
print("Generating extension icons...")
icon_dir = os.path.join(OUT, "extension", "icons")
for size in [16, 48, 128]:
    icon = draw_icon(size, padding_ratio=0.08)
    icon.save(os.path.join(icon_dir, f"icon{size}.png"))
    print(f"  icon{size}.png")

# ── 2. macOS App Icons ──────────────────────────────────────────────
print("Generating macOS app icons...")
mac_icon_dir = os.path.join(OUT, "macos-app", "ChatGPTExport", "Assets.xcassets", "AppIcon.appiconset")
for size in [16, 32, 64, 128, 256, 512, 1024]:
    icon = draw_icon(size, padding_ratio=0.1)
    icon.save(os.path.join(mac_icon_dir, f"icon_{size}x{size}.png"))
    print(f"  icon_{size}x{size}.png")

# ── 3. Marquee (1280x800) ───────────────────────────────────────────
print("Generating marquee...")
img = Image.new("RGB", (1280, 800), BG_DARK)
draw = ImageDraw.Draw(img)

# Top accent bar
draw.rectangle([0, 0, 1280, 6], fill=GREEN)

# Icon on the left
icon_large = draw_icon(280, padding_ratio=0.05)
img.paste(icon_large, (100, 200), icon_large)

# Text on the right
text_x = 460
title_font = get_font(64, bold=True)
sub_font = get_font(34)
bullet_font = get_font(28)

draw.text((text_x, 200), "ChatGPT Export", fill=WHITE, font=title_font)
draw.text((text_x, 285), "Bulk export all your conversations", fill=GRAY, font=sub_font)

bullets = [
    "Export all conversations with one click",
    "Works with Team & Business workspaces",
    "Downloads file attachments",
    "No API key needed",
    "GDPR data portability",
]
y = 370
for b in bullets:
    # Green bullet dot
    draw.ellipse([text_x, y + 8, text_x + 14, y + 22], fill=GREEN)
    draw.text((text_x + 28, y), b, fill=LIGHT_GRAY, font=bullet_font)
    y += 50

# Bottom accent
draw.rectangle([0, 794, 1280, 800], fill=GREEN)

img.save(os.path.join(OUT, "store-assets", "marquee-1280x800.png"))
print("  marquee-1280x800.png")

# ── 4. Promo Tile (440x280) ─────────────────────────────────────────
print("Generating promo tile...")
img = Image.new("RGB", (440, 280), BG_DARK)
draw = ImageDraw.Draw(img)

# Top accent
draw.rectangle([0, 0, 440, 4], fill=GREEN)

# Icon
icon_small = draw_icon(100, padding_ratio=0.05)
img.paste(icon_small, (30, 50), icon_small)

# Text
title_font_sm = get_font(30, bold=True)
sub_font_sm = get_font(16)
bullet_font_sm = get_font(14)

text_x = 150
draw.text((text_x, 50), "ChatGPT", fill=WHITE, font=title_font_sm)
draw.text((text_x, 88), "Export", fill=WHITE, font=title_font_sm)

draw.text((text_x, 130), "Bulk conversation exporter", fill=GRAY, font=sub_font_sm)

bullets_sm = [
    "One-click export",
    "Team & Business workspaces",
    "File attachments included",
]
y = 165
for b in bullets_sm:
    draw.ellipse([text_x, y + 4, text_x + 8, y + 12], fill=GREEN)
    draw.text((text_x + 16, y), b, fill=LIGHT_GRAY, font=bullet_font_sm)
    y += 28

# Bottom accent
draw.rectangle([0, 276, 440, 280], fill=GREEN)

img.save(os.path.join(OUT, "store-assets", "promo-440x280.png"))
print("  promo-440x280.png")

# ── 5. Screenshot (1280x800) ────────────────────────────────────────
print("Generating screenshot...")
img = Image.new("RGB", (1280, 800), (52, 53, 65))  # ChatGPT-ish background
draw = ImageDraw.Draw(img)

# Fake ChatGPT sidebar
draw.rectangle([0, 0, 260, 800], fill=(32, 33, 35))
sidebar_font = get_font(14)
draw.text((20, 20), "ChatGPT", fill=WHITE, font=get_font(18, bold=True))

chats = ["Solar panel pricing analysis", "Token issuance strategy", "Panama import logistics",
         "Mining hardware comparison", "ERCOT market analysis", "El Salvador CNAD docs",
         "Fundraising deck review", "Ohio facility planning"]
y = 70
for c in chats:
    draw_rounded_rect(draw, [10, y, 250, y + 36], 6, (64, 65, 79))
    draw.text((20, y + 8), c, fill=LIGHT_GRAY, font=sidebar_font)
    y += 44

# Main area - ChatGPT-like
draw.text((300, 300), "What can I help with?", fill=(140, 140, 150), font=get_font(36))

# Extension popup overlay
popup_x, popup_y = 420, 80
popup_w, popup_h = 380, 520

# Popup shadow
for i in range(20):
    alpha_color = (0, 0, 0)
    draw_rounded_rect(draw, [popup_x - 10 + i//3, popup_y - 10 + i//3,
                             popup_x + popup_w + 10 - i//3, popup_y + popup_h + 10 - i//3],
                     12, (20 + i, 20 + i, 30 + i))

# Popup background
draw_rounded_rect(draw, [popup_x, popup_y, popup_x + popup_w, popup_y + popup_h], 10, BG_MID)

# Popup top accent
draw.rectangle([popup_x, popup_y, popup_x + popup_w, popup_y + 4], fill=GREEN)

# Popup header
header_font = get_font(22, bold=True)
draw.text((popup_x + 20, popup_y + 20), "ChatGPT Export", fill=WHITE, font=header_font)
draw.text((popup_x + 20, popup_y + 48), "Bulk export all conversations", fill=GRAY, font=get_font(13))

# Status card
status_y = popup_y + 85
draw_rounded_rect(draw, [popup_x + 15, status_y, popup_x + popup_w - 15, status_y + 55], 8, (30, 40, 70))
draw.text((popup_x + 25, status_y + 5), "STATUS", fill=GRAY, font=get_font(11))
draw.text((popup_x + 25, status_y + 22), "Exporting...", fill=GREEN, font=get_font(18, bold=True))

# Stats grid
stats_y = status_y + 70
box_w = (popup_w - 50) // 2

# Conversations box
draw_rounded_rect(draw, [popup_x + 15, stats_y, popup_x + 15 + box_w, stats_y + 70], 8, (30, 40, 70))
draw.text((popup_x + 30, stats_y + 8), "783", fill=WHITE, font=get_font(32, bold=True))
draw.text((popup_x + 30, stats_y + 48), "Conversations", fill=GRAY, font=get_font(12))

# Attachments box
draw_rounded_rect(draw, [popup_x + 25 + box_w, stats_y, popup_x + popup_w - 15, stats_y + 70], 8, (30, 40, 70))
draw.text((popup_x + 35 + box_w, stats_y + 8), "1,012", fill=WHITE, font=get_font(32, bold=True))
draw.text((popup_x + 35 + box_w, stats_y + 48), "Attachments", fill=GRAY, font=get_font(12))

# Progress bar
prog_y = stats_y + 90
draw_rounded_rect(draw, [popup_x + 15, prog_y, popup_x + popup_w - 15, prog_y + 12], 6, (30, 40, 70))
progress_width = int((popup_w - 50) * 0.65)
draw_rounded_rect(draw, [popup_x + 15, prog_y, popup_x + 15 + progress_width, prog_y + 12], 6, GREEN)
draw.text((popup_x + 140, prog_y + 18), "509 / 783", fill=GRAY, font=get_font(12))

# Options
opt_y = prog_y + 50
draw.text((popup_x + 20, opt_y), "Options", fill=GRAY, font=get_font(12))

# Checkbox 1 - checked
cb_y = opt_y + 22
draw_rounded_rect(draw, [popup_x + 20, cb_y, popup_x + 38, cb_y + 18], 3, GREEN)
draw.text((popup_x + 23, cb_y - 1), "✓", fill=WHITE, font=get_font(14, bold=True))
draw.text((popup_x + 45, cb_y + 1), "Download file attachments", fill=LIGHT_GRAY, font=get_font(13))

# Checkbox 2 - unchecked
cb_y2 = cb_y + 28
draw_rounded_rect(draw, [popup_x + 20, cb_y2, popup_x + 38, cb_y2 + 18], 3, (50, 60, 90))
draw.text((popup_x + 45, cb_y2 + 1), "Include archived conversations", fill=LIGHT_GRAY, font=get_font(13))

# Export button
btn_y = cb_y2 + 45
draw_rounded_rect(draw, [popup_x + 15, btn_y, popup_x + popup_w - 15, btn_y + 48], 8, GREEN)
btn_text = "Export All Conversations"
btn_font = get_font(17, bold=True)
bbox = draw.textbbox((0, 0), btn_text, font=btn_font)
tw = bbox[2] - bbox[0]
draw.text((popup_x + (popup_w - tw) // 2, btn_y + 13), btn_text, fill=WHITE, font=btn_font)

# Log area
log_y = btn_y + 65
draw.text((popup_x + 20, log_y), "Activity Log", fill=GRAY, font=get_font(12))
draw_rounded_rect(draw, [popup_x + 15, log_y + 20, popup_x + popup_w - 15, log_y + 90], 6, (20, 25, 45))
log_font = get_font(10)
logs = [
    "Fetching conversations page 6/8...",
    "Downloaded: Token issuance strategy",
    "Downloaded: Solar panel pricing",
    "Downloaded: Mining hardware comparison",
]
ly = log_y + 26
for l in logs:
    draw.text((popup_x + 22, ly), l, fill=(120, 130, 150), font=log_font)
    ly += 15

img.save(os.path.join(OUT, "store-assets", "screenshot-1280x800.png"))
print("  screenshot-1280x800.png")

print("\nAll assets generated!")
