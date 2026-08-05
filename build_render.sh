#!/bin/bash
set -e

pip install -r requirements.txt

mkdir -p bin

# static ffmpeg
echo "[build] downloading ffmpeg..."
curl -fsSL https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz -o /tmp/ffmpeg.tar.xz
tar -xJf /tmp/ffmpeg.tar.xz --strip-components=1 -C bin/ --wildcards "*/ffmpeg" "*/ffprobe"
echo "[build] ffmpeg ready"

# wgcf - WARP credential generator
echo "[build] downloading wgcf..."
curl -fsSL -o bin/wgcf https://github.com/ViRb3/wgcf/releases/download/v2.2.32/wgcf_2.2.32_linux_amd64
chmod +x bin/wgcf

# wireproxy - userspace WireGuard SOCKS5 proxy
echo "[build] downloading wireproxy..."
curl -fsSL https://github.com/windtf/wireproxy/releases/download/v1.1.3/wireproxy_linux_amd64.tar.gz -o /tmp/wireproxy.tar.gz
tar -xzf /tmp/wireproxy.tar.gz -C bin/

# register WARP account and generate WireGuard profile (one-time, idempotent)
echo "[build] registering WARP account..."
bin/wgcf register --accept-tos --config /tmp/wgcf-account.toml 2>/dev/null || true
bin/wgcf generate --config /tmp/wgcf-account.toml --profile /tmp/wgcf-profile.conf 2>/dev/null || true

# create wireproxy config
cat > /tmp/wireproxy.conf << 'EOF'
WGConfig = /tmp/wgcf-profile.conf

[Socks5]
BindAddress = 127.0.0.1:1080
EOF

echo "[build] WARP proxy setup complete (SOCKS5 will be on 127.0.0.1:1080)"

chmod +x start_render.sh
