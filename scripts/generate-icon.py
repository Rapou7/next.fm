"""Generate next.fm's original geometric waveform icon with the Python standard library."""
from pathlib import Path
import math
import struct
import zlib

size = 1024
rows = bytearray()
bars = [(304, 172), (408, 305), (512, 420), (616, 262), (720, 145)]
for y in range(size):
    rows.append(0)
    for x in range(size):
        blend = (x + y) / (2 * size)
        color = [int(98 - blend * 54), int(42 - blend * 26), int(164 - blend * 78)]
        for center, height in bars:
            dx = max(abs(x - center) - 4, 0)
            dy = max(abs(y - 512) - (height / 2 - 32), 0)
            distance = math.hypot(dx, dy)
            coverage = min(1, max(0, 33 - distance))
            if coverage:
                color = [int(c * (1 - coverage) + 255 * coverage) for c in color]
                break
        rows.extend(color)

def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)

png = b'\x89PNG\r\n\x1a\n'
png += chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b'')
assets = Path(__file__).resolve().parents[1] / 'App/Resources/Assets.xcassets'
for relative_path in ('AppIcon.appiconset/AppIcon.png', 'BrandIcon.imageset/BrandIcon.png'):
    target = assets / relative_path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(png)
    print(f'Generated {target.name}')
