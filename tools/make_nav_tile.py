"""生成共享的「导航瓦片」贴图。

导航层用的瓦片是半透明的：编辑器里能看见才画得准，
但游戏里它永远被地板盖住（NavLayer 放在地板下面），所以不会破坏画面。

    python tools/make_nav_tile.py

输出：shared/tileset/nav_tile.png（48x48，一格一张）
"""
import struct
import sys
import zlib

W = H = 48
CELL = 48  # 和角色帧同宽，和示例地图的 tile_size 保持一致

# 淡淡的青色底 + 稍亮一点的边框
FILL = (90, 200, 190, 56)
EDGE = (90, 200, 190, 110)


def rgba(x, y):
    if x == 0 or y == 0 or x == W - 1 or y == H - 1:
        return EDGE
    return FILL


def write_png(path, w, h, pixel):
    raw = bytearray()
    for y in range(h):
        raw.append(0)  # filter type 0
        for x in range(w):
            raw.extend(pixel(x, y))

    def chunk(tag, body):
        return (struct.pack(">I", len(body)) + tag + body
                + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    open(path, "wb").write(png)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "shared/tileset/nav_tile.png"
    write_png(out, W, H, rgba)
    print("wrote %s (%dx%d)" % (out, W, H))
