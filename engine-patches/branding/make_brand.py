#!/usr/bin/env python3
"""Generate original CHoMU Engine branding (logo mark + wordmark) as SVG and PNG/WebP.
Mark: bold stylized "C" ring (orange) with a purple offset shadow and purple core dot, on dark.
Text glyphs are converted to SVG paths from Inter Bold (OFL, shipped in Godot thirdparty/fonts).
"""
import io, math, os, sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "godot")
OUT = os.path.join(HERE, "out")
os.makedirs(OUT, exist_ok=True)

ORANGE = "#FF7A18"
ORANGE2 = "#FFA62B"
PURPLE = "#8B3DFF"
DARK = "#17121F"
LIGHT = "#EDE7F6"

FONT = TTFont(os.path.join(SRC, "thirdparty/fonts/Inter_Bold.woff2"))
GS = FONT.getGlyphSet()
CMAP = FONT.getBestCmap()
UPM = FONT["head"].unitsPerEm
HMTX = FONT["hmtx"]


def text_paths(text, x, baseline, size, spacing=0.0):
    """Return list of (char, svg path d) for text at given position/size (px)."""
    s = size / UPM
    out = []
    cx = x
    for ch in text:
        gname = CMAP[ord(ch)]
        pen = SVGPathPen(GS)
        tpen = TransformPen(pen, (s, 0, 0, -s, cx, baseline))
        GS[gname].draw(tpen)
        out.append((ch, pen.getCommands()))
        cx += HMTX[gname][0] * s + spacing * size
    return out, cx - x - spacing * size


def text_width(text, size, spacing=0.0):
    s = size / UPM
    w = sum(HMTX[CMAP[ord(c)]][0] * s for c in text)
    return w + spacing * size * (len(text) - 1)


def c_ring(cx, cy, ro, ri, gap_deg=42):
    """Filled 'C' ring path: annulus with an opening on the right side, rounded ends."""
    a0 = math.radians(gap_deg)
    a1 = math.radians(360 - gap_deg)
    def pt(r, a):
        return cx + r * math.cos(a), cy - r * math.sin(a)
    # SVG y-down: angle measured counterclockwise visually
    p0o = pt(ro, a0); p1o = pt(ro, a1)
    p0i = pt(ri, a0); p1i = pt(ri, a1)
    rc = (ro - ri) / 2
    d = (f"M{p0o[0]:.2f},{p0o[1]:.2f} "
         f"A{ro},{ro} 0 1 0 {p1o[0]:.2f},{p1o[1]:.2f} "
         f"A{rc:.2f},{rc:.2f} 0 0 0 {p1i[0]:.2f},{p1i[1]:.2f} "
         f"A{ri},{ri} 0 1 1 {p0i[0]:.2f},{p0i[1]:.2f} "
         f"A{rc:.2f},{rc:.2f} 0 0 0 {p0o[0]:.2f},{p0o[1]:.2f} Z")
    return d


def mark_group(x, y, size, bg=True, mono=None):
    """The C mark inside a size x size box at (x,y). Returns SVG elements string."""
    s = size / 128.0
    els = []
    if bg:
        els.append(f'<rect x="{x}" y="{y}" width="{size}" height="{size}" rx="{28*s:.2f}" fill="{mono or DARK}"/>')
    cx, cy = x + 62 * s, y + 62 * s
    shadow = c_ring(cx + 6 * s, cy + 6 * s, 46 * s, 25 * s)
    ring = c_ring(cx, cy, 46 * s, 25 * s)
    if mono:
        els.append(f'<path d="{ring}" fill="#fff"/>')
        els.append(f'<circle cx="{cx+4*s:.2f}" cy="{cy:.2f}" r="{10*s:.2f}" fill="#fff"/>')
    else:
        els.append(f'<path d="{shadow}" fill="{PURPLE}"/>')
        els.append(f'<path d="{ring}" fill="{ORANGE}"/>')
        els.append(f'<circle cx="{cx+4*s:.2f}" cy="{cy:.2f}" r="{10*s:.2f}" fill="{PURPLE}"/>')
        els.append(f'<circle cx="{cx+1*s:.2f}" cy="{cy-3*s:.2f}" r="{4*s:.2f}" fill="{ORANGE2}"/>')
    return "\n".join(els)


def wordmark(x, baseline, size, sub=True, sub_color=LIGHT):
    els = []
    paths, w = text_paths("CHoMU", x, baseline, size, spacing=0.01)
    for ch, d in paths:
        col = PURPLE if ch == "o" else ORANGE
        els.append(f'<path d="{d}" fill="{col}"/>')
    total_w = w
    if sub:
        ssize = size * 0.36
        sw = text_width("ENGINE", ssize, spacing=0.32)
        sx = x + (w - sw) / 2
        spaths, _ = text_paths("ENGINE", sx, baseline + ssize * 1.35, ssize, spacing=0.32)
        for ch, d in spaths:
            els.append(f'<path d="{d}" fill="{sub_color}"/>')
    return "\n".join(els), total_w


def svg(w, h, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">\n{body}\n</svg>\n'


def build_svgs():
    files = {}
    # Square mark on dark (project icon / app icon)
    files["mark.svg"] = svg(128, 128, mark_group(0, 0, 128))
    files["mark_nobg.svg"] = svg(128, 128, mark_group(0, 0, 128, bg=False))
    files["mark_mono.svg"] = svg(128, 128, mark_group(0, 0, 128, bg=False, mono="#fff"))
    # Editor Logo.svg (about dialog) 187x69: mark + wordmark, transparent bg
    fs = min(38, 109 / (text_width("CHoMU", 1, 0.01)))
    wm, ww = wordmark(74, 44, fs, sub=True)
    files["Logo.svg"] = svg(187, 69, mark_group(2, 2, 65) + "\n" + wm)
    # TitleBarLogo 100x24
    fs2 = min(19, 72 / text_width("CHoMU", 1, 0.01))
    wm2, ww2 = wordmark(27, 18, fs2, sub=False)
    files["TitleBarLogo.svg"] = svg(100, 24, mark_group(0, 0, 24) + "\n" + wm2)
    # Large logo for splash/preview: 800x600 transparent-ish layout
    wm3, ww3 = wordmark(0, 0, 120, sub=True)
    return files


def render_svg(svg_path, png_path, w, h):
    """Rasterize using the stock Godot binary's ThorVG? Not available headless; use cairosvg if present."""
    import cairosvg
    cairosvg.svg2png(url=svg_path, write_to=png_path, output_width=w, output_height=h)


def big_layout(W, H, bg=DARK, scale=1.0):
    """Mark above wordmark, centered."""
    ms = int(220 * scale)
    tsize = 110 * scale
    tw = text_width("CHoMU", tsize, spacing=0.01)
    body = []
    if bg:
        body.append(f'<rect width="{W}" height="{H}" fill="{bg}"/>')
    mx = (W - ms) / 2
    my = H / 2 - ms / 2 - 80 * scale
    body.append(mark_group(mx, my, ms, bg=False))
    wm, _ = wordmark((W - tw) / 2, my + ms + 115 * scale, tsize, sub=True)
    body.append(wm)
    return svg(W, H, "\n".join(body))


if __name__ == "__main__":
    files = build_svgs()
    files["splash_editor.svg"] = big_layout(800, 600, bg=None, scale=0.85)
    files["preview.svg"] = big_layout(1024, 768, bg=DARK, scale=1.0)
    for name, content in files.items():
        with open(os.path.join(OUT, name), "w") as f:
            f.write(content)
    print("wrote", sorted(files))
