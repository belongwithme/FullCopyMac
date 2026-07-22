#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/dist/全文复制助手.app"

if [ ! -d "$APP" ]; then
  "$ROOT/build.sh"
fi

rm -rf "/Applications/全文复制助手.app"
cp -R "$APP" /Applications/
open "/Applications/全文复制助手.app"
echo "已安装到 /Applications/全文复制助手.app"
