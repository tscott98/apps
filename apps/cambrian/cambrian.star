"""
Applet: Cambrian
Summary: Cambrian sea screensaver
Description: A procedural screensaver of the Cambrian seafloor. Anomalocaris, Opabinia, Hallucigenia, trilobites, Marrella, Wiwaxia, Pikaia and comb jellies are drawn from code each frame, with undulating flaps, walking legs and drifting marine snow.
Author: tscott98
"""

load("math.star", "math")
load("random.star", "random")
load("render.star", "canvas", "render")
load("schema.star", "schema")

# The scene is drawn on a logical grid (64x32, or 64x64 on square panels)
# and every logical pixel is scaled up on 2x panels.
FRAMES = 150
DELAY_MS = 100

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

def rnd(v):
    return int(math.floor(v + 0.5))

def clamp(v, lo, hi):
    return max(lo, min(hi, v))

def hex2(n):
    digits = "0123456789abcdef"
    n = clamp(int(n), 0, 255)
    return digits[n // 16] + digits[n % 16]

def rgb(r, g, b):
    return "#" + hex2(r) + hex2(g) + hex2(b)

def mix(c1, c2, t):
    """Linear blend of two (r, g, b) tuples."""
    return rgb(
        c1[0] + (c2[0] - c1[0]) * t,
        c1[1] + (c2[1] - c1[1]) * t,
        c1[2] + (c2[2] - c1[2]) * t,
    )

def rainbow(phase):
    """Iridescent colour cycling used by Marrella spines and comb rows."""
    return rgb(
        150 + 100 * math.sin(phase),
        150 + 100 * math.sin(phase + 2.1),
        200 + 55 * math.sin(phase + 4.2),
    )

# A drawing context is a dict holding the frame buffer, the creature's origin
# and the direction it faces. Creatures are written facing right in local
# coordinates; facing left mirrors them.
def ctx(buf, w, h, ox, oy, facing):
    return {"buf": buf, "w": w, "h": h, "ox": ox, "oy": oy, "f": facing}

def put(c, lx, ly, color):
    x = c["ox"] + rnd(lx) * c["f"]
    y = c["oy"] + rnd(ly)
    if x >= 0 and x < c["w"] and y >= 0 and y < c["h"]:
        c["buf"][y * c["w"] + x] = color

def hline(c, x0, x1, y, color):
    for x in range(rnd(x0), rnd(x1) + 1):
        put(c, x, y, color)

def vline(c, x, y0, y1, color):
    lo = min(rnd(y0), rnd(y1))
    hi = max(rnd(y0), rnd(y1))
    for y in range(lo, hi + 1):
        put(c, x, y, color)

def line(c, x0, y0, x1, y1, color):
    steps = max(abs(rnd(x1) - rnd(x0)), abs(rnd(y1) - rnd(y0)), 1)
    for i in range(steps + 1):
        t = i / steps
        put(c, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, color)

def ellipse(c, cx, cy, rx, ry, color):
    for dy in range(-ry, ry + 1):
        frac = 1.0 - (dy * dy) / ((ry + 0.5) * (ry + 0.5))
        half = rnd(rx * math.sqrt(max(frac, 0.0)))
        hline(c, cx - half, cx + half, cy + dy, color)

# ---------------------------------------------------------------------------
# Critters. Each draw function takes a context and an animation phase
# (frame number) and draws the animal centred on the origin, facing right.
# ---------------------------------------------------------------------------

def draw_anomalocaris(c, t):
    body = (196, 82, 58)
    back = (140, 48, 34)
    flap = (232, 128, 92)
    claw = (244, 170, 96)
    p = t * 0.45

    # Tail fan: three pairs of blades that flex with the stroke.
    flex = math.sin(p) * 1.2
    line(c, -9, -1, -14, -4 + flex, rgb(*flap))
    line(c, -9, 1, -14, 4 + flex, rgb(*flap))
    line(c, -9, 0, -13, flex * 0.5, rgb(*back))
    line(c, -9, -1, -12, -2 + flex, rgb(*back))
    line(c, -9, 1, -12, 2 + flex, rgb(*back))

    # Far-side flaps peek over the back, near-side flaps ripple below the belly.
    for k in range(8):
        x = 5 - k * 2
        wave = math.sin(p - k * 0.8)
        up = rnd(0.5 + wave * 0.6)
        down = 2 + rnd(1.0 + wave * 1.2)
        half = body_half(x)
        vline(c, x, -half, -half - up, rgb(*back))
        vline(c, x, half, half + down, rgb(*flap))
        vline(c, x - 1, half, half + down - 1, rgb(*flap))

    # Segmented body, lighter on top, darker belly, stripes between segments.
    for x in range(-9, 10):
        half = body_half(x)
        for y in range(-half, half + 1):
            shade = 0.25 + 0.5 * (y + half) / max(1, 2 * half)
            col = mix(flap, back, shade)
            if x % 2 == 0 and x < 6:
                col = mix(body, back, 0.6)
            put(c, x, y, col)

    # Eye on a short stalk.
    put(c, 6, -3, rgb(*back))
    put(c, 6, -4, "#111111")
    put(c, 7, -4, "#111111")
    put(c, 6, -5, "#111111")
    put(c, 7, -5, "#ffffff")

    # Frontal appendages curl and uncurl, with spines on the inner edge.
    # They reach forward, then hook down and back towards the mouth.
    curl = 0.42 + 0.2 * math.sin(p * 0.6)
    ax = 9.0
    ay = 1.0
    ang = -0.15
    for j in range(6):
        nx = ax + math.cos(ang) * 1.5
        ny = ay + math.sin(ang) * 1.5
        line(c, ax, ay, nx, ny, rgb(*claw))
        if j % 2 == 0:
            # Spine on the inner (lower) edge.
            put(c, nx - math.sin(ang), ny + math.cos(ang), rgb(*flap))
        ax = nx
        ay = ny
        ang += curl

def body_half(x):
    """Half-height of the Anomalocaris body at local x."""
    if x >= 8:
        return 1
    if x >= -2:
        return 3
    if x >= -6:
        return 2
    return 1

def draw_opabinia(c, t):
    body = (94, 140, 168)
    dark = (52, 86, 112)
    flap = (150, 196, 220)
    tail = (214, 96, 84)
    p = t * 0.5

    # Tail fan, red with a flicker.
    flex = math.sin(p) * 1.0
    line(c, -8, 0, -11, -3 + flex, rgb(*tail))
    line(c, -8, 0, -11, 3 + flex, rgb(*tail))
    line(c, -8, 0, -10, flex * 0.5, rgb(*tail))

    # Flaps below the body.
    for k in range(7):
        x = 4 - k * 2
        down = 1 + rnd(1.0 + math.sin(p - k * 0.9) * 1.0)
        vline(c, x, 2, 2 + down, rgb(*flap))

    # Body.
    for x in range(-8, 7):
        half = 2 if x > -5 else 1
        for y in range(-half, half + 1):
            col = rgb(*body) if y < half else rgb(*dark)
            if x % 2 == 0:
                col = mix(body, dark, 0.5)
            put(c, x, y, col)

    # Five stalked eyes on top of the head.
    for i in range(5):
        ex = 2 + i
        ey = -4 - (1 if i % 2 == 1 else 0)
        put(c, ex, -3, rgb(*dark))
        put(c, ex, ey, "#ffd166" if (i + t // 6) % 5 == 0 else "#1b1b1b")

    # The proboscis sweeps forward and down, ending in a snapping claw.
    sweep = math.sin(p * 0.4)
    px = 6.0
    py = 2.0
    for _ in range(8):
        px += 1.0
        py += 0.25 + sweep * 0.35
        put(c, px, py, rgb(*body))
    open = 1 if (t // 5) % 3 == 0 else 0
    put(c, px + 1, py - 1 - open, rgb(*tail))
    put(c, px + 1, py + 1 + open, rgb(*tail))
    put(c, px + 2, py - open, rgb(*tail))
    put(c, px + 2, py + open, rgb(*tail))

def draw_hallucigenia(c, t):
    body = (236, 196, 120)
    spine = (176, 104, 72)
    leg = (220, 160, 110)
    p = t * 0.6

    # Seven pairs of tentacle legs walk in a wave.
    for k in range(7):
        x = -6 + k * 2
        swing = math.sin(p - k * 0.9)
        line(c, x, 1, x + swing * 1.2, 4, rgb(*leg))

    # Tubular body arching slightly, head bulb at the front, tail curling down.
    for x in range(-8, 8):
        y = -0.5 * math.cos(x * 0.25)
        put(c, x, y, rgb(*body))
        put(c, x, y + 1, mix(body, leg, 0.5))
    put(c, -9, 1, rgb(*body))
    put(c, -10, 2, rgb(*body))
    put(c, 8, 0, rgb(*body))
    put(c, 9, 1, rgb(*body))
    put(c, 10, 1, rgb(*body))
    put(c, 10, 2, rgb(*body))
    put(c, 11, 1, "#1b1b1b")

    # Paired spines along the back, leaning back and swaying as it walks.
    for k in range(7):
        x = -6 + k * 2
        lean = -1 + math.sin(p * 0.5 - k * 0.6) * 0.5
        tall = 4 if k % 2 == 0 else 3
        line(c, x, -1, x + lean, -1 - tall, rgb(*spine))

def draw_trilobite(c, t):
    shell = (150, 118, 90)
    dark = (96, 72, 56)
    light = (204, 176, 140)
    p = t * 0.8

    # Little legs patter underneath.
    for k in range(6):
        x = -4 + k * 2
        off = 1 if math.sin(p - k * 1.1) > 0 else 0
        put(c, x + off, 1, rgb(*dark))

    # Domed shell: tail shield, segmented thorax, raised head with glabella.
    for x in range(-6, 7):
        top = -2
        if abs(x) == 6:
            top = 0
        elif abs(x) == 5:
            top = -1
        elif x >= 2 and x <= 4:
            top = -3
        for y in range(top, 1):
            col = rgb(*shell)
            if y == top:
                col = rgb(*light)
            elif y == 0:
                col = rgb(*dark)
            elif x % 2 == 0 and x < 2 and x > -5:
                col = rgb(*dark)
            put(c, x, y, col)

    # Genal spine sweeping back from the head, and a crescent eye.
    line(c, 1, 0, -3, 1, rgb(*light))
    put(c, 3, -2, "#1b1b1b")

    # Antennae feel ahead.
    wave = math.sin(p * 0.5)
    line(c, 6, -1, 9, -2 + wave, rgb(*light))

def draw_marrella(c, t):
    body = (200, 176, 160)
    p = t * 0.4

    # Iridescent swept-back head spines: two pairs.
    sheen = rainbow(p)
    sheen2 = rainbow(p + 1.5)
    line(c, 2, -1, -3, -4, sheen)
    line(c, -3, -4, -7, -3, sheen)
    line(c, 2, 0, -2, 3, sheen2)
    line(c, -2, 3, -6, 4, sheen2)

    # Fluttering gill-legs.
    for k in range(5):
        x = -3 + k
        put(c, x, 1 + (1 if math.sin(t * 0.9 - k) > 0 else 0), rgb(*body))

    # Small body.
    hline(c, -4, 2, 0, rgb(*body))
    hline(c, -2, 1, -1, mix(body, (255, 255, 255), 0.3))

    # Long antennae.
    wave = math.sin(p) * 0.8
    line(c, 3, 0, 7, -1 + wave, rgb(*body))
    line(c, 3, 0, 7, 1 - wave, rgb(*body))

def draw_wiwaxia(c, t):
    scale_a = (90, 120, 80)
    scale_b = (130, 160, 96)
    spine = (226, 214, 160)

    # Scaly oval body; scales glint in sequence.
    for x in range(-6, 7):
        top = -3 if abs(x) < 4 else -2
        if abs(x) == 6:
            top = -1
        for y in range(top, 1):
            col = rgb(*scale_a) if (x + y) % 2 == 0 else rgb(*scale_b)
            if (x + y + t // 3) % 13 == 0:
                col = "#e9f5db"
            put(c, x, y, col)

    # Two rows of spines fanning backwards, swaying slightly.
    sway = math.sin(t * 0.15) * 0.8
    for k in range(4):
        x = -3 + k * 2
        lean = -2.5 + k * 0.5
        line(c, x, -3, x + lean + sway, -7 + (1 if k == 0 else 0), rgb(*spine))
        line(c, x + 1, -3, x + 1 + lean + 1.5 + sway, -6, mix(spine, scale_a, 0.45))

def draw_pikaia(c, t):
    body = (244, 172, 183)
    dark = (200, 120, 140)
    p = t * 0.7

    # A ribbon undulating along its length.
    for x in range(-7, 7):
        amp = 0.4 + (7 - x) * 0.1
        y = math.sin(p - x * 0.55) * amp
        put(c, x, y, rgb(*body))
        if x > -5 and x < 5:
            put(c, x, y + 1, rgb(*dark))

    # Head with tiny tentacles.
    hy = math.sin(p - 7 * 0.55) * 0.4
    put(c, 7, hy, rgb(*body))
    put(c, 8, hy - 1, rgb(*dark))
    put(c, 8, hy + 1, rgb(*dark))

def draw_ctenophore(c, t):
    bell = (120, 170, 200)
    p = t * 0.5

    # Translucent oval body.
    for y in range(-4, 5):
        half = rnd(3 * math.sqrt(max(0.0, 1.0 - (y * y) / 25.0)))
        for x in range(-half, half + 1):
            if abs(x) == half or y == -4 or y == 4:
                put(c, x, y, rgb(*bell))

    # Comb rows ripple with rainbow light, running from top to bottom.
    for row in [-2, 0, 2]:
        for y in range(-3, 4):
            if (y + t) % 3 == 0:
                put(c, row, y, rainbow(p + y * 0.8 + row))

    # Trailing tentacles.
    for k in range(2):
        x0 = -1 + k * 2
        for j in range(5):
            put(c, x0 + math.sin(p + j * 0.7 + k) * 0.8, 5 + j, mix(bell, (20, 40, 70), 0.3 + j * 0.1))

CRITTERS = {
    "anomalocaris": {
        "name": "Anomalocaris",
        "draw": draw_anomalocaris,
        "half_w": 15,
        "half_h": 6,
        "habitat": "swim",
        "speed": 0.62,
    },
    "opabinia": {
        "name": "Opabinia",
        "draw": draw_opabinia,
        "half_w": 17,
        "half_h": 5,
        "habitat": "swim",
        "speed": 0.5,
    },
    "hallucigenia": {
        "name": "Hallucigenia",
        "draw": draw_hallucigenia,
        "half_w": 12,
        "half_h": 4,
        "habitat": "floor",
        "speed": 0.12,
    },
    "trilobite": {
        "name": "Olenoides",
        "draw": draw_trilobite,
        "half_w": 10,
        "half_h": 3,
        "habitat": "floor",
        "speed": 0.15,
    },
    "marrella": {
        "name": "Marrella",
        "draw": draw_marrella,
        "half_w": 8,
        "half_h": 4,
        "habitat": "swim",
        "speed": 0.35,
    },
    "wiwaxia": {
        "name": "Wiwaxia",
        "draw": draw_wiwaxia,
        "half_w": 8,
        "half_h": 7,
        "habitat": "floor",
        "speed": 0.06,
    },
    "pikaia": {
        "name": "Pikaia",
        "draw": draw_pikaia,
        "half_w": 9,
        "half_h": 2,
        "habitat": "swim",
        "speed": 0.55,
    },
    "ctenophore": {
        "name": "Comb jelly",
        "draw": draw_ctenophore,
        "half_w": 4,
        "half_h": 10,
        "habitat": "drift",
        "speed": 0.08,
    },
}

CRITTER_ORDER = ["anomalocaris", "opabinia", "hallucigenia", "trilobite", "marrella", "wiwaxia", "pikaia", "ctenophore"]

# ---------------------------------------------------------------------------
# Scene: water, seafloor and sponges. Drawn once as runs of boxes.
# ---------------------------------------------------------------------------

def is_square():
    w, h = canvas.size()
    return h == w

def floor_y(h):
    return h - 5

def draw_background(buf, w, h):
    top = (18, 72, 96)
    bottom = (6, 26, 44)
    fy = floor_y(h)
    for y in range(h):
        col = mix(top, bottom, y / max(1, fy))
        for x in range(w):
            buf[y * w + x] = col

    # Shafts of light from the surface.
    for _ in range(3):
        sx = random.number(4, w - 4)
        for y in range(fy):
            x = sx + y // 3
            if x < w:
                i = y * w + x
                buf[i] = mix(top, (90, 150, 160), 0.35 * (1.0 - y / fy))

    # Silty seafloor with some texture.
    for y in range(fy, h):
        for x in range(w):
            n = (x * 7 + y * 13 + (x * x) // 5) % 9
            shade = 0.1 * (y - fy) + (0.12 if n == 0 else 0.0)
            buf[y * w + x] = mix((88, 82, 60), (40, 36, 28), shade)

    c = ctx(buf, w, h, 0, 0, 1)

    # Vauxia: branching tube sponges with open tips.
    for _ in range(random.number(1, 2)):
        bx = random.number(3, w - 4)
        col = rgb(196, 140, 80)
        tip = rgb(232, 196, 128)
        tall = random.number(6, 9)
        vline(c, bx, fy - 1, fy - tall, col)
        vline(c, bx - 2, fy - 3, fy - tall + 2, col)
        vline(c, bx + 2, fy - 4, fy - tall + 1, col)
        put(c, bx - 1, fy - 2, col)
        put(c, bx + 1, fy - 3, col)
        put(c, bx, fy - tall, tip)
        put(c, bx - 2, fy - tall + 2, tip)
        put(c, bx + 2, fy - tall + 1, tip)

    # Choia: spiky ball sponges.
    for _ in range(random.number(1, 2)):
        bx = random.number(2, w - 3)
        col = rgb(200, 190, 120)
        put(c, bx, fy - 1, col)
        put(c, bx - 1, fy - 2, col)
        put(c, bx + 1, fy - 2, col)
        put(c, bx, fy - 3, col)
        put(c, bx - 2, fy - 3, col)
        put(c, bx + 2, fy - 3, col)
        put(c, bx, fy - 2, rgb(150, 120, 80))

    # Margaretia: green algal fronds.
    for _ in range(random.number(1, 3)):
        bx = random.number(1, w - 2)
        tall = random.number(4, 8)
        for y in range(tall):
            put(c, bx + (1 if (y // 2) % 2 == 0 else 0), fy - y, rgb(70, 130, 70))

def buffer_to_widgets(buf, w, scale):
    """Collapse a dict frame buffer into horizontal runs of boxes."""
    children = []
    keys = sorted(buf.keys())
    i = 0
    n = len(keys)
    for _ in range(n):
        if i >= n:
            break
        k = keys[i]
        color = buf[k]
        y = k // w
        x = k % w
        run = 1
        for j in range(i + 1, n):
            k2 = keys[j]
            if k2 != k + run or k2 // w != y or buf[k2] != color:
                break
            run += 1
        i += run
        children.append(
            render.Padding(
                pad = (x * scale, y * scale, 0, 0),
                child = render.Box(width = run * scale, height = scale, color = color),
            ),
        )
    return children

# ---------------------------------------------------------------------------
# Actors
# ---------------------------------------------------------------------------

def make_actor(key, w, h, role):
    spec = CRITTERS[key]
    facing = 1 if random.number(0, 1) == 1 else -1
    fy = floor_y(h)
    hw = spec["half_w"]
    hh = spec["half_h"]
    habitat = spec["habitat"]

    if habitat == "floor":
        # Origin height so the feet rest on the top row of sand.
        y = {"hallucigenia": fy - 5, "trilobite": fy - 2, "wiwaxia": fy - 1}.get(key, fy - 1)
        x = random.number(hw // 2, max(hw // 2 + 1, w - hw // 2))
        speed = spec["speed"]
    elif habitat == "drift":
        y = random.number(hh, max(hh + 1, fy - hh - 2))
        x = random.number(4, w - 4)
        speed = spec["speed"]
    else:
        y = random.number(hh + 1, max(hh + 2, fy - hh - 2))
        if role == "featured":
            # Cross the whole screen during the animation, already nosing
            # into view on the first frame.
            x = -hw // 2 if facing == 1 else w + hw // 2
            speed = float(w + hw) / FRAMES
        else:
            x = random.number(0, w)
            speed = spec["speed"]

    return {
        "key": key,
        "x": float(x),
        "y": float(y),
        "facing": facing,
        "speed": speed,
        "habitat": habitat,
        "phase": random.number(0, 50),
        "bob": random.number(0, 100) / 16.0,
    }

def draw_actor(buf, w, h, a, frame):
    spec = CRITTERS[a["key"]]
    x = a["x"] + a["facing"] * a["speed"] * frame
    y = a["y"]
    if a.get("wrap"):
        # Companions loop around so they never leave the scene for good.
        hw = spec["half_w"]
        span = w + 2 * hw
        x = math.mod(x + hw, span)
        if x < 0:
            x += span
        x -= hw
    if a["habitat"] == "swim":
        y += math.sin(frame * 0.08 + a["bob"]) * 1.2
    elif a["habitat"] == "drift":
        y += math.sin(frame * 0.05 + a["bob"]) * 2.0
        x = a["x"] + math.sin(frame * 0.02 + a["bob"]) * 3.0
    c = ctx(buf, w, h, rnd(x), rnd(y), a["facing"])
    spec["draw"](c, frame + a["phase"])

def spread_swimmers(actors, h):
    """Give each swimmer its own depth band so they don't pile up."""
    swimmers = [a for a in actors if a["habitat"] == "swim"]
    if not swimmers:
        return
    fy = floor_y(h)
    lanes = list(range(len(swimmers)))

    # Shuffle the lanes.
    for i in range(len(lanes) - 1, 0, -1):
        j = random.number(0, i)
        lanes[i], lanes[j] = lanes[j], lanes[i]
    band = float(fy) / len(swimmers)
    for i, a in enumerate(swimmers):
        hh = CRITTERS[a["key"]]["half_h"]
        y = band * lanes[i] + band / 2
        a["y"] = float(clamp(rnd(y), hh + 1, fy - hh - 2))

def spread_walkers(actors, w):
    """Give each floor critter its own stretch of seafloor."""
    walkers = [a for a in actors if a["habitat"] == "floor"]
    if not walkers:
        return
    slots = list(range(len(walkers)))
    for i in range(len(slots) - 1, 0, -1):
        j = random.number(0, i)
        slots[i], slots[j] = slots[j], slots[i]
    band = float(w) / len(walkers)
    for i, a in enumerate(walkers):
        a["x"] = band * slots[i] + band / 2 + random.number(0, 4) - 2

def pick_companions(featured, count):
    pool = [k for k in CRITTER_ORDER if k != featured]
    chosen = []
    for _ in range(count):
        if not pool:
            break
        k = pool[random.number(0, len(pool) - 1)]
        pool = [p for p in pool if p != k]
        chosen.append(k)
    return chosen

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(config):
    width, height = canvas.size()
    scale = 2 if canvas.is2x() else 1
    w = width // scale
    h = height // scale

    choice = config.get("critter", "random")
    if choice not in CRITTERS:
        choice = CRITTER_ORDER[random.number(0, len(CRITTER_ORDER) - 1)]
    crowd = config.get("crowd", "some")
    show_name = config.bool("show_name", True)

    # Background: water, light shafts, seafloor, sponges.
    bg = {}
    draw_background(bg, w, h)
    bg_widget = render.Stack(children = buffer_to_widgets(bg, w, scale))

    # The featured critter crosses the scene; companions mill about.
    n_companions = {"none": 0, "some": 2, "lots": 3}.get(crowd, 2)
    if is_square():
        n_companions += 1
    actors = [make_actor(k, w, h, "companion") for k in pick_companions(choice, n_companions)]
    for a in actors:
        a["wrap"] = True
    actors.append(make_actor(choice, w, h, "featured"))
    spread_swimmers(actors, h)
    spread_walkers(actors, w)

    # Floor critters behind swimmers.
    order = {"floor": 0, "drift": 1, "swim": 2}
    actors = sorted(actors, key = lambda a: order[a["habitat"]])

    # Marine snow drifting down.
    flakes = []
    for _ in range(6 if is_square() else 4):
        flakes.append((random.number(0, w - 1), random.number(0, h - 1), random.number(3, 7)))
    fy = floor_y(h)

    label = None
    if show_name:
        font = "tb-8" if scale == 2 else "tom-thumb"
        name = CRITTERS[choice]["name"]

        # Drop shadow keeps the name readable over light shafts and critters.
        label = render.Stack(
            children = [
                render.Padding(
                    pad = (2 * scale, 2 * scale, 0, 0),
                    child = render.Text(name, font = font, color = "#04121c"),
                ),
                render.Padding(
                    pad = (1 * scale, 1 * scale, 0, 0),
                    child = render.Text(name, font = font, color = "#e8f1f2"),
                ),
            ],
        )

    frames = []
    for f in range(FRAMES):
        buf = {}
        for fx, fy0, period in flakes:
            yy = (fy0 + f // period) % fy
            xx = (fx + rnd(math.sin((f + fy0) * 0.07))) % w
            buf[yy * w + xx] = "#7f9fae"
        for a in actors:
            draw_actor(buf, w, h, a, f)
        children = [bg_widget] + buffer_to_widgets(buf, w, scale)

        # Show the name during the first part of the loop.
        if label != None and f < FRAMES // 3:
            children.append(label)
        frames.append(render.Stack(children = children))

    return render.Root(
        delay = DELAY_MS,
        show_full_animation = True,
        child = render.Animation(children = frames),
    )

def get_schema():
    critter_options = [schema.Option(display = "Random", value = "random")]
    for k in CRITTER_ORDER:
        critter_options.append(schema.Option(display = CRITTERS[k]["name"], value = k))

    return schema.Schema(
        version = "1",
        fields = [
            schema.Dropdown(
                id = "critter",
                name = "Featured critter",
                desc = "The critter that swims across the scene.",
                icon = "fish",
                default = "random",
                options = critter_options,
            ),
            schema.Dropdown(
                id = "crowd",
                name = "Other critters",
                desc = "How many other critters share the scene.",
                icon = "users",
                default = "some",
                options = [
                    schema.Option(display = "None", value = "none"),
                    schema.Option(display = "Some", value = "some"),
                    schema.Option(display = "Lots", value = "lots"),
                ],
            ),
            schema.Toggle(
                id = "show_name",
                name = "Show name",
                desc = "Show the featured critter's name at the start.",
                icon = "tag",
                default = True,
            ),
        ],
    )
