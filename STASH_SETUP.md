# Setting up Stash (beginner walkthrough)

This is the "browse my library with thumbnails" app. You're on Windows, so
this uses the plain `.exe` — no Docker needed.

## 1. Download it

1. Go to https://github.com/stashapp/stash/releases
2. Under the newest release, find **Assets**, and download the Windows
   build — it'll be named something like `stash-win.exe`.
3. Make a folder for it, e.g. `C:\Stash`, and move the downloaded `.exe`
   there.

## 2. Pick your library folder

This should be the **same folder** your downloader tool's `config.json`
uses as `library_root` (e.g. `D:\Library\Videos`). If that folder doesn't
exist yet, create it now — File Explorer → right-click → New → Folder.

## 3. Run it

1. Double-click `stash-win.exe` inside `C:\Stash`.
2. A black terminal window will pop up and stay open — that's the server
   running, don't close it while you're using Stash. (Minimize it instead.)
3. Open your browser and go to: `http://localhost:9999`

## 4. First-run setup wizard

Stash will walk you through a few screens the first time:

1. **Setup** screen: it asks where to store its own database/config files —
   the default location is fine, just note it (you'll want to back this up
   later, see the checklist in `README.md`).
2. **Add a library**: click **Add** and browse to your library folder
   (`D:\Library\Videos`). This tells Stash where to look for videos.
3. Finish the wizard — it'll land you on the main dashboard.

## 5. Run your first scan

1. Click **Settings** (gear icon, usually left sidebar) → **Tasks**.
2. Find **Scan** and click **Scan** (or **Rescan**).
3. If you already have a few videos in the library folder, wait for it to
   finish — you'll see them appear as scenes with auto-generated
   thumbnails on the **Scenes** page.
4. If the folder is empty right now, that's fine — just confirms it's
   wired up correctly. Run Scan again any time after you add videos
   (via the downloader tool).

## 6. Lock it down (do this before anything else)

1. **Settings → Security**.
2. Set a **username and password**. Without this, anyone on your network
   (or your Tailscale tailnet, later) could open the app with no login.

## 7. Get an API key (needed for the downloader tool's "push to Stash" feature)

1. **Settings → Security → API Key**.
2. Click **Generate API Key**, then copy it.
3. Put it in `tools/downloader/config.json` as `"stash_api_key"` (see that
   file's example for the exact field) — this lets the downloader tool
   push link-only entries into Stash automatically instead of you manually
   re-entering them.

## 8. (Optional) Apply the custom theme

The repo includes `stash-custom-theme.css` and `stash-custom.js` — a
glassmorphism/glow visual theme built entirely from CSS transitions and
animations, plus a small vanilla-JS cursor-follow glow effect. This is the
supported way to restyle Stash: it's a prebuilt binary with no source
access, so there's no way to wire in a React animation library (Framer
Motion) or a drop-in component kit (OriginUI) — those need to be compiled
into Stash's own frontend, which we don't have. Pure CSS + vanilla JS
against the real rendered page is what Stash's Custom CSS/JS boxes
actually support, and it still gets a genuinely modern look: frosted-glass
cards, hover lift and glow, an animated gradient nav underline, and
link-only ("fileless") scenes visually distinguished with a dashed glow
border so they stand out from real files at a glance.

1. **Settings → Interface**, scroll to **Custom CSS**.
2. Open `stash-custom-theme.css` from the repo root, copy its entire
   contents, and paste into the Custom CSS box. Save.
3. Scroll to **Custom Javascript** (same Interface tab).
4. Open `stash-custom.js`, copy its contents, and paste into the Custom
   Javascript box. Save.
5. Refresh the **Scenes** page — hover over a card to see the lift/glow
   effect and the cursor-follow glow; link-only scenes should show a
   dashed glowing border instead of a solid one.

If you ever want to tweak colors, the CSS defines `--glow` near the top
(`rgba(79, 70, 229, ...)`, the same indigo used in the downloader app) —
change that one value to shift the whole theme's accent color.

## Everyday use after setup

- Download something with the downloader tool → run **Scan** in Stash
  (Settings → Tasks → Scan) → it shows up with a thumbnail.
- Add a link-only entry → the downloader tool pushes it into Stash
  automatically (once the API key is configured) → it shows up as a
  title card (no thumbnail, since there's no file — see README for why).

## If something goes wrong

- **Black window closes immediately**: try running it from a terminal
  instead of double-clicking, so you can read the error — open PowerShell,
  `cd C:\Stash`, then `.\stash-win.exe`.
- **Port 9999 already in use**: something else is using that port; the
  terminal output will tell you, or you can set a different port in
  Stash's config file.
- **Videos not showing up after scan**: double check the library path in
  Stash's settings matches exactly where the downloader tool is saving
  files (`library_root` in `tools/downloader/config.json`).
