#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/kunkka/projects/option-learner-guide"
APP_PORT="3101"
BASE_PATH="/option-learner-guide"
BIN_DIR="$HOME/bin"
TUNNEL_NAME="olg-tunnel"

mkdir -p "$BIN_DIR"
if [ ! -x "$BIN_DIR/cloudflared" ]; then
  echo '[i] 下载 cloudflared...'
  curl -fsSL -o "$BIN_DIR/cloudflared" \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
  chmod +x "$BIN_DIR/cloudflared"
fi

"$BIN_DIR/cloudflared" --version || true

EXE="$BIN_DIR/cloudflared"
ARGS=(tunnel --no-autoupdate --url "http://127.0.0.1:${APP_PORT}")

if pm2 jlist 2>/dev/null | grep -q '"name":"'"${TUNNEL_NAME}"; then
  pm2 restart "$TUNNEL_NAME" --update-env --time
else
  pm2 start "$EXE" --name "$TUNNEL_NAME" -- "${ARGS[@]}"
fi
pm2 save || true
sleep 2

URL=$(pm2 logs "$TUNNEL_NAME" --lines 400 --nostream | rg -o "https://[a-z0-9.-]*trycloudflare.com" | tail -n1 || true)
if [ -n "$URL" ]; then
  echo "[✓] 公网地址：${URL}${BASE_PATH}"
else
  echo '[!] 未从日志解析到 URL，请执行：pm2 logs olg-tunnel 查看包含 trycloudflare.com 的链接行'
fi
