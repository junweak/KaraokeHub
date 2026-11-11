# KaraokeHub — Progress

## Done
- 2026-07-15 — Initial app (`59f71db`): Flask + Socket.IO room server, 4-digit room codes with QR, SQLite index over `library/`, yt-dlp YouTube fallback, host/join/landing templates, plus an Electron wrapper (`package.json`, `main.js`, `electron.bat`).
- 2026-07-15 — Electron wrapper deleted in favour of a browser launcher (`52718da`): `run.bat` now self-heals the venv, checks ffmpeg, kills a stale `:5000` listener, prompts for Brave, and starts the server hidden. Same commit added client-side vocal reduction over the Web Audio API and drag-drop queue reordering.
- 2026-07-16 — Room/playlist persistence: `cache/rooms.json` written with `fsync`, restored on startup, 7-day timeout, previous rooms listed on the landing page (`08d5610`).
- 2026-07-16 — Join-page rework series: sticky search header, fixed-height layout, hide Now Playing/Set list while searching, result expansion, smooth collapse animations (`d1b3698`, `9c38b75`, `df5a540`, `b58c0de`, `89a5f5e`).
- 2026-07-16 — Queue UX: drag-drop reorder, double-click context menu with Play Next, fly-to-queue animation (`52718da`, `b9e699d`, `73481de`, `1a3d727`).
- 2026-07-16 — Branding and polish: SVG/ICO favicon plus `/favicon.ico` route (`0554320`), sidebar toggle styling (`b757cb4`, `86bca1f`, `c1df0c2`), search debounce raised to 500 ms (`1f9aa0d`), suggestion panel scroll styling (`2cbcd1b`).
- 2026-07-20 — Hardware lock: app refuses to start if the folder is copied to a different volume, keyed on `os.stat(app_dir).st_dev` (`5f9679f`, `0f0ec0b`, simplified back to serial-only in `3b9d5ac`). Enforced only outside Render.
- 2026-08-05 — Render deployment: `render.yaml` web service, `build_render.sh` / `start_render.sh`, `run_prod.py`, static ffmpeg download, Render-aware join URLs (`557cfb5`). Then gunicorn → SocketIO server (`4782410`), eventlet ordering fixes (`579966c`), final switch to threading mode (`c72536c`), `simple-websocket` pinned to 1.1.0 (`40e61ea`).
- 2026-08-05 — Cloudflare WARP SOCKS5 proxy so yt-dlp works from Render's datacenter IPs: `wgcf` register + `wireproxy`, proxy-aware yt-dlp calls, YouTube stream piped through ffmpeg (`ca32506`), hardened startup checks (`f41649c`), WARP state moved from `/tmp` to `warp_data/` because build and start run in separate containers (`72fa9e2`).
- Vocal reduction works two ways in-tree: browser-side channel-inversion/equaliser chain in `static/js/host.js`, and server-side ffmpeg `VOCAL_KILL` filter chain in `app.py`.

## In progress
- Three untracked paths in `git status` (no commits since `72fa9e2`, 2026-08-05): `$null`, `download_ffmpeg.bat`, `icon/karaoke.png`.
  - `$null` is a stray PowerShell artifact from a `taskkill ... > $null` redirect executed outside PowerShell; its content is a kill confirmation, not app data.
  - `download_ffmpeg.bat` downloads a portable ffmpeg into `bin/`, which `run.bat` already expects.
  - `icon/karaoke.png` is the launcher/app icon; templates still use `static/favicon.svg` and `static/favicon.ico`.
- Decision pending on whether to commit, gitignore, or delete those three.

## Next
- Reconcile the dead media paths: `#playerAudio`, `#albumArt`, and `#ytPlayer` in `templates/host.html` are never activated, and the server-side `/api/media/vocal`, `/api/media/vocal/yt`, and `/api/yt/<vid>` routes are not called by either JS file. Either finish them or remove them.
- Add a minimal test setup (smoke test for `/api/rooms`, `/api/search`, queue reorder) — there is currently no test framework, no CI config, and no lint config anywhere in the repo.
- README's own backlog is still open: Raspberry Pi deployment, Pi as its own WiFi AP, skip-voting, singer rotation, song history.
- Remove or formalise the `mpv` playback path in `app.py` (`play_media`) now that the browser player is the real output.
- Consider giving the hardware lock a documented re-authorise flow instead of "delete `.hardware_lock`" printed to stdout.

## Known bugs
- ~~`scan_library()` purges absolute-path songs~~ — **fixed 2026-11-11.** `scan_library()` (`app.py`) computed `existing = {all filepath rows}` but `found = {library-relative paths}`, then deleted `existing - found`, so every song added through `/api/library/scan-path` (absolute paths, e.g. a USB folder) vanished on the next rescan. The delete set is now restricted to relative paths, and absolute rows are pruned only when the file itself is gone.
- Double playback locally: `play_media()` spawns `mpv --fullscreen` on the host while `playMedia()` in `static/js/host.js` also plays the same URL in the browser. Two audio outputs if mpv is installed; harmless only because the `FileNotFoundError` branch swallows it where mpv is absent.
- Streaming failures are silent: `search_youtube()` returns `[]` and the `/api/stream/yt/<vid>` handler returns a bare `{"error": "stream unavailable"}` with the exception discarded, so WARP/proxy or format problems leave no diagnostic.
- Audio-only files render in the `<video>` element: `playMedia()` unconditionally shows `#playerVideo`, so `.mp3`/`.wav` playback shows an empty black video surface.
- `seed_youtube_suggestions()` performs a live yt-dlp search at module import (alongside `scan_library()`), so a cold start does network I/O and, without a working proxy, silently yields zero suggestions.
- Local port conflict reproduces in `stderr.txt` (2026-08-05 run): `OSError: [WinError 10048]` when a second instance binds port 5000; `run.bat` mitigates it, `python app.py` run twice does not.

## Gotchas
- Render build and start run in different containers — anything written to `/tmp` at build time is gone at start. WARP state must be regenerated or persisted under the app directory (`warp_data/`), which is exactly what `72fa9e2` fixed.
- `start_render.sh` assumes `warp_data/wireproxy.conf` already exists from the build step; it does not generate the WireGuard profile itself.
- Every yt-dlp call must go through `_ydl_opts()` so the `WARP_SOCKS` proxy is applied; a direct `YoutubeDL({...})` will be blocked on Render.
- `bin/` is gitignored: a fresh clone has no `ffmpeg`, so server-side remux/vocal endpoints fall back to PATH and fail if ffmpeg is not installed.
- `run.bat` requires Python 3.13 (`py -3.13`) even though `README.md` advertises 3.9+; the venv it builds is auto-rebuilt if `import flask` fails.
- `.hardware_lock` is gitignored but load-bearing: copying the checkout to another drive makes `python app.py` exit with "UNAUTHORIZED DRIVE" until the file is deleted. `IS_RENDER` bypasses the check.
- Room state and song index are separate stores: `cache/rooms.json` (queues, survives restarts) versus `library.db` (rebuildable by rescanning `library/`). Deleting one does not affect the other.
- Socket.IO's browser client is loaded from `https://cdn.socket.io/4.7.5/socket.io.min.js` in both `host.html` and `join.html`, so even fully local library playback needs outbound internet for the guest page to connect.
- `library/` contains only `.gitkeep` in the repo — an empty library means search returns only YouTube results, and the join page's Suggestions grid stays empty.
- `node_modules/electron` still exists locally with no `package.json` in the repo; `npm install` is not part of any workflow and must not be reintroduced as one.
