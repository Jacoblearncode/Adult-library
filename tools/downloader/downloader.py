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


def add_history_entry(url, category, status, title="", note=""):
    entries = load_link_entries()
    entries.append({
        "url": url,
        "category": category,
        "status": status,
        "title": title,
        "note": note,
        "pushed_to_stash": False,
        "added_at": time.strftime("%Y-%m-%d %H:%M:%S"),
    })
    save_link_entries(entries)
    return entries


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


def download_url(url, category, config):
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
        add_history_entry(url, category, "link_only", note=f"yt-dlp unsupported: {error}")
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
        )
        return {
            "status": "link_only",
            "reason": "library size cap reached",
            "category": category,
        }

    ydl_opts = {
        "outtmpl": str(target_dir / "%(title)s.%(ext)s"),
        "download_archive": str(ARCHIVE_PATH),
        "quiet": True,
        "no_warnings": True,
        "noprogress": True,
        "progress_hooks": [_progress_hook],
    }
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([url])
        title = info.get("title", url)
        add_history_entry(url, category, "downloaded", title=title)
        return {
            "status": "downloaded",
            "category": category,
            "title": title,
        }
    except Exception as e:
        add_history_entry(url, category, "link_only", note=f"download failed: {e}")
        return {
            "status": "link_only",
            "reason": f"download failed: {e}",
            "category": category,
        }


def process_url(url, category, action, config):
    """action: 'auto' | 'download' | 'link'"""
    if action == "link":
        add_history_entry(url, category, "link_only", note="forced link-only")
        return {"status": "link_only", "reason": "forced link-only", "category": category}

    return download_url(url, category, config)


def parse_batch_input(text, default_category):
    """Parse a textarea of URLs (one per line, optional ", category" suffix)
    into a list of (url, category) tuples.
    """
    items = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "," in line:
            url, category = line.split(",", 1)
            url = url.strip()
            category = category.strip() or default_category
        else:
            url = line
            category = default_category
        items.append((url, category))
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
    details_bits = [f"category: {entry.get('category', 'uncategorized')}"]
    if entry.get("note"):
        details_bits.append(entry["note"])

    try:
        resp = requests.post(
            stash_url,
            json={
                "query": STASH_SCENE_CREATE_MUTATION,
                "variables": {
                    "title": title,
                    "urls": [entry["url"]],
                    "details": " | ".join(details_bits),
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


def process_batch(text, default_category, action, config):
    """Run process_url over every line of a batch textarea. Returns a list
    of result dicts (each with the source url/category attached).
    """
    results = []
    for url, category in parse_batch_input(text, default_category):
        result = process_url(url, category, action, config)
        result = dict(result)
        result["url"] = url
        results.append(result)
    return results
