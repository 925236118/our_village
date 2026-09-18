"""Check a submitted character sheet against the activity spec.

Decodes the PNG in pure Python (no Pillow needed) and verifies that every
animation's frames are present in the columns the layout rules say.

Frames *beyond* those columns are not checked: the generator appends some
extra "说明帧" after each action, and the engine never reads that far.

    python tools/inspect_sheet.py entries/某人/char/sheet.png

Exit code 0 = pass, 1 = something is wrong.
Used by the host when reviewing PRs; contributors can run it too.
"""
import struct
import sys
import zlib

# Windows 控制台默认是 GBK，不强制成 UTF-8 的话中文输出会乱码
try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, OSError):
    pass

FRAME_W, FRAME_H = 48, 96
COLS, ROWS = 56, 20

# name -> (row, frames, dirs)  -- keep in sync with character_sheet.gd
ANIM = [
    ("static", 0, 1, "RULD"), ("idle", 1, 6, "RULD"), ("walk", 2, 6, "RULD"),
    ("sleep", 3, 6, "D"), ("sit", 4, 6, "RL"), ("sit_desk", 5, 6, "RL"),
    ("phone", 6, 12, "D"), ("read", 7, 12, "D"), ("push", 8, 6, "RULD"),
    ("pickup", 9, 12, "RULD"), ("gift", 10, 10, "RULD"), ("lift", 11, 14, "RULD"),
    ("throw", 12, 14, "RULD"), ("hit", 13, 6, "RULD"), ("punch", 14, 6, "RULD"),
    ("stab", 15, 6, "RULD"), ("grab_gun", 16, 4, "RULD"), ("gun_idle", 17, 6, "RULD"),
    ("shoot", 18, 3, "RULD"), ("hurt", 19, 3, "RULD"),
]


def read_png(path):
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    pos, idat, plte, trns = 8, b"", None, None
    w = h = bd = ct = None
    while pos < len(data):
        ln = struct.unpack(">I", data[pos:pos + 4])[0]
        typ = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + ln]
        if typ == b"IHDR":
            w, h, bd, ct, _c, _f, inter = struct.unpack(">IIBBBBB", body)
            if inter:
                raise ValueError("interlaced PNG is not supported")
            if bd != 8:
                raise ValueError("only 8-bit PNGs are supported")
        elif typ == b"PLTE":
            plte = body
        elif typ == b"tRNS":
            trns = body
        elif typ == b"IDAT":
            idat += body
        elif typ == b"IEND":
            break
        pos += 12 + ln

    ch = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ct]
    raw = zlib.decompress(idat)
    stride = w * ch
    alpha = bytearray(w * h)
    prev = bytearray(stride)

    def paeth(a, b, c):
        p = a + b - c
        pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
        return a if pa <= pb and pa <= pc else (b if pb <= pc else c)

    p = 0
    for y in range(h):
        f = raw[p]
        p += 1
        line = bytearray(raw[p:p + stride])
        p += stride
        if f:
            for i in range(stride):
                a = line[i - ch] if i >= ch else 0
                b = prev[i]
                c = prev[i - ch] if i >= ch else 0
                if f == 1:
                    line[i] = (line[i] + a) & 255
                elif f == 2:
                    line[i] = (line[i] + b) & 255
                elif f == 3:
                    line[i] = (line[i] + ((a + b) >> 1)) & 255
                else:
                    line[i] = (line[i] + paeth(a, b, c)) & 255
        row_off = y * w
        if ct == 6:
            for x in range(w):
                alpha[row_off + x] = line[x * 4 + 3]
        elif ct == 4:
            for x in range(w):
                alpha[row_off + x] = line[x * 2 + 1]
        elif ct == 3:
            for x in range(w):
                idx = line[x]
                alpha[row_off + x] = trns[idx] if trns and idx < len(trns) else 255
        else:
            alpha[row_off:row_off + w] = b"\xff" * w
        prev = line
    return w, h, alpha


def occupied(alpha, w, cx, cy):
    for y in range(cy, cy + FRAME_H, 2):
        base = y * w
        for x in range(cx, cx + FRAME_W, 2):
            if alpha[base + x] > 8:
                return True
    return False


def main(path):
    problems = []
    w, h, alpha = read_png(path)

    if (w, h) != (COLS * FRAME_W, ROWS * FRAME_H):
        problems.append(
            "尺寸是 %dx%d，应该是 %dx%d（是不是裁剪过了？请用生成器原始输出）"
            % (w, h, COLS * FRAME_W, ROWS * FRAME_H))
        report(path, w, h, alpha, problems)
        return 1

    extras = 0
    for name, row, frames, dirs in ANIM:
        expected = len(dirs) * frames
        for c in range(expected):
            if not occupied(alpha, w, c * FRAME_W, row * FRAME_H):
                problems.append(
                    "第 %d 行「%s」第 %d 帧是空的（这一行应该有 %d 帧）"
                    % (row + 1, name, c + 1, expected))
        # 规范帧右边的格子不检查。生成器会在动作后面附一些「说明帧」，
        # 引擎只读前 expected 列，多出来的内容不影响播放，不是错误。
        if any(occupied(alpha, w, c * FRAME_W, row * FRAME_H)
               for c in range(expected, COLS)):
            extras += 1

    report(path, w, h, alpha, problems, extras)
    return 1 if problems else 0


def report(path, w, h, alpha, problems, extras=0):
    print("%s  %dx%d -> %d cols x %d rows of %dx%d\n"
          % (path, w, h, w // FRAME_W, h // FRAME_H, FRAME_W, FRAME_H))
    print("     " + "".join(str(c // 10) if c % 10 == 0 else " " for c in range(COLS)))
    print("     " + "".join(str(c % 10) for c in range(COLS)))
    for r in range(ROWS):
        cells = "".join("#" if occupied(alpha, w, c * FRAME_W, r * FRAME_H) else "."
                        for c in range(COLS))
        print("%3d  %s" % (r, cells))
    print()
    if problems:
        print("发现 %d 个问题：" % len(problems))
        for p in problems:
            print("  - " + p)
    else:
        print("通过：所有动画的帧位都和规范一致。")
    if extras:
        print("（有 %d 行在规范帧后面还带着生成器附的说明帧，那些格子引擎不读，无视即可。）"
              % extras)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "sheet.png"))
