#!/usr/bin/env python3
"""Extracts one version's section from CHANGELOG.md.

usage: release-notes.py VERSION [--html]
Prints the Markdown body (or a small HTML rendering for the Sparkle appcast).
Exits 1 when the section is missing or empty, so a release cannot ship without notes.
"""
import html, re, sys

version = sys.argv[1]
as_html = "--html" in sys.argv
text = open("CHANGELOG.md", encoding="utf-8").read()
m = re.search(rf"^## {re.escape(version)}\s*\n(.*?)(?=^## |\Z)", text, re.S | re.M)
body = (m.group(1) if m else "").strip()
if not body:
    sys.stderr.write(f"CHANGELOG.md has no notes for {version}\n")
    sys.exit(1)
if not as_html:
    print(body)
    sys.exit(0)

def inline(s):
    s = html.escape(s)
    s = re.sub(r"`([^`]+)`", r"<code>\1</code>", s)
    s = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", s)
    s = re.sub(r"\[([^\]]+)\]\((https?://[^)]+)\)", r'<a href="\2">\1</a>', s)
    return s

out, para, in_list = [], [], False
def flush_para():
    global para
    if para:
        out.append("<p>" + inline(" ".join(para)) + "</p>")
        para = []
for line in body.splitlines():
    if line.startswith("- "):
        flush_para()
        if not in_list:
            out.append("<ul>"); in_list = True
        out.append("<li>" + inline(line[2:].strip()) + "</li>")
    else:
        if in_list and line.strip() == "" or (in_list and not line.startswith("- ")):
            out.append("</ul>"); in_list = False
        if line.startswith("### "):
            flush_para(); out.append("<h3>" + inline(line[4:]) + "</h3>")
        elif line.strip() == "":
            flush_para()
        else:
            para.append(line.strip())
flush_para()
if in_list:
    out.append("</ul>")
print("\n".join(out))
