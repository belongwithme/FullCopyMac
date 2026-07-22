#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="FullCopy"
DISPLAY_NAME="全文复制助手"
DIST="$ROOT/dist"
APP="$DIST/$DISPLAY_NAME.app"

if ! command -v swift >/dev/null 2>&1; then
  echo "未找到 Swift。请先运行：xcode-select --install"
  exit 1
fi

echo "[1/4] 编译 Release 版本..."
cd "$ROOT"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN="$BIN_DIR/$APP_NAME"

if [ ! -f "$BIN" ]; then
  echo "编译产物不存在：$BIN"
  exit 1
fi

echo "[2/4] 生成 .app..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/$APP_NAME"

echo "[3/4] 本地临时签名..."
codesign --force --deep --sign - "$APP"

echo "[4/4] 完成"
echo "应用位置：$APP"
echo ""
echo "启动命令：open \"$APP\""
echo "安装到 Applications：cp -R \"$APP\" /Applications/"
