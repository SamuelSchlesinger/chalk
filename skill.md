# video production skill guide

how to compose scripted math explainer videos entirely from the command line on macOS.
no GUI editors, no drag-and-drop timelines — just python, ffmpeg, and a microphone.

## what we built

a ~4.5 minute explainer video on sigma protocols (zero-knowledge proofs, schnorr
identification, fiat-shamir transform, schnorr signatures) with:
- 23 programmatic animations (manim)
- voice-cloned narration from a 12-second reference recording (f5-tts-mlx)
- automated compositing and concatenation (ffmpeg)

total production time: ~2 hours of iteration, ~20 minutes of render/generation compute.

## toolchain

| tool | purpose | install |
|------|---------|---------|
| manim CE | math/diagram animations | `pip install manim` + `brew install ffmpeg cairo pango` + LaTeX |
| f5-tts-mlx | voice cloning/synthesis on apple silicon (model: `lucasnewman/f5-tts-mlx`, a flow-matching diffusion transformer) | `pip install f5-tts-mlx` |
| ffmpeg | audio/video compositing, format conversion | `brew install ffmpeg` |
| sox | audio recording from terminal | `brew install sox` |

use a python venv to keep dependencies isolated:
```bash
python3 -m venv .venv && source .venv/bin/activate
pip install manim f5-tts-mlx soundfile
```

## end-to-end pipeline

### step 0: plan the video

before writing anything, decide on structure:

**target length:** 3-5 minutes is the sweet spot for explainer videos. longer than 5 and
you lose people; shorter than 3 and you can't develop ideas.

**segment count and duration:** plan 15-25 segments of 5-15 seconds each. shorter segments
(4-6s) work for punchy transitions and one-liners. longer segments (10-16s) work for
explanations with multiple animation beats.

**duration estimation:** count the words in each narration line and divide by 2.5.
that gives you the speech duration in seconds. the manim scene duration should match.

| words | speech duration | good for |
|-------|----------------|----------|
| 10-15 | 4-6s | titles, transitions, one-liners |
| 20-30 | 8-12s | single concept + animation |
| 30-40 | 12-16s | multi-step explanation |
| 40-50 | 16-20s | algebraic walkthrough, complex diagrams |

**total video time** = sum of all segment durations + ~0.5s silence between segments.

### step 1: write the script

write everything in one markdown file (`script.md`). interleave three kinds of content:

- **spoken lines** — plain text, lowercase, pithy
- **`> [MANIM:]` cues** — what animation plays during this section
- **`> [DIRECTOR:]` notes** — performance direction for on-camera delivery

```markdown
## the three-move dance

> **[DIRECTOR: straighten up. hold up three fingers on "three messages".]**

sigma protocols are elegant. three messages. that's it

> **[CUT TO MANIM: ThreeMoveDance scene]** prover/verifier diagram,
> arrows appear one at a time.
```

this format lets you read the script as a teleprompter while also serving as the
technical spec for the animation and compositing pipeline.

#### script structure conventions

**heading = segment boundary.** each `##` heading in the script maps to exactly one
narration segment, one manim scene class, and one composited video file. when you add
a heading, you're committing to all three.

**spoken lines are lowercase, pithy.** no capitals except proper nouns. no filler. write
like you talk, then cut 30%. these lines go verbatim into `generate_narration.py`'s
`SEGMENTS` list — the TTS model reads exactly what's written.

**`> [MANIM:]` cues describe what to animate.** be specific enough to implement:
name the scene class, describe the visual elements, state transitions, and timing beats.
these are your spec when building `timed_scenes.py`.

**`> [DIRECTOR:]` notes are performance direction.** tone, energy, gestures, pacing —
everything you'd tell yourself before recording a take. useful if you ever film yourself
on camera to intercut with animations.

**`> [CUT TO MANIM:]` vs `> [MANIM:]`:** use `CUT TO` when the visual switches entirely
to the animation (no on-camera). use bare `MANIM:` when the animation plays alongside
or picture-in-picture with the speaker.

#### keeping script, audio, and animation in sync

the script is the **single source of truth**. the other three files derive from it:

```
script.md (source of truth)
    ├── generate_narration.py   — spoken text + durations
    ├── timed_scenes.py         — animation content + durations
    └── composite.sh            — segment ordering
```

**when you change a spoken line:**
1. update the text in `script.md`
2. copy the new text into the matching `SEGMENTS` entry in `generate_narration.py`
3. recount words → update the `speech_duration` if the length changed meaningfully
4. delete the old `.wav`: `rm clips/XX_segment_name.wav`
5. regenerate: `python generate_narration.py`
6. if the duration changed, update `DUR["key"]` in `timed_scenes.py` and re-render that scene

