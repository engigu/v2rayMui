#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="$ROOT_DIR/v2rayMui/Resources/v2ray-core"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TARGET_DIR"

ARCH="${DOWNLOAD_ARCH:-$(uname -m)}"
case "$ARCH" in
  arm64|aarch64) ASSET="Xray-macos-arm64-v8a.zip" ;;
  x86_64|amd64)  ASSET="Xray-macos-64.zip" ;;
  *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;;
esac

# https://github.com/XTLS/Xray-core/releases/download/v25.8.3/Xray-macos-64.zip
#https://github.com/XTLS/Xray-core/releases/download/v25.8.3/Xray-macos-arm64-v8a.zip

URL="https://gh-proxy.com/https://github.com/XTLS/Xray-core/releases/latest/download/$ASSET"

curl -fL "$URL" -o "$TMP_DIR/xray.zip"
unzip -q "$TMP_DIR/xray.zip" -d "$TMP_DIR"

BIN=""
if [[ -f "$TMP_DIR/xray" ]]; then BIN="$TMP_DIR/xray";
elif [[ -f "$TMP_DIR/Xray" ]]; then BIN="$TMP_DIR/Xray";
else BIN="$(find "$TMP_DIR" -maxdepth 2 -type f \( -name xray -o -name Xray \) | head -n 1 || true)"; fi

if [[ -z "${BIN:-}" || ! -f "$BIN" ]]; then
  echo "xray binary not found in archive" >&2
  exit 1
fi

cp "$TMP_DIR"/* "$TARGET_DIR"
mv "$TARGET_DIR/Xray" "$TARGET_DIR/v2ray"
rm -rf "$TMP_DIR"
rm -rf "$TARGET_DIR/xray.zip"
chmod 755 "$TARGET_DIR/v2ray"
echo "$TARGET_DIR/v2ray"


