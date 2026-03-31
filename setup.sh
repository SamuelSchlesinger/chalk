#!/bin/bash
# Set up the chalk development environment.
#
# Run once after cloning the repo. Safe to re-run.
#
# Usage:
#   ./setup.sh

set -euo pipefail

echo "setting up chalk environment..."

# ── directories ──────────────────────────────────────────────
mkdir -p clips output/segments
echo "  clips/ and output/ ready"

# ── system dependencies ──────────────────────────────────────
if ! command -v ffmpeg &>/dev/null || ! command -v sox &>/dev/null; then
    echo "  installing system deps (ffmpeg, cairo, pango, sox)..."
    brew install ffmpeg cairo pango sox
else
    echo "  system deps already installed"
fi

# ── python venv ──────────────────────────────────────────────
if [ -d .venv ]; then
    echo "  .venv exists, skipping"
else
    echo "  creating .venv..."
    python3 -m venv .venv
    .venv/bin/pip install -q manim mlx-whisper
fi

# ── make scripts executable ──────────────────────────────────
chmod +x render.sh voiceover.sh

echo ""
echo "=== done ==="
echo ""
echo "  activate:  source .venv/bin/activate"
echo ""
echo "  then edit outline.md, script.md, and timed_scenes.py for your video."
