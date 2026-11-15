"""Generate next.fm's original geometric waveform icon with the Python standard library."""
from pathlib import Path
import math
import struct
import zlib

size = 1024
rows = bytearray()
bars = [(304, 138), (408, 244), (512, 336), (616, 210), (720, 116)]
for y in range(size):
    rows.append(0)
    for x in range(size):
        blend = (x + y) / (2 * size)
        color = [int(248 - blend * 52), int(55 - blend * 30), int(111 + blend * 12)]
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
target = Path(__file__).resolve().parents[1] / 'App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
target.parent.mkdir(parents=True, exist_ok=True)
target.write_bytes(png)
print('Generated AppIcon.png')
