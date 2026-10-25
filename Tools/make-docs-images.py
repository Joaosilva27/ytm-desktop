#!/usr/bin/env python3
"""Generate the artwork used by the README and the release page.

    python3 Tools/make-docs-images.py

Writes:
    Resources/dmg-background.png          Finder backdrop for the .dmg
    docs/screenshots/download-button.png  README download banner
    docs/screenshots/install-download.png Install step 1
    docs/screenshots/install-drag.png     Install step 2
    docs/screenshots/install-open.png     Install step 3

Requires Pillow (pip install pillow). Inter is used when it is available;
otherwise the script falls back to whatever sans font it can find.
"""

import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOTS = os.path.join(ROOT, "docs", "screenshots")

INK = (29, 29, 31)
INK_SOFT = (75, 75, 80)
MUTED = (138, 138, 145)
HAIRLINE = (226, 226, 231)
ACCENT = (241, 25, 52)
VERSION = "1.0.0"

FONT_DIRS = [
    os.path.join(ROOT, "build", "fonts", "extras", "ttf"),
    "/Library/Fonts",
    "/System/Library/Fonts",
    "/usr/share/fonts/truetype/inter",
]
FONT_FALLBACKS = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/opt/freestyle/python/lib/python3.12/site-packages/matplotlib/mpl-data/fonts/ttf/DejaVuSans.ttf",
]
WEIGHTS = {"Regular": "Inter-Regular", "Medium": "Inter-Medium", "SemiBold": "Inter-SemiBold", "Bold": "Inter-Bold"}

_fonts = {}


def font(size, weight="Regular"):
    key = (size, weight)
    if key in _fonts:
        return _fonts[key]
    path = None
    for directory in FONT_DIRS:
        candidate = os.path.join(directory, WEIGHTS[weight] + ".ttf")
        if os.path.exists(candidate):
            path = candidate
            break
    if path is None:
        for candidate in FONT_FALLBACKS:
            if os.path.exists(candidate):
                path = candidate
                break
    if path is None:
        raise SystemExit("No usable font found; put Inter-Regular.ttf in build/fonts/extras/ttf")
    _fonts[key] = ImageFont.truetype(path, size)
    return _fonts[key]


def app_icon(size):
    icon = Image.open(os.path.join(ROOT, "Resources", "AppIcon.icns")).convert("RGBA")
    return icon.resize((size, size), Image.LANCZOS)


def vertical_gradient(size, top, bottom):
    width, height = size
    strip = Image.new("RGB", (1, height))
    for y in range(height):
        t = y / max(height - 1, 1)
        strip.putpixel((0, y), tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return strip.resize((width, height), Image.BILINEAR)


def gradient_card(canvas, box, radius, top, bottom, border=None):
    width = box[2] - box[0]
    height = box[3] - box[1]
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, width - 1, height - 1], radius, fill=255)
    layer = vertical_gradient((width, height), top, bottom).convert("RGBA")
    layer.putalpha(mask)
    if border:
        ImageDraw.Draw(layer).rounded_rectangle(
            [0, 0, width - 1, height - 1], radius, outline=border, width=1
        )
    canvas.alpha_composite(layer, (box[0], box[1]))
    return layer


def shadow(canvas, box, radius, blur=16, dy=8, opacity=48):
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(
        [box[0], box[1] + dy, box[2], box[3] + dy], radius, fill=(0, 0, 0, opacity)
    )
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def wrap(draw, text, face, width):
    lines, line = [], ""
    for word in text.split():
        candidate = (line + " " + word).strip()
        if draw.textlength(candidate, font=face) <= width or not line:
            line = candidate
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def paragraph(draw, xy, text, face, fill, width, leading):
    x, y = xy
    for line in wrap(draw, text, face, width):
        draw.text((x, y), line, font=face, fill=fill)
        y += leading
    return y


