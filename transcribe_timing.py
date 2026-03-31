"""Transcribe voiceover audio with word-level timestamps.

Uses Whisper to extract precise word timings from recorded voiceover,
so you can sync manim animations to exactly when you say each phrase.

Usage:
    python transcribe_timing.py              # all segments
    python transcribe_timing.py 02           # just segment 02
    python transcribe_timing.py 02 --phrases "identity function" "abstraction"
                                              # highlight specific phrases

Then use the timestamps as CUE_* constants in timed_scenes.py:

    CUE_IDENTITY = 41.2   # from transcribe_timing.py
    self.wait(max(CUE_IDENTITY - elapsed - 0.8, 0.1))
    elapsed = CUE_IDENTITY - 0.8
    self.play(Write(identity), run_time=0.8)
    elapsed += 0.8
"""

import sys
import os
import glob
import mlx_whisper

MODEL = "mlx-community/whisper-large-v3-turbo"


def transcribe(audio_path):
    """Return word-level timestamps for an audio file."""
    result = mlx_whisper.transcribe(
        audio_path,
        path_or_hf_repo=MODEL,
        word_timestamps=True,
        language="en",
    )
    words = []
    for seg in result.get("segments", []):
        for w in seg.get("words", []):
            words.append({
                "word": w["word"].strip(),
                "start": w["start"],
                "end": w["end"],
            })
    return words


def print_timing(name, words, phrases=None):
    """Print word timestamps, highlighting phrase matches."""
    print(f"\n{'='*60}")
    print(f"  {name}")
    print(f"{'='*60}")

    for w in words:
        marker = ""
        if phrases:
            wl = w["word"].lower()
            for ph in phrases:
                if wl in ph.lower().split():
                    marker = f"  <-- [{ph}]"
                    break
        print(f"  {w['start']:6.2f}s  {w['word']}{marker}")

    if phrases:
        print(f"\n  --- phrase cue points ---")
        for ph in phrases:
            ph_words = ph.lower().split()
            for i in range(len(words) - len(ph_words) + 1):
                match = all(
                    words[i + j]["word"].lower().strip(".,!?;:") == pw.strip(".,!?;:")
                    for j, pw in enumerate(ph_words)
                )
                if match:
                    print(f"  {words[i]['start']:6.2f}s  \"{ph}\"")
                    break
            else:
                for i, w in enumerate(words):
                    if ph.lower() in w["word"].lower():
                        print(f"  {w['start']:6.2f}s  \"{ph}\" (partial: \"{w['word']}\")")
                        break

    print()


def main():
    clips_dir = "clips"
    segment_filter = None
    phrases = None

    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--phrases":
            phrases = args[i + 1:]
            break
        else:
            segment_filter = args[i]
        i += 1

    vo_files = sorted(glob.glob(f"{clips_dir}/vo_*.wav"))
    if not vo_files:
        print("No voiceover files found in clips/")
        sys.exit(1)

    for vo_path in vo_files:
        name = os.path.basename(vo_path).replace("vo_", "").replace(".wav", "")
        seg_num = name.split("_")[0]

        if segment_filter and seg_num != segment_filter:
            continue

        print(f"\nTranscribing {vo_path}...")
        words = transcribe(vo_path)
        print_timing(name, words, phrases)


if __name__ == "__main__":
    main()
