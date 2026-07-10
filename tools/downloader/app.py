"""Local web UI for the download/link tool.

Run with: python app.py
Then open http://localhost:5050
Not intended to be exposed beyond localhost / your private VPN.
"""
from flask import Flask, request, render_template_string, redirect, url_for

import downloader

app = Flask(__name__)

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
  .field { margin-bottom: 1rem; }
  .actions label { margin-right: 1.25rem; font-weight: 400; font-size: 0.9rem; }

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
  .tag { display: inline-block; padding: 0.1rem 0.5rem; border-radius: 6px; background: #eef0ff; color: var(--accent); font-size: 0.8rem; }
  .url-cell { max-width: 260px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .muted { color: var(--muted); font-size: 0.85rem; }
  pre { background: #f6f7fb; border-radius: 8px; padding: 0.9rem; overflow-x: auto; }
  .searchbar { display: flex; gap: 0.5rem; margin-bottom: 1rem; }
  .searchbar input { flex: 1; }
</style>
"""

NAV = """
<nav><a href="/">Add one link</a><a href="/batch">Add a batch</a></nav>
"""

PAGE = """
<!doctype html>
<title>Library Downloader</title>
""" + STYLE + """
<div class="card">
""" + NAV + """
<h1>Paste a link</h1>
<form method="post" action="/add">
  <div class="field"><input type="text" name="url" placeholder="https://..." size="60" required></div>
  <div class="field">
    Category:
    <select name="category">
      {% for c in categories %}<option value="{{ c }}">{{ c }}</option>{% endfor %}
    </select>
    or new: <input type="text" name="new_category" placeholder="type a new category">
  </div>
  <div class="field actions">
    <label><input type="radio" name="action" value="auto" checked> Auto (download if supported, else link)</label>
    <label><input type="radio" name="action" value="download"> Force download attempt</label>
    <label><input type="radio" name="action" value="link"> Force link-only</label>
  </div>
  <button type="submit">Add</button>
</form>

{% if result %}
<h1 style="margin-top:1.5rem;">Result</h1>
<pre>{{ result }}</pre>
{% endif %}
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
<form class="searchbar" method="get" action="/">
  <input type="text" name="q" value="{{ q or '' }}" placeholder="Search by URL, title, or category">
  <button type="submit">Search</button>
</form>
<table>
<tr><th>Title / URL</th><th>Category</th><th>Status</th><th>Note</th><th>Added</th><th></th></tr>
{% for idx, e in entries %}
<tr>
  <td class="url-cell" title="{{ e.url }}">{{ e.title or e.url }}</td>
  <td><span class="tag">{{ e.category }}</span></td>
  <td><span class="pill {{ e.status }}">{{ "Downloaded" if e.status == "downloaded" else "Link only" }}</span></td>
  <td class="muted">{{ e.note or "" }}</td>
  <td class="muted">{{ e.added_at }}</td>
  <td>
    <form method="post" action="/delete/{{ idx }}" onsubmit="return confirm('Remove this entry from the log?');">
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
""" + NAV + """
<h1>Add a batch of links</h1>
<p class="muted">Paste one URL per line &mdash; links you picked yourself while browsing.
Optionally add a category per line as <code>url, category</code>; otherwise the default below is used.</p>
<form method="post" action="/batch">
  <div class="field"><textarea name="urls" rows="10" cols="70" placeholder="https://example.com/video-1&#10;https://example.com/video-2, favorites"></textarea></div>
  <div class="field">
    Default category:
    <select name="default_category">
      {% for c in categories %}<option value="{{ c }}">{{ c }}</option>{% endfor %}
    </select>
    or new: <input type="text" name="new_default_category" placeholder="type a new category">
  </div>
  <div class="field actions">
    <label><input type="radio" name="action" value="auto" checked> Auto (download if supported, else link)</label>
    <label><input type="radio" name="action" value="download"> Force download attempt</label>
    <label><input type="radio" name="action" value="link"> Force link-only</label>
  </div>
  <button type="submit">Process batch</button>
</form>
</div>

{% if results is not none %}
<div class="card">
<h1>Batch results ({{ results|length }})</h1>
<table>
<tr><th>URL</th><th>Category</th><th>Status</th><th>Detail</th></tr>
{% for r in results %}
<tr>
  <td class="url-cell" title="{{ r.url }}">{{ r.url }}</td>
  <td><span class="tag">{{ r.category }}</span></td>
  <td><span class="pill {{ r.status }}">{{ "Downloaded" if r.status == "downloaded" else "Link only" }}</span></td>
  <td class="muted">{{ r.title or r.reason or "" }}</td>
</tr>
{% endfor %}
</table>
<p class="muted" style="margin-top:0.8rem;">
  Downloaded: {{ results|selectattr("status", "equalto", "downloaded")|list|length }}
  &nbsp;|&nbsp;
  Link-only: {{ results|selectattr("status", "equalto", "link_only")|list|length }}
</p>
</div>
{% endif %}
"""


def _filtered_indexed_entries(q):
    entries = downloader.load_link_entries()
    indexed = list(enumerate(entries))
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


def _render_index(result=None):
    config = downloader.load_config()
    q = request.args.get("q", "").strip()
    indexed_entries, all_entries = _filtered_indexed_entries(q)
    current_bytes = downloader.get_library_size_bytes(config["library_root"])
    max_bytes = config.get("max_library_bytes", 1) or 1

    return render_template_string(
        PAGE,
        categories=config.get("categories", ["uncategorized"]),
        entries=indexed_entries,
        q=q,
        downloaded_count=sum(1 for e in all_entries if e.get("status") == "downloaded"),
        link_only_count=sum(1 for e in all_entries if e.get("status") == "link_only"),
        current_gb=current_bytes / (1024 ** 3),
        max_gb=max_bytes / (1024 ** 3),
        result=result,
    )


@app.route("/", methods=["GET"])
def index():
    return _render_index()


@app.route("/add", methods=["POST"])
def add():
    config = downloader.load_config()
    url = request.form["url"].strip()
    category = request.form.get("new_category", "").strip() or request.form.get("category", "uncategorized")
    action = request.form.get("action", "auto")

    result = downloader.process_url(url, category, action, config)
    return _render_index(result=result)


@app.route("/delete/<int:idx>", methods=["POST"])
def delete(idx):
    downloader.delete_entry(idx)
    return redirect(url_for("index"))


@app.route("/batch", methods=["GET"])
def batch_form():
    config = downloader.load_config()
    return render_template_string(
        BATCH_PAGE,
        categories=config.get("categories", ["uncategorized"]),
        results=None,
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

    results = downloader.process_batch(urls_text, default_category, action, config)

    return render_template_string(
        BATCH_PAGE,
        categories=config.get("categories", ["uncategorized"]),
        results=results,
    )


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5050, debug=False)
