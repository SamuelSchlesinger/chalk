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
echo "  ensuring system deps (ffmpeg, cairo, pango, sox)..."
if ! command -v brew >/dev/null 2>&1; then
    echo "ERROR: Homebrew is required to install system dependencies."
    echo "  install it from https://brew.sh, then re-run ./setup.sh"
    exit 1
fi
brew install ffmpeg cairo pango sox 2>/dev/null

if ! command -v latex >/dev/null 2>&1 && ! command -v pdflatex >/dev/null 2>&1; then
    echo "ERROR: LaTeX was not found, and Manim MathTex needs it."
    echo "  install MacTeX or BasicTeX, then re-run ./setup.sh"
    exit 1
fi

# ── python venv ──────────────────────────────────────────────
if [ -d .venv ]; then
    echo "  .venv exists"
else
    echo "  creating .venv..."
    python3 -m venv .venv
fi
echo "  ensuring python packages (manim, mlx-whisper)..."
.venv/bin/python -m pip install -q manim mlx-whisper

# ── make scripts executable ──────────────────────────────────
chmod +x render.sh voiceover.sh setup.sh

echo ""
echo "=== done ==="
echo ""
echo "  activate:  source .venv/bin/activate"
echo ""
echo "  then edit outline.md, script.md, and timed_scenes.py for your video."
