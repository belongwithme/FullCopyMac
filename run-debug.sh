#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/dist/全文复制助手.app"

if [ ! -d "$APP" ]; then
  "$ROOT/build.sh"
fi

BIN="$APP/Contents/MacOS/FullCopy"
echo "正在以前台调试模式启动：$BIN"
echo "保持此终端窗口打开；若应用崩溃，错误会直接显示在这里。"
exec "$BIN"
