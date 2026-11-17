"""Optional public API key for CI builds; never requires a Last.fm API secret."""
import json
import os
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
destination = root / "App" / "Resources" / "BuildConfig.json"
destination.parent.mkdir(parents=True, exist_ok=True)
try:
    commit_hash = subprocess.check_output(
        ["git", "rev-parse", "--short=7", "HEAD"], cwd=root, stderr=subprocess.DEVNULL, text=True
    ).strip()
except (OSError, subprocess.CalledProcessError):
    commit_hash = "unknown"

destination.write_text(json.dumps({
    "lastFMAPIKey": os.environ.get("LASTFM_API_KEY", ""),
    "commitHash": commit_hash,
}), encoding="utf-8")
print("Build configuration written.")
