from PIL import Image, ImageDraw
import base64
import json
import os
import random
import io

OUTPUT_DIR = r"c:\Users\10713\Desktop\CET4_English\generated_cards"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))

def make_card(w, h, grad1, grad2, accent, shapes_seed, icon_draw_fn):
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for y in range(h):
        t = y / h
        c = lerp_color(grad1, grad2, t)
        draw.line([(0, y), (w, y)], fill=(*c, 255))

    rng = random.Random(shapes_seed)
    overlay = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for _ in range(6):
        cx, cy = rng.randint(10, w-10), rng.randint(10, h-10)
        r = rng.randint(15, 45)
        a = rng.randint(15, 40)
        od.ellipse([cx-r, cy-r, cx+r, cy+r], fill=(*accent, a))
    for _ in range(4):
        x, y = rng.randint(5, w-25), rng.randint(5, h-25)
        s = rng.randint(10, 30)
        a = rng.randint(20, 45)
        od.rounded_rectangle([x, y, x+s, y+s], radius=4, fill=(*accent, a))
    for _ in range(3):
        x1, y1 = rng.randint(5, w-5), rng.randint(5, h-5)
        x2, y2 = x1 + rng.randint(-30, 30), y1 + rng.randint(-30, 30)
        a = rng.randint(15, 35)
        od.line([(x1, y1), (x2, y2)], fill=(*accent, a), width=2)
    img = Image.alpha_composite(img, overlay)
    draw = ImageDraw.Draw(img)
    icon_draw_fn(draw, w, h, accent)
    return img

def icon_book(draw, w, h, c):
    cx, cy = w * 0.65, h * 0.35
    bw, bh = 50, 40
    draw.rounded_rectangle([cx-bw, cy-bh, cx+bw, cy+bh], radius=4, fill=(*c, 50), outline=(*c, 80), width=2)
    draw.line([(cx, cy-bh), (cx, cy+bh)], fill=(*c, 80), width=2)
    for i in range(4):
        y = cy - bh*0.6 + i * bh*0.4
        draw.line([(cx+5, y), (cx+bw*0.7, y)], fill=(*c, 50), width=1)
    draw.ellipse([w*0.2, h*0.7, w*0.2+20, h*0.7+20], fill=(*c, 35))
    draw.ellipse([w*0.15, h*0.25, w*0.15+12, h*0.25+12], fill=(*c, 25))

def icon_x_mark(draw, w, h, c):
    cx, cy = w * 0.6, h * 0.4
    s = 25
    draw.line([(cx-s, cy-s), (cx+s, cy+s)], fill=(*c, 70), width=4)
    draw.line([(cx+s, cy-s), (cx-s, cy+s)], fill=(*c, 70), width=4)
    r = 35
    draw.ellipse([cx-r, cy-r, cx+r, cy+r], outline=(*c, 55), width=3)
    draw.ellipse([w*0.2, h*0.7, w*0.2+15, h*0.7+15], fill=(*c, 30))
    draw.rounded_rectangle([w*0.7, h*0.75, w*0.7+20, h*0.75+10], radius=3, fill=(*c, 35))

def icon_pencil(draw, w, h, c):
    cx, cy = w * 0.55, h * 0.45
    pts = [(cx-8, cy+30), (cx+8, cy+30), (cx, cy-20)]
    draw.polygon(pts, fill=(*c, 55), outline=(*c, 75))
    draw.rectangle([cx-18, cy-15, cx+18, cy+15], fill=(*c, 40), outline=(*c, 60), width=1)
    draw.ellipse([w*0.2, h*0.2, w*0.2+25, h*0.2+25], outline=(*c, 40), width=2)
    draw.ellipse([w*0.75, h*0.7, w*0.75+18, h*0.7+18], fill=(*c, 30))

