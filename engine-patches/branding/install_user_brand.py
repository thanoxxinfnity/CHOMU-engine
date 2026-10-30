#!/usr/bin/env python3
"""Install the user's CHoMU Engine logo (from /workspace/work/chomu-brand) into the Godot source tree.
SVG editor icons are produced by tracing (potrace) the white artwork into vector paths.
"""
import io, os, re, subprocess, shutil, tempfile
from PIL import Image

BRAND = "/workspace/work/chomu-brand"
HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.join(HERE, "..", "godot")
OUT = os.path.join(HERE, "out_user")
os.makedirs(OUT, exist_ok=True)
BG = (0x26, 0x29, 0x2F, 255)
BGHEX = "#26292F"

icon = Image.open(f"{BRAND}/icon_1024.png").convert("RGBA")
white = Image.open(f"{BRAND}/icon_white_transparent.png").convert("RGBA")
splash = Image.open(f"{BRAND}/splash_full.png").convert("RGBA")


def trace(mask_img):
    """mask_img: L image, white(255)=shape. Returns (svg path d list, width, height) in pixel units."""
    w, h = mask_img.size
    bw = mask_img.point(lambda v: 0 if v > 127 else 255).convert("1")  # potrace traces black
    with tempfile.TemporaryDirectory() as td:
        p = os.path.join(td, "in.pbm")
        bw.save(p)
        svg = subprocess.check_output(["potrace", p, "-s", "-o", "-", "--flat", "-t", "4", "-O", "0.4"]).decode()
    # potrace output: <g transform="translate(0,H) scale(0.1,-0.1)"> <path d=.../>
    tr = re.search(r'<g transform="([^"]+)"', svg).group(1)
    paths = re.findall(r'<path d="([^"]+)"', svg, re.S)
    return tr, [" ".join(d.split()) for d in paths], w, h


def bbox_crop(img_l, pad=0):
    bb = img_l.point(lambda v: 255 if v > 127 else 0).getbbox()
    x0, y0, x1, y1 = bb
    return img_l.crop((max(0, x0 - pad), max(0, y0 - pad), x1 + pad, y1 + pad))


def traced_group(img_l, fill, box_x, box_y, box_w, box_h):
    """Trace img_l and fit it centered into the given box. Returns SVG <g> string."""
    tr, paths, w, h = trace(img_l)
    s = min(box_w / w, box_h / h)
    ox = box_x + (box_w - w * s) / 2
    oy = box_y + (box_h - h * s) / 2
    d = " ".join(paths)
    return (f'<g transform="translate({ox:.3f},{oy:.3f}) scale({s:.5f})">'
            f'<g transform="{tr}"><path fill="{fill}" d="{d}"/></g></g>')


def svg(w, h, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>\n'


# Masks
mark_mask = bbox_crop(white.getchannel("A"), pad=4)
splash_l = splash.convert("L")
splash_mask = bbox_crop(splash_l.point(lambda v: 255 if v > 140 else 0), pad=6)
# Downscale big masks a bit for smaller SVG output while keeping detail.
def shrink(m, maxw):
    if m.width > maxw:
        m = m.resize((maxw, round(m.height * maxw / m.width)), Image.LANCZOS)
    return m
mark_mask_s = shrink(mark_mask, 512)
splash_mask_s = shrink(splash_mask, 900)

files = {}
# Default project icon (128): white mark on dark rounded square
files["DefaultProjectIcon.svg"] = svg(128, 128,
    f'<rect x="2" y="2" width="124" height="124" rx="14" fill="{BGHEX}"/>' + traced_group(mark_mask_s, "#fff", 14, 14, 100, 100))
# About dialog logo (187x69): full gear + wordmark lockup, white
files["Logo.svg"] = svg(187, 69, traced_group(splash_mask_s, "#fff", 1, 1, 185, 67))
# Title bar logo (100x24)
files["TitleBarLogo.svg"] = svg(100, 24, traced_group(splash_mask_s, "#e0e0e0", 0, 0, 100, 24))
for n, c in files.items():
    open(os.path.join(OUT, n), "w").write(c)
    shutil.copy(os.path.join(OUT, n), os.path.join(G, "editor/icons", n))

# main/ PNGs (embedded in libgodot at compile time)
icon.resize((128, 128), Image.LANCZOS).save(os.path.join(G, "main/app_icon.png"))
splash.convert("RGB").save(os.path.join(G, "main/splash.png"), optimize=True)
splash.convert("RGB").save(os.path.join(G, "main/splash_editor.png"), optimize=True)

# Splash background colour #26292F in both generated splash headers.
mb = os.path.join(G, "main/main_builders.py")
s = open(mb).read()
col = "Color(0.149, 0.161, 0.184)"  # #26292F
s = s.replace("boot_splash_bg_color = Color(0.14, 0.14, 0.14)", f"boot_splash_bg_color = {col}")
s = s.replace("boot_splash_editor_bg_color = Color(0.125, 0.145, 0.192)", f"boot_splash_editor_bg_color = {col}")
open(mb, "w").write(s)


def save_webp(im, path):
    im.save(path, "WEBP", lossless=True, quality=100)


def fit_white(size, frac):
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = round(size * frac)
    m = white.resize((inner, inner), Image.LANCZOS)
    canvas.alpha_composite(m, ((size - inner) // 2, (size - inner) // 2))
    return canvas

res = os.path.join(G, "platform/android/java/lib/src/main/res")
dens = {"mipmap-mdpi": (48, 108), "mipmap-hdpi": (72, 162), "mipmap-xhdpi": (96, 216),
        "mipmap-xxhdpi": (144, 324), "mipmap-xxxhdpi": (192, 432), "mipmap": (192, 108)}
for d, (legacy, adaptive) in dens.items():
    p = os.path.join(res, d)
    save_webp(icon.resize((legacy, legacy), Image.LANCZOS), os.path.join(p, "icon.webp"))
    save_webp(Image.new("RGBA", (adaptive, adaptive), BG), os.path.join(p, "icon_background.webp"))
    # Adaptive foreground: keep artwork within the 66dp safe zone (of 108dp).
    save_webp(fit_white(adaptive, 0.60), os.path.join(p, "icon_foreground.webp"))
    save_webp(fit_white(adaptive, 0.60), os.path.join(p, "icon_monochrome.webp"))
# Android 12+ splash icon (432px, content must fit inside the 2/3 circle) and branding image.
save_webp(fit_white(432, 0.58), os.path.join(res, "drawable/splash_icon.webp"))
save_webp(icon.resize((100, 100), Image.LANCZOS), os.path.join(res, "drawable/splash_branding_image.webp"))

# Preview
splash.convert("RGB").resize((1000, 558), Image.LANCZOS).save("/workspace/work/chomu_logo.png")
print("installed user brand")
