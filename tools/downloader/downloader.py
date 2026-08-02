"""Core logic for the download/link tool.

Given a URL, either downloads it via yt-dlp into the configured library
folder (category subfolder), or falls back to logging it as a link-only
entry when the site isn't supported by yt-dlp or the library is at its
size cap.
"""
import json
import os
import re
import sys
import time
from pathlib import Path
from urllib.parse import urlparse

DIRECT_FILE_EXTENSIONS = (".mp4", ".webm", ".mov", ".mkv", ".m4v", ".avi")

BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / "config.json"
CONFIG_EXAMPLE_PATH = BASE_DIR / "config.example.json"
HISTORY_PATH = BASE_DIR / "link_entries.json"
ARCHIVE_PATH = BASE_DIR / ".download-archive.txt"


def load_config():
    path = CONFIG_PATH if CONFIG_PATH.exists() else CONFIG_EXAMPLE_PATH
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def load_link_entries():
    if not HISTORY_PATH.exists():
        return []
    with open(HISTORY_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def save_link_entries(entries):
    with open(HISTORY_PATH, "w", encoding="utf-8") as f:
        json.dump(entries, f, indent=2)


def add_history_entry(url, category, status, title="", note="", file_path="", quality="best"):
    entries = load_link_entries()
    entries.append({
        "url": url,
        "category": category,
        "status": status,
        "title": title,
        "note": note,
        "file_path": file_path,
        "quality": quality,
        "pushed_to_stash": False,
        "added_at": time.strftime("%Y-%m-%d %H:%M:%S"),
    })
    save_link_entries(entries)
    return entries


def find_existing_entry(url):
    """Return the most recent history entry for this exact URL, or None."""
    matches = [e for e in load_link_entries() if e.get("url") == url]
    return matches[-1] if matches else None


def delete_entry(index):
    entries = load_link_entries()
    if 0 <= index < len(entries):
        entries.pop(index)
        save_link_entries(entries)
    return entries


def mark_pushed(index):
    entries = load_link_entries()
    if 0 <= index < len(entries):
        entries[index]["pushed_to_stash"] = True
        save_link_entries(entries)
    return entries


def sanitize_category(category):
    """Sanitize a possibly-nested category path like 'favorites/holiday'
    into safe folder path segments, preserving the '/' nesting.
    """
    category = (category or "uncategorized").strip().lower()
    parts = [
        re.sub(r"[^a-z0-9_-]+", "-", part).strip("-")
        for part in category.split("/")
    ]
    parts = [p for p in parts if p]
    return "/".join(parts) or "uncategorized"


def sanitize_filename(name):
    name = re.sub(r'[<>:"/\\|?*]', "_", name).strip()
    return name or "video"


def top_level_folders(entries):
    seen = []
    for e in entries:
        top = e.get("category", "uncategorized").split("/")[0]
        if top not in seen:
            seen.append(top)
    return sorted(seen)


def get_library_size_bytes(library_root):
    total = 0
    root = Path(library_root)
    if not root.exists():
        return 0
    for dirpath, _dirnames, filenames in os.walk(root):
        for name in filenames:
            fp = Path(dirpath) / name
            try:
                total += fp.stat().st_size
            except OSError:
                pass
    return total


def probe_url(url):
    """Check whether yt-dlp can extract info for this URL without downloading.

    Returns (supported: bool, info: dict | None, error: str | None)
    """
    try:
        import yt_dlp
    except ImportError:
        return False, None, "yt-dlp is not installed"

    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "simulate": True,
        "skip_download": True,
    }
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
        return True, info, None
    except Exception as e:  # yt-dlp raises its own DownloadError etc.
        return False, None, str(e)


