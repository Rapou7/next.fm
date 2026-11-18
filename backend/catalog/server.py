"""Read-only WSGI endpoint for the versioned catalog produced by build.py."""
from bisect import bisect_left, bisect_right
from functools import lru_cache
from itertools import accumulate
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import unicodedata
import zlib

ROOT = Path(os.environ.get("CATALOG_DIR", "/catalog"))
MANIFEST = json.loads((ROOT / "manifest.json").read_text())
if MANIFEST["version"] != 1:
    raise ValueError("Unsupported catalog")

MASK = (1 << 64) - 1


def digest(text):
    return int.from_bytes(hashlib.md5(text.encode(), usedforsecurity=False).digest()[8:], "little")


def normalize(text):
    value = unicodedata.normalize("NFC", text).lower()
    return " ".join("".join(c if unicodedata.category(c)[0] in "LMN" else " " for c in value).split())


@lru_cache(maxsize=512)
def directory(path):
    with path.open("rb") as f:
        f.seek(-8, 2)
        start, = struct.unpack("<Q", f.read(8))
        f.seek(start)
        entries = list(struct.iter_unpack("<QQ", f.read(path.stat().st_size - start - 8)))
    return [x[0] for x in entries], [x[1] for x in entries] + [start]


def candidates(kind, key):
    path = ROOT / f"{kind}-{key >> 56:02x}.bin"
    if path.name not in MANIFEST["files"]:
        return
    keys, offsets = directory(path)
    first = max(0, bisect_left(keys, key) - 1)
    last = bisect_right(keys, key)
    with path.open("rb") as f:
        for block in range(first, last):
            f.seek(offsets[block])
            data = zlib.decompress(f.read(offsets[block + 1] - offsets[block]))
            n = len(data) // (20 if kind == "name" else 12)
            decoded = list(accumulate(struct.unpack_from(f"<{n}Q", data)))
            for i in range(bisect_left(decoded, key), bisect_right(decoded, key)):
                album = struct.unpack_from("<Q", data, 8*n + 8*i)[0] if kind == "name" else None
                ms = struct.unpack_from("<I", data, len(data) - 4*n + 4*i)[0]
                yield album, ms


def resolve(item):
    if not isinstance(item, dict) or set(item) - {"spotify_id", "artist", "title", "album"}:
        raise ValueError
    if any(not isinstance(v, str) or len(v) > 512 for v in item.values()):
        raise ValueError
    spotify_id = item.get("spotify_id")
    if spotify_id is not None and not re.fullmatch("[a-zA-Z0-9]{22}", spotify_id):
        raise ValueError
    durations = {ms for _, ms in candidates("id", digest(spotify_id))} if spotify_id else set()
    match = "spotify_id"
    if not durations:
        artist = normalize(item.get("artist", ""))
        title = normalize(item.get("title", ""))
        if not (artist and title):
            return {"status": "missing"}
        a = digest(artist)
        key = digest(title) ^ ((a >> 17) | ((a << 47) & MASK))
        rows = list(candidates("name", key))
        album = normalize(item.get("album", ""))
        album_key = digest(album) if album else None
        durations = {ms for al, ms in rows if al == album_key}
        match = "artist_title_album"
        if not durations:
            durations = {ms for _, ms in rows}
            match = "artist_title"
    if not durations:
        return {"status": "missing"}
    ordered = sorted(durations)
    if ordered[-1] - ordered[0] > 5000:
        return {"status": "ambiguous", "matched_by": match,
                "min_ms": ordered[0], "max_ms": ordered[-1]}
    return {"status": "matched", "matched_by": match, "duration_ms": ordered[len(ordered)//2]}


def application(env, start_response):
    path, method = env["PATH_INFO"], env["REQUEST_METHOD"]
    status = "200 OK"
    if (method, path) == ("GET", "/health"):
        body = {"status": "ok", "rows": MANIFEST["rows"]}
    elif (method, path) == ("POST", "/v1/durations"):
        try:
            size = int(env.get("CONTENT_LENGTH") or "0")
            if not 0 < size <= 65536:
                status, body = "413 Payload Too Large", {"error": "body_size"}
            else:
                items = json.loads(env["wsgi.input"].read(size))
                if not isinstance(items, list) or not 1 <= len(items) <= 100:
                    raise ValueError
                results = []
                for item in items:
                    try:
                        results.append(resolve(item))
                    except ValueError:
                        results.append({"status": "invalid"})
                body = {"results": results}
        except (ValueError, RecursionError):
            status, body = "400 Bad Request", {"error": "invalid_batch"}
    else:
        status, body = "404 Not Found", {"error": "not_found"}
    data = json.dumps(body, separators=(",", ":")).encode()
    start_response(status, [("Content-Type", "application/json"), ("Content-Length", str(len(data)))])
    return [data]
