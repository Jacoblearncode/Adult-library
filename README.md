# Personal Media Library — Project Plan

A **local-first, private** media library for organizing videos on my own device(s).
Not a public website. Access is restricted to me and, optionally, specific friends
over a private VPN (Tailscale) — never exposed to the public internet.

## Guiding principles

- **Local-first**: files live on my disk, not a cloud host.
- **Link over download**: prefer storing a URL/metadata entry over downloading
  and storing the full file, unless I actually want an offline copy.
- **No public exposure**: no public cloud hosting, no port-forwarding to the
  open internet. Sharing = private VPN only, with auth.
- **Simple now, extensible later**: start with the smallest working setup,
  keep pieces swappable (e.g. binary → Docker later if needed).

---

## Part 1 — Core library app (Stash)

Using [Stash](https://github.com/stashapp/stash) as the media organizer
instead of building one from scratch. Handles scanning, tagging, thumbnails,
scrapers, and URL-only entries out of the box.

### Setup checklist

- [ ] Follow `STASH_SETUP.md` for a full beginner walkthrough (Windows,
      no Docker) — install, first scan, security, and getting an API key
- [ ] Download the prebuilt Stash binary for Windows from the
      [releases page](https://github.com/stashapp/stash/releases) (no Docker needed)
- [ ] Create a media folder to act as the library root (e.g. `D:\Library\Videos`)
- [ ] Run the `.exe`, open `http://localhost:9999`, complete the first-run wizard
- [ ] Point Stash at the media folder as a **Library**
- [ ] Run an initial **Scan** to confirm it picks up test files
- [ ] Confirm the **SQLite database** location (this holds all tags/metadata —
      separate from the video files)
- [ ] Add one **URL-only scene** manually (no file) to confirm that workflow
- [ ] Settings → Security → set a **username/password** (do this before any
      remote access)
- [ ] Decide a rough **tagging convention** (categories, performers, whatever
      matters) before the library grows
- [ ] Set up a **backup routine** for the Stash database file specifically

### Later / optional

- [ ] Enable a metadata **scraper** plugin for auto-tagging (skip if manual
      tagging is fine)
- [ ] Migrate to **Docker** if I want easier updates or to run companion
      containers later
- [ ] DLNA / cast-to-TV setup

### Restricted sharing with a friend

- [ ] Install [Tailscale](https://tailscale.com) (free tier) on my machine
- [ ] Install Tailscale on friend's device, add to my private tailnet
- [ ] Share the Stash URL over the Tailscale IP — never a public address
- [ ] Confirm basic auth is required before sharing access

---

## Part 2 — Download workflow (planning)

**Goal**: an easy way to either (a) download a video for offline storage, or
(b) save it as a link-only entry in Stash — with some way to pick
category/type/length/style before deciding which.

### Reality check on tooling

- [`yt-dlp`](https://github.com/yt-dlp/yt-dlp) is the standard free/open-source
  downloader, but its maintainers deliberately **do not support most
  mainstream adult tube sites** (long-standing project policy). It works for:
  - sites with an official supported extractor (e.g. Vimeo, some
    creator/self-hosted platforms)
  - my own content, or content from platforms that explicitly provide a
    download feature/API
- There is **no general-purpose legitimate tool** that downloads from
  arbitrary adult tube sites against their ToS — treat "download" as the
  *exception* path, not the default.
- **Default path = link-only entry** in Stash (matches what I wanted anyway:
  not storing everything).

### Planned architecture

1. **Download tool**: plain `yt-dlp` CLI for the sites it actually supports.
   No Docker required — single executable, cross-platform.
2. **Folder convention**: downloads land in a structured path so Stash
   auto-organizes on scan, e.g.
   ```
   D:\Library\Videos\<category>\<title>.mp4
   ```
3. **Selection step (category/type/length/style)**: before running a
   download, decide the category/tag — simplest version is just picking the
   destination subfolder; a nicer version later is a small local script/UI
   that:
   - takes a pasted link
   - lets me pick category/tags from a dropdown
   - calls `yt-dlp` (if supported) *or* creates a link-only entry directly
     in Stash via its API if not
4. **Stash API integration** (future): Stash exposes a GraphQL API — a small
   script could create scenes (file-based or URL-only) directly with tags
   pre-filled, instead of relying on manual entry + scrapers.

### Checklist

- [x] Build a local tool: paste link → pick category → download (if
      supported) or link-only fallback — see `tools/downloader/`
- [x] Enforce a 100 GB library size cap before any download
- [x] Use yt-dlp's `--download-archive` to avoid duplicate downloads
- [x] Batch mode: paste a list of self-picked URLs at `/batch` instead of
      one at a time (deliberately does not search/scrape on its own — see
      note below on why)
- [ ] Install Python + dependencies and do first real run
      (`tools/downloader/README.md` has setup steps)
- [ ] Test it against one or two sites it actually supports
- [ ] Point `config.json`'s `library_root` at the same folder Stash scans
- [ ] For unsupported sites (most adult tube sites): confirm link-only
      entries land correctly in `link_entries.json`
- [x] Folder-style nested categories (`favorites/holiday`) mapping to real
      subfolders on disk, with folder-chip filtering in the UI
- [x] Push link-only entries into Stash as URL-only scenes via its GraphQL
      API, once `stash_url` / `stash_api_key` are set in `config.json`
- [ ] Generate a Stash API key and confirm the "Push to Stash" button works
      end-to-end
- [x] Quality selector per link (best / 1080p / 720p / audio-only), mp4/mp3
      normalization for consistent playback
- [x] Source-of-truth tracking so a downloaded video can't get orphaned
      from where it came from: `.info.json` sidecar, embedded `purl`
      metadata tag in the file itself, and a source link + file path shown
      in the history table
- [x] Post-download integrity check (file exists, non-empty) before
      logging a download as successful, instead of trusting yt-dlp blindly
- [ ] Install ffmpeg (needed for mp4 merging, audio extraction, and
      metadata embedding — see `tools/downloader/README.md`)
- [x] Direct-file fallback: downloads straight video-file URLs (by
      extension or content-type) even when yt-dlp has no extractor for the
      site — not scraping, just fetching the exact URL given
- [x] Background download queue (`/queue`) so adding a link or batch no
      longer freezes the page while downloads run
- [x] Flash messages for push/retry/delete instead of terminal-only feedback
- [x] Duplicate URL detection (skipped under Auto, with a warning) and a
      Retry button per link-only row
- [x] Status filter dropdown (Downloaded / Link-only) alongside search and
      folder chips
- [x] Basic auth (off by default; set `auth_username`/`auth_password` in
      `config.json` before ever exposing beyond localhost)
- [x] "Push all link-only to Stash" bulk button
- [x] `start.bat` one-click launcher for Stash + the downloader app
      (edit the `STASH_EXE` path inside it once)

---

### Scope note: the PowerShell scripts

The `download-center.ps1` / `download-menu.ps1` / `download-videos.ps1` /
`launcher.ps1` / `pornstar-config.json` scripts in the repo root came from
an earlier project and do automated multi-site search-and-bulk-download
(scripted searches across ~10 tube sites, proxy support to sustain bulk
requests). That pattern — automated scraping across many sites plus a
proxy to avoid rate-limiting/blocking — is out of scope for this project
and won't be integrated or extended. The `tools/downloader` batch mode
covers the same underlying need (getting more than one video in without
doing it one at a time) without the scraping/evasion part: you pick the
URLs yourself by browsing, and paste the list in.

## Open questions to revisit

- Do I want the "paste link, pick category" step to be a real UI, or is a
  folder-naming convention + manual Stash entry good enough for now?
- How much do I care about offline copies vs. just linking? (affects how much
  effort goes into the download tool vs. skipping it)
- When (if ever) do I move to Docker — only when I want auto-updates, or
  also if I add more moving pieces (Tailscale sidecar, custom scripts)?