def _try_direct_download(url, category, config):
    """Best-effort fallback for URLs yt-dlp doesn't recognize: if the URL
    points straight at an actual video file (by extension, or the server
    reports a video/* content type), fetch it with a plain HTTP GET.

    This is not a scraper — it only ever fetches the exact URL given, the
    same as pasting it into a browser's address bar. Returns
    (file_path, title) on success, or None if it doesn't look like a direct
    file or the request fails.
    """
    import requests

    path_lower = urlparse(url).path.lower()
    looks_like_file = path_lower.endswith(DIRECT_FILE_EXTENSIONS)

    try:
        if not looks_like_file:
            head = requests.head(url, timeout=10, allow_redirects=True)
            content_type = head.headers.get("Content-Type", "")
            if not content_type.startswith("video/"):
                return None
        resp = requests.get(url, stream=True, timeout=30)
        resp.raise_for_status()
    except Exception:
        return None

    category = sanitize_category(category)
    library_root = Path(config["library_root"])
    target_dir = library_root / category
    target_dir.mkdir(parents=True, exist_ok=True)

    max_bytes = config.get("max_library_bytes", 100 * 1024 ** 3)
    current_size = get_library_size_bytes(library_root)
    total = int(resp.headers.get("Content-Length") or 0)
    if total and current_size + total > max_bytes:
        resp.close()
        return None

    raw_name = Path(urlparse(url).path).name or "video"
    stem = sanitize_filename(Path(raw_name).stem or "video")
    ext = Path(raw_name).suffix or ".mp4"
    dest = target_dir / f"{stem}{ext}"
    counter = 1
    while dest.exists():
        dest = target_dir / f"{stem}-{counter}{ext}"
        counter += 1

    downloaded = 0
    try:
        with open(dest, "wb") as f:
            for chunk in resp.iter_content(chunk_size=1024 * 1024):
                if not chunk:
                    continue
                f.write(chunk)
                downloaded += len(chunk)
                if total:
                    pct = f"{downloaded / total * 100:.1f}%"
                else:
                    pct = f"{downloaded / (1024 * 1024):.1f} MiB"
                sys.stdout.write(f"\rDownloading (direct)... {pct}   ")
                sys.stdout.flush()
        sys.stdout.write("\rDownload complete, processing...                \n")
        sys.stdout.flush()
    except Exception:
        dest.unlink(missing_ok=True)
        return None

    if not dest.exists() or dest.stat().st_size == 0:
        dest.unlink(missing_ok=True)
        return None

    sidecar = dest.with_suffix(dest.suffix + ".info.json")
    try:
        with open(sidecar, "w", encoding="utf-8") as f:
            json.dump({"title": stem, "webpage_url": url, "source": "direct-download"}, f, indent=2)
    except OSError:
        pass

    return str(dest), stem


def _progress_hook(d):
    """Collapse yt-dlp's per-fragment spam into a single updating line."""
    if d.get("status") == "downloading":
        percent = (d.get("_percent_str") or "").strip()
        speed = (d.get("_speed_str") or "").strip()
        eta = (d.get("_eta_str") or "").strip()
        sys.stdout.write(f"\rDownloading... {percent} at {speed}, ETA {eta}   ")
        sys.stdout.flush()
    elif d.get("status") == "finished":
        sys.stdout.write("\rDownload complete, processing...                \n")
        sys.stdout.flush()


# Quality choices exposed in the UI, mapped to yt-dlp format selectors.
# "best" leaves format selection to yt-dlp's own default.
QUALITY_FORMATS = {
    "best": None,
    "1080p": "bestvideo[height<=1080]+bestaudio/best[height<=1080]",
    "720p": "bestvideo[height<=720]+bestaudio/best[height<=720]",
    "audio": "bestaudio/best",
}


def download_url(url, category, config, quality="best"):
    """Attempt to download via yt-dlp into the category folder.

    Returns a dict describing the outcome.
    """
    import yt_dlp

    category = sanitize_category(category)
    library_root = Path(config["library_root"])
    target_dir = library_root / category
    target_dir.mkdir(parents=True, exist_ok=True)

    max_bytes = config.get("max_library_bytes", 100 * 1024 ** 3)
    current_size = get_library_size_bytes(library_root)

    supported, info, error = probe_url(url)
    if not supported:
        direct = _try_direct_download(url, category, config)
        if direct:
            file_path, title = direct
            add_history_entry(
                url, category, "downloaded", title=title, file_path=file_path,
                note="direct file download (no yt-dlp extractor for this site)",
                quality=quality,
            )
            return {
                "status": "downloaded",
                "category": category,
                "title": title,
                "file_path": file_path,
            }
        add_history_entry(url, category, "link_only", note=f"yt-dlp unsupported: {error}", quality=quality)
        return {
            "status": "link_only",
            "reason": error or "URL not supported by yt-dlp",
            "category": category,
        }

    estimated_size = info.get("filesize") or info.get("filesize_approx") or 0
    if current_size + estimated_size > max_bytes:
        add_history_entry(
            url, category, "link_only",
            note=f"skipped download: would exceed {max_bytes / (1024**3):.1f} GB cap",
            quality=quality,
        )
        return {
            "status": "link_only",
            "reason": "library size cap reached",
            "category": category,
        }

    final_path_holder = {}

    def _pp_hook(d):
        if d.get("status") == "finished":
            info_dict = d.get("info_dict") or {}
            final_path_holder["path"] = info_dict.get("filepath") or d.get("filename")

    ydl_opts = {
        "outtmpl": str(target_dir / "%(title)s.%(ext)s"),
        "download_archive": str(ARCHIVE_PATH),
        "quiet": True,
        "no_warnings": True,
        "noprogress": True,
        "progress_hooks": [_progress_hook],
        "postprocessor_hooks": [_pp_hook],
        # Consistent container so playback/Stash preview behaves the same
        # across sources, instead of whatever mkv/webm a site happens to serve.
        "merge_output_format": "mp4",
        # Sidecar <title>.info.json next to the video, containing the
        # original webpage_url and full metadata — survives even if the
        # file gets moved away from this tool's own history log.
        "writeinfojson": True,
    }
    format_selector = QUALITY_FORMATS.get(quality)
    if format_selector:
        ydl_opts["format"] = format_selector

    # Embeds metadata into the video file itself (via ffmpeg), including a
    # "purl" tag with the source URL — the most durable copy, since it
    # travels with the file even if renamed or moved elsewhere. When
    # extracting audio, that has to run first so metadata embeds into the
    # final mp3, not the discarded video container.
    postprocessors = []
    if quality == "audio":
        postprocessors.append({"key": "FFmpegExtractAudio", "preferredcodec": "mp3"})
    postprocessors.append({"key": "FFmpegMetadata", "add_metadata": True})
    ydl_opts["postprocessors"] = postprocessors

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([url])
        title = info.get("title", url)

        file_path = final_path_holder.get("path", "")
        if not file_path or not Path(file_path).exists() or Path(file_path).stat().st_size == 0:
            add_history_entry(
                url, category, "link_only",
                note="download reported success but no file was found (possibly missing ffmpeg)",
                quality=quality,
            )
            return {
                "status": "link_only",
                "reason": "download produced no file",
                "category": category,
            }

        add_history_entry(url, category, "downloaded", title=title, file_path=file_path, quality=quality)
        return {
            "status": "downloaded",
            "category": category,
            "title": title,
            "file_path": file_path,
        }
    except Exception as e:
        add_history_entry(url, category, "link_only", note=f"download failed: {e}", quality=quality)
        return {
            "status": "link_only",
            "reason": f"download failed: {e}",
            "category": category,
        }


