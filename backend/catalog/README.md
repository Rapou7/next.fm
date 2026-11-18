# Duration catalog

The builder reads the public-catalog Parquet tables named in the command below. It produces compressed, sorted lookup indexes for Spotify track IDs and normalized artist/title pairs. Album fingerprints distinguish releases. Lookup data consists of fingerprints and track lengths. The input files stay intact. Artwork, image URLs, user data and streaming history are outside the catalog.

On a build machine with Python, DuckDB 2.0, NumPy and PyArrow, run:

```sh
python build.py /path/to/parquet /path/to/new-catalog
```

Use a new output directory and allow extra space for the temporary DuckDB staging file and sort spill. The input directory must contain tracks.parquet, track_artists.parquet, albums.parquet and artists.parquet. Transfer the completed binary shards and manifest.json together. Verify their SHA-256 hashes against the manifest before starting a container or switching to a new catalog.

Set CATALOG_PATH in the Compose environment to the completed catalog directory, then run:

```sh
docker compose up -d --build --wait
curl http://127.0.0.1:18743/health
curl -H 'Content-Type: application/json' http://127.0.0.1:18743/v1/durations \
  -d '[{"artist":"Yung Beef","title":"RELIGION","album":"RELIGION"},{"spotify_id":"2l3lnbVgoal5DDx0gBALpl"}]'
```

Results follow request order. Each item can supply a Spotify track ID, artist and title, or both. Album is optional. The server prefers an ID, then a matching album, then the artist/title pair. When distinct candidate durations span at most five seconds, it returns an observed median candidate. Larger spreads return an ambiguous result with the range. A missing result indicates no matching duration. The service accepts up to 100 items per request and a maximum body of 64 KiB.

The Compose service binds IPv4 loopback on port 18743 and mounts the catalog read-only. Clients on other machines can use SSH port forwarding. The public nextfm.panxo.eu.org endpoint uses nextfm.nginx.conf with TLS, per-address and service-wide rate and concurrency limits. Requests cost one quota unit per batch of up to 100 items. Request bodies are buffered before proxying. The public virtual host exposes only the lookup route and disables access logging. The iPhone uses anonymous, opt-in lookups. Catalog updates require a new build and container recreation with the new CATALOG_PATH.
