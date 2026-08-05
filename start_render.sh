#!/bin/bash
set -e

echo "[start] launching WARP proxy..."
bin/wireproxy --config /tmp/wireproxy.conf &
WIREPROXY_PID=$!

# wait for SOCKS5 port to be available (max 15s)
for i in $(seq 1 15); do
    if nc -z 127.0.0.1 1080 2>/dev/null; then
        echo "[start] WARP SOCKS5 proxy ready on 127.0.0.1:1080"
        break
    fi
    sleep 1
done

export WARP_SOCKS=socks5://127.0.0.1:1080
export RENDER=true

echo "[start] starting KaraokeHub..."
exec python run_prod.py
