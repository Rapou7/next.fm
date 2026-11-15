"""Optional public API key for CI builds; never requires a Last.fm API secret."""
import json
import os
from pathlib import Path

destination = Path(__file__).resolve().parents[1] / "App" / "Resources" / "BuildConfig.json"
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps({"lastFMAPIKey": os.environ.get("LASTFM_API_KEY", "")}), encoding="utf-8")
print("Build configuration written.")
