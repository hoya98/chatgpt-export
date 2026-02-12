#!/bin/bash
# Generate app icons for ChatGPT Export macOS app
# Requires: Python 3 with Pillow, OR just uses sips (built into macOS)
#
# Usage: ./generate-icons.sh
#
# This script creates a simple icon with a dark background and green download arrow.
# For a production icon, replace with a professionally designed icon.

set -e

ICON_DIR="ChatGPTExport/Assets.xcassets/AppIcon.appiconset"
SIZES=(16 32 64 128 256 512 1024)

# Check if we have a source icon to resize
if [ -f "icon_source.png" ]; then
    echo "Resizing icon_source.png to all required sizes..."
    for size in "${SIZES[@]}"; do
        sips -z "$size" "$size" "icon_source.png" --out "$ICON_DIR/icon_${size}.png" > /dev/null 2>&1
        echo "  Created icon_${size}.png"
    done
    echo "Done! All icons generated from icon_source.png"
    exit 0
fi

# Generate icons programmatically using Python + Pillow
echo "Generating icons programmatically..."

python3 << 'PYTHON_SCRIPT'
import sys
try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Pillow not installed. Generating placeholder icons with sips instead.")
    sys.exit(1)

import os

icon_dir = "ChatGPTExport/Assets.xcassets/AppIcon.appiconset"
sizes = [16, 32, 64, 128, 256, 512, 1024]

def create_icon(size):
    """Create an icon at the given size."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background: rounded rectangle with dark color #1a1a2e
    bg_color = (26, 26, 46, 255)
    # Draw full background (rounded corners handled by macOS)
    draw.rectangle([0, 0, size-1, size-1], fill=bg_color)

    # Draw a green download arrow icon
    center_x = size // 2
    center_y = size // 2
    scale = size / 1024.0

    # Arrow color: #10b981
    arrow_color = (16, 185, 129, 255)

    # Arrow shaft
    shaft_width = int(80 * scale)
    shaft_top = int(200 * scale)
    shaft_bottom = int(600 * scale)
    draw.rectangle([
        center_x - shaft_width//2, shaft_top,
        center_x + shaft_width//2, shaft_bottom
    ], fill=arrow_color)

    # Arrow head (triangle pointing down)
    head_width = int(300 * scale)
    head_top = int(500 * scale)
    head_bottom = int(700 * scale)
    draw.polygon([
        (center_x - head_width//2, head_top),
        (center_x + head_width//2, head_top),
        (center_x, head_bottom)
    ], fill=arrow_color)

    # Base line
    line_y = int(780 * scale)
    line_width = int(400 * scale)
    line_height = int(60 * scale)
    draw.rectangle([
        center_x - line_width//2, line_y,
        center_x + line_width//2, line_y + line_height
    ], fill=arrow_color)

    # Document outline (subtle)
    doc_color = (96, 165, 250, 180)  # #60a5fa with some transparency
    doc_width = int(500 * scale)
    doc_height = int(650 * scale)
    doc_left = center_x - doc_width//2
    doc_top = int(180 * scale)
    line_w = max(int(8 * scale), 1)

    # Just draw the document outline border
    # Top
    draw.rectangle([doc_left, doc_top, doc_left + doc_width, doc_top + line_w], fill=doc_color)
    # Bottom
    draw.rectangle([doc_left, doc_top + doc_height - line_w, doc_left + doc_width, doc_top + doc_height], fill=doc_color)
    # Left
    draw.rectangle([doc_left, doc_top, doc_left + line_w, doc_top + doc_height], fill=doc_color)
    # Right
    draw.rectangle([doc_left + doc_width - line_w, doc_top, doc_left + doc_width, doc_top + doc_height], fill=doc_color)

    return img

for s in sizes:
    icon = create_icon(s)
    path = os.path.join(icon_dir, f"icon_{s}.png")
    icon.save(path)
    print(f"  Created icon_{s}.png ({s}x{s})")

print("Done! All icons generated.")
PYTHON_SCRIPT

# If Python/Pillow failed, create simple placeholder icons
if [ $? -ne 0 ]; then
    echo "Creating placeholder icons using sips..."

    # Create a simple 1024x1024 PNG using built-in tools
    # Use a temporary tiff created by Python without Pillow
    python3 << 'FALLBACK_SCRIPT'
import struct, zlib, os

icon_dir = "ChatGPTExport/Assets.xcassets/AppIcon.appiconset"
sizes = [16, 32, 64, 128, 256, 512, 1024]

def create_png(width, height, bg_r, bg_g, bg_b):
    """Create a minimal valid PNG with solid color."""
    def chunk(chunk_type, data):
        c = chunk_type + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)

    header = b'\x89PNG\r\n\x1a\n'
    ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))

    raw_data = b''
    row = bytes([bg_r, bg_g, bg_b] * width)
    for y in range(height):
        raw_data += b'\x00' + row

    idat = chunk(b'IDAT', zlib.compress(raw_data))
    iend = chunk(b'IEND', b'')

    return header + ihdr + idat + iend

for s in sizes:
    png_data = create_png(s, s, 26, 26, 46)  # #1a1a2e background
    path = os.path.join(icon_dir, f"icon_{s}.png")
    with open(path, 'wb') as f:
        f.write(png_data)
    print(f"  Created placeholder icon_{s}.png ({s}x{s})")

print("Placeholder icons created. Replace with proper designs for App Store submission.")
FALLBACK_SCRIPT
fi

echo ""
echo "Icon generation complete."
echo "For a production-quality icon, create a 1024x1024 PNG and save it as icon_source.png,"
echo "then re-run this script to resize it to all required sizes."
