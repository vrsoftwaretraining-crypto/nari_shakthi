# Developed by Codesoftwares
# Usage: pip install pillow && python tools/make_backgrounds.py app/assets/images
# Generates wedding-themed illustrated backgrounds (original artwork, no third-party photos).
from PIL import Image, ImageDraw
import math, random, sys
S = 2
W, H = 1080 * S, 2160 * S

def grad(top, bot):
    img = Image.new('RGB', (W, H)); d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return img.convert('RGBA')

def petal(d, cx, cy, ang, L, Wd, fill, outline=None, ow=0):
    pts = []
    px, py = cx + (L / 2) * math.cos(ang), cy + (L / 2) * math.sin(ang)
    for k in range(28):
        t = 2 * math.pi * k / 28
        ex, ey = (L / 2) * math.cos(t), (Wd / 2) * math.sin(t)
        pts.append((px + ex * math.cos(ang) - ey * math.sin(ang), py + ex * math.sin(ang) + ey * math.cos(ang)))
    d.polygon(pts, fill=fill, outline=outline, width=ow)

def marigold(d, cx, cy, r):
    for n, L, w, col in [(14, r, .55, (240, 138, 28, 255)), (10, r * .75, .5, (247, 169, 40, 255)), (8, r * .5, .4, (255, 200, 61, 255))]:
        off = random.random()
        for k in range(n):
            petal(d, cx, cy, 2 * math.pi * k / n + off, L, L * w * (1 if col[0] == 240 else 1), col)
    d.ellipse([cx - r * .12, cy - r * .12, cx + r * .12, cy + r * .12], fill=(179, 90, 12, 255))

def leaf(d, cx, cy, ang, L):
    petal(d, cx, cy, ang, L, L * .38, (52, 128, 60, 255))

def strand(d, x0, y0, n, step, r):
    pts = [(x0 + 8 * S * math.sin(i * .7), y0 + i * step) for i in range(n)]
    d.line(pts, fill=(60, 110, 50, 255), width=3 * S)
    for i, (x, y) in enumerate(pts):
        leaf(d, x, y, math.pi / 2 + (.9 if i % 2 else -.9), r * 1.5)
    for x, y in pts:
        marigold(d, x, y, r)
    d.polygon([(pts[-1][0], pts[-1][1] + r * 1.1), (pts[-1][0] - r * .5, pts[-1][1] + r * 2.2), (pts[-1][0] + r * .5, pts[-1][1] + r * 2.2)], fill=(200, 60, 80, 255))

def swag(d, base, sag, r, step):
    xs = list(range(-20 * S, W + 20 * S, step))
    pts = [(x, base + sag * math.sin(math.pi * (x + 20 * S) / (W + 40 * S))) for x in xs]
    d.line(pts, fill=(60, 110, 50, 255), width=4 * S)
    for i, (x, y) in enumerate(pts):
        leaf(d, x, y, math.pi / 2 + (1 if i % 2 else -1), r * 1.6)
    for x, y in pts:
        marigold(d, x, y, r)

def mandala(img, cx, cy, R, alpha):
    ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    gold = (196, 150, 40, alpha)
    for layer in range(7):
        r = R * (1 - layer * .13); n = 12 + layer * 4
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=gold, width=2 * S)
        for k in range(n):
            petal(d, cx, cy, 2 * math.pi * k / n, r, r * .22, (0, 0, 0, 0), outline=gold, ow=2 * S)
    return Image.alpha_composite(img, ov)

def lotus(img, rows, alpha_main):
    ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    for row in range(rows):
        off = (row % 2) * 55 * S
        for x in range(-100 * S, W + 100 * S, 110 * S):
            petal(d, x + off, H + row * 10 * S, -math.pi / 2, (250 - row * 45) * S, 130 * S, (200 + row * 15, 70 + row * 40, 110 + row * 30, alpha_main - row * 25), outline=(212, 160, 50, 200), ow=2 * S)
    return Image.alpha_composite(img, ov)

def ring(d, cx, cy, r, w, col, hi):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=col, width=w)
    d.ellipse([cx - r + w // 3, cy - r + w // 3, cx + r - w // 3, cy + r - w // 3], outline=hi, width=max(2, w // 4))

def rings(img, cx, cy):
    ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    r, w, gap = 120 * S, 16 * S, 85 * S
    gold, hi = (201, 151, 36, 255), (250, 222, 120, 255)
    ring(d, cx - gap, cy, r, w, gold, hi); ring(d, cx + gap, cy, r, w, gold, hi)
    # interlock: redraw the left ring's right arc over the right ring
    arc = Image.new('RGBA', (W, H), (0, 0, 0, 0)); da = ImageDraw.Draw(arc)
    ring(da, cx - gap, cy, r, w, gold, hi)
    mask = Image.new('L', (W, H), 0); dm = ImageDraw.Draw(mask)
    dm.rectangle([cx, cy - r - w, cx + r, cy - r * .2], fill=255)
    ov.paste(arc, (0, 0), mask)
    # diamond
    dx, dy = cx + gap, cy - r - 6 * S
    d.polygon([(dx, dy - 38 * S), (dx + 28 * S, dy), (dx, dy + 24 * S), (dx - 28 * S, dy)], fill=(255, 255, 255, 235), outline=(150, 190, 230, 255))
    return Image.alpha_composite(img, ov)

def sparkles(img, n, seed):
    random.seed(seed); ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    for _ in range(n):
        x, y, s = random.randint(0, W), random.randint(int(H * .15), int(H * .95)), random.randint(8, 22) * S
        d.polygon([(x, y - s), (x + s * .22, y - s * .22), (x + s, y), (x + s * .22, y + s * .22), (x, y + s), (x - s * .22, y + s * .22), (x - s, y), (x - s * .22, y - s * .22)], fill=(214, 170, 60, 150))
    return Image.alpha_composite(img, ov)

def build(light):
    random.seed(11)
    img = grad((255, 247, 236), (250, 222, 229) if not light else (252, 235, 238))
    img = mandala(img, W // 2, int(H * .46), 470 * S, 55 if not light else 28)
    img = lotus(img, 3 if not light else 2, 150 if not light else 90)
    if not light:
        img = rings(img, W // 2, int(H * .83))
    img = sparkles(img, 26 if not light else 12, 3)
    ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    if not light:
        for x, n in [(.06, 6), (.2, 9), (.35, 5), (.5, 7), (.65, 5), (.8, 9), (.94, 6)]:
            strand(d, int(W * x), 120 * S, n, 62 * S, 27 * S)
        swag(d, 60 * S, 130 * S, 30 * S, 56 * S)
    else:
        swag(d, 30 * S, 80 * S, 26 * S, 58 * S)
    img = Image.alpha_composite(img, ov)
    return img.convert('RGB').resize((1080, 2160), Image.LANCZOS)

out = sys.argv[1]
build(False).save(out + '/login_bg.jpg', quality=88, optimize=True)
build(True).save(out + '/app_bg.jpg', quality=88, optimize=True)
