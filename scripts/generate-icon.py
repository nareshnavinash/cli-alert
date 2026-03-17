#!/usr/bin/env python3
"""Generate the shelldone radar-ping icon at all required .iconset sizes.

Design: Dark rounded-square background with an off-center dot and radiating
concentric arcs that fade from bright cyan to transparent — like a freeze-frame
of a sonar pulse mid-broadcast. Motion blur on the rings implies animation.

Requirements: Pillow (pip install Pillow)
"""

import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

# Sizes required for macOS .iconset
ICONSET_SIZES = [16, 32, 128, 256, 512]

# Colors
BG_COLOR = (30, 30, 40)          # Dark blue-gray background
DOT_COLOR = (0, 230, 255)        # Bright cyan dot
RING_BASE = (0, 200, 240)        # Cyan ring color (will fade)
GLOW_COLOR = (0, 180, 220, 60)   # Subtle glow around dot


def draw_icon(size):
    """Render the radar-ping icon at the given pixel size."""
    # Work at 4x for antialiasing, then downscale
    scale = max(4, 512 // size) if size < 128 else 2
    s = size * scale
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Rounded-square background
    corner = int(s * 0.22)
    draw.rounded_rectangle([0, 0, s - 1, s - 1], radius=corner, fill=BG_COLOR)

    # Center of the radar pulse (slightly off-center, lower-left)
    cx = int(s * 0.38)
    cy = int(s * 0.62)

    # Draw concentric arc rings (radiating outward, fading)
    num_rings = 5
    max_radius = int(s * 0.55)
    min_radius = int(s * 0.12)

    for i in range(num_rings):
        t = i / max(num_rings - 1, 1)
        radius = int(min_radius + (max_radius - min_radius) * t)
        alpha = int(200 * (1.0 - t * 0.8))  # Fade outward
        ring_width = max(2, int(s * 0.018 * (1.0 + t * 0.5)))

        # Draw arc (upper-right quadrant, ~135 degrees)
        r, g, b = RING_BASE
        arc_color = (r, g, b, alpha)

        # Create a temporary image for this arc with transparency
        arc_img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        arc_draw = ImageDraw.Draw(arc_img)

        bbox = [cx - radius, cy - radius, cx + radius, cy + radius]
        arc_draw.arc(bbox, start=-135, end=10, fill=arc_color, width=ring_width)

        # Apply slight blur to outer rings for motion-blur effect
        if t > 0.3:
            blur_radius = max(1, int(s * 0.005 * t))
            arc_img = arc_img.filter(ImageFilter.GaussianBlur(radius=blur_radius))

        img = Image.alpha_composite(img, arc_img)

    # Glow behind the dot
    glow_img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_img)
    glow_r = int(s * 0.08)
    glow_draw.ellipse(
        [cx - glow_r, cy - glow_r, cx + glow_r, cy + glow_r],
        fill=GLOW_COLOR,
    )
    glow_img = glow_img.filter(ImageFilter.GaussianBlur(radius=int(s * 0.04)))
    img = Image.alpha_composite(img, glow_img)

    # Central dot
    dot_r = int(s * 0.04)
    dot_img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    dot_draw = ImageDraw.Draw(dot_img)
    dot_draw.ellipse(
        [cx - dot_r, cy - dot_r, cx + dot_r, cy + dot_r],
        fill=DOT_COLOR,
    )
    img = Image.alpha_composite(img, dot_img)

    # Downscale with high-quality resampling
    img = img.resize((size, size), Image.LANCZOS)
    return img


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)

    iconset_dir = os.path.join(
        project_dir, "assets", "darwin", "shelldone.app",
        "Contents", "Resources", "AppIcon.iconset",
    )
    linux_dir = os.path.join(project_dir, "assets", "linux")

    os.makedirs(iconset_dir, exist_ok=True)
    os.makedirs(linux_dir, exist_ok=True)

    # Generate .iconset images
    for size in ICONSET_SIZES:
        # @1x
        icon = draw_icon(size)
        icon.save(os.path.join(iconset_dir, f"icon_{size}x{size}.png"))
        print(f"  icon_{size}x{size}.png")

        # @2x (double resolution)
        icon2x = draw_icon(size * 2)
        icon2x.save(os.path.join(iconset_dir, f"icon_{size}x{size}@2x.png"))
        print(f"  icon_{size}x{size}@2x.png")

    # Linux icon (256px)
    linux_icon = draw_icon(256)
    linux_icon.save(os.path.join(linux_dir, "shelldone.png"))
    print(f"  assets/linux/shelldone.png")

    print(f"\nIconset at: {iconset_dir}")
    return iconset_dir


if __name__ == "__main__":
    iconset_dir = main()

    # On macOS, convert to .icns
    if sys.platform == "darwin":
        import subprocess

        icns_path = iconset_dir.replace(".iconset", ".icns")
        try:
            subprocess.run(
                ["iconutil", "-c", "icns", iconset_dir, "-o", icns_path],
                check=True,
            )
            print(f"AppIcon.icns created at: {icns_path}")
        except (subprocess.CalledProcessError, FileNotFoundError) as e:
            print(f"Warning: iconutil failed ({e}), .iconset kept for manual conversion")
