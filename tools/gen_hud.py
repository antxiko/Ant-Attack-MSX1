"""Generate the Ant Attack MSX1 bitmap HUD from the Spectrum layout."""
from pathlib import Path
import re
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "msx"
font_source = (ROOT / "tools" / "font8x8_basic.h").read_text()
glyphs = []
for block in re.findall(r"\{([^{}]+)\}", font_source):
    values = [int(x, 16) for x in re.findall(r"0x[0-9a-fA-F]{2}", block)]
    if len(values) == 8:
        glyphs.append([int(f"{row:08b}"[::-1], 2) for row in values])
if len(glyphs) != 128:
    raise ValueError("Unexpected HUD font")

# TheNestruo's edited sheet uses 8x8 cells for BOTH letters and digits.
# The old 3x7 row is deliberately blank. Keep the supplied PNG as the source.
font_sheet = Image.open(ROOT / "tipos_hud_todos_1x.png").convert("RGB")
if font_sheet.size != (208, 24):
    raise ValueError("Expected TheNestruo's 208x24 HUD sheet")
if set(font_sheet.getdata()) - {(0, 0, 0), (255, 255, 255)}:
    raise ValueError("HUD font must be pure black and white")
for chars, y in (("ABCDEFGHIJKLMNOPQRSTUVWXYZ", 0), ("0123456789", 8)):
    for index, char in enumerate(chars):
        glyphs[ord(char)] = [sum((0x80 >> x) for x in range(8)
                                    if font_sheet.getpixel((index * 8 + x, y + row))[0])
                             for row in range(8)]

# Center each digit's ink in its eight-pixel slot. Thus four slots occupy
# the complete 32-pixel TIME interior without inheriting the sheet's left bias.
for char in "0123456789":
    rows = glyphs[ord(char)]
    occupied = [x for bits in rows for x in range(8) if bits & (0x80 >> x)]
    left, right = min(occupied), max(occupied)
    shift = (8 - (right - left + 1)) // 2 - left
    glyphs[ord(char)] = [bits >> shift if shift >= 0 else bits << -shift for bits in rows]

# Only the fixed header (0..7) and footer (128..191) are stored.
pixels = bytearray(72 * 32)
colors = bytearray([0xF1] * (72 * 32))


def line(y: int) -> int:
    return y if y < 8 else y - 120


def row_color(x0: int, x1: int, y: int, value: int) -> None:
    offset = line(y) * 32
    for x in range(x0 // 8, (x1 + 7) // 8):
        colors[offset + x] = value


def rect(x0: int, y0: int, x1: int, y1: int, color: int) -> None:
    for y in range(y0, y1):
        for x in range(x0, x1):
            pos = line(y) * 32 + x // 8
            if color:
                pixels[pos] |= 0x80 >> (x & 7)
            else:
                pixels[pos] &= ~(0x80 >> (x & 7))


def label(x: int, y: int, value: str) -> None:
    for char in value:
        for dy, bits in enumerate(glyphs[ord(char)]):
            for dx in range(8):
                if bits & (0x80 >> dx):
                    rect(x + dx, y + dy, x + dx + 1, y + dy + 1, 1)
        x += 8


def centered_label(panel_x: int, value: str) -> None:
    occupied = [i * 8 + x for i, char in enumerate(value)
                for bits in glyphs[ord(char)] for x in range(8)
                if bits & (0x80 >> x)]
    left, right = min(occupied), max(occupied)
    # Center the visible ink, rather than the number of allocated tiles.
    x = panel_x + (48 - (right - left + 1)) // 2 - left
    label(x, 166, value)


# Frame source: piiixl, Frames 1-Bit, CC BY 4.0:
# https://piiixl.itch.io/frames-1-bit
# Adapted 8x8 tiles from the 32x32 frame at (48,208), recolored in the HUD.
frame_sheet = Image.open(ROOT / "frames 1-bit.png").convert("RGBA")
if frame_sheet.size != (512, 512):
    raise ValueError("Unexpected frame sheet size")


def frame_tile(dst_x: int, dst_y: int, src_x: int, src_y: int) -> None:
    for dy in range(8):
        for dx in range(8):
            x, y = dst_x + dx, dst_y + dy
            pos = line(y) * 32 + x // 8
            bit = 0x80 >> (x & 7)
            if frame_sheet.getpixel((src_x + dx, src_y + dy))[0] > 128:
                pixels[pos] |= bit
            else:
                pixels[pos] &= ~bit


def hud_frame(x: int) -> None:
    for col in range(6):
        src_x = 48 if col == 0 else 72 if col == 5 else 56
        dst_x = x + col * 8
        frame_tile(dst_x, 140, src_x, 208)
        frame_tile(dst_x, 156, src_x, 232)
    frame_tile(x, 148, 48, 216)
    frame_tile(x + 40, 148, 72, 216)


# Spectrum header: scores in white on black.
label(8, 0, "SCORE:")
label(136, 0, "RESCUED:")

# Magenta rail and five black panels using the source frame tiles.
for y in range(128, 192):
    row_color(0, 256, y, 0xF1)
for y in range(132, 139):
    row_color(8, 248, y, 0xD1)
rect(8, 133, 248, 139, 1)
for x in range(8, 248, 16):
    rect(x, 132, x + 8, 133, 1)

for index, name in enumerate(("AMMO", "GIRL", "BOY", "TIME", "SCAN")):
    x = 8 + 48 * index
    for y in range(140, 148):
        row_color(x, x + 48, y, 0xD1)
    for y in range(148, 156):
        row_color(x, x + 8, y, 0xD1)
        row_color(x + 40, x + 48, y, 0xD1)
    for y in range(156, 164):
        row_color(x, x + 48, y, 0xD1)
    hud_frame(x)
    for y in range(166, 174):
        row_color(x + 8, x + 40, y, 0xD1)
    centered_label(x, name)

# The scanner uses sprites so its red/green color does not recolor the frame.

if len(pixels) != 2304 or len(colors) != 2304:
    raise ValueError("HUD size changed")
# SCREEN 2 stores eight scanlines of each 8x8 cell together, then the next
# cell. The drawing helpers above use ordinary scanline order.
def screen2_order(source: bytearray) -> bytes:
    return bytes(source[(band * 8 + row) * 32 + col]
                 for band in range(9) for col in range(32) for row in range(8))


(SRC / "hud_patterns.bin").write_bytes(screen2_order(pixels))
(SRC / "hud_colors.bin").write_bytes(screen2_order(colors))
# All lower HUD counters use the same 8x8 source. The visible seven rows
# stay at y=148..154; border rows at 144 and 159 must survive each update.
font_lines = ["; TheNestruo HUD font, generated from tipos_hud_todos_1x.png"]
font_lines.append("font_header_digits:")
for char in "0123456789":
    font_lines.append(" db " + ",".join(f"0{v:02X}h" for v in glyphs[ord(char)]))
for name in ("font_hud_digits", "font_time_first", "font_time_middle", "font_time_last"):
    font_lines.append(name + ":")
for char in "0123456789":
    rows = glyphs[ord(char)]
    assert rows[7] == 0, "Lower HUD currently reserves seven visible rows"
    values = [0xFF, 0, 0, 0] + rows[:7] + [0] * 4 + [0xFF]
    assert len(values) == 16
    font_lines.append(" db " + ",".join(f"0{v:02X}h" for v in values))
(SRC / "hud_digits.inc").write_text("\n".join(font_lines) + "\n")
print("wrote HUD patterns and colors using TheNestruo font")
