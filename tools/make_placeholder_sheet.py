"""Generate a placeholder character sheet (2688x1920) in pure Python.

Used to make entries/_example runnable before the real character generator
output is available. Also doubles as a reference implementation of the sheet
layout described in shared/character/character_sheet.gd.

    python tools/make_placeholder_sheet.py entries/_example/char/sheet.png
"""
import struct
import sys
import zlib

FRAME_W, FRAME_H = 48, 96
COLS, ROWS = 56, 20

# name -> (row, frames, dirs)  -- keep in sync with character_sheet.gd
ANIM = [
    ("static",   0,  1, "RULD"),
    ("idle",     1,  6, "RULD"),
    ("walk",     2,  6, "RULD"),
    ("sleep",    3,  6, "D"),
    ("sit",      4,  6, "RL"),
    ("sit_desk", 5,  6, "RL"),
    ("phone",    6, 12, "D"),
    ("read",     7, 12, "D"),
    ("push",     8,  6, "RULD"),
    ("pickup",   9, 12, "RULD"),
    ("gift",    10, 10, "RULD"),
    ("lift",    11, 14, "RULD"),
    ("throw",   12, 14, "RULD"),
    ("hit",     13,  6, "RULD"),
    ("punch",   14,  6, "RULD"),
    ("stab",    15,  6, "RULD"),
    ("grab_gun",16,  4, "RULD"),
    ("gun_idle",17,  6, "RULD"),
    ("shoot",   18,  3, "RULD"),
    ("hurt",    19,  3, "RULD"),
]
ORDER = "RULD"
SKIN = (233, 190, 155, 255)
SHIRT = {"R": (86, 132, 209, 255), "U": (209, 132, 86, 255),
         "L": (110, 190, 120, 255), "D": (190, 110, 170, 255)}

# 共享玩家用的配色，和参与者的占位图区分开
SHIRT_PLAYER = {"R": (72, 190, 190, 255), "U": (72, 190, 190, 255),
                "L": (72, 190, 190, 255), "D": (72, 190, 190, 255)}

VARIANTS = {"default": SHIRT, "player": SHIRT_PLAYER}


def write_png(path, w, h, px):
    raw = bytearray()
    stride = w * 4
    for y in range(h):
        raw.append(0)                      # filter type 0
        raw += px[y * stride:(y + 1) * stride]

    def chunk(tag, data):
        body = tag + data
        return (struct.pack(">I", len(data)) + body
                + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF))

    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)


def main(out_path, shirt=SHIRT):
    W, H = COLS * FRAME_W, ROWS * FRAME_H
    px = bytearray(W * H * 4)              # all transparent

    def put(x, y, rgba):
        if 0 <= x < W and 0 <= y < H:
            o = (y * W + x) * 4
            px[o:o + 4] = bytes(rgba)

    def rect(x0, y0, x1, y1, rgba):
        for yy in range(y0, y1):
            for xx in range(x0, x1):
                put(xx, yy, rgba)

    for name, row, frames, dirs in ANIM:
        offset = 0
        for d in ORDER:
            if d not in dirs:
                continue
            for f in range(frames):
                cx = (offset + f) * FRAME_W
                cy = row * FRAME_H
                # per-frame bob so the animation is visibly moving
                bob = [0, -2, -3, -2, 0, -1, 0, -1][f % 8] if frames > 1 else 0
                # torso
                rect(cx + 14, cy + 44 + bob, cx + 34, cy + 74 + bob, shirt[d])
                # head
                rect(cx + 16, cy + 22 + bob, cx + 32, cy + 44 + bob, SKIN)
                # eyes, placed on the side the character faces
                eye = {"R": (29, 31), "L": (17, 19), "U": (17, 31), "D": (21, 27)}[d]
                rect(cx + eye[0], cy + 30 + bob, cx + eye[1], cy + 33 + bob,
                     (40, 40, 50, 255))
                # legs alternate on even/odd frames
                if f % 2 == 0:
                    rect(cx + 16, cy + 74 + bob, cx + 22, cy + 92, (70, 70, 90, 255))
                    rect(cx + 26, cy + 74 + bob, cx + 32, cy + 90, (70, 70, 90, 255))
                else:
                    rect(cx + 15, cy + 74 + bob, cx + 21, cy + 90, (70, 70, 90, 255))
                    rect(cx + 27, cy + 74 + bob, cx + 33, cy + 92, (70, 70, 90, 255))
            offset += frames

    write_png(out_path, W, H, px)
    print("wrote %s  %dx%d  %d bytes" % (out_path, W, H, len(open(out_path, "rb").read())))


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "sheet.png"
    variant = sys.argv[2] if len(sys.argv) > 2 else "default"
    if variant not in VARIANTS:
        raise SystemExit("variant 只能是：%s" % "、".join(VARIANTS))
    main(out, VARIANTS[variant])
