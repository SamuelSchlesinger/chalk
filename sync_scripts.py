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
import shlex
import subprocess
import sys


def slugify(text):
    """Return the segment key form used by audio stems and headings."""
    slug = re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")
    return re.sub(r"_+", "_", slug)


def extract_segments(script_path="script.md"):
    """Extract spoken text per section from script.md."""
    with open(script_path) as f:
        content = f.read()

    sections = re.split(r"^##\s+(.+?)\s*$", content, flags=re.MULTILINE)
    texts = {}
    headings = {}
    for i in range(1, len(sections), 2):
        heading = sections[i].strip()
        name = slugify(heading)
        if name in texts:
            raise ValueError(
                f"duplicate script heading slug {name!r}; rename one of the headings"
            )
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
        headings[name] = heading
    return texts, headings


def extract_segment_order(voiceover_path="voiceover.sh"):
    """Extract segment order from SEGMENTS array in voiceover.sh."""
    with open(voiceover_path) as f:
        content = f.read()
    match = re.search(r"SEGMENTS=\(\n(.*?)\n\)", content, re.DOTALL)
    if not match:
        raise ValueError("SEGMENTS array not found in voiceover.sh")
    entries = []
    for raw in re.findall(r'^\s*"([^"]+)"', match.group(1), flags=re.MULTILINE):
        parts = raw.split(":", 3)
        if len(parts) != 4:
            raise ValueError(f"invalid SEGMENTS entry: {raw!r}")
        num, scene, stem, desc = parts
        key = re.sub(r"^\d+[a-z]?_", "", stem)
        entries.append(
            {
                "num": num,
                "scene": scene,
                "stem": stem,
                "desc": desc,
                "key": slugify(key),
            }
        )
    return entries


def resolve_text(texts, headings, segment):
    """Find the script section text for a segment registry entry."""
    key = segment["key"]
    if key in texts:
        return texts[key]

    matches = [name for name in texts if name.startswith(f"{key}_")]
    if len(matches) == 1:
        return texts[matches[0]]
    if len(matches) > 1:
        matched = ", ".join(headings[name] for name in matches)
        raise ValueError(
            f"ambiguous script section for audio stem {segment['stem']!r}: {matched}"
        )

    available = ", ".join(headings[name] for name in texts) or "(none)"
    raise ValueError(
        f"no script section found for audio stem {segment['stem']!r}; "
        f"available headings: {available}"
    )


def build_scripts_array(texts, headings, segments):
    """Build the bash SCRIPTS=() array string."""
    lines = ["SCRIPTS=("]
    for segment in segments:
        text = resolve_text(texts, headings, segment)
        lines.append(f"    {shlex.quote(text)}")
    lines.append(")")
    return "\n".join(lines)


def expected_script_texts(texts, headings, segments):
    """Return expected SCRIPTS values in segment order."""
    return [resolve_text(texts, headings, segment) for segment in segments]


def replace_scripts(voiceover_path, new_scripts):
    """Replace SCRIPTS=() in voiceover.sh."""
    with open(voiceover_path) as f:
        content = f.read()
    new_content = re.sub(
        r"SCRIPTS=\(.*?\n\)",
        lambda _: new_scripts,
        content,
        count=1,
        flags=re.DOTALL,
    )
    with open(voiceover_path, "w") as f:
        f.write(new_content)


def extract_voiceover_scripts(voiceover_path):
    """Evaluate voiceover.sh just far enough to read its SCRIPTS array."""
    result = subprocess.run(
        [
            "bash",
            "-c",
            'source "$1" >/dev/null; printf "%s\\0" "${SCRIPTS[@]}"',
            "bash",
            voiceover_path,
        ],
        capture_output=True,
    )
    if result.returncode != 0:
        stderr = result.stderr.decode(errors="replace").strip()
        raise ValueError(f"could not read SCRIPTS from voiceover.sh: {stderr}")
    values = result.stdout.split(b"\0")
    if values and values[-1] == b"":
        values = values[:-1]
    return [value.decode() for value in values]


def verify(texts, headings, segments, voiceover_path="voiceover.sh"):
    """Check if voiceover.sh matches script.md."""
    with open(voiceover_path) as f:
        content = f.read()
    match = re.search(r"SCRIPTS=\(\n(.*?)\n\)", content, re.DOTALL)
    if not match:
        raise ValueError("SCRIPTS array not found in voiceover.sh")

    expected = expected_script_texts(texts, headings, segments)
    actual = extract_voiceover_scripts(voiceover_path)
    return actual == expected


def main():
    check_only = "--check" in sys.argv

    try:
        texts, headings = extract_segments()
        segments = extract_segment_order()
    except ValueError as exc:
        print(f"ERROR: {exc}")
        sys.exit(1)

    if check_only:
        try:
            in_sync = verify(texts, headings, segments)
        except ValueError as exc:
            print(f"OUT OF SYNC: {exc}")
            sys.exit(1)
        if not in_sync:
            print("OUT OF SYNC: voiceover.sh SCRIPTS differs from script.md")
            sys.exit(1)
        else:
            print(f"ALL {len(segments)} SEGMENTS IN SYNC")
            sys.exit(0)

    # Sync
    try:
        new_scripts = build_scripts_array(texts, headings, segments)
    except ValueError as exc:
        print(f"ERROR: {exc}")
        sys.exit(1)
    replace_scripts("voiceover.sh", new_scripts)

    # Verify
    if not verify(texts, headings, segments):
        print("ERROR: still out of sync after write")
        sys.exit(1)

    for segment in segments:
        text = resolve_text(texts, headings, segment)
        wc = len(text.split())
        print(f"  {segment['key']:25s} {wc:4d} words")
    print(f"\n  synced {len(segments)} segments")


if __name__ == "__main__":
    main()
