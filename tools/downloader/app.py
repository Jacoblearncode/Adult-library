"""Local web UI for the download/link tool.

Run with: python app.py
Then open http://localhost:5050
Not intended to be exposed beyond localhost / your private VPN.
"""
from flask import Flask, request, render_template_string

import downloader

app = Flask(__name__)

NAV = """
<p><a href="/">Add one link</a> | <a href="/batch">Add a batch</a></p>
"""

PAGE = """
<!doctype html>
<title>Library Downloader</title>
""" + NAV + """
<h1>Paste a link</h1>
<form method="post" action="/add">
  <p><input type="text" name="url" placeholder="https://..." size="60" required></p>
  <p>Category:
    <select name="category">
      {% for c in categories %}<option value="{{ c }}">{{ c }}</option>{% endfor %}
    </select>
    or new: <input type="text" name="new_category" placeholder="type a new category">
  </p>
  <p>Action:
    <label><input type="radio" name="action" value="auto" checked> Auto (download if supported, else link)</label>
    <label><input type="radio" name="action" value="download"> Force download attempt</label>
    <label><input type="radio" name="action" value="link"> Force link-only</label>
  </p>
  <button type="submit">Add</button>
</form>

{% if result %}
<h2>Result</h2>
<pre>{{ result }}</pre>
{% endif %}

<h1>Library</h1>
<p>Current size: {{ "%.2f"|format(current_gb) }} GB / {{ "%.0f"|format(max_gb) }} GB cap</p>

<h2>Link-only entries ({{ entries|length }})</h2>
<table border="1" cellpadding="4">
<tr><th>URL</th><th>Category</th><th>Note</th><th>Added</th></tr>
{% for e in entries %}
<tr><td>{{ e.url }}</td><td>{{ e.category }}</td><td>{{ e.note }}</td><td>{{ e.added_at }}</td></tr>
{% endfor %}
</table>
"""

BATCH_PAGE = """
<!doctype html>
<title>Library Downloader - Batch</title>
""" + NAV + """
<h1>Add a batch of links</h1>
<p>Paste one URL per line. You picked these yourself while browsing &mdash;
this just saves you doing them one at a time. Optionally add a category
per line as <code>url, category</code>; otherwise the default below is used.</p>
<form method="post" action="/batch">
  <p><textarea name="urls" rows="12" cols="80" placeholder="https://example.com/video-1&#10;https://example.com/video-2, favorites"></textarea></p>
  <p>Default category (used for lines without one):
    <select name="default_category">
      {% for c in categories %}<option value="{{ c }}">{{ c }}</option>{% endfor %}
    </select>
    or new: <input type="text" name="new_default_category" placeholder="type a new category">
  </p>
  <p>Action:
    <label><input type="radio" name="action" value="auto" checked> Auto (download if supported, else link)</label>
    <label><input type="radio" name="action" value="download"> Force download attempt</label>
    <label><input type="radio" name="action" value="link"> Force link-only</label>
  </p>
  <button type="submit">Process batch</button>
</form>

{% if results is not none %}
<h2>Batch results ({{ results|length }})</h2>
<table border="1" cellpadding="4">
<tr><th>URL</th><th>Category</th><th>Status</th><th>Detail</th></tr>
{% for r in results %}
<tr>
  <td>{{ r.url }}</td>
  <td>{{ r.category }}</td>
  <td>{{ r.status }}</td>
  <td>{{ r.title or r.reason or "" }}</td>
</tr>
{% endfor %}
</table>
<p>
  Downloaded: {{ results|selectattr("status", "equalto", "downloaded")|list|length }}
  &nbsp;|&nbsp;
  Link-only: {{ results|selectattr("status", "equalto", "link_only")|list|length }}
</p>
{% endif %}
"""


@app.route("/", methods=["GET"])
def index():
    config = downloader.load_config()
    entries = downloader.load_link_entries()
    current_bytes = downloader.get_library_size_bytes(config["library_root"])
    return render_template_string(
        PAGE,
        categories=config.get("categories", ["uncategorized"]),
        entries=list(reversed(entries)),
        current_gb=current_bytes / (1024 ** 3),
        max_gb=config.get("max_library_bytes", 0) / (1024 ** 3),
        result=None,
    )


@app.route("/add", methods=["POST"])
def add():
    config = downloader.load_config()
    url = request.form["url"].strip()
    category = request.form.get("new_category", "").strip() or request.form.get("category", "uncategorized")
    action = request.form.get("action", "auto")

    result = downloader.process_url(url, category, action, config)

    entries = downloader.load_link_entries()
    current_bytes = downloader.get_library_size_bytes(config["library_root"])
    return render_template_string(
        PAGE,
        categories=config.get("categories", ["uncategorized"]),
        entries=list(reversed(entries)),
        current_gb=current_bytes / (1024 ** 3),
        max_gb=config.get("max_library_bytes", 0) / (1024 ** 3),
        result=result,
    )


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
