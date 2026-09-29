#!/usr/bin/env python3
"""Fail if README.md has broken relative links."""
import pathlib
import re
import sys

root = pathlib.Path(".")
text = (root / "README.md").read_text(errors="replace")
broken = []
for _label, href in re.findall(r"\[([^\]]+)\]\(([^)]+)\)", text):
    if href.startswith(("http://", "https://", "mailto:", "#")):
        continue
    path = href.split("#")[0].split("?")[0]
    if not path:
        continue
    target = (root / path).resolve()
    try:
        target.relative_to(root.resolve())
    except ValueError:
        continue
    if not target.exists():
        broken.append(href)
if broken:
    print("Broken relative links:")
    for item in broken:
        print(" -", item)
    sys.exit(1)
print("README relative links OK")
