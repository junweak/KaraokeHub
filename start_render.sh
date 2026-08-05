#!/bin/bash

WARP_DIR="$(pwd)/warp_data"

echo "[start] launching WARP proxy..."
bin/wireproxy --config "$WARP_DIR/wireproxy.conf" > /tmp/wireproxy.log 2>&1 &
WIREPROXY_PID=$!

echo "[start] wireproxy PID=$WIREPROXY_PID, waiting for SOCKS5 port..."
for i in $(seq 1 20); do
    if ! kill -0 $WIREPROXY_PID 2>/dev/null; then
        echo "[start] ERROR: wireproxy died! Log:"
        cat /tmp/wireproxy.log
        exit 1
    fi
    if timeout 1 bash -c "echo >/dev/tcp/127.0.0.1/1080" 2>/dev/null; then
        echo "[start] WARP SOCKS5 proxy ready on 127.0.0.1:1080 (took ${i}s)"
        break
    fi
    sleep 1
done

if ! kill -0 $WIREPROXY_PID 2>/dev/null; then
    echo "[start] ERROR: wireproxy died after startup! Log:"
    cat /tmp/wireproxy.log
    exit 1
fi

export WARP_SOCKS=socks5://127.0.0.1:1080
export RENDER=true

echo "[start] starting KaraokeHub..."
exec python run_prod.py
