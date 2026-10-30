#!/usr/bin/env python3
"""Rasterize CHoMU branding and copy it into the Godot source tree."""
import os, subprocess, shutil, io
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
G = os.path.join(HERE, "..", "godot")
DARK = (0x17, 0x12, 0x1F, 255)


def rs(svg, w, h=None):
    h = h or w
    data = subprocess.check_output(["rsvg-convert", "-w", str(w), "-h", str(h), os.path.join(OUT, svg)])
    return Image.open(io.BytesIO(data)).convert("RGBA")


def save_webp(im, path):
    im.save(path, "WEBP", lossless=True, quality=100)


# Editor SVG icons
for name in ["Logo.svg", "TitleBarLogo.svg"]:
    shutil.copy(os.path.join(OUT, name), os.path.join(G, "editor/icons", name))
shutil.copy(os.path.join(OUT, "mark.svg"), os.path.join(G, "editor/icons/DefaultProjectIcon.svg"))

# main/ PNGs
rs("mark.svg", 128).save(os.path.join(G, "main/app_icon.png"))
rs("splash_editor.svg", 800, 600).save(os.path.join(G, "main/splash_editor.png"))
# Neutral default boot splash for games: fully transparent (bg color shows through).
Image.new("RGBA", (64, 64), (0, 0, 0, 0)).save(os.path.join(G, "main/splash.png"))

# Android launcher icons (lib module res, shared by editor app)
res = os.path.join(G, "platform/android/java/lib/src/main/res")
dens = {"mipmap-mdpi": (48, 108), "mipmap-hdpi": (72, 162), "mipmap-xhdpi": (96, 216),
        "mipmap-xxhdpi": (144, 324), "mipmap-xxxhdpi": (192, 432), "mipmap": (192, 108)}
for d, (legacy, adaptive) in dens.items():
    p = os.path.join(res, d)
    save_webp(rs("mark.svg", legacy), os.path.join(p, "icon.webp"))
    save_webp(Image.new("RGBA", (adaptive, adaptive), DARK), os.path.join(p, "icon_background.webp"))
    # Foreground: mark centered in the 66/108 safe zone
    fg = Image.new("RGBA", (adaptive, adaptive), (0, 0, 0, 0))
    inner = int(adaptive * 64 / 108)
    m = rs("mark_nobg.svg", inner)
    fg.alpha_composite(m, ((adaptive - inner) // 2, (adaptive - inner) // 2))
    save_webp(fg, os.path.join(p, "icon_foreground.webp"))
    mono = Image.new("RGBA", (adaptive, adaptive), (0, 0, 0, 0))
    mono.alpha_composite(rs("mark_mono.svg", inner), ((adaptive - inner) // 2, (adaptive - inner) // 2))
    save_webp(mono, os.path.join(p, "icon_monochrome.webp"))

# Android 12+ splash icon (432) and branding image (100)
sp = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
sp.alpha_composite(rs("mark_nobg.svg", 260), (86, 86))
save_webp(sp, os.path.join(res, "drawable/splash_icon.webp"))
save_webp(rs("mark.svg", 100), os.path.join(res, "drawable/splash_branding_image.webp"))
print("installed")
