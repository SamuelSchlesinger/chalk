#!/usr/bin/env python3
"""Sync voiceover.sh SCRIPTS array from script.md.

script.md is the single source of truth. This script extracts the spoken
text from each ## section, strips director notes (> lines), and replaces
the SCRIPTS=() array in voiceover.sh.

Usage:
    python sync_scripts.py          # sync and verify
    python sync_scripts.py --check  # verify only, exit 1 if out of sync
"""

import re
import sys


def extract_segments(script_path="script.md"):
    """Extract spoken text per section from script.md."""
    with open(script_path) as f:
        content = f.read()

    sections = re.split(r"^## (\w+)", content, flags=re.MULTILINE)
    texts = {}
    for i in range(1, len(sections), 2):
        name = sections[i]
        body = sections[i + 1]
        lines = [
            l.strip()
            for l in body.strip().split("\n")
            if l.strip()
            and not l.strip().startswith(">")
            and not l.strip().startswith("#")
            and l.strip() != "---"
        ]
        texts[name] = " ".join(lines)
    return texts


def extract_segment_order(voiceover_path="voiceover.sh"):
    """Extract segment order from SEGMENTS array in voiceover.sh."""
    with open(voiceover_path) as f:
        content = f.read()
    match = re.search(r"SEGMENTS=\(\n(.*?)\n\)", content, re.DOTALL)
    if not match:
        raise ValueError("SEGMENTS array not found in voiceover.sh")
    entries = re.findall(r'"(\d+):(\w+):(\w+):(.*?)"', match.group(1))
    # Return list of audio_stem names (e.g., "01_intro" -> "intro")
    return [stem.split("_", 1)[1] if "_" in stem else stem for _, _, stem, _ in entries]


def build_scripts_array(texts, order):
    """Build the bash SCRIPTS=() array string."""
    lines = ["SCRIPTS=("]
    for name in order:
        text = texts.get(name, "").replace('"', "")
        lines.append(f'    "{text}"')
    lines.append(")")
    return "\n".join(lines)


def replace_scripts(voiceover_path, new_scripts):
    """Replace SCRIPTS=() in voiceover.sh."""
    with open(voiceover_path) as f:
        content = f.read()
    new_content = re.sub(
        r"SCRIPTS=\(.*?\n\)", new_scripts, content, count=1, flags=re.DOTALL
    )
    with open(voiceover_path, "w") as f:
        f.write(new_content)


def verify(texts, order, voiceover_path="voiceover.sh"):
    """Check if voiceover.sh matches script.md. Returns list of mismatches."""
    with open(voiceover_path) as f:
        content = f.read()
    match = re.search(r"SCRIPTS=\(\n(.*?)\n\)", content, re.DOTALL)
    vo_texts = re.findall(r'"(.*?)"', match.group(1), re.DOTALL)

    mismatches = []
    for i, name in enumerate(order):
        s = texts.get(name, "").replace('"', "").strip()
        v = vo_texts[i].strip() if i < len(vo_texts) else ""
        if s != v:
            mismatches.append(name)
    return mismatches


def main():
    check_only = "--check" in sys.argv

    texts = extract_segments()
    order = extract_segment_order()

    if check_only:
        mismatches = verify(texts, order)
        if mismatches:
            print(f"OUT OF SYNC: {', '.join(mismatches)}")
            sys.exit(1)
        else:
            print(f"ALL {len(order)} SEGMENTS IN SYNC")
            sys.exit(0)

    # Sync
    new_scripts = build_scripts_array(texts, order)
    replace_scripts("voiceover.sh", new_scripts)

    # Verify
    mismatches = verify(texts, order)
    if mismatches:
        print(f"ERROR: still out of sync after write: {', '.join(mismatches)}")
        sys.exit(1)

    for name in order:
        wc = len(texts.get(name, "").split())
        print(f"  {name:25s} {wc:4d} words")
    print(f"\n  synced {len(order)} segments")


if __name__ == "__main__":
    main()
