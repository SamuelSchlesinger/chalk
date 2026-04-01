"""Manim scenes for YouTube Shorts (1080x1920, 9:16 vertical).

Adapted from timed_scenes.py with layout adjustments for the
narrower vertical frame (frame_width ~ 4.5 units).

Key differences from landscape:
- Font sizes ~2x larger (phones are small screens)
- Stack elements vertically instead of side-by-side
- More vertical spacing between equations (large text needs room)
- Reduce horizontal offsets (frame is only ~4.5 units wide)

Render with:  manim render -r 1080,1920 --fps 60 -qh timed_scenes_shorts.py SceneName
NOTE: -r takes height,width (not width,height!)
"""

from manim import *

# ── colour palette ────────────────────────────────────────────
BG = "#1a1a2e"
GREEN = "#4ade80"
RED = "#f87171"
BLUE = "#60a5fa"
YELLOW = "#facc15"
WHITE = "#e2e8f0"
DIM = "#8888a8"

# ── fonts ────────────────────────────────────────────────────
FONT_MONO = "Courier New"

# ── visual delay (seconds) ───────────────────────────────────
VISUAL_DELAY = 1.5

# ── durations (seconds) ──────────────────────────────────────
# keep in sync with voiceover.sh
DUR = {
    "intro": 6.0 + VISUAL_DELAY,
    # "concept": 12.0 + VISUAL_DELAY,
}


class S01_Intro(Scene):
    """opening line goes here. | second phrase. | third phrase."""

    def setup(self):
        self.camera.background_color = BG

    def construct(self):
        d = DUR["intro"]
        e = 0

        self.wait(VISUAL_DELAY); e += VISUAL_DELAY

        # "opening line goes here" — title appears with the words
        # NOTE: ~2x font sizes vs landscape for phone readability
        title = Text("Title", font_size=144, color=WHITE)
        self.play(FadeIn(title), run_time=0.8); e += 0.8

        # "second phrase" — hold, then animate when phrase lands ~2.5s
        self.wait(1.7); e += 1.7
        # ... next animation here ...

        self.wait(max(d - e, 0.1))