def draw_arrow(draw, x0, x1, y, colour, thickness, head):
    draw.line([(x0, y), (x1 - head * 0.6, y)], fill=colour, width=thickness)
    draw.polygon(
        [(x1, y), (x1 - head, y - head * 0.62), (x1 - head, y + head * 0.62)], fill=colour
    )


def download_glyph(draw, box, colour):
    x, y, size = box
    stem = size * 0.52
    draw.rounded_rectangle(
        [x + size / 2 - size * 0.06, y, x + size / 2 + size * 0.06, y + stem],
        size * 0.05,
        fill=colour,
    )
    draw.polygon(
        [
            (x + size * 0.5, y + size),
            (x + size * 0.5 - size * 0.19, y + stem * 1.02),
            (x + size * 0.5 + size * 0.19, y + stem * 1.02),
        ],
        fill=colour,
    )
    draw.rounded_rectangle(
        [x + size * 0.16, y + size * 0.92, x + size * 0.84, y + size],
        size * 0.04,
        fill=colour,
    )


def folder_icon(size):
    """A flat rendition of the macOS Applications folder."""
    scale = 4
    pixels = size * scale
    mask = Image.new("L", (pixels, pixels), 0)
    draw = ImageDraw.Draw(mask)
    radius = pixels * 0.085
    draw.rounded_rectangle(
        [pixels * 0.06, pixels * 0.17, pixels * 0.45, pixels * 0.44], radius, fill=255
    )
    draw.rounded_rectangle(
        [pixels * 0.06, pixels * 0.28, pixels * 0.94, pixels * 0.87], radius, fill=255
    )
    image = vertical_gradient((pixels, pixels), (130, 197, 247), (48, 132, 210)).convert("RGBA")
    image.putalpha(mask)
    return image.resize((size, size), Image.LANCZOS)


def dmg_backdrop(width, height, scale=1.0):
    """The backdrop drawn inside the disk image window (and in the README mock)."""
    image = vertical_gradient((width, height), (247, 247, 250), (234, 234, 239)).convert("RGBA")
    draw = ImageDraw.Draw(image)
    draw_arrow(
        draw,
        width * 0.34,
        width * 0.66,
        height * 0.455,
        (193, 193, 202),
        max(2, round(7 * scale)),
        max(6, round(28 * scale)),
    )
    face = font(max(11, round(13 * scale)), "Medium")
    label = "Drag YouTube Music into Applications"
    draw.text(
        (width / 2, height - 34 * scale),
        label,
        font=face,
        fill=(154, 154, 161),
        anchor="mm",
    )
    return image


def make_dmg_background():
    image = dmg_backdrop(800, 372, 1.0)
    image.convert("RGB").save(os.path.join(ROOT, "Resources", "dmg-background.png"), optimize=True)


def make_download_button():
    scale = 2
    pad = 30 * scale
    icon_size = 96 * scale
    title = font(40 * scale, "SemiBold")
    subtitle = font(23 * scale, "Regular")
    label = "Download for macOS"
    note = "macOS 13 or later  ·  Apple silicon & Intel"

    probe = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    text_width = max(
        probe.textlength(label, font=title), probe.textlength(note, font=subtitle)
    )
    width = int(pad * 2 + icon_size + 26 * scale + text_width + pad)
    height = int(pad * 2 + icon_size)

    width += 24 * scale
    canvas = Image.new("RGBA", (width + 40 * scale, height + 40 * scale), (0, 0, 0, 0))
    box = [20 * scale, 20 * scale, 20 * scale + width, 20 * scale + height]
    shadow(canvas, box, 26 * scale, blur=18 * scale, dy=8 * scale)
    gradient_card(canvas, box, 26 * scale, (27, 27, 32), (14, 14, 18), border=(58, 58, 66))

    icon = app_icon(icon_size)
    canvas.alpha_composite(icon, (box[0] + pad, box[1] + pad))

    draw = ImageDraw.Draw(canvas)
    text_x = box[0] + pad + icon_size + 26 * scale
    draw.text((text_x, box[1] + pad + 6 * scale), label, font=title, fill=(255, 255, 255))
    draw.text(
        (text_x, box[1] + pad + 58 * scale),
        note,
        font=subtitle,
        fill=(160, 160, 170),
    )
    canvas.save(os.path.join(SHOTS, "download-button.png"), optimize=True)


