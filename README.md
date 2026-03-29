# chalk

collaborate on scripted math explainer videos entirely from the command line on macOS.
no GUI editors, no drag-and-drop timelines — just python, ffmpeg, and a microphone.

## quick start

```bash
# clone chalk
git clone <your-chalk-repo-url> my-video
cd my-video

# initialize the project
./init.sh "sqrt 2 is irrational"

# activate venv and start working
source .venv/bin/activate
```

then follow the pipeline below.

## toolchain

| tool | purpose | install |
|------|---------|---------|
| manim CE | math/diagram animations | `pip install manim` + `brew install ffmpeg cairo pango` + LaTeX |
| ffmpeg | audio/video compositing, format conversion | `brew install ffmpeg` |
| sox | audio recording from terminal | `brew install sox` |
| mlx-whisper | word-level transcription for timing sync | `pip install mlx-whisper` |

`init.sh` creates a `.venv` and installs the python dependencies for you.

## project structure

```
my-video/
├── init.sh                    # run once to set up the project
├── render.sh                  # render all scenes (handles quality + shorts)
├── README.md                  # you are here
├── outline.md                 # collaborative outline — intellectual arc and structure
├── script.md                  # co-authored script — single source of truth for production
├── timed_scenes.py            # manim scenes, one class per segment (landscape)
├── timed_scenes_shorts.py     # same scenes adapted for 9:16 vertical
├── transcribe_timing.py       # whisper-based voiceover timing analysis
├── voiceover.sh               # record yourself, composite, check durations
├── clips/                     # audio
│   ├── vo_01_intro.wav            # voiceover recordings
│   └── ...
├── output/                    # final product
│   ├── segments/                  # individual composited segments
│   ├── final.mp4                  # the final video
│   └── shorts/                    # shorts version (1080x1920)
│       ├── segments/
│       └── final_shorts.mp4
├── media/                     # manim output (auto-generated)
└── .venv/                     # python virtual environment
```

## end-to-end pipeline

### step 0: outline the video

work together — human and AI — on `outline.md`. this is where the video's intellectual structure gets worked out before anyone writes spoken lines or animation cues.

the outline takes whatever shape the video needs. a pedagogical blueprint with numbered sections and pacing notes. a narrative arc with bullet points tracing a personal journey. a proof skeleton with key lemmas and visual ideas. don't force a format — let the content dictate the structure.

what the outline should answer:
- what should the viewer understand after watching?
- what's the intellectual arc — where do we start, where do we end?
- what are the segments, roughly, and what does each one accomplish?
- how long is the video?

**duration estimation:** word count / 2.5 ≈ speech duration in seconds at natural pace. use actual recorded durations as feedback and adjust timing accordingly.

| words | duration | good for |
|-------|----------|----------|
| 10-15 | 4-6s | titles, transitions, one-liners |
| 20-30 | 8-12s | single concept + animation |
| 30-40 | 12-16s | multi-step explanation |
| 40-50 | 16-20s | algebraic walkthrough, complex diagrams |

### step 1: write the script

with the outline as a guide, collaboratively draft `script.md`. human and AI each write sections, then edit each other's work, going back and forth until the voice is right. the human's voice is the critical value add — anyone can ask an AI for their video ideas, so the distinctive perspective and editorial judgment of the human author is what makes the video worth watching.

**the author-review-revise loop:** iterate on the script until it reaches a fixed point — accurate, high quality, and meeting the author's goals. the AI should fact-check its own contributions (definitions, theorem statements, attributions, dates) and flag anything it's uncertain about. the human reviews for voice, correctness, and whether the explanation actually lands. revise, re-review, repeat. the script is done when neither party has changes to make.

interleave three kinds of content in `script.md`:

- **spoken lines** — plain text, lowercase, precise
- **`> [MANIM:]` cues** — what animation plays during this section
- **`> [DIRECTOR:]` notes** — performance direction

here's an example from a proof that sqrt(2) is irrational:

