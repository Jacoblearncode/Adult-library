# Downloader tool

Small local web UI: paste a link, pick a category, and it either downloads
the video via `yt-dlp` (only works for sites yt-dlp actually supports) or
falls back to a link-only entry. Every attempt (downloaded or link-only) is
logged to `link_entries.json` and shown in one searchable history table on
the home page, with stat cards for downloaded count / link-only count /
library size against the cap, and a remove button per row.

Runs entirely on `localhost` — do not expose this port beyond your machine
or your private Tailscale network.

## Setup

1. Install Python 3.10+ if you don't have it.
1b. Install [ffmpeg](https://www.gyan.dev/ffmpeg/builds/) and make sure it's
    on your PATH. Needed for merging video+audio into mp4, extracting audio,
    and embedding source metadata into the file (see below) — without it,
    downloads may still work for some sites but skip these steps.
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

## Batch mode

Go to http://localhost:5050/batch to paste a list of URLs you've already
picked out while browsing (one per line). Optionally set a category per
line as `url, category`; lines without one use the default category you
pick on the form. This is meant for links *you* selected by hand — it does
not search or scrape anything on its own, it just runs each URL through the
same download-or-link logic in one batch instead of one at a time.

## How it decides download vs link-only

- Tries `yt-dlp` extraction first (no download yet, just a probe).
- If yt-dlp doesn't recognize the site, it tries one more thing: a **direct
  file fallback**. If the URL points straight at an actual video file (by
  extension, or the server reports a `video/*` content type), it downloads
  that file directly with a plain HTTP request — no scraping, it only ever
  fetches the exact URL you gave it, same as pasting it into a browser.
  This covers self-hosted clips, direct CDN links, and smaller sites yt-dlp
  has no extractor for.
- If neither works, or the estimated file size would push the library over
  the configured cap, it logs a **link-only** entry instead.
- The `.download-archive.txt` file (yt-dlp's own dedup mechanism) prevents
  re-downloading the same video twice.

## Download queue

Adding a link or a batch no longer blocks the page while the download runs
— it queues the job and redirects to **/queue**, where a single background
worker processes downloads one at a time. The queue page auto-refreshes
every 3 seconds while anything is queued or running. Queue state is
in-memory only (cleared on restart) — the actual download history in
`link_entries.json` is unaffected.

## Folder-style categories

Categories can be nested with "/", e.g. `favorites/holiday` — this maps
directly to `<library_root>/favorites/holiday/` on disk, and Stash's own
folder scanning picks up the same structure. The home page shows folder
chips (top-level only) to quickly filter the history table.

## Pushing link-only entries into Stash

Once `stash_url` and `stash_api_key` are set in `config.json` (see
`STASH_SETUP.md` for getting an API key), each link-only row in the history
table gets a **"Push to Stash"** button. This creates a URL-only scene in
Stash via its GraphQL API — no file, just title/URL/category metadata — so
it shows up in Stash's browsing grid as a title card. Once pushed, the row
is marked "In Stash" and won't be pushed again.

**Finding the source link in Stash**: since there's no video file, there's
nothing to play — open the scene and the source URL is the **first line of
the description**, right under the title (Stash's structured "urls" field
also gets it, but isn't surfaced prominently for file-less scenes, so the
description is the reliable place to look). This only applies to scenes
pushed after this was added — anything pushed earlier needs re-pushing to
pick up the improved description.

## Download quality and source tracking

- Pick a quality per link (Best / 1080p max / 720p max / Audio only) on
  either the single-add or batch form; batch lines can also override it
  individually as `url, category, quality`.
- Downloads are normalized to mp4 (or mp3 for audio-only) for consistent
  playback.
- Every download writes a `<title>.info.json` sidecar next to the video
  with the full source metadata (including the original URL), and embeds
  a `purl` metadata tag with the source URL directly into the video file
  itself — so you can recover where a video came from even if it's moved
  or renamed later, or if `link_entries.json` itself is ever lost. The
  history table also shows a direct "source" link and the saved file path
  per entry.
- After a download, the tool checks the file actually exists and isn't
  empty before marking it "downloaded" — if postprocessing silently failed
  (e.g. ffmpeg missing), it logs a link-only entry with a note instead of
  a false success.

## After downloading

Files land in `<library_root>/<category>/`. Run a **Scan** in Stash to pick
them up and get real thumbnails.

## Link-only export (`link_only.txt`)

A plain-text file in this folder that always reflects the current
link-only entries — grouped by category, with title/URL/note/pushed
status per entry. It's **auto-generated and rewritten on every add,
delete, or push** (via `save_link_entries()`), so it's always current
without clicking anything. Don't edit it by hand — your changes would be
overwritten on the next mutation. Open it in Notepad any time you want a
readable list of everything that couldn't be downloaded, e.g. to review
later or copy elsewhere.

## Duplicate detection and retry

- Adding a URL that's already in history is skipped under "Auto" mode — you
  get a warning message telling you its existing status instead of a
  duplicate entry. Pick "Force download attempt" (single add) if you really
  want to add it again anyway; batch mode follows the same rule per line
  and reports how many were skipped.
- Every link-only row gets a **Retry** button — re-queues the same URL
  (same category/quality) for another attempt instead of you having to
  copy-paste it back into the form. Useful for transient failures like
  connection resets.
- A **"Push all link-only to Stash"** button above the history table pushes
  every not-yet-pushed link-only entry in one click instead of one row at a
  time.
- Push/retry/delete results now show as a message banner on the page
  instead of only printing to the terminal.

## Status filter

Next to the search box, a dropdown filters the history table to just
Downloaded or just Link-only entries, on top of the existing folder chips
and text search.

## Locking it down with basic auth

Off by default so a fresh install just works. Set `auth_username` and
`auth_password` in `config.json` to require a login before the app will
respond to anything — do this before ever exposing the app beyond
localhost (e.g. over Tailscale to share with a friend), same as the
Security step in `STASH_SETUP.md`.

## One-click launcher

`start.bat` in the repo root starts Stash, starts this app, and opens both
in your browser. Edit the `STASH_EXE` path at the top of the file once to
match where you installed Stash, then just double-click it going forward.