def make_install_download():
    width, height = 1200, 300
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    box = [40, 40, width - 40, height - 40]
    shadow(canvas, box, 20, blur=14, dy=6, opacity=34)
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(box, 20, fill=(255, 255, 255, 255), outline=HAIRLINE, width=1)

    icon = app_icon(84)
    canvas.alpha_composite(icon, (box[0] + 28, box[1] + 46))

    draw.text(
        (box[0] + 132, box[1] + 56),
        "YouTube-Music-%s.dmg" % VERSION,
        font=font(29, "SemiBold"),
        fill=INK,
    )
    draw.text(
        (box[0] + 132, box[1] + 98),
        "Disk image  ·  Universal  ·  macOS 13 or later",
        font=font(20, "Regular"),
        fill=MUTED,
    )

    button = [box[2] - 244, box[1] + 60, box[2] - 44, box[1] + 140]
    gradient_card(canvas, button, 40, (255, 62, 82), (214, 12, 40))
    download_glyph(draw, (button[0] + 30, button[1] + 26, 28), (255, 255, 255))
    draw.text(
        (button[0] + 74, button[1] + 40),
        "Download",
        font=font(23, "SemiBold"),
        fill=(255, 255, 255),
        anchor="lm",
    )
    canvas.save(os.path.join(SHOTS, "install-download.png"), optimize=True)


def make_install_drag():
    scale = 1.4
    win_w, win_h = round(800 * scale), round(400 * scale)
    canvas = Image.new("RGBA", (1200, win_h + 140), (0, 0, 0, 0))
    box = [40, 40, 40 + win_w, 40 + win_h]
    shadow(canvas, box, 12, blur=22, dy=12, opacity=48)

    titlebar = round(28 * scale)
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(box, 12, fill=(238, 238, 241, 255))
    backdrop = dmg_backdrop(win_w, win_h - titlebar, scale)
    mask = Image.new("L", backdrop.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, backdrop.width - 1, backdrop.height - 1], 12, fill=255
    )
    ImageDraw.Draw(mask).rectangle([0, 0, backdrop.width, 12], fill=255)
    backdrop.putalpha(mask)
    canvas.alpha_composite(backdrop, (box[0], box[1] + titlebar))

    draw = ImageDraw.Draw(canvas)
    for index, colour in enumerate([(255, 95, 87), (254, 188, 46), (40, 200, 64)]):
        cx = box[0] + round(20 * scale) + index * round(20 * scale)
        cy = box[1] + round(14 * scale)
        r = round(6 * scale)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=colour)
    draw.text(
        ((box[0] + box[2]) / 2, box[1] + round(14 * scale)),
        "YouTube Music",
        font=font(round(13 * scale), "SemiBold"),
        fill=(90, 90, 96),
        anchor="mm",
    )

    origin_y = box[1] + titlebar
    icon_size = round(160 * scale)
    label_face = font(round(12 * scale), "Medium")
    positions = [
        (round(190 * scale), "YouTube Music"),
        (round(610 * scale), "Applications"),
    ]
    for index, (center_x, name) in enumerate(positions):
        center_y = round(170 * scale)
        top = origin_y + center_y - icon_size // 2
        left = box[0] + center_x - icon_size // 2
        if index == 0:
            canvas.alpha_composite(app_icon(icon_size), (left, top))
        else:
            canvas.alpha_composite(folder_icon(icon_size), (left, top))
        draw.text(
            (left + icon_size / 2, top + icon_size + round(14 * scale)),
            name,
            font=label_face,
            fill=(58, 58, 64),
            anchor="mm",
        )
    canvas.save(os.path.join(SHOTS, "install-drag.png"), optimize=True)