```markdown
## square both sides

> **[DIRECTOR: walk through the algebra one step at a time.]**

square both sides. two equals alpha squared over beta squared. multiply through: alpha squared equals two beta squared.

> **[CUT TO MANIM: S03_Square scene]** show the algebra step by step:
> sqrt(2) = α/β -> 2 = α²/β² -> α² = 2β²
```

#### voice and tone

the goal is **clarity with flair** — not hype. the best math communication lets the ideas do the work.

- **explain, don't sell.** if a result is beautiful, say why — don't just say "and here's where it gets wild."
- **be precise.** use correct terminology and define it. vagueness isn't accessible, it's confusing.
- **earn the wonder.** set up a concept carefully and the moment it clicks is naturally exciting. no hype needed.
- **conversational, not performative.** talk to the viewer like you're explaining to a smart friend, not presenting to an audience.
- **cut the filler.** "let's", "so basically", "here's the thing" — these pad runtime without adding understanding.
- **lowercase is fine, but don't force casualness.** "this gives us injectivity" is better than "boom — injectivity."

bad: "both alpha and beta are even. boom. contradiction."
good: "both alpha and beta are even. they share a factor of two. but we assumed they had no common factors. contradiction."

bad: "congratulations, you just proved irrationality."
good: "the square root of two is irrational."

#### LLM-isms to avoid

