"""Local web UI for the download/link tool.

Run with: python app.py
Then open http://localhost:5050
Not intended to be exposed beyond localhost / your private VPN.
"""
import queue
import threading
import time
import uuid

from flask import Flask, request, render_template_string, redirect, url_for

import downloader

app = Flask(__name__)

# --- Background download queue -------------------------------------------
# Downloads (especially with quality selection / large batches) can take a
# while; running them inline in the Flask request would freeze the browser
# tab until they finish. Instead, /add and /batch just enqueue jobs and
# redirect to /queue, and a single background worker thread processes them
# one at a time. This state is in-memory only (lost on restart) — the
# actual download history in link_entries.json is unaffected either way.
JOBS = {}
JOBS_LOCK = threading.Lock()
JOB_QUEUE = queue.Queue()


def _worker():
    while True:
        job_id = JOB_QUEUE.get()
        with JOBS_LOCK:
            job = JOBS[job_id]
            job["status"] = "running"
        config = downloader.load_config()
        try:
            result = downloader.process_url(
                job["url"], job["category"], job["action"], config, quality=job["quality"]
            )
        except Exception as e:
            result = {"status": "link_only", "reason": f"unexpected error: {e}"}
        with JOBS_LOCK:
            job["status"] = "done"
            job["result"] = result
        JOB_QUEUE.task_done()


threading.Thread(target=_worker, daemon=True).start()