def icon_bookmark(draw, w, h, c):
    cx, cy = w * 0.6, h * 0.4
    s = 25
    pts = [(cx-s, cy-s), (cx+s, cy-s), (cx+s, cy+s), (cx, cy+s*0.3), (cx-s, cy+s)]
    draw.polygon(pts, fill=(*c, 50), outline=(*c, 70), width=2)
    draw.ellipse([w*0.2, h*0.7, w*0.2+18, h*0.7+18], fill=(*c, 30))
    draw.rounded_rectangle([w*0.75, h*0.25, w*0.75+12, h*0.25+20], radius=3, fill=(*c, 35))
    draw.ellipse([w*0.3, h*0.2, w*0.3+10, h*0.2+10], fill=(*c, 25))

def icon_robot(draw, w, h, c):
    cx, cy = w * 0.55, h * 0.45
    s = 28
    draw.rounded_rectangle([cx-s, cy-s*0.7, cx+s, cy+s*0.5], radius=5, fill=(*c, 45), outline=(*c, 65), width=2)
    draw.ellipse([cx-s*0.6, cy-s*0.35, cx-s*0.15, cy+s*0.05], fill=(*c, 70))
    draw.ellipse([cx+s*0.15, cy-s*0.35, cx+s*0.6, cy+s*0.05], fill=(*c, 70))
    draw.line([(cx, cy-s*0.7), (cx, cy-s*1.1)], fill=(*c, 60), width=2)
    draw.ellipse([cx-4, cy-s*1.2, cx+4, cy-s*1.1], fill=(*c, 70))
    draw.ellipse([w*0.2, h*0.75, w*0.2+15, h*0.75+15], fill=(*c, 25))
    for i in range(3):
        x = w*0.15 + i*12
        draw.line([(x, h*0.2), (x, h*0.2+8)], fill=(*c, 30), width=1)

def icon_timer(draw, w, h, c):
    cx, cy = w * 0.55, h * 0.45
    r = 30
    draw.ellipse([cx-r, cy-r, cx+r, cy+r], outline=(*c, 60), width=3)
    draw.line([(cx, cy), (cx, cy-r*0.7)], fill=(*c, 70), width=3)
    draw.line([(cx, cy), (cx+r*0.5, cy+r*0.2)], fill=(*c, 50), width=2)
    draw.ellipse([cx-4, cy-r-8, cx+4, cy-r-1], fill=(*c, 60))
    draw.rounded_rectangle([w*0.2, h*0.7, w*0.2+22, h*0.7+16], radius=3, fill=(*c, 35))
    draw.ellipse([w*0.75, h*0.25, w*0.75+12, h*0.25+12], fill=(*c, 25))

cards = [
    ("card_word",     (0x16,0x5D,0xFF), (0x3B,0x82,0xF6), icon_book,     100),
    ("card_wrong",    (0xEF,0x44,0x44), (0xF8,0x71,0x71), icon_x_mark,   200),
    ("card_exam",     (0xF5,0x9E,0x0B), (0xFB,0xBF,0x24), icon_pencil,   300),
    ("card_wordbook", (0x10,0xB9,0x81), (0x34,0xD3,0x99), icon_bookmark, 400),
    ("card_ai",       (0x8B,0x5C,0xF6), (0xA7,0x8B,0xFA), icon_robot,    500),
    ("card_mock",     (0x16,0x5D,0xFF), (0x3B,0x82,0xF6), icon_timer,    600),
]

results = {}
for name, g1, g2, icon_fn, seed in cards:
    img = make_card(400, 400, g1, g2, (255,255,255), seed, icon_fn)
    buf = io.BytesIO()
    img.save(buf, format='PNG', optimize=True)
    data = buf.getvalue()
    b64 = base64.b64encode(data).decode('ascii')
    results[name] = b64
    with open(os.path.join(OUTPUT_DIR, f"{name}.png"), 'wb') as f:
        f.write(data)
    print(f"{name}: {len(data)} bytes, base64: {len(b64)} chars")

out = os.path.join(OUTPUT_DIR, "cards_base64.json")
with open(out, 'w') as f:
    json.dump(results, f)
print(f"\nSaved to {out}")

import hashlib
for name, _, _, _, _ in cards:
    p = os.path.join(OUTPUT_DIR, f"{name}.png")
    with open(p, 'rb') as f:
        h = hashlib.md5(f.read()).hexdigest()
    print(f"  {name}: MD5={h}")
