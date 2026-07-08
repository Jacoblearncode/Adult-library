# Downloader tool

Small local web UI: paste a link, pick a category, and it either downloads
the video via `yt-dlp` (only works for sites yt-dlp actually supports) or
falls back to a link-only entry logged in `link_entries.json`.

Runs entirely on `localhost` — do not expose this port beyond your machine
or your private Tailscale network.

## Setup

1. Install Python 3.10+ if you don't have it.
2. From this folder:
   ```
   pip install -r requirements.txt
   copy config.example.json config.json
   ```
3. Edit `config.json`:
   - `library_root`: your actual media folder (same one Stash scans),
     e.g. `D:/Library/Videos`
   - `max_library_bytes`: hard cap on total library size before it refuses
     to download further (default in the example = 100 GB)
   - `categories`: starter list shown in the dropdown; you can always type
     a new one in the form
4. Run it:
   ```
   python app.py
   ```
5. Open http://localhost:5050

## How it decides download vs link-only

- Tries `yt-dlp` extraction first (no download yet, just a probe).
- If the site isn't supported (most adult tube sites won't be, by yt-dlp's
  own policy), or the estimated file size would push the library over the
  configured cap, it automatically logs a **link-only** entry instead.
- The `.download-archive.txt` file (yt-dlp's own dedup mechanism) prevents
  re-downloading the same video twice.

## After downloading

Files land in `<library_root>/<category>/`. Run a **Scan** in Stash to pick
them up. Link-only entries currently just live in `link_entries.json` —
manually add them as URL-only scenes in Stash for now; a future step could
push them into Stash automatically via its GraphQL API.
