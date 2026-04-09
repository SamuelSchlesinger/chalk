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

Text() renders through Pango/Cairo and has a **known kerning bug at small font sizes** (< 24) where letters bunch together. The default font is fine for font_size >= 24. Only pass `font=` explicitly if you encounter kerning issues at your target resolution.

```python
# ── fonts ────────────────────────────────────────────────────
FONT_MONO = "Courier New"    # code snippets, labels — ships with macOS
```

Rules:
- **Mathematical content:** always use `MathTex(r"...")`
- **Regular text:** `Text("...", font_size=48, color=WHITE)` — the default font works well at normal sizes
- **Code/labels:** use `Text("...", font=FONT_MONO)`
- **Small text:** use `MathTex(r"\text{...}")` instead of `Text()` when font_size < 24
- If you see kerning issues at a specific size, pass `font="Helvetica"` (or another tested sans-serif) to that `Text()` call

Courier New ships with macOS. If you install additional fonts, JetBrains Mono is a good monospace upgrade. Avoid decorative or serif fonts unless tested at target resolution.

## writing the script

script.md is co-authored by human and AI. **The human voice is the critical value add** — the AI helps with structure, accuracy, and iteration, but the human's perspective and editorial judgment is what makes the video worth watching.

Before writing or editing script content, read the "voice and tone" and "LLM-isms to avoid" sections of README.md. The most important guidance:

**Write conversationally, not like a textbook.** Build ideas step by step — introduce each piece as you need it, use "you/we/our" naturally, weave examples alongside abstractions instead of stating full definitions then illustrating them. Connect each idea to what came before ("now that we have X, we can ask Y"). Vary sentence length. The script should read like someone thinking out loud at a whiteboard, explaining to a smart friend.

The avoidance rules matter too, but they're second-order — getting the conversational voice right prevents most of the problems automatically:

- **Explain, don't sell.** Let the math do the work. If a result is beautiful, say why — don't hype it.
- **Be precise.** Use correct terminology. Vagueness isn't accessible, it's confusing.
- **Avoid significance inflation.** "Remarkable", "profound", "elegant", "pivotal", "crucial" — if the explanation is good, you don't need the adjective.
- **No "not just X — Y" parallelisms.** Rewrite as direct statements.
- **No rule-of-three lists.** One example is enough. If you have three, two need to go.
- **End on one thought**, not a recap of every point.
- **Watch for AI vocabulary.** Delve, intricate, tapestry, testament, landscape (figurative), meticulous, underscore, showcase, foster, vibrant, enduring — rewrite if you see a cluster.

## manim patterns

See README.md "manim reference" and "lessons learned" for the full list. The most common mistakes:

- **Text() font_size ≥ 24.** Kerning bug below this. Use `MathTex(r"\text{...}")` for smaller.
- **Start each scene with `self.wait(VISUAL_DELAY)`.** Gives the first visual a moment before narration.
- **Track elapsed time.** `self.wait(max(target - elapsed, 0.1))` at the end of each scene.
- **Specify scene names when rendering.** Omitting triggers an interactive prompt that breaks automation.
- **Manim caches aggressively.** Delete the output .mp4 if re-rendering doesn't pick up changes.
- **Shorts: double font sizes, stack vertically.** Frame is only ~4.5 units wide. See README "shorts" section.

## improving chalk itself

Chalk is a living tool, not a frozen template. When working on a video project and you discover something that would systematically improve productivity, video quality, or process — a better Manim pattern, a workflow shortcut, a fix for a rendering gotcha, a new lesson learned — **make a PR back to chalk**.

Examples of things worth upstreaming:
- Bug workarounds or gotchas discovered during production (like the font kerning fix)
- New animation patterns that proved effective across multiple scenes
- Improvements to render.sh, voiceover.sh, or transcribe_timing.py
- Updates to this CLAUDE.md or README.md based on what actually helped vs. what was noise
- New tooling (e.g. a scene preview script, a duration estimator)

The bar is: would this help the next video project start in a better place? If yes, PR it. Keep chalk sharp.