since these scripts are co-authored with AI, the AI-contributed sections tend to pick up identifiable writing tics. both the human editor and the AI should watch for these — the AI should actively avoid producing them, and the human should rewrite any that slip through. the human voice is what makes these videos worth watching over just asking the AI directly. (see [wikipedia's field guide](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing) for the full taxonomy.)

**significance inflation.** LLMs love to tell the audience how important something is rather than showing why. words like "remarkable", "profound", "elegant", "pivotal", "crucial", "key" are flags. if something is remarkable, the explanation should make the viewer feel that — you shouldn't need the adjective.

bad: "this is the remarkable thing: every algorithm can be expressed as a turing machine."
good: "every algorithm ever written can be expressed as a turing machine."

bad: "turing's most profound insight wasn't just the machine."
good: "turing went further. he described a specific machine."

**"not just X — Y" and other negative parallelisms.** a staple of LLM rhetoric: "not just X, but Y", "it wasn't X — it was Y", "not because X — because Y". occasionally fine, but if your script has three of them, two need to go. rewrite as direct statements.

bad: "not because we lack the hardware — because no machine could solve them in principle."
good: "no machine could solve them, regardless of speed or memory."

**rule of three.** LLMs default to tripling: "every search engine, every compiler, every neural network." once in a script is fine. twice is a pattern. three times and the audience can hear the prompt.

**em dash overuse.** LLMs reach for em dashes where commas, colons, periods, or parentheses would be more natural. one or two per segment is fine. if every sentence has one, restructure.

**recap closings.** LLMs love to end by restating every point made in the piece ("X drew the boundary. Y showed universality. Z proved the limits."). a closing should leave the viewer with one thought, not a bulleted summary masquerading as prose.

bad: "the church-turing thesis draws the boundary. the universal turing machine shows one machine can simulate them all. quantum computers push efficiency. the halting problem proves the boundary is real."
good: end on a single image or idea that the video has earned.

**rhetorical question pairs.** "but is there X? are there Y?" — LLMs use paired rhetorical questions as transitions. one question is fine. a pair, where the second rephrases the first, is filler.

**AI vocabulary.** these words appear at far higher rates in LLM output than in human writing: delve, intricate, tapestry, testament, landscape (figurative), meticulous, underscore, showcase, foster, vibrant, enduring, bolster, garner, pivotal, crucial. not banned, but if you see a cluster of them, rewrite.

**superficial participle tails.** sentences ending with "...representing X", "...highlighting Y", "...underscoring Z". these tack on a shallow interpretation instead of letting the fact speak. cut the participle phrase or make it its own sentence with actual content.

bad: "their states become correlated, representing a departure from classical physics."
good: "their states become correlated in ways that classical probability cannot describe."

#### conventions

**heading = segment boundary.** each `##` heading maps to one narration segment, one manim scene class, and one composited video file.

**spoken lines are lowercase, precise.** write like you're explaining to a smart friend, then trim. these go verbatim into `voiceover.sh` as recording prompts.

**naming consistency:**

| file | pattern | example |
|------|---------|---------|
| `script.md` | `## heading` | `## square both sides` |
| `timed_scenes.py` | `class S03_Square(Scene)` + `DUR["square"]` | class + dict key |
| `voiceover.sh` | `"03:S03_Square:03_square:description"` | id:class:audio:desc |

#### keeping files in sync

the outline feeds the script, and the script feeds production:
```
outline.md                      ← collaborative planning
    └── script.md               ← co-authored (single source of truth for production)
            ├── timed_scenes.py         — animation content + durations
            └── voiceover.sh            — segment mapping + script text
```

**when you change a spoken line:** update script.md, update SCRIPTS in voiceover.sh, re-record the segment, update DUR in timed_scenes.py if duration changed.

**when you add a segment:** add to all three files. use "b" suffixes for insertions (e.g. `03b_square`).

### step 2: build timed animations

edit `timed_scenes.py` — one scene class per segment, durations from DUR dict.

**key patterns:**
- `DUR` dict at top — durations defined once, referenced by descriptive key
- elapsed time tracking in comments — `self.wait(max(d - elapsed, 0.1))` at end
- scene naming: `S01_Intro`, `S03_Square` — number prefix for order, name for content
- **sync visuals to narration** — use the class docstring to write out the spoken text with `|` delimiters between phrases. start with word-count estimates (~2.5 words/sec) and place `self.wait()` calls accordingly. after recording voiceover, use `transcribe_timing.py` (step 4b) to get exact word timestamps, then use `CUE_*` constants: `self.wait(max(CUE - elapsed - run_time, 0.1))`. this ensures each visual appears as the viewer hears it described

### step 3: render animations

```bash
# all scenes, fast iteration
./render.sh

# all scenes, final quality
./render.sh -qh

# one scene
./render.sh -ql S03_Square

# quality flags:
#   -ql  480p/15fps   fast iteration
#   -qm  720p/30fps   review drafts
#   -qh  1080p/60fps  final render
#   -qk  4K/60fps     4K final
```

`render.sh` auto-discovers scene classes from `timed_scenes.py`, activates the venv, and loops through them. no need to maintain a separate scene list.

### step 3b: render shorts animations (optional)

`timed_scenes_shorts.py` is adapted for the 9:16 vertical frame. `init.sh` scaffolds it for you — adapt each scene from `timed_scenes.py` with layout changes for the narrow vertical frame.

```bash
# all shorts scenes
./render.sh --shorts -qh

# one shorts scene
./render.sh --shorts -ql S03_Square
```

`render.sh --shorts` handles the `-r 1080,1920 --fps 60` flags automatically.

**key layout differences from landscape:**

| property | landscape (16:9) | shorts (9:16) |
|----------|-----------------|---------------|
| frame width | ~14.2 units | ~4.5 units |
| frame height | 8 units | 8 units |
| font sizes | 48-96 | 72-192 (~2x) |
| horizontal layout | side-by-side ok | stack vertically |
| vertical spacing | 0.6-0.8 buff | 0.8-1.0 buff (large text needs room) |

**common pitfalls:**
- `-r` flag is **height,width** not width,height — `-r 1080,1920` gives 1080w x 1920h
- wide equations (e.g. `\gcd(\alpha, \beta) = 1`) may overflow — split across lines or reduce font size
- elements placed with `LEFT * 2` / `RIGHT * 2` are near the frame edge (frame is only ±2.25 wide)
- test with `-ql` first — vertical rendering is the same speed as landscape

### step 4: record voiceover

```bash
# record all segments (video autoplays while you speak)
./voiceover.sh record

# record just one segment
./voiceover.sh record 05

# record from segment 05 onwards (skipping earlier segments)
./voiceover.sh record-from 05

# check duration mismatches
./voiceover.sh durations

# preview a segment's animation
./voiceover.sh play 05
```

only re-record segments you want to replace.

### step 4b: sync animations to voiceover with whisper

when you record voiceover at your natural pace, the animations (timed to word-count estimates) will be out of sync. `transcribe_timing.py` uses whisper to extract word-level timestamps from your recordings, so you can place animations exactly where you say the corresponding words.

```bash
# transcribe a segment, find when key phrases are spoken
python transcribe_timing.py 02 --phrases "identity function" "abstraction" "application"
```

output:

```
  --- phrase cue points ---
   18.18s  "variables"
   22.12s  "abstraction"
   30.62s  "application"
   41.24s  "identity function"
```

then use these as `CUE_*` constants in `timed_scenes.py`:

```python
def construct(self):
    d = DUR["lambda"]
    elapsed = 0.0

    # ... earlier animations ...

    # "abstraction" @ 22.1s — animation appears as you say the word
    CUE_ABSTRACTION = 22.1
    self.wait(max(CUE_ABSTRACTION - elapsed - 0.5, 0.1))
    elapsed = CUE_ABSTRACTION - 0.5
    self.play(FadeIn(abs_group), run_time=0.5)
    elapsed += 0.5
```

the pattern: `self.wait(max(CUE - elapsed - run_time, 0.1))` ensures the animation lands exactly when the cue word is spoken. re-render, re-composite, and the visuals will be in sync with your voice.

**workflow loop:**
1. `./voiceover.sh record` — record at your natural pace
2. `./voiceover.sh durations` — check duration mismatches, adjust `DUR` values
3. `python transcribe_timing.py 02 --phrases "key phrase"` — find cue points
4. update `CUE_*` constants in `timed_scenes.py`
5. `./render.sh -ql S02_Lambda` — re-render
6. `./voiceover.sh composite` — check the result
7. repeat 3-6 as needed

### step 5: composite and concatenate

```bash
# composite landscape
./voiceover.sh composite

# composite shorts (uses same audio, different video from timed_scenes_shorts)
./voiceover.sh composite-shorts
```

the composite step:
1. pairs each animation + audio into a segment video
2. handles audio longer than video (freezes last frame via tpad)
3. concatenates all segments
4. applies 2-pass YouTube loudnorm (-14 LUFS, -1 dBTP)

## manim reference

### useful primitives

- `MathTex(r"...")` — LaTeX math. `{{ }}` double braces for sub-part morphing
- `Text("...", font="Courier New")` — plain text
- `Arrow(start, end)` — animate with `GrowArrow()`
- `Graph(vertices, edges, layout=...)` — network graphs
- `SurroundingRectangle(obj)` — highlight box
- `VGroup(a, b, c)` — group for collective animation

### animation patterns

```python
self.play(FadeIn(obj), run_time=0.5)
self.play(obj.animate.move_to(RIGHT * 3), run_time=0.8)
self.play(TransformMatchingTex(eq1, eq2))
self.play(Flash(obj, color=RED, flash_radius=0.5))
self.play(FadeIn(a), GrowArrow(b), run_time=0.6)           # simultaneous
self.play(obj.animate.set_fill(GREEN, opacity=0.8))         # color change
```

### rendering quality flags

| flag | resolution | fps | use case |
|------|-----------|-----|----------|
| `-ql` | 854x480 | 15 | fast iteration |
| `-qm` | 1280x720 | 30 | review drafts |
| `-qh` | 1920x1080 | 60 | final render |
| `-qk` | 3840x2160 | 60 | 4K final |

## lessons learned

### whisper (transcribe_timing.py)
- **use `--phrases` for targeted lookup** — transcribing a full segment dumps hundreds of words. `--phrases` scans for multi-word matches and prints just the cue points you need
- **whisper hallucinates in silence** — if your recording has trailing silence, whisper fills it with repeated words (e.g. "Ash Ash Ash..."). this is harmless — the real speech timestamps are accurate, just ignore the tail
- **model downloads on first run** — `mlx-community/whisper-large-v3-turbo` is ~1.5GB. first transcription takes longer while it fetches the model
- **partial matches** — if a phrase isn't found verbatim (e.g. you said "the abstraction" but searched for "abstraction"), the tool falls back to single-word partial matching

### manim
- **keep `Text()` font_size ≥ 24** — Manim's `Text` class has a known kerning bug where small font sizes cause letters to bunch together with uneven spacing. this is especially visible at 1080p. `MathTex` is not affected. if you need small text, consider using `MathTex(r"\text{...}")` instead
- **use VISUAL_DELAY** — start each scene with `self.wait(VISUAL_DELAY)` (typically 1.5s) so the first visual has a moment to appear before narration begins. include VISUAL_DELAY in each DUR value and update DUR to match actual voiceover durations after recording
- **always specify scene names when rendering** — `manim render -ql timed_scenes.py` without a scene name triggers an interactive prompt that breaks automation. render each scene explicitly in a loop
- **one scene class per segment** — much easier to time than monolithic scenes
- **networkx layouts are 2d, manim wants 3d** — convert with `{k: [v[0], v[1], 0] for k, v in layout.items()}`
- **`Text` submobjects are SVG paths, not characters** — use `save_state()` + `Restore()` for scatter-assemble
- **track elapsed time in comments** — `self.wait(max(target - elapsed, 0.1))` ensures exact duration
- **manim caches aggressively** — if you edit a scene file and re-render, manim may serve the old cached video. delete the output `.mp4` file before re-rendering to force a fresh build. `--flush_cache` alone may not be enough
- **`-r` flag changes the output directory** — `-r 1080,1920 -ql` renders to `1920p15/` not `480p15/`. the custom resolution overrides the quality preset's resolution but keeps its fps. always check the actual output path after rendering with `-r`
- **fade out elements before replacing them** — when transitioning between scene phases, explicitly `FadeOut` text and labels that will be replaced. leaving them on screen (even if partially obscured) causes visual clutter, especially in the narrow 9:16 frame

### ffmpeg / compositing
- **`-shortest` clips video endings** — when video is longer than audio (due to VISUAL_DELAY), `-shortest` trims the video, cutting off fade-out animations. fix: add `apad` to the audio filter chain (`-af "apad,loudnorm=..."`) to pad audio with silence to match video length
- **never use `seq`/`printf` with 08, 09** — bash interprets as invalid octal. hardcode the list
- **re-encode at both stages** — per-segment and final concat. `-c copy` causes playback freezing
- **tpad for audio > video** — `tpad=stop_mode=clone:stop_duration=N` freezes last frame. do NOT use `-stream_loop`
- **2-pass loudnorm for YouTube** — measure first, then encode with measured values + `linear=true`

### shorts (9:16 vertical)
- **`-r` is height,width** — `manim render -r 1080,1920` gives 1080w x 1920h. getting this backwards gives landscape at a weird resolution
- **double your font sizes** — phone screens are small. text that's readable at 48pt on a laptop needs ~96pt for shorts
- **stack, don't spread** — the frame is only ~4.5 units wide. anything side-by-side in landscape should be stacked vertically
- **increase vertical spacing** — larger text takes more room. use `buff=0.8-1.0` instead of `0.6-0.8`
- **watch for overlap** — fractions (`\frac{}{}`) are tall. increase `UP/DOWN` shifts between equations
- **same audio, different video** — `composite-shorts` reuses the same voiceover clips with the shorts-rendered video

### workflow
- **iterate at `-ql`** — much faster than production quality. check timing before committing
- **outline feeds script, script feeds production** — the outline is where intellectual structure gets worked out collaboratively; the script is the single source of truth for all production files
- **line up visuals with narration** — animations should appear in sync with the words describing them. if you say "square both sides" while the equation is already on screen, it feels disconnected. use `transcribe_timing.py` to get exact word timestamps and drive animation timing with `CUE_*` constants rather than guessing
