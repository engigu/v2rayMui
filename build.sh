#!/usr/bin/env bash
set -euo pipefail

# 先构建前端资源
pushd server/web >/dev/null
npm run build
popd >/dev/null

# 通用函数：去除隔离属性
function dequarantine() {
  local target="$1"
  xattr -dr com.apple.quarantine "$target" 2>/dev/null || true
}

# 然后构建后端（Go Universal Binary: arm64 + amd64）
pushd server >/dev/null
OUT_ARM64="v2rayMuiGoServer_arm64"
OUT_AMD64="v2rayMuiGoServer_amd64"
OUT_UNI="v2rayMuiGoServer"
rm -f "$OUT_ARM64" "$OUT_AMD64" "$OUT_UNI"

echo "Building Go server (arm64)…"
GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 go build -ldflags "-s -w" -o "$OUT_ARM64" main.go

echo "Building Go server (amd64)…"
GOOS=darwin GOARCH=amd64 CGO_ENABLED=0 go build -ldflags "-s -w" -o "$OUT_AMD64" main.go

echo "Creating universal binary…"
lipo -create -output "$OUT_UNI" "$OUT_ARM64" "$OUT_AMD64"
chmod 755 "$OUT_UNI"
rm -f "$OUT_ARM64" "$OUT_AMD64"
popd >/dev/null

# 确保 resources/bin 存在
mkdir -p ./v2rayMui/Resources/bin/

# 拷贝 Go 服务到 Resources/bin 并去除隔离
cp server/v2rayMuiGoServer ./v2rayMui/Resources/bin/
dequarantine ./v2rayMui/Resources/bin/v2rayMuiGoServer

# 确保 xray 也去除隔离（若存在）
if [[ -f "./v2rayMui/Resources/bin/xray" ]]; then
  chmod 755 ./v2rayMui/Resources/bin/xray || true
  dequarantine ./v2rayMui/Resources/bin/xray
fi

# 输出目录结构，便于排查
echo "========================"
echo "Resources/bin contents:"
ls -la ./v2rayMui/Resources/bin/ | cat
echo "========================"