def process_url(url, category, action, config, quality="best"):
    """action: 'auto' | 'download' | 'link'"""
    if action == "link":
        add_history_entry(url, category, "link_only", note="forced link-only")
        return {"status": "link_only", "reason": "forced link-only", "category": category}

    return download_url(url, category, config, quality=quality)


def parse_batch_input(text, default_category, default_quality="best"):
    """Parse a textarea of URLs (one per line, optional ", category, quality"
    suffix) into a list of (url, category, quality) tuples.
    """
    items = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        parts = [p.strip() for p in line.split(",")]
        url = parts[0]
        category = parts[1] if len(parts) > 1 and parts[1] else default_category
        quality = parts[2] if len(parts) > 2 and parts[2] else default_quality
        items.append((url, category, quality))
    return items


STASH_SCENE_CREATE_MUTATION = """
mutation SceneCreate($title: String, $urls: [String!], $details: String) {
  sceneCreate(input: { title: $title, urls: $urls, details: $details }) {
    id
  }
}
"""


def push_to_stash(entry, config):
    """Create a URL-only scene in Stash for a link-only history entry.

    Requires 'stash_url' and 'stash_api_key' in config. Returns
    (success: bool, message: str).
    """
    import requests

    stash_url = config.get("stash_url")
    api_key = config.get("stash_api_key")
    if not stash_url:
        return False, "stash_url not set in config.json"
    if not api_key:
        return False, "stash_api_key not set in config.json"

    title = entry.get("title") or entry["url"]
    # The source URL also goes into Stash's structured "urls" field, but
    # that isn't surfaced prominently in Stash's UI for file-less scenes.
    # Putting it as the first line of the description guarantees it's
    # visible directly under the title with no digging required.
    details_bits = [f"Source: {entry['url']}", f"Category: {entry.get('category', 'uncategorized')}"]
    if entry.get("note"):
        details_bits.append(f"Note: {entry['note']}")

    try:
        resp = requests.post(
            stash_url,
            json={
                "query": STASH_SCENE_CREATE_MUTATION,
                "variables": {
                    "title": title,
                    "urls": [entry["url"]],
                    "details": "\n".join(details_bits),
                },
            },
            headers={"ApiKey": api_key},
            timeout=15,
        )
        resp.raise_for_status()
        data = resp.json()
        if data.get("errors"):
            return False, str(data["errors"])
        return True, data["data"]["sceneCreate"]["id"]
    except Exception as e:
        return False, str(e)


def push_all_unpushed_to_stash(config):
    """Push every link-only, not-yet-pushed entry to Stash. Returns
    (pushed_count, failed_count).
    """
    entries = load_link_entries()
    pushed = 0
    failed = 0
    for idx, entry in enumerate(entries):
        if entry.get("status") != "link_only" or entry.get("pushed_to_stash"):
            continue
        success, _message = push_to_stash(entry, config)
        if success:
            mark_pushed(idx)
            pushed += 1
        else:
            failed += 1
    return pushed, failed


def process_batch(text, default_category, action, config, default_quality="best"):
    """Run process_url over every line of a batch textarea. Returns a list
    of result dicts (each with the source url/category attached).
    """
    results = []
    for url, category, quality in parse_batch_input(text, default_category, default_quality):
        result = process_url(url, category, action, config, quality=quality)
        result = dict(result)
        result["url"] = url
        results.append(result)
    return results
