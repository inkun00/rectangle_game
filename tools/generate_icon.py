import os
from PIL import Image, ImageDraw, ImageFilter

def create_triangle_art_icon(size=256):
    scale = 4
    img_size = size * scale
    img = Image.new("RGBA", (img_size, img_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Rounded rectangle background
    bg_color = (11, 17, 30, 255) # #0b111e
    border_color = (56, 189, 248, 120) # #38bdf8
    radius = int(img_size * 0.22)
    padding = int(img_size * 0.04)

    # Draw rounded background
    draw.rounded_rectangle(
        [padding, padding, img_size - padding, img_size - padding],
        radius=radius,
        fill=bg_color,
        outline=border_color,
        width=int(scale * 3)
    )

    # Draw nested triangles
    cx = img_size / 2.0
    cy = img_size / 2.0 + (img_size * 0.04)

    # Outer triangle (Cyan)
    r_outer = img_size * 0.36
    p1_out = (cx, cy - r_outer)
    p2_out = (cx + r_outer * 0.866, cy + r_outer * 0.5)
    p3_out = (cx - r_outer * 0.866, cy + r_outer * 0.5)
    draw.polygon([p1_out, p2_out, p3_out], fill=(6, 182, 212, 35), outline=(6, 182, 212, 255), width=int(scale * 4))

    # Middle triangle (Violet/Indigo)
    r_mid = img_size * 0.26
    p1_mid = (cx, cy - r_mid)
    p2_mid = (cx + r_mid * 0.866, cy + r_mid * 0.5)
    p3_mid = (cx - r_mid * 0.866, cy + r_mid * 0.5)
    draw.polygon([p1_mid, p2_mid, p3_mid], fill=(129, 140, 248, 60), outline=(168, 85, 247, 255), width=int(scale * 3))

    # Inner triangle (Gold/Amber)
    r_in = img_size * 0.15
    p1_in = (cx, cy - r_in)
    p2_in = (cx + r_in * 0.866, cy + r_in * 0.5)
    p3_in = (cx - r_in * 0.866, cy + r_in * 0.5)
    draw.polygon([p1_in, p2_in, p3_in], fill=(245, 158, 11, 140), outline=(251, 191, 36, 255), width=int(scale * 3))

    # Draw vertex dots on outer triangle
    dot_r = int(scale * 6)
    for px, py in [p1_out, p2_out, p3_out]:
        draw.ellipse([px - dot_r, py - dot_r, px + dot_r, py + dot_r], fill=(56, 189, 248, 255))

    # Downsample for crisp anti-aliasing
    final_img = img.resize((size, size), Image.Resampling.LANCZOS)
    return final_img

if __name__ == "__main__":
    os.makedirs("assets/icons", exist_ok=True)
    icon_256 = create_triangle_art_icon(256)
    icon_256.save("assets/icons/icon.png", optimize=True, compress_level=9)

    # Also save direct icons in build/web
    os.makedirs("build/web", exist_ok=True)
    icon_256.save("build/web/index.icon.png", optimize=True, compress_level=9)
    icon_256.resize((180, 180), Image.Resampling.LANCZOS).save(
        "build/web/index.apple-touch-icon.png", optimize=True, compress_level=9
    )
    print("Triangle Art icons generated successfully!")
