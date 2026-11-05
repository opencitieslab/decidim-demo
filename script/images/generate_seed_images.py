"""Generate branded placeholder images for the CCT demo seed (OCL palette).

No photos or City of Cape Town marks are used — abstract banners only, so the
demo can't be mistaken for an official City asset and nothing is copyrighted.

Usage: python -I script/images/generate_seed_images.py [out_dir]
Default out_dir: db/seeds/cct/images
Fonts: Segoe UI (Windows) if present, otherwise PIL's default font.
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont

AMBER = (252, 175, 0)
ORANGE = (216, 97, 57)
CHARCOAL = (47, 53, 66)
WHITE = (255, 255, 255)

THEMES = [
    ("economic_growth", "Economic growth", AMBER, ORANGE),
    ("basic_services", "Basic services", ORANGE, CHARCOAL),
    ("safety", "Safety", CHARCOAL, ORANGE),
    ("housing", "Housing", ORANGE, AMBER),
    ("public_space_environment", "Public space & environment", AMBER, CHARCOAL),
    ("transport", "Transport", CHARCOAL, AMBER),
    ("resilience", "A resilient city", ORANGE, CHARCOAL),
    ("spatial_integration", "An integrated, inclusive city", AMBER, ORANGE),
    ("capable_government", "Capable, collaborative government", CHARCOAL, ORANGE),
]

FONT_DIRS = [r"C:\Windows\Fonts", "/usr/share/fonts/truetype/dejavu"]


def font(size, bold=True):
    names = ["segoeuib.ttf", "DejaVuSans-Bold.ttf"] if bold else ["segoeui.ttf", "DejaVuSans.ttf"]
    for d in FONT_DIRS:
        for n in names:
            p = os.path.join(d, n)
            if os.path.exists(p):
                return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def gradient(w, h, c1, c2):
    img = Image.new("RGB", (w, h), c1)
    px = img.load()
    for x in range(w):
        t = x / (w - 1)
        col = tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))
        for y in range(h):
            px[x, y] = col
    return img


def circles(img, seed, colour):
    rnd = random.Random(seed)
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    w, h = img.size
    for _ in range(7):
        r = rnd.randint(h // 4, h)
        cx, cy = rnd.randint(-r // 2, w), rnd.randint(-r // 2, h)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=colour + (60,))
    return Image.alpha_composite(img.convert("RGBA"), over).convert("RGB")


def wrap(draw, text, fnt, max_w):
    words, lines, cur = text.split(), [], ""
    for w in words:
        test = (cur + " " + w).strip()
        if draw.textlength(test, font=fnt) <= max_w:
            cur = test
        else:
            lines.append(cur)
            cur = w
    lines.append(cur)
    return lines


def banner(path, title, subtitle, c1, c2, seed, size=(1600, 600)):
    w, h = size
    # Abstract only: Decidim renders the title/description over hero and card images,
    # so text baked into the image would duplicate it. `title`/`subtitle` kept for alt text callers.
    img = circles(gradient(w, h, c1, c2), seed, WHITE)
    img = circles(img, seed + 1000, c2)
    img.save(path, "PNG", optimize=True)


def logo(path, size=(1400, 200)):
    w, h = size
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = h // 2 - 10
    for i, col in enumerate([AMBER, ORANGE, CHARCOAL]):
        cx = 20 + r + i * int(r * 0.9)
        d.ellipse([cx - r, h // 2 - r, cx + r, h // 2 + r], fill=col + (255,))
    x = 20 + r * 2 + 2 * int(r * 0.9) + 30
    d.text((x, int(h * 0.12)), "Cape Town Participate", font=font(int(h * 0.30)), fill=CHARCOAL)
    d.text((x, int(h * 0.55)), "Demo · not an official City platform", font=font(int(h * 0.17), bold=False), fill=ORANGE)
    img.save(path, "PNG", optimize=True)


def favicon(path, size=512):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, size - 1, size - 1], fill=AMBER + (255,))
    d.pieslice([size * 0.25, 0, size * 1.25, size - 1], 90, 270, fill=ORANGE + (255,))
    d.ellipse([size * 0.55, size * 0.18, size * 1.2, size * 0.82], fill=CHARCOAL + (255,))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, size - 1, size - 1], fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, mask=mask)
    out.save(path, "PNG", optimize=True)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join("db", "seeds", "cct", "images")
    os.makedirs(out, exist_ok=True)
    for i, (key, name, c1, c2) in enumerate(THEMES):
        banner(os.path.join(out, f"theme-{key}.png"), name, "Have your say · Cape Town demo", c1, c2, seed=i)
    banner(os.path.join(out, "home-hero.png"), "Have your say, Cape Town",
           "Demonstration platform · English · Afrikaans · isiXhosa", CHARCOAL, ORANGE, seed=99, size=(1920, 700))
    banner(os.path.join(out, "group-have-your-say.png"), "Have your say 2025–26",
           "Real City of Cape Town consultations · demo", ORANGE, AMBER, seed=7)
    banner(os.path.join(out, "ward-allocations.png"), "Ward Allocations 2026/27",
           "R1 million per ward · demo", AMBER, CHARCOAL, seed=11)
    logo(os.path.join(out, "logo.png"))
    favicon(os.path.join(out, "favicon.png"))
    print("written to", out, sorted(os.listdir(out)))


if __name__ == "__main__":
    main()
