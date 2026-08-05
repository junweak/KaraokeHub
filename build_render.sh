#!/bin/bash
set -e

echo "[build] installing Python dependencies..."
pip install -r requirements.txt

mkdir -p bin

echo "[build] downloading static ffmpeg..."
curl -fsSL https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz -o /tmp/ffmpeg.tar.xz
tar -xJf /tmp/ffmpeg.tar.xz --strip-components=1 -C bin/ --wildcards "*/ffmpeg" "*/ffprobe"
echo "[build] ffmpeg ready"

echo "[build] downloading wgcf..."
curl -fsSL -o bin/wgcf https://github.com/ViRb3/wgcf/releases/download/v2.2.32/wgcf_2.2.32_linux_amd64
chmod +x bin/wgcf

echo "[build] downloading wireproxy..."
curl -fsSL https://github.com/windtf/wireproxy/releases/download/v1.1.3/wireproxy_linux_amd64.tar.gz -o /tmp/wireproxy.tar.gz
tar -xzf /tmp/wireproxy.tar.gz -C bin/ wireproxy
chmod +x bin/wireproxy
echo "[build] wireproxy ready"

echo "[build] registering WARP account..."
if ! bin/wgcf register --accept-tos --config /tmp/wgcf-account.toml; then
    echo "[build] ERROR: wgcf register failed!" >&2
    exit 1
fi

echo "[build] generating WireGuard profile..."
if ! bin/wgcf generate --config /tmp/wgcf-account.toml --profile /tmp/wgcf-profile.conf; then
    echo "[build] ERROR: wgcf generate failed!" >&2
    exit 1
fi

if [ ! -f /tmp/wgcf-profile.conf ]; then
    echo "[build] ERROR: wgcf-profile.conf was not created!" >&2
    exit 1
fi
echo "[build] WARP WireGuard profile generated"

cat > /tmp/wireproxy.conf << 'EOF'
WGConfig = /tmp/wgcf-profile.conf

[Socks5]
BindAddress = 127.0.0.1:1080
EOF

echo "[build] testing wireproxy config..."
bin/wireproxy --config /tmp/wireproxy.conf --configtest 2>&1

echo "[build] DONE. SOCKS5 will be on 127.0.0.1:1080"
chmod +x start_render.sh
