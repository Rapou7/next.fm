"""Regression checks for binary block boundaries and version-aware resolution."""
import importlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import numpy as np

from build import save_shard


class CatalogTest(unittest.TestCase):
    def test_duplicate_keys_across_blocks_and_album_selection(self):
        from hashlib import md5

        def fingerprint(value):
            return int.from_bytes(md5(value.encode()).digest()[8:], "little")

        artist = fingerprint("artist")
        key = fingerprint("title") ^ ((artist >> 17) | ((artist & 131071) << 47))
        album = fingerprint("edition")
        with tempfile.TemporaryDirectory() as folder, patch.dict(os.environ, CATALOG_DIR=""):
            root = Path(folder)
            os.environ["CATALOG_DIR"] = folder
            keys = np.full(2050, key, dtype="<u8")
            albums = np.arange(2050, dtype="<u8")
            albums[-1] = album
            durations = np.arange(2050, dtype="<u4") + 180000
            durations[-1] = 200000
            save_shard(root, "name", key >> 56, [[keys, albums, durations]])
            files = {p.name: "" for p in root.glob("*.bin")}
            (root / "manifest.json").write_text(json.dumps({"version": 1, "files": files, "rows": {}}))
            server = importlib.import_module("server")
            with patch.object(server, "ROOT", root), patch.object(server, "MANIFEST", {"files": files}):
                item = {"artist": "ARTIST", "title": "Title"}
                self.assertEqual(server.resolve(item)["status"], "ambiguous")
                self.assertEqual(server.resolve(dict(item, album="Edition"))["duration_ms"], 200000)
                self.assertEqual(server.resolve(dict(item, title="Silent"))["status"], "missing")


if __name__ == "__main__":
    unittest.main()
