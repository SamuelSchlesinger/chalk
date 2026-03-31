"""Manim scenes — one class per narration segment.

Initial timing uses ~2.5 words/sec estimates. After recording voiceover,
use transcribe_timing.py to get exact word timestamps and replace
hardcoded waits with CUE-point-based timing.
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
# MathTex uses LaTeX (no kerning issues). Text() uses Pango/Cairo
# and has a known kerning bug with some fonts. Always pass font=
# explicitly — never rely on the default.
FONT_TEXT = "Helvetica"       # regular text — ships with macOS, safe kerning
FONT_MONO = "Courier New"    # code snippets, labels — ships with macOS

# ── visual delay (seconds) ───────────────────────────────────
# video starts this many seconds before the audio in each segment,
# giving the first visual a moment to appear before narration begins.
VISUAL_DELAY = 1.5

# ── durations (seconds) ──────────────────────────────────────
# Start with estimates (~2.5 words/sec + VISUAL_DELAY). After recording
# voiceover, update to actual durations: voiceover_duration + VISUAL_DELAY.
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
        title = Text("Title", font=FONT_TEXT, font_size=72, color=WHITE)
        self.play(FadeIn(title), run_time=0.8); e += 0.8

        # "second phrase" — hold, then animate when phrase lands ~2.5s
        self.wait(1.7); e += 1.7
        # ... next animation here ...

        # ── after recording voiceover, replace waits with CUE points: ──
        # CUE_PHRASE = 5.2  # from transcribe_timing.py
        # target_e = VISUAL_DELAY + CUE_PHRASE - 0.8
        # self.wait(max(target_e - e, 0.1)); e = target_e
        # self.play(SomeAnimation(...), run_time=0.5); e += 0.5

        self.wait(max(d - e - 1.0, 0.1))
        # fade_all(self, run_time=1.0)  # uncomment when you have content
