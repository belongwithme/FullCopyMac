#!/usr/bin/env python3
from pathlib import Path

target = 1_000_000
parts = []
length = 0
line = 1
while length < target:
    text = f"第{line:06d}行：这是用于验证全文复制是否截断的中文测试文本。ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789\n"
    parts.append(text)
    length += len(text)
    line += 1
content = "".join(parts)
path = Path(__file__).resolve().parent.parent / "large-copy-test.txt"
path.write_text(content, encoding="utf-8")
print(f"Generated: {path}")
print(f"Characters: {len(content):,}")
print(f"UTF-8 bytes: {len(content.encode('utf-8')):,}")