**when you add a new segment:**
1. add the section in `script.md` at the right position
2. add a `SEGMENTS` entry in `generate_narration.py` (use "b" suffix if inserting between existing segments — e.g. `03b_public_key`)
3. add a `DUR` entry and a new scene class in `timed_scenes.py`
4. add the mapping line in `composite.sh`'s `SEGMENTS` array
5. add the segment ID to the hardcoded concat `for` loop in `composite.sh`

**when you reorder segments:**
1. reorder in `script.md`
2. reorder the `SEGMENTS` list in `generate_narration.py` (audio filenames don't change)
3. reorder the concat `for` loop in `composite.sh` (scene classes and audio files stay the same)
4. `timed_scenes.py` scene order doesn't matter — manim renders by class name, not position

**when you delete a segment:**
1. remove from `script.md`
2. remove from `generate_narration.py`'s `SEGMENTS`
3. remove the scene class from `timed_scenes.py` and its `DUR` entry
4. remove from both the `SEGMENTS` array and concat loop in `composite.sh`
5. optionally: `rm clips/XX_segment_name.wav output/segments/seg_XX.mp4`

**naming consistency across files:**

| file | naming pattern | example |
|------|---------------|---------|
| `script.md` | `## heading` | `## public key` |
| `generate_narration.py` | `"03b_public_key"` | filename stem |
| `timed_scenes.py` | `class S03b_PublicKey(Scene)` + `DUR["public_key"]` | class + dict key |
| `composite.sh` | `"03b:S03b_PublicKey:03b_public_key"` | id:class:audio |

the segment number (`03b`) ties them together. the descriptive name (`public_key`) keeps
code readable. maintain both consistently and you'll never lose track of which pieces
belong to which segment.

### step 2: record reference audio

record 8-12 seconds of yourself reading a line from the script. this becomes the
voice the AI will clone for all narration.

```bash
brew install sox          # one-time
rec clips/my_voice_ref.wav
# read your line, then Ctrl+C after ~1 second of silence
```

resample to 24kHz mono (required by f5-tts):
```bash
ffmpeg -y -i clips/my_voice_ref.wav -ac 1 -ar 24000 -sample_fmt s16 clips/my_voice_ref_24k.wav
```

**reference audio rules:**
- 8-12 seconds is the sweet spot. the model clips beyond ~12s internally
- leave ~1 second of silence at the end (prevents bleed into generated audio)
- do not cut off mid-word. let the sentence finish naturally
- speak in exactly the tone/pace you want — the model clones style, not just timbre
- clean audio matters more than length. no background noise, no clipping
- the transcription of what you said must be exact — the model uses text/audio ratio for timing

### step 3: generate narration

create `generate_narration.py` — the complete template below is copy-pasteable.
adapt `BASE`, `REF_AUDIO`, `REF_TEXT`, and `SEGMENTS` for your project.

**critical: use explicit `duration`, never `estimate_duration=True`.** the estimator
frequently overshoots, causing the model to split into chunks and hallucinate — we saw
it produce 103 seconds of audio for an 8-second line. always calculate duration manually.

```python
"""Generate all narration segments with explicit durations."""

from f5_tts_mlx.generate import generate
import subprocess
import os

BASE = "/path/to/your/project"
CLIPS = f"{BASE}/clips"

# ── reference audio ──────────────────────────────────────────
# path to your 24kHz mono reference recording
REF_AUDIO = f"{CLIPS}/my_voice_ref_24k.wav"

# EXACT transcription of what you said in the reference recording.
# the model uses text-to-audio-length ratio for timing — wrong text = garbled output.
REF_TEXT = (
    "the exact words you spoke in your reference recording, "
    "transcribed precisely as you said them."
)

# ── generation settings ──────────────────────────────────────
STEPS = 32      # 8 for drafts (fast), 32 for final (high quality)
CFG = 3.5       # voice adherence. 3.5 = sweet spot for cloning

# ── measure this from your reference file ────────────────────
# ffprobe -v error -show_entries format=duration -of csv=p=0 clips/my_voice_ref_24k.wav
REF_DUR = 12.25

# ── narration segments ──────────────────────────────────────
# (filename, spoken text, speech duration in seconds)
# duration rule of thumb: count words / 2.5, round up
SEGMENTS = [
    (
        "01_intro",
        "your first narration line goes here.",
        7.0,
    ),
    (
        "02_next_section",
        "your second narration line goes here.",
        10.0,
    ),
    # add all segments...
]


def generate_segment(name, text, speech_duration):
    """Generate one narration segment. Skips if file already exists."""
    out_path = f"{CLIPS}/{name}.wav"
    if os.path.exists(out_path):
        print(f"  skipping {name} (exists)")
        return out_path

    total_duration = REF_DUR + speech_duration
    print(f"  generating {name} ({speech_duration}s speech, {total_duration}s total)...")
    generate(
        generation_text=text,
        ref_audio_path=REF_AUDIO,
        ref_audio_text=REF_TEXT,
        duration=total_duration,
        speed=1.0,
        steps=STEPS,
        cfg_strength=CFG,
        output_path=out_path,
    )
    print(f"  done: {name}")
    return out_path


def concatenate_audio(segment_files, output_path):
    """Concatenate all segments with 0.5s silence gaps into one file."""
    silence = f"{CLIPS}/_silence.wav"
    subprocess.run([
        "ffmpeg", "-y", "-f", "lavfi", "-i",
        "anullsrc=r=24000:cl=mono", "-t", "0.5",
        "-c:a", "pcm_s16le", silence,
    ], capture_output=True)

    list_path = f"{CLIPS}/_concat_list.txt"
    with open(list_path, "w") as f:
        for i, seg in enumerate(segment_files):
            f.write(f"file '{seg}'\n")
            if i < len(segment_files) - 1:
                f.write(f"file '{silence}'\n")

    subprocess.run([
        "ffmpeg", "-y", "-f", "concat", "-safe", "0",
        "-i", list_path, "-c:a", "pcm_s16le", output_path,
    ], capture_output=True)
    print(f"full narration: {output_path}")


def main():
    os.makedirs(CLIPS, exist_ok=True)

    print("generating narration segments...")
    segment_files = []
    for name, text, dur in SEGMENTS:
        path = generate_segment(name, text, dur)
        segment_files.append(path)

    full_narration = f"{CLIPS}/full_narration.wav"
    print("\nconcatenating...")
    concatenate_audio(segment_files, full_narration)

    # print durations for verification
    print("\nsegment durations:")
    import soundfile as sf
    total = 0
    for name, _, _ in SEGMENTS:
        path = f"{CLIPS}/{name}.wav"
        data, sr = sf.read(path)
        dur = len(data) / sr
        total += dur
        print(f"  {name}: {dur:.1f}s")
    print(f"  TOTAL: {total:.1f}s")


if __name__ == "__main__":
    main()
```

**key design decisions:**
- `generate_segment` **skips existing files** — so you only regenerate what changed. to
  force regeneration of a segment, delete its `.wav` file first
- `concatenate_audio` produces a `full_narration.wav` — useful for listening to the whole
  thing end-to-end without video
- the duration printout at the end lets you verify timing before rendering animations

**to regenerate a changed segment:** `rm clips/09_schnorr_setup.wav clips/full_narration.wav`
then re-run `python generate_narration.py`. only the deleted segments get regenerated.

**quality/speed tradeoffs on M4 48GB:**

| steps | quality | time per ~10s segment |
|-------|---------|----------------------|
| 8     | draft   | ~10s                 |
| 32    | high    | ~1 min               |
| 64    | max     | ~2 min               |

use 8 steps while iterating on the script. bump to 32 for final. 64 is marginal improvement.

### step 4: build timed animations

create `timed_scenes.py` with one manim scene class per narration segment. each scene's
total duration (animations + waits) must equal its narration segment's duration.

use a shared `DUR` dict at the top of the file so durations are defined once and
referenced by both the scene classes and (mentally) by the narration script.

```python
from manim import *

# ── color palette (define once, use everywhere) ──────────────
BG = "#0f0f0f"
BLUE = "#3b82f6"
GREEN = "#22c55e"
RED = "#ef4444"
YELLOW = "#facc15"
WHITE = "#e2e8f0"

# ── durations from narration (seconds) ───────────────────────
# these MUST match the speech_duration values in generate_narration.py.
# use descriptive keys, not numbers — makes insertions painless.
DUR = {
    "intro": 7.0,
    "scenario": 10.0,
    "public_key": 14.0,
    "played": 10.0,
    "elegant": 4.0,
    # ... all segments
}


class S01_Intro(Scene):
    """7.0s — title card"""

    def setup(self):
        self.camera.background_color = BG

    def construct(self):
        d = DUR["intro"]

        title = Text("your title here", font="Courier New",
                      font_size=72, color=WHITE)
        self.play(FadeIn(title), run_time=0.8)   # 0.8
        self.wait(1.0)                             # 1.8
        self.play(title.animate.scale(1.05), run_time=0.3)  # 2.1
        self.play(title.animate.scale(1/1.05), run_time=0.3) # 2.4

        remaining = d - 2.4
        self.wait(max(remaining, 0.1))


class S05_Elegant(Scene):
    """4.0s — 'three messages. that's it.'"""

    def setup(self):
        self.camera.background_color = BG

    def construct(self):
        d = DUR["elegant"]

        text = Text("three messages.", font="Courier New",
                     font_size=48, color=WHITE)
        sub = Text("that's it.", font="Courier New",
                    font_size=36, color=YELLOW)
        sub.next_to(text, DOWN, buff=0.4)

        self.play(FadeIn(text, scale=0.9), run_time=0.5)
        self.wait(0.8)
        self.play(FadeIn(sub, shift=UP * 0.2), run_time=0.4)
        # 0.5 + 0.8 + 0.4 = 1.7s elapsed

        remaining = d - 1.7
        self.wait(max(remaining, 0.1))
```

**key patterns:**
- **DUR dict** — durations defined once at top, referenced by descriptive key. when you
  change a duration, update it in `DUR` and in `generate_narration.py`'s `SEGMENTS` list
- **elapsed time tracking** — comment cumulative elapsed time after each animation/wait,
  then use `self.wait(max(d - elapsed, 0.1))` at the end to pad to exact duration
- **scene naming** — `S01_Intro`, `S03b_PublicKey`, etc. the number prefix keeps them
  in order; the name suffix describes the content

### step 5: render animations

```bash
source .venv/bin/activate

# render a single scene (for iteration)
manim render -qm timed_scenes.py S05_Elegant

# render multiple specific scenes
manim render -qm timed_scenes.py S01_Intro S02_Scenario S03_Secret

# render ALL scenes in the file (for full rebuild)
manim render -qm timed_scenes.py
```

use `-ql` (480p/15fps) while iterating on animation content, `-qm` (720p/30fps) for review,
`-qh` for final.

output lands in `media/videos/timed_scenes/<quality>/S01_Intro.mp4` — e.g. `720p30/` for
`-qm`. **important:** `composite.sh`'s `VIDEO` path must match the quality you rendered at.
if you render at `-ql` but composite.sh points to `720p30/`, it won't find the files.

### step 6: composite and concatenate

create `composite.sh` — the complete template below is copy-pasteable.
adapt `BASE` and the `SEGMENTS` array for your project.

```bash
#!/bin/bash
# Composite all animation + narration segments into final video

BASE="/path/to/your/project"
CLIPS="$BASE/clips"
VIDEO="$BASE/media/videos/timed_scenes/720p30"
OUT="$BASE/output"

mkdir -p "$OUT/segments"

# ── segment mapping ──────────────────────────────────────────
# format: "segment_id:SceneClassName:audio_filename"
# segment_id = used for output filename (seg_01.mp4, seg_03b.mp4, etc.)
# SceneClassName = manim class name (matches the .mp4 in media/videos/)
# audio_filename = clip name without .wav extension
SEGMENTS=(
    "01:S01_Intro:01_intro"
    "02:S02_Scenario:02_scenario"
    "03:S03_Secret:03_secret"
    # use "b" suffixes for inserted scenes (avoids renumbering everything)
    "03b:S03b_PublicKey:03b_public_key"
    "04:S04_NextSection:04_next_section"
    # ... add all segments
)

echo "=== compositing segments ==="

# ── pair each video + audio ──────────────────────────────────
for entry in "${SEGMENTS[@]}"; do
    IFS=: read -r num scene audio <<< "$entry"
    video_file="$VIDEO/${scene}.mp4"
    audio_file="$CLIPS/${audio}.wav"
    output_file="$OUT/segments/seg_${num}.mp4"

    if [ ! -f "$video_file" ]; then
        echo "WARNING: missing video $video_file"
        continue
    fi
    if [ ! -f "$audio_file" ]; then
        echo "WARNING: missing audio $audio_file"
        continue
    fi

    echo "  compositing segment $num ($scene + $audio)..."
    ffmpeg -y -i "$video_file" -i "$audio_file" \
        -c:v libx264 -preset fast -crf 18 -pix_fmt yuv420p \
        -c:a aac -b:a 192k \
        -shortest -movflags +faststart \
        "$output_file" 2>/dev/null
done

echo ""
echo "=== concatenating final video ==="

# ── build concat list ────────────────────────────────────────
# IMPORTANT: hardcode the segment IDs here — do NOT use seq/printf
# (bash interprets 08/09 as invalid octal)
CONCAT_LIST="$OUT/concat_list.txt"
> "$CONCAT_LIST"
for num in 01 02 03 03b 04; do  # list ALL segment IDs in order
    echo "file 'segments/seg_${num}.mp4'" >> "$CONCAT_LIST"
done

# ── concatenate all segments ─────────────────────────────────
# re-encode for reliable playback (do NOT use -c copy — causes freezing)
ffmpeg -y -f concat -safe 0 \
    -i "$CONCAT_LIST" \
    -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
    -c:a aac -b:a 192k \
    -movflags +faststart \
    "$OUT/final_video.mp4" 2>/dev/null

echo ""
echo "=== done ==="
echo "final video: $OUT/final_video.mp4"
```

**key design decisions:**
- the `SEGMENTS` array defines the mapping from scene names to audio clips.
  add/remove/reorder entries here and everything follows
- `-shortest` on per-segment compositing handles tiny duration mismatches between
  manim video and generated audio
- `-pix_fmt yuv420p` ensures QuickTime/browser compatibility
- `-movflags +faststart` puts the moov atom first so the video plays immediately
- **do NOT use `-c copy` for concat** — even with identical codecs, stream-copy can cause
  playback freezing. re-encoding is slower but reliable

**re-compositing after changes:**
when you change a single scene or audio clip, just re-run `bash composite.sh`. it
re-composites everything (fast — each segment takes ~1s). to be selective, comment out
unchanged segments in the array temporarily.

## manim reference

### useful primitives

- `MathTex(r"...")` — LaTeX math. use `{{ }}` double braces for sub-part morphing
- `Text("...", font="Courier New")` — plain text in monospace
- `Arrow(start, end)` — animate with `GrowArrow()`
- `Graph(vertices, edges, layout=...)` — network graphs
- `SurroundingRectangle(obj)` — highlight box
- `VGroup(a, b, c)` — group for collective animation
- `Dot(point, color=..., radius=...)` — simple dots
- `RoundedRectangle(width, height, corner_radius)` — boxes

### animation patterns

```python
self.play(FadeIn(obj), run_time=0.5)
self.play(obj.animate.move_to(RIGHT * 3), run_time=0.8)
self.play(TransformMatchingTex(eq1, eq2))
self.play(Flash(obj, color=RED, flash_radius=0.5))
self.play(FadeIn(a), GrowArrow(b), run_time=0.6)           # simultaneous
self.play(obj.animate.shift(LEFT * 5),
          rate_func=rate_functions.ease_in_cubic)            # easing
self.play(obj.animate.set_fill(GREEN, opacity=0.8))         # color change
self.play(obj.animate.scale(1.5).set_opacity(0))            # scale + fade
```

### rendering quality flags

| flag | resolution | fps | use case |
|------|-----------|-----|----------|
| `-ql` | 854x480 | 15 | fast iteration |
| `-qm` | 1280x720 | 30 | review drafts |
| `-qh` | 1920x1080 | 60 | final render |
| `-qk` | 3840x2160 | 60 | 4K final |

## f5-tts-mlx parameter reference

| parameter | default | recommended | notes |
|-----------|---------|-------------|-------|
| `steps` | 8 | 32 | diffusion steps. 8=draft, 32=production, 64=diminishing returns |
| `cfg_strength` | 2.0 | 3.5 | voice adherence. higher = sounds more like reference |
| `speed` | 1.0 | 1.0 | speech rate. use when `estimate_duration` (not recommended) |
| `method` | "rk4" | "rk4" | solver. rk4 is best quality |
| `seed` | None | set for reproducibility | |
| `sway_sampling_coef` | -1.0 | -1.0 | sampling diversity |

## project structure

```
project/
├── script.md              # script: spoken lines + [MANIM:] + [DIRECTOR:] cues
├── timed_scenes.py        # manim scenes, one class per narration segment
├── generate_narration.py  # f5-tts batch generation with explicit durations
├── composite.sh           # ffmpeg: pair audio+video, then concatenate
├── skill.md               # this file
├── brainstorm.md          # initial ideas
├── clips/                 # audio
│   ├── my_voice_ref.wav       # raw mic recording
│   ├── my_voice_ref_24k.wav   # resampled for f5-tts
│   ├── 01_intro.wav           # generated narration segments
│   ├── 02_scenario.wav
│   └── ...
├── output/                # final product
│   ├── segments/              # individual composited segments
│   │   ├── seg_01.mp4
│   │   └── ...
│   ├── concat_list.txt
│   └── final_video.mp4       # the final video
├── media/                 # manim output (auto-generated)
│   └── videos/timed_scenes/720p30/*.mp4
└── .venv/                 # python virtual environment
```

## lessons learned (the hard way)

### f5-tts-mlx
- **never use `estimate_duration=True`** — it caused 103-second audio for an 8-second line. the model chunks the text, each chunk overshoots, and you get minutes of hallucinated speech. always pass explicit `duration = ref_duration + speech_duration`
- **transcription accuracy is critical** — the model uses text-to-audio-length ratio for internal timing. wrong transcription = garbled output, repeated words, or reference audio leaking into generated speech
- **cfg_strength=3.5 is the cloning sweet spot** — lower values (2.0) sound natural but less like you. 3.5 strikes the balance. above 4.0 starts sounding overfit
- **reference audio must be 24kHz mono** — the model hard-errors on anything else. always resample with ffmpeg before use
- **8-12 seconds of clean reference is ideal** — more isn't better (model clips at 12s internally). a 12s reference typically leaves up to ~20s for generated speech per call (total ~32s works fine)

### manim
- **one scene class per narration segment** — much easier to time than monolithic scenes that try to cover multiple narration chunks
- **networkx layouts are 2d, manim wants 3d** — convert with `{k: [v[0], v[1], 0] for k, v in layout.items()}`
- **`Text` submobjects are SVG paths, not characters** — don't access `.text` on them. for scatter-assemble animations, use `save_state()` + `Restore()` instead of manually indexing characters
- **track elapsed time in comments** — the `self.wait(max(target - elapsed, 0.1))` pattern at the end of each scene ensures exact duration matching
- **render in parallel** — scenes are independent. launching all with `&` + `wait` reduces total render time from sum to max

### ffmpeg / bash
- **never use `seq`/`printf` with zero-padded numbers like 08, 09** — bash interprets them as invalid octal. hardcode the list instead
- **re-encode at both stages** — per-segment to mux video + audio, and again during final concat. stream-copy concat (`-c copy`) can cause playback freezing even when all segments share the same codec. re-encoding the final concat with `-pix_fmt yuv420p -movflags +faststart` produces universally playable output
- **two compositing strategies** — the template uses `-shortest`, which works when audio and video durations roughly match (the common case). but if you add per-segment audio padding (lead-in silence, fades, tail silence), the audio becomes longer than the video. in that case, `-shortest` will clip the padded audio. use the `tpad` approach instead:
  ```bash
  adur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 audio.wav)
  ffmpeg -y -i video.mp4 -i audio.wav \
      -vf "tpad=stop_mode=clone:stop_duration=3" \
      -c:v libx264 -preset fast -crf 18 -pix_fmt yuv420p \
      -c:a aac -b:a 192k \
      -t "$adur" -movflags +faststart \
      output.mp4
  ```
  this freezes the last video frame to fill the gap. do NOT use `-stream_loop -1` to extend video — it loops from the beginning instead of freezing
- **optional: per-segment audio padding** — to add breathing room, pad each narration clip before compositing. get the audio duration first, then apply lead-in silence, fade-in, fade-out, and tail silence:
  ```bash
  dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 input.wav)
  fade_out_start=$(echo "$dur - 0.3" | bc)
  ffmpeg -i input.wav -af "adelay=400|400,afade=t=in:d=0.15,afade=t=out:st=${fade_out_start}:d=0.3,apad=pad_dur=0.8" output.wav
  ```
  if you do this, use the `tpad` compositing approach above (not `-shortest`)

### workflow
- **iterate audio at 8 steps, video at `-ql`** — both are 5-10x faster than production quality, letting you check timing and content before committing to a full render. when using `-ql` for iteration, update `composite.sh`'s `VIDEO` path to `480p15` temporarily, or just render at `-qm` throughout (the speed difference is modest)
- **the script is the single source of truth** — animation cues, director's notes, and spoken lines all live in `script.md`. the narration generator, manim scenes, and composite script all derive from it
- **voice reference recording matters more than you think** — the AI clones your cadence, energy, and pacing, not just your timbre. if you record flat, every line sounds flat. record with the energy you want in the final video