def _enqueue(url, category, action, quality):
    job_id = str(uuid.uuid4())[:8]
    with JOBS_LOCK:
        JOBS[job_id] = {
            "id": job_id,
            "url": url,
            "category": category,
            "action": action,
            "quality": quality,
            "status": "queued",
            "result": None,
            "submitted_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        }
    JOB_QUEUE.put(job_id)
    return job_id


def _pending_job_count():
    with JOBS_LOCK:
        return sum(1 for j in JOBS.values() if j["status"] in ("queued", "running"))

STYLE = """
<style>
  :root { --accent: #4f46e5; --bg: #f4f5f9; --card: #ffffff; --border: #e4e5ec;
          --text: #1f2130; --muted: #6b6f80; --green: #16a34a; --gray: #6b7280; }
  * { box-sizing: border-box; }
  body { margin: 0; padding: 2.5rem; background: var(--bg); color: var(--text);
         font-family: -apple-system, "Segoe UI", Roboto, sans-serif; }
  .card { background: var(--card); border: 1px solid var(--border); border-radius: 14px;
          padding: 1.75rem; max-width: 960px; margin: 0 auto 1.5rem; }
  nav a { color: var(--accent); text-decoration: none; font-weight: 600; margin-right: 1.25rem; }
  nav a:hover { text-decoration: underline; }
  h1 { font-size: 1.3rem; margin: 0 0 1rem; }
  input[type=text], select, textarea {
    border: 1px solid var(--border); border-radius: 8px; padding: 0.55rem 0.7rem;
    font-size: 0.95rem; background: #fafafe; color: var(--text);
  }
  button {
    background: var(--accent); color: #fff; border: none; border-radius: 8px;
    padding: 0.6rem 1.2rem; font-size: 0.95rem; font-weight: 600; cursor: pointer;
  }
  button:hover { opacity: 0.9; }
  button.link-btn { background: none; color: var(--muted); padding: 0.2rem 0.4rem; font-weight: 400; }
  button.link-btn:hover { color: #dc2626; opacity: 1; text-decoration: underline; }
  button.push-btn { background: none; color: var(--accent); padding: 0.2rem 0.4rem; font-weight: 600; font-size: 0.82rem; }
  button.push-btn:hover { text-decoration: underline; opacity: 1; }
  .field { margin-bottom: 1rem; }
  .actions label { margin-right: 1.25rem; font-weight: 400; font-size: 0.9rem; }
  .hint { color: var(--muted); font-size: 0.8rem; margin-top: 0.25rem; }

  .stats { display: flex; gap: 1rem; max-width: 960px; margin: 0 auto 1.5rem; }
  .stat { flex: 1; background: var(--card); border: 1px solid var(--border); border-radius: 14px;
          padding: 1.1rem 1.3rem; }
  .stat .label { font-size: 0.8rem; color: var(--muted); margin-bottom: 0.3rem; }
  .stat .value { font-size: 1.4rem; font-weight: 700; }
  .bar-track { height: 8px; border-radius: 4px; background: var(--border); margin-top: 0.6rem; overflow: hidden; }
  .bar-fill { height: 100%; background: var(--accent); }
  .bar-fill.warn { background: #dc2626; }

  table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
  th { text-align: left; color: var(--muted); font-weight: 600; font-size: 0.8rem;
       text-transform: uppercase; padding: 0.5rem 0.6rem; border-bottom: 1px solid var(--border); }
  td { padding: 0.6rem; border-bottom: 1px solid var(--border); vertical-align: top; }
  tr:hover td { background: #fafafe; }
  .pill { display: inline-block; padding: 0.15rem 0.6rem; border-radius: 999px; font-size: 0.78rem; font-weight: 600; }
  .pill.downloaded { background: #dcfce7; color: var(--green); }
  .pill.link_only { background: #f1f2f6; color: var(--gray); }
  .pill.pushed { background: #eef0ff; color: var(--accent); margin-left: 0.35rem; }
  .tag { display: inline-block; padding: 0.1rem 0.5rem; border-radius: 6px; background: #eef0ff; color: var(--accent); font-size: 0.8rem; }
  .crumb-sep { color: var(--muted); margin: 0 0.15rem; }
  .url-cell { max-width: 260px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .muted { color: var(--muted); font-size: 0.85rem; }
  pre { background: #f6f7fb; border-radius: 8px; padding: 0.9rem; overflow-x: auto; }
  .searchbar { display: flex; gap: 0.5rem; margin-bottom: 1rem; }
  .searchbar input { flex: 1; }
  .folders { display: flex; flex-wrap: wrap; gap: 0.5rem; margin-bottom: 1rem; }
  .folder-chip { display: inline-block; padding: 0.3rem 0.75rem; border-radius: 999px; font-size: 0.85rem;
                 background: #f1f2f6; color: var(--text); text-decoration: none; }
  .folder-chip.active { background: var(--accent); color: #fff; }
</style>
"""

def _nav():
    pending = _pending_job_count()
    queue_label = f"Queue ({pending})" if pending else "Queue"
    return f"""
<nav><a href="/">Add one link</a><a href="/batch">Add a batch</a><a href="/queue">{queue_label}</a></nav>
"""

PAGE = """
<!doctype html>
<title>Library Downloader</title>
""" + STYLE + """
<div class="card">
{{ nav|safe }}
<h1>Paste a link</h1>
<form method="post" action="/add">
  <div class="field"><input type="text" name="url" placeholder="https://..." size="60" required></div>
  <div class="field">
    Category / folder:
    <select name="category">
      {% for c in categories %}<option value="{{ c }}">{{ c }}</option>{% endfor %}
    </select>
    or new: <input type="text" name="new_category" placeholder="e.g. favorites/holiday">
    <div class="hint">Use "/" to nest folders, e.g. <code>favorites/holiday</code> &mdash; matches how files get organized on disk.</div>
  </div>
  <div class="field">
    Quality (if downloaded):
    <select name="quality">
      <option value="best" selected>Best available</option>
      <option value="1080p">1080p max</option>
      <option value="720p">720p max</option>
      <option value="audio">Audio only</option>
    </select>
  </div>
  <div class="field actions">
    <label><input type="radio" name="action" value="auto" checked> Auto (download if supported, else link)</label>
    <label><input type="radio" name="action" value="download"> Force download attempt</label>
    <label><input type="radio" name="action" value="link"> Force link-only</label>
  </div>
  <button type="submit">Add</button>
</form>
</div>

<div class="stats">
  <div class="stat">
    <div class="label">Downloaded</div>
    <div class="value">{{ downloaded_count }}</div>
  </div>
  <div class="stat">
    <div class="label">Link-only</div>
    <div class="value">{{ link_only_count }}</div>
  </div>
  <div class="stat">
    <div class="label">Library size</div>
    <div class="value">{{ "%.1f"|format(current_gb) }} / {{ "%.0f"|format(max_gb) }} GB</div>
    <div class="bar-track"><div class="bar-fill {% if current_gb / max_gb > 0.9 %}warn{% endif %}"
         style="width: {{ [100 * current_gb / max_gb, 100]|min }}%;"></div></div>
  </div>
</div>

<div class="card">
<h1>Library history ({{ entries|length }})</h1>

{% if folders %}
<div class="folders">
  <a class="folder-chip {% if not folder %}active{% endif %}" href="{{ url_for('index', q=q) }}">All</a>
  {% for f in folders %}
  <a class="folder-chip {% if folder == f %}active{% endif %}" href="{{ url_for('index', q=q, folder=f) }}">{{ f }}</a>
  {% endfor %}
</div>
{% endif %}

<form class="searchbar" method="get" action="/">
  {% if folder %}<input type="hidden" name="folder" value="{{ folder }}">{% endif %}
  <input type="text" name="q" value="{{ q or '' }}" placeholder="Search by URL, title, or category">
  <button type="submit">Search</button>
</form>
<table>
<tr><th>Title / URL</th><th>Category</th><th>Status</th><th>Note</th><th>Added</th><th></th></tr>
{% for idx, e in entries %}
<tr>
  <td class="url-cell" title="{{ e.url }}">
    {{ e.title or e.url }}
    <div class="muted" style="font-size:0.75rem; white-space:normal;">
      <a href="{{ e.url }}" target="_blank" rel="noopener">source</a>
      {% if e.file_path %} &middot; {{ e.file_path }}{% endif %}
    </div>
  </td>
  <td>
    {% for part in e.category.split('/') %}{% if not loop.first %}<span class="crumb-sep">/</span>{% endif %}<span class="tag">{{ part }}</span>{% endfor %}
  </td>
  <td>
    <span class="pill {{ e.status }}">{{ "Downloaded" if e.status == "downloaded" else "Link only" }}</span>
    {% if e.pushed_to_stash %}<span class="pill pushed">In Stash</span>{% endif %}
  </td>
  <td class="muted">{{ e.note or "" }}</td>
  <td class="muted">{{ e.added_at }}</td>
  <td>
    {% if e.status == "link_only" and not e.pushed_to_stash %}
    <form method="post" action="/push/{{ idx }}" style="display:inline;">
      <button type="submit" class="push-btn">Push to Stash</button>
    </form>
    {% endif %}
    <form method="post" action="/delete/{{ idx }}" onsubmit="return confirm('Remove this entry from the log?');" style="display:inline;">
      <button type="submit" class="link-btn">Remove</button>
    </form>
  </td>
</tr>
{% endfor %}
</table>
</div>
"""

BATCH_PAGE = """
<!doctype html>
<title>Library Downloader - Batch</title>
""" + STYLE + """
<div class="card">
{{ nav|safe }}
<h1>Add a batch of links</h1>
<p class="muted">Paste one URL per line &mdash; links you picked yourself while browsing.
Optionally add a category and/or quality per line as <code>url, category, quality</code>
(use "/" to nest folders, e.g. <code>favorites/holiday</code>; quality is one of
<code>best</code>, <code>1080p</code>, <code>720p</code>, <code>audio</code>); leave either
blank to fall back to the defaults below.</p>
<form method="post" action="/batch">
  <div class="field"><textarea name="urls" rows="10" cols="70" placeholder="https://example.com/video-1&#10;https://example.com/video-2, favorites/holiday, 720p"></textarea></div>
  <div class="field">
    Default category:
    <select name="default_category">
      {% for c in categories %}<option value="{{ c }}">{{ c }}</option>{% endfor %}
    </select>
    or new: <input type="text" name="new_default_category" placeholder="e.g. favorites/holiday">
  </div>
  <div class="field">
    Default quality (if downloaded):
    <select name="default_quality">
      <option value="best" selected>Best available</option>
      <option value="1080p">1080p max</option>
      <option value="720p">720p max</option>
      <option value="audio">Audio only</option>
    </select>
  </div>
  <div class="field actions">
    <label><input type="radio" name="action" value="auto" checked> Auto (download if supported, else link)</label>
    <label><input type="radio" name="action" value="download"> Force download attempt</label>
    <label><input type="radio" name="action" value="link"> Force link-only</label>
  </div>
  <button type="submit">Process batch</button>
</form>
</div>
"""


def _filtered_indexed_entries(q, folder):
    entries = downloader.load_link_entries()
    indexed = list(enumerate(entries))

    if folder:
        indexed = [
            (i, e) for i, e in indexed
            if e.get("category", "uncategorized") == folder
            or e.get("category", "uncategorized").startswith(folder + "/")
        ]

    if q:
        q_lower = q.lower()
        indexed = [
            (i, e) for i, e in indexed
            if q_lower in e.get("url", "").lower()
            or q_lower in e.get("title", "").lower()
            or q_lower in e.get("category", "").lower()
        ]

    indexed.reverse()
    return indexed, entries


def _render_index():
    config = downloader.load_config()
    q = request.args.get("q", "").strip()
    folder = request.args.get("folder", "").strip()
    indexed_entries, all_entries = _filtered_indexed_entries(q, folder)
    current_bytes = downloader.get_library_size_bytes(config["library_root"])
    max_bytes = config.get("max_library_bytes", 1) or 1

    return render_template_string(
        PAGE,
        nav=_nav(),
        categories=config.get("categories", ["uncategorized"]),
        entries=indexed_entries,
        q=q,
        folder=folder,
        folders=downloader.top_level_folders(all_entries),
        downloaded_count=sum(1 for e in all_entries if e.get("status") == "downloaded"),
        link_only_count=sum(1 for e in all_entries if e.get("status") == "link_only"),
        current_gb=current_bytes / (1024 ** 3),
        max_gb=max_bytes / (1024 ** 3),
    )


@app.route("/", methods=["GET"])
def index():
    return _render_index()


@app.route("/add", methods=["POST"])
def add():
    url = request.form["url"].strip()
    category = request.form.get("new_category", "").strip() or request.form.get("category", "uncategorized")
    action = request.form.get("action", "auto")
    quality = request.form.get("quality", "best")

    _enqueue(url, category, action, quality)
    return redirect(url_for("queue_view"))


@app.route("/delete/<int:idx>", methods=["POST"])
def delete(idx):
    downloader.delete_entry(idx)
    return redirect(url_for("index"))


@app.route("/push/<int:idx>", methods=["POST"])
def push(idx):
    config = downloader.load_config()
    entries = downloader.load_link_entries()
    if 0 <= idx < len(entries):
        success, message = downloader.push_to_stash(entries[idx], config)
        if success:
            downloader.mark_pushed(idx)
        # message isn't surfaced yet beyond server logs; a future pass could
        # flash it. For now, print so it's visible while the app is running.
        print(f"push_to_stash idx={idx} success={success} message={message}")
    return redirect(url_for("index"))


@app.route("/batch", methods=["GET"])
def batch_form():
    config = downloader.load_config()
    return render_template_string(
        BATCH_PAGE,
        nav=_nav(),
        categories=config.get("categories", ["uncategorized"]),
    )


@app.route("/batch", methods=["POST"])
def batch_submit():
    config = downloader.load_config()
    urls_text = request.form.get("urls", "")
    default_category = (
        request.form.get("new_default_category", "").strip()
        or request.form.get("default_category", "uncategorized")
    )
    action = request.form.get("action", "auto")
    default_quality = request.form.get("default_quality", "best")

    for url, category, quality in downloader.parse_batch_input(urls_text, default_category, default_quality):
        _enqueue(url, category, action, quality)

    return redirect(url_for("queue_view"))


QUEUE_PAGE = """
<!doctype html>
<title>Library Downloader - Queue</title>
""" + STYLE + """
{% if auto_refresh %}<meta http-equiv="refresh" content="3">{% endif %}
<div class="card">
{{ nav|safe }}
<h1>Download queue ({{ jobs|length }})</h1>
<p class="muted">Downloads run in the background so the page doesn't freeze.
{% if auto_refresh %}This page auto-refreshes every 3s while anything is queued or running.{% endif %}</p>
<table>
<tr><th>URL</th><th>Category</th><th>Quality</th><th>Status</th><th>Result</th><th>Submitted</th></tr>
{% for j in jobs %}
<tr>
  <td class="url-cell" title="{{ j.url }}">{{ j.url }}</td>
  <td><span class="tag">{{ j.category }}</span></td>
  <td class="muted">{{ j.quality }}</td>
  <td>
    {% if j.status == "queued" %}<span class="pill link_only">Queued</span>
    {% elif j.status == "running" %}<span class="pill pushed">Running</span>
    {% elif j.result and j.result.status == "downloaded" %}<span class="pill downloaded">Downloaded</span>
    {% else %}<span class="pill link_only">Link only</span>{% endif %}
  </td>
  <td class="muted">
    {% if j.result %}{{ j.result.title or j.result.reason or "" }}{% endif %}
  </td>
  <td class="muted">{{ j.submitted_at }}</td>
</tr>
{% endfor %}
</table>
{% if not jobs %}<p class="muted">Nothing queued yet &mdash; add a link or a batch to get started.</p>{% endif %}
</div>
"""


@app.route("/queue", methods=["GET"])
def queue_view():
    with JOBS_LOCK:
        jobs = sorted(JOBS.values(), key=lambda j: j["submitted_at"], reverse=True)
        auto_refresh = any(j["status"] in ("queued", "running") for j in jobs)
    return render_template_string(QUEUE_PAGE, nav=_nav(), jobs=jobs, auto_refresh=auto_refresh)


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5050, debug=False)
