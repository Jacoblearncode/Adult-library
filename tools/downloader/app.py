"""Local web UI for the download/link tool.

Run with: python app.py
Then open http://localhost:5050
Not intended to be exposed beyond localhost / your private VPN.
"""
from flask import Flask, request, render_template_string

import downloader

app = Flask(__name__)

PAGE = """
<!doctype html>
<title>Library Downloader</title>
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


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5050, debug=False)
