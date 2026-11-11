# KaraokeHub

Local-first karaoke party app. A Flask + Socket.IO server runs on the host laptop (the TV screen); guests join a 4-digit room from their phone over the same WiFi and everyone feeds one shared queue. Songs come from a local `library/` folder indexed into SQLite plus a `yt-dlp` YouTube fallback (search, and on-demand stream piped through ffmpeg). The same codebase also deploys as a Render free web service, where a Cloudflare WARP SOCKS5 proxy (`wgcf` + `wireproxy`) is required to reach YouTube from a datacenter IP. Shape: one Python module (`app.py`), three Jinja templates, two vanilla-JS files, hand-written CSS, no frontend build step.

## Stack
- Python 3.9+ (README; `run.bat` hardcodes `py -3.13`), single-file Flask app (`app.py`)
- Flask 3.0.3, Flask-SocketIO 5.3.6, python-socketio 5.11.2, simple-websocket 1.1.0 — threading mode, no eventlet, no gunicorn
- `qrcode[pil]` for room QR codes; `yt-dlp` for YouTube search/stream; stdlib `sqlite3` for the library index
- Frontend: Jinja2 + vanilla JS (`static/js/host.js`, `static/js/join.js`) + hand-written CSS; Socket.IO browser client from CDN 4.7.5; Web Audio API for client-side vocal reduction
- External binaries: `ffmpeg` (resolved from `bin/` then PATH) for remux/vocal-cut endpoints, plus optional `mpv`
- Target platform: web app (LAN host + phone guests), also deployed as a Render web service; Windows launcher `run.bat`

## Commands
```bash
# install (README)
python3 -m venv venv && source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt

# dev server — prints LAN URL, port 5000
python app.py

# Windows launcher — self-healing venv, checks ffmpeg, kills old :5000 listener, opens Brave/app window
run.bat

# production entry — PORT env (default 5000), threading SocketIO server
python run_prod.py

# Render build/start (invoked by render.yaml, not meant to be run locally)
bash build_render.sh    # pip install + static ffmpeg + wgcf/wireproxy + WARP profile into warp_data/
bash start_render.sh    # wireproxy on 127.0.0.1:1080, then exec python run_prod.py

# one-time local ffmpeg download for the vocal/remux endpoints (Windows, untracked script)
download_ffmpeg.bat

# tests — UNKNOWN: no test files, no test framework, no CI config in the repo
# lint  — UNKNOWN: no flake8/ruff/black/eslint config in the repo
```

## Layout
`templates/` — Jinja pages: `index.html` (landing/previous rooms), `host.html` (TV screen), `join.html` (guest)
`static/js/` — `host.js` (playback, queue, drag-drop, vocal toggle) and `join.js` (guest search/browse/queue)
`static/css/` — `style.css`, single stylesheet with CSS custom props
`static/` — `favicon.svg` + `favicon.ico`
`library/` — song drop folder (`.mp3 .mp4 .cdg .m4a .wav .webm`), only `.gitkeep` tracked
`cache/` — `rooms.json` room/queue persistence, fsynced on every mutation (gitignored)
`bin/` — local `ffmpeg.exe` and Render-downloaded `wgcf`/`wireproxy` (gitignored)
`icon/` — `karaoke.png` launcher icon (untracked)
`warp_data/` — generated WARP account/profile + `wireproxy.conf` (gitignored, build-time only)
`node_modules/` — orphaned `electron` leftover, gitignored, no `package.json` exists anymore
`venv/`, `__pycache__/` — local Python env and bytecode (gitignored)
`docs/` — agent-facing notes (`PROGRESS.md`)

## Conventions
- Python: snake_case, 4-space indent, stdlib `sqlite3` + raw SQL (no ORM, no migrations — `init_db()` uses `CREATE TABLE IF NOT EXISTS` and a try/except `ALTER TABLE`), `pathlib.Path` for paths, module-level constants in CAPS.
- `app.py` is organised by `# ---` banner comments: state → locking → library index → YouTube → startup init → page routes → API routes → streaming → Socket.IO.
- Room state lives in the in-memory `rooms` dict (keyed by code) and is the source of truth; every mutation is followed by `save_rooms()`.
- REST under `/api/...` returns bare `jsonify({...})` dicts; failures use `jsonify({"error": ...}), <code>`.
- Queue items are plain dicts: `{item_id, title, artist, source: "local"|"youtube", source_ref, requested_by}` where `source_ref` is a library-relative/absolute path or a YouTube video id.
- Socket.IO contract: client emits `join` with `{code}`; server emits `queue_update`, `now_playing_update`, `playback_update`.
- JS: one `const socket = io();` at file top, `function` declarations, camelCase, `fetch` against `/api/...`, every interpolated user string passed through `escapeHtml()`.
- Styling via CSS custom props (`--gold`, `--pink`, `--muted`, `--line`) and shared button classes (`btn btn-primary|btn-secondary|btn-ghost`); templates keep small inline styles, larger rules go to `style.css`.
- Commit messages are imperative one-liners that state the visible change ("Add fly-to-queue animation when adding songs from search/browse").

## Don'ts
- Do not write runtime state to `/tmp` on Render: build and start run in separate containers, so WARP config must live in `warp_data/` (commit 72fa9e2).
- Do not reintroduce eventlet, `wsgi.py`, or gunicorn — production is `socketio.run(...)` in threading mode (commits 4782410, 579966c, c72536c).
- Do not commit `library.db`, `cache/`, `bin/`, `warp_data/`, `node_modules/`, `.hardware_lock`, `stdout*.txt`, `stderr*.txt` — all gitignored, local-only.
- Do not delete `.hardware_lock` casually: `check_hardware_lock()` binds the app to the folder's volume serial and exits if it mismatches; deleting the file re-authorises the current drive.
- Do not add an Electron wrapper back without also adding `package.json`/`main.js` — both were deleted on 2026-07-15 and `node_modules/electron` is a dead leftover.
- Do not assume `ffmpeg` or `mpv` exist: `bin/ffmpeg.exe` is gitignored and the code falls back to PATH, then fails the stream request.
- Do not hardcode `http://localhost` join URLs — page routes branch on `IS_RENDER` to build `https://{request.host}/join/<code>`.
- Do not interpolate guest-supplied titles without `escapeHtml()`; queue entries come from anonymous phones.
- Do not start a second server on port 5000 while one is listening — `stderr.txt` shows the resulting `WinError 10048`.
- Do not "fix" the unused `#playerAudio` / `#ytPlayer` / `/api/media/vocal` paths without asking; they are deliberate leftovers, not wiring bugs to invent around.

Read docs/PROGRESS.md before starting. Update it before finishing.
