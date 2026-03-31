# chalk

Chalk is a command-line tool for creating scripted math explainer videos on macOS. Human and AI collaborate on outline and script; animations are coded in Manim; voiceover is human-recorded and synced with Whisper timestamps.

**Read README.md before working on any video project.** It documents the full pipeline (outline → script → animate → record → composite), Manim patterns, ffmpeg compositing, shorts layout, and hard-won lessons. Everything below supplements the README with agent-specific guidance.

## project setup

System dependencies: `brew install ffmpeg cairo pango sox` + LaTeX.

Python environment:
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install manim mlx-whisper
```

Project files (outline.md, script.md, timed_scenes.py, timed_scenes_shorts.py, voiceover.sh, transcribe_timing.py) should follow the conventions in README.md. render.sh handles all rendering — don't invoke manim directly in loops.

## fonts

MathTex renders through LaTeX (Computer Modern by default) and is immune to kerning bugs.

Text() renders through Pango/Cairo and has a **known kerning bug** that causes letters to bunch together at small sizes or with certain fonts. All video projects should use explicit font configuration:

```python
# ── fonts ────────────────────────────────────────────────────
FONT_TEXT = "Helvetica"       # regular text — ships with macOS, safe kerning
FONT_MONO = "Courier New"    # code snippets, labels — ships with macOS
```

Rules:
- **Mathematical content:** always use `MathTex(r"...")`
- **Regular text:** always use `Text("...", font=FONT_TEXT)` — never rely on Manim's default font
- **Code/labels:** use `Text("...", font=FONT_MONO)`
- **Small text:** use `MathTex(r"\text{...}")` instead of `Text()` when font_size < 24
- **Never omit the font parameter** on `Text()` — the default font triggers kerning bugs where letters bunch together (verified at 1080p)

Helvetica and Courier New ship with macOS and are verified safe. If you install additional fonts, Inter and JetBrains Mono are good upgrades. Avoid decorative or serif fonts unless tested at target resolution.

## writing the script

script.md is co-authored by human and AI. **The human voice is the critical value add** — the AI helps with structure, accuracy, and iteration, but the human's perspective and editorial judgment is what makes the video worth watching.

Before writing or editing script content, read the "voice and tone" and "LLM-isms to avoid" sections of README.md. The most critical rules:

- **Explain, don't sell.** Let the math do the work. If a result is beautiful, say why — don't hype it.
- **Be precise.** Use correct terminology. Vagueness isn't accessible, it's confusing.
- **Cut filler.** "let's", "so basically", "here's the thing" — these pad runtime without adding understanding.
- **Avoid significance inflation.** "Remarkable", "profound", "elegant", "pivotal", "crucial" — if the explanation is good, you don't need the adjective.
- **No "not just X — Y" parallelisms.** Rewrite as direct statements.
- **No rule-of-three lists.** One example is enough. If you have three, two need to go.
- **End on one thought**, not a recap of every point.
- **Watch for AI vocabulary.** Delve, intricate, tapestry, testament, landscape (figurative), meticulous, underscore, showcase, foster, vibrant, enduring — rewrite if you see a cluster.

## manim patterns

See README.md "manim reference" and "lessons learned" for the full list. The most common mistakes:

- **Text() font_size ≥ 24.** Kerning bug below this. Use `MathTex(r"\text{...}")` for smaller.
- **Always pass `font=FONT_TEXT`** (or `FONT_MONO`) to `Text()`.
- **Start each scene with `self.wait(VISUAL_DELAY)`.** Gives the first visual a moment before narration.
- **Track elapsed time.** `self.wait(max(target - elapsed, 0.1))` at the end of each scene.
- **Specify scene names when rendering.** Omitting triggers an interactive prompt that breaks automation.
- **Manim caches aggressively.** Delete the output .mp4 if re-rendering doesn't pick up changes.
- **Shorts: double font sizes, stack vertically.** Frame is only ~4.5 units wide. See README "shorts" section.