def make_install_open():
    width, height = 1200, 312
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    body = font(15, "Regular")
    small = font(13, "Regular")

    # Left: the alert macOS shows when the app is first opened.
    alert = [36, 32, 640, 272]
    shadow(canvas, alert, 16, blur=18, dy=8)
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(alert, 16, fill=(250, 250, 252, 255), outline=HAIRLINE, width=1)
    canvas.alpha_composite(app_icon(60), (alert[0] + 26, alert[1] + 26))
    draw.text(
        (alert[0] + 100, alert[1] + 28),
        "\u201cYouTube Music\u201d Not Opened",
        font=font(20, "SemiBold"),
        fill=INK,
    )
    paragraph(
        draw,
        (alert[0] + 100, alert[1] + 66),
        "Apple could not verify \u201cYouTube Music\u201d is free of malware that may harm your Mac or compromise your privacy.",
        body,
        INK_SOFT,
        alert[2] - alert[0] - 130,
        23,
    )
    draw.line([(alert[0], alert[3] - 74), (alert[2], alert[3] - 74)], fill=HAIRLINE, width=1)
    draw.text(
        (alert[0] + 26, alert[3] - 44),
        "The app was downloaded from the internet.",
        font=small,
        fill=MUTED,
    )
    draw.rounded_rectangle(
        [alert[2] - 110, alert[3] - 56, alert[2] - 26, alert[3] - 18], 8, fill=(10, 132, 255, 255)
    )
    draw.text(
        (alert[2] - 68, alert[3] - 37),
        "Done",
        font=font(15, "SemiBold"),
        fill=(255, 255, 255),
        anchor="mm",
    )

    # Right: where the exception is granted.
    panel = [700, 32, 1164, 272]
    shadow(canvas, panel, 16, blur=18, dy=8)
    draw.rounded_rectangle(panel, 16, fill=(255, 255, 255, 255), outline=HAIRLINE, width=1)
    draw.text(
        (panel[0] + 26, panel[1] + 22), "Privacy & Security", font=font(18, "SemiBold"), fill=INK
    )
    draw.line([(panel[0], panel[1] + 58), (panel[2], panel[1] + 58)], fill=HAIRLINE, width=1)
    draw.text((panel[0] + 26, panel[1] + 74), "SECURITY", font=font(10, "SemiBold"), fill=MUTED)
    paragraph(
        draw,
        (panel[0] + 26, panel[1] + 96),
        "\u201cYouTube Music\u201d was blocked from use because it is not from an identified developer.",
        small,
        INK_SOFT,
        panel[2] - panel[0] - 52,
        20,
    )
    draw.rounded_rectangle(
        [panel[0] + 26, panel[1] + 142, panel[0] + 210, panel[1] + 186], 9, fill=(10, 132, 255, 255)
    )
    draw.text(
        (panel[0] + 118, panel[1] + 164),
        "Open Anyway",
        font=font(15, "SemiBold"),
        fill=(255, 255, 255),
        anchor="mm",
    )
    paragraph(
        draw,
        (panel[0] + 26, panel[1] + 202),
        "Confirm with your password, then choose Open Anyway in the final dialog.",
        small,
        MUTED,
        panel[2] - panel[0] - 52,
        20,
    )

    # Connector between the two panels.
    draw_arrow(draw, 656, 692, (alert[1] + alert[3]) / 2, (198, 198, 206), 5, 18)
    canvas.save(os.path.join(SHOTS, "install-open.png"), optimize=True)


if __name__ == "__main__":
    os.makedirs(SHOTS, exist_ok=True)
    make_dmg_background()
    make_download_button()
    make_install_download()
    make_install_drag()
    make_install_open()
    print("Wrote Resources/dmg-background.png and docs/screenshots/*.png")
