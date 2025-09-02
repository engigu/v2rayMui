#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/v2rayMui/Resources/webserver"
SRC_DIR="$ROOT_DIR/web"

mkdir -p "$OUT_DIR"

if ! command -v go >/dev/null 2>&1; then
  echo "Go 未安装，请先安装 Go 1.20+" >&2
  exit 1
fi

echo "构建 Go Web Server..."
GOOS=darwin GOARCH=amd64 go build -o "$OUT_DIR/webserver" "$SRC_DIR/cmd/webserver/main.go"
chmod +x "$OUT_DIR/webserver"

echo "拷贝前端静态资源..."
rsync -a --delete "$SRC_DIR/static/" "$OUT_DIR/static/"

echo "完成。将随 App 打包到 Bundle Resources/webserver/"


