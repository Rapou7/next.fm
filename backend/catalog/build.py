"""Build a read-only catalog. Requires DuckDB, PyArrow and NumPy on the build machine."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import zlib

import duckdb
import numpy as np


def save_shard(folder, kind, prefix, batches):
    columns = [np.concatenate(parts) for parts in zip(*batches)]
    path = folder / f"{kind}-{prefix:02x}.bin"
    partial = path.with_suffix(".part")
    index = bytearray()
    with partial.open("wb") as out:
        for i in range(0, len(columns[0]), 1024):
            keys, *values = [c[i:i + 1024] for c in columns]
            index.extend(struct.pack("<QQ", int(keys[0]), out.tell()))
            delta = keys.copy()
            delta[1:] -= keys[:-1]
            payload = b"".join(c.tobytes() for c in (delta, *values))
            out.write(zlib.compress(payload, 2))
        offset = out.tell()
        out.write(index)
        out.write(struct.pack("<Q", offset))
    os.replace(partial, path)


def emit(db, folder, kind, query):
    reader = db.sql(query).to_arrow_reader(262144)
    prefix = None
    batches = []
    count = 0
    for batch in reader:
        cols = [np.asarray(col, dtype=dt) for col, dt in zip(batch.columns,
                (["<u8", "<u8", "<u4"] if kind == "name" else ["<u8", "<u4"]))]
        prefixes = cols[0] >> 56
        bounds = np.r_[0, np.flatnonzero(np.diff(prefixes)) + 1, len(prefixes)]
        for start, end in zip(bounds[:-1], bounds[1:]):
            new = int(prefixes[start])
            if new != prefix and batches:
                save_shard(folder, kind, prefix, batches)
                batches = []
            prefix = new
            batches.append([c[start:end] for c in cols])
        count += len(prefixes)
    if batches:
        save_shard(folder, kind, prefix, batches)
    print(kind, count, flush=True)
    return count


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    folder = args.destination.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    db = duckdb.connect(str(folder / "stage.duckdb"))
    db.execute("SET threads=6")
    db.execute("SET memory_limit='9GB'")
    db.execute("SET preserve_insertion_order=false")
    for table in ["tracks", "albums", "artists", "track_artists"]:
        db.read_parquet(str(args.source / (table + ".parquet"))).create_view(table)
    db.execute(r"""CREATE MACRO norm(s) AS trim(regexp_replace(lower(nfc_normalize(s)),
        '[^\p{L}\p{M}\p{N}]+', ' ', 'g'))""")
    db.execute("""CREATE TABLE a AS SELECT rowid, md5_number_lower(norm(name)) artist
        FROM artists WHERE name IS NOT NULL AND norm(name) <> ''""")
    db.execute("""CREATE TABLE al AS SELECT rowid, md5_number_lower(norm(name)) album
        FROM albums WHERE name IS NOT NULL AND norm(name) <> ''""")
    print("Artist and album mappings ready", flush=True)
    db.execute("""CREATE TABLE t AS SELECT t.rowid rid, md5_number_lower(id) idkey,
        md5_number_lower(norm(t.name)) title, coalesce(al.album, 0::UBIGINT) album,
        duration_ms::UINTEGER ms FROM tracks t LEFT JOIN al ON al.rowid=t.album_rowid
        WHERE duration_ms BETWEEN 1 AND 4294967295 AND id IS NOT NULL AND t.name IS NOT NULL""")
    print("Track mappings ready", flush=True)
    finish(db, folder)


def finish(db, folder):
    counts = {}
    counts["id"] = emit(db, folder, "id", "SELECT idkey, ms FROM t ORDER BY idkey, ms")
    counts["name"] = emit(db, folder, "name", """SELECT DISTINCT
        xor(t.title, (a.artist >> 17) | ((a.artist & 131071) << 47)) k,
        t.album, t.ms FROM t JOIN track_artists ta ON ta.track_rowid=t.rid
        JOIN a ON a.rowid=ta.artist_rowid ORDER BY k, t.album, t.ms""")
    db.close()
    (folder / "stage.duckdb").unlink()
    files = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(folder.glob("*.bin"))}
    (folder / "manifest.json").write_text(json.dumps(dict(version=1, rows=counts, files=files)), encoding="utf-8")


if __name__ == "__main__":
    main()
