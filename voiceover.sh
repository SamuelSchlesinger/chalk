#!/bin/bash
# Record voiceover, composite segments, check durations, preview.
#
# Usage:
#   ./voiceover.sh record          — record all segments
#   ./voiceover.sh record 05       — record just segment 05
#   ./voiceover.sh record-from 05  — record from segment 05 onwards
#   ./voiceover.sh composite       — composite segments
#   ./voiceover.sh composite-shorts — composite shorts (1080x1920 vertical)
#   ./voiceover.sh durations       — compare voiceover vs video durations
#   ./voiceover.sh play 05         — preview segment 05 video

set -euo pipefail

BASE="."
CLIPS="$BASE/clips"
OUT="$BASE/output"

# ── auto-detect render quality ───────────────────────────────
# check from highest to lowest quality
VIDEO=""
for q in 2160p60 1440p60 1080p60 720p30 480p15; do
    if [ -d "$BASE/media/videos/timed_scenes/$q" ]; then
        VIDEO="$BASE/media/videos/timed_scenes/$q"
        break
    fi
done
if [ -z "$VIDEO" ]; then
    echo "WARNING: no rendered videos found in media/videos/timed_scenes/"
    echo "  render first: manim render -qh timed_scenes.py SceneName"
    VIDEO="$BASE/media/videos/timed_scenes/1080p60"  # fallback
fi

# ── project slug (used for final output filename) ────────────
# Change this to match your video title.
SLUG="my_video"

mkdir -p "$OUT/segments"

# ── segment registry ──────────────────────────────────────────
# id:SceneClass:audio_stem:description
SEGMENTS=(
    "01:S01_Intro:01_intro:intro"
    # add segments here...
    # "02:S02_Concept:02_concept:the core concept"
)

# ── script text for recording prompts ─────────────────────────
# index matches SEGMENTS order
SCRIPTS=(
    "opening line goes here"
    # add matching script text...
)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# recording
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

record_segment() {
    local num="$1" scene="$2" audio="$3" desc="$4" idx="$5"
    local video_file="$VIDEO/${scene}.mp4"
    local vo_file="$CLIPS/vo_${audio}.wav"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Segment $num: $desc"

    local vdur
    vdur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$video_file" 2>/dev/null)
    [ -n "$vdur" ] && echo "  Video duration: ${vdur}s"
    echo "  Output: $vo_file"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ -f "$vo_file" ]; then
        local existing_dur
        existing_dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$vo_file" 2>/dev/null)
        echo "  (existing recording: ${existing_dur}s)"
    fi

    echo ""
    echo "  Script:"
    echo "  ───────"
    echo "  ${SCRIPTS[$idx]}" | fmt -w 70 | sed 's/^/  /'
    echo ""
    echo "  (speak at your natural pace — animation will be adjusted to fit)"
    echo ""

    while true; do
        read -rp "  (r)ecord / (s)kip / (p)layback / (q)uit? " choice
        case "$choice" in
            r)
                echo ""
                echo "  3..."
                sleep 1
                echo "  2..."
                sleep 1
                echo "  1..."
                sleep 1
                echo "  Recording... press ENTER when done"
                echo ""

                rec -q -r 24000 -c 1 -b 16 "$vo_file" 2>/dev/null &
                REC_PID=$!

                if [ -f "$video_file" ]; then
                    ffplay -autoexit -window_title "Segment $num" \
                        -x 960 -y 540 \
                        "$video_file" 2>/dev/null &
                    FFPLAY_PID=$!
                else
                    FFPLAY_PID=""
                fi

                read -rp "  (press ENTER to stop recording) "

                kill $REC_PID 2>/dev/null
                wait $REC_PID 2>/dev/null
                [ -n "$FFPLAY_PID" ] && kill $FFPLAY_PID 2>/dev/null && wait $FFPLAY_PID 2>/dev/null

                local rec_dur
                rec_dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$vo_file" 2>/dev/null)
                echo ""
                echo "  Saved: $vo_file (${rec_dur}s)"

                read -rp "  (k)eep / (r)e-record / (p)lay back? " choice2
                case "$choice2" in
                    k) return ;;
                    p)
                        ffplay -autoexit -nodisp "$vo_file" 2>/dev/null
                        read -rp "  (k)eep / (r)e-record? " choice3
                        [ "$choice3" = "r" ] && continue
                        return
                        ;;
                    r) continue ;;
                    *) return ;;
                esac
                ;;
            s) return ;;
            p)
                if [ -f "$vo_file" ]; then
                    ffplay -autoexit -nodisp "$vo_file" 2>/dev/null
                fi
                ;;
            q) exit 0 ;;
            *) ;;
        esac
    done
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# durations
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

do_durations() {
    echo ""
    printf "%-4s  %-30s  %8s  %8s  %8s\n" "SEG" "DESCRIPTION" "VIDEO" "VOICE" "DIFF"
    printf "%-4s  %-30s  %8s  %8s  %8s\n" "───" "──────────────────────────────" "────────" "────────" "────────"
    for entry in "${SEGMENTS[@]}"; do
        IFS=: read -r num scene audio desc <<< "$entry"
        local video_file="$VIDEO/${scene}.mp4"
        local vo_file="$CLIPS/vo_${audio}.wav"

        vdur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$video_file" 2>/dev/null)

        if [ -f "$vo_file" ]; then
            adur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$vo_file" 2>/dev/null)
            diff=$(python3 -c "d=float('${adur}')-float('${vdur}'); print(f'{d:+.1f}s' + (' !!!' if abs(d)>2 else ''))")
            printf "%-4s  %-30s  %7.1fs  %7.1fs  %s\n" "$num" "${desc:0:30}" "$vdur" "$adur" "$diff"
        else
            printf "%-4s  %-30s  %7.1fs  %8s  %s\n" "$num" "${desc:0:30}" "$vdur" "—" "(no recording)"
        fi
    done
    echo ""
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# composite
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

do_composite() {
    echo "=== compositing segments ==="

    for entry in "${SEGMENTS[@]}"; do
        IFS=: read -r num scene audio desc <<< "$entry"
        local video_file="$VIDEO/${scene}.mp4"
        local audio_file="$CLIPS/vo_${audio}.wav"
        local output_file="$OUT/segments/seg_${num}.mp4"

        if [ ! -f "$audio_file" ]; then
            echo "WARNING: no audio for segment $num"
            continue
        fi

        if [ ! -f "$video_file" ]; then
            echo "WARNING: missing video $video_file"
            continue
        fi

        echo "  $num ($scene)..."

        # if audio is longer than video, freeze last frame
        adur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$audio_file" 2>/dev/null)
        vdur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$video_file" 2>/dev/null)
        longer=$(python3 -c "print('audio' if float('${adur}') > float('${vdur}') + 0.5 else 'ok')")

        if [ "$longer" = "audio" ]; then
            pad=$(python3 -c "print(f'{float(\"${adur}\") - float(\"${vdur}\") + 0.5:.1f}')")
            ffmpeg -y -i "$video_file" -i "$audio_file" \
                -filter_complex "[0:v]tpad=stop_mode=clone:stop_duration=${pad}[vout]" \
                -map "[vout]" -map 1:a \
                -c:v libx264 -preset fast -crf 18 -pix_fmt yuv420p \
                -af "loudnorm=I=-16:TP=-1.5:LRA=11" \
                -c:a aac -b:a 192k \
                -shortest -movflags +faststart \
                "$output_file" 2>/dev/null
        else
            # pad audio with silence to match video length so -shortest
            # doesn't clip the ending (video is longer due to VISUAL_DELAY)
            ffmpeg -y -i "$video_file" -i "$audio_file" \
                -c:v libx264 -preset fast -crf 18 -pix_fmt yuv420p \
                -af "apad,loudnorm=I=-16:TP=-1.5:LRA=11" \
                -c:a aac -b:a 192k \
                -shortest -movflags +faststart \
                "$output_file" 2>/dev/null
        fi
    done

    echo ""
    echo "=== concatenating final video ==="

    CONCAT_LIST="$OUT/concat_list.txt"
    > "$CONCAT_LIST"
    for entry in "${SEGMENTS[@]}"; do
        IFS=: read -r num scene audio desc <<< "$entry"
        echo "file 'segments/seg_${num}.mp4'" >> "$CONCAT_LIST"
    done

    # pass 1: measure loudness
    echo "  pass 1: measuring loudness..."
    LOUDNORM_STATS=$(ffmpeg -y -f concat -safe 0 \
        -i "$CONCAT_LIST" \
        -af loudnorm=I=-14:TP=-1:LRA=11:print_format=json \
        -f null - 2>&1 | grep -A 20 '"input_')

    INPUT_I=$(echo "$LOUDNORM_STATS" | grep input_i | sed 's/[^0-9.-]//g')
    INPUT_TP=$(echo "$LOUDNORM_STATS" | grep input_tp | sed 's/[^0-9.-]//g')
    INPUT_LRA=$(echo "$LOUDNORM_STATS" | grep input_lra | sed 's/[^0-9.-]//g')
    INPUT_THRESH=$(echo "$LOUDNORM_STATS" | grep input_thresh | sed 's/[^0-9.-]//g')

    echo "  measured: I=${INPUT_I} LUFS, TP=${INPUT_TP} dBTP, LRA=${INPUT_LRA}"

    # pass 2: encode with measured values
    echo "  pass 2: encoding with loudnorm..."
    ffmpeg -y -f concat -safe 0 \
        -i "$CONCAT_LIST" \
        -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
        -af loudnorm=I=-14:TP=-1:LRA=11:measured_I=${INPUT_I}:measured_TP=${INPUT_TP}:measured_LRA=${INPUT_LRA}:measured_thresh=${INPUT_THRESH}:linear=true \
        -c:a aac -b:a 192k \
        -movflags +faststart \
        "$OUT/$SLUG.mp4" 2>/dev/null

    echo ""
    echo "=== done ==="
    echo "final video: $OUT/$SLUG.mp4"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# composite-shorts (1080x1920 vertical)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

do_composite_shorts() {
    # find shorts video directory
    SHORTS_VIDEO=""
    for q in 1920p60 1920p30 1920p15; do
        if [ -d "$BASE/media/videos/timed_scenes_shorts/$q" ]; then
            SHORTS_VIDEO="$BASE/media/videos/timed_scenes_shorts/$q"
            break
        fi
    done
    if [ -z "$SHORTS_VIDEO" ]; then
        echo "ERROR: no shorts videos found."
        echo "  render first: manim render -r 1080,1920 --fps 60 -qh timed_scenes_shorts.py SceneName"
        echo "  NOTE: -r takes height,width (not width,height!)"
        exit 1
    fi

    SHORTS_OUT="$BASE/output/shorts"
    mkdir -p "$SHORTS_OUT/segments"

    echo "=== compositing shorts segments ==="
    echo "  source: $SHORTS_VIDEO"

    for entry in "${SEGMENTS[@]}"; do
        IFS=: read -r num scene audio desc <<< "$entry"
        local video_file="$SHORTS_VIDEO/${scene}.mp4"
        local audio_file="$CLIPS/vo_${audio}.wav"
        local output_file="$SHORTS_OUT/segments/seg_${num}.mp4"

        if [ ! -f "$audio_file" ]; then
            echo "WARNING: no audio for segment $num"
            continue
        fi

        if [ ! -f "$video_file" ]; then
            echo "WARNING: missing video $video_file"
            continue
        fi

        echo "  $num ($scene)..."

        adur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$audio_file" 2>/dev/null)
        vdur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$video_file" 2>/dev/null)
        longer=$(python3 -c "print('audio' if float('${adur}') > float('${vdur}') + 0.5 else 'ok')")

        if [ "$longer" = "audio" ]; then
            pad=$(python3 -c "print(f'{float(\"${adur}\") - float(\"${vdur}\") + 0.5:.1f}')")
            ffmpeg -y -i "$video_file" -i "$audio_file" \
                -filter_complex "[0:v]tpad=stop_mode=clone:stop_duration=${pad}[vout]" \
                -map "[vout]" -map 1:a \
                -c:v libx264 -preset fast -crf 18 -pix_fmt yuv420p \
                -af "loudnorm=I=-16:TP=-1.5:LRA=11" \
                -c:a aac -b:a 192k \
                -shortest -movflags +faststart \
                "$output_file" 2>/dev/null
        else
            ffmpeg -y -i "$video_file" -i "$audio_file" \
                -c:v libx264 -preset fast -crf 18 -pix_fmt yuv420p \
                -af "apad,loudnorm=I=-16:TP=-1.5:LRA=11" \
                -c:a aac -b:a 192k \
                -shortest -movflags +faststart \
                "$output_file" 2>/dev/null
        fi
    done

    echo ""
    echo "=== concatenating shorts video ==="

    CONCAT_LIST="$SHORTS_OUT/concat_list.txt"
    > "$CONCAT_LIST"
    for entry in "${SEGMENTS[@]}"; do
        IFS=: read -r num scene audio desc <<< "$entry"
        echo "file 'segments/seg_${num}.mp4'" >> "$CONCAT_LIST"
    done

    echo "  pass 1: measuring loudness..."
    LOUDNORM_STATS=$(ffmpeg -y -f concat -safe 0 \
        -i "$CONCAT_LIST" \
        -af loudnorm=I=-14:TP=-1:LRA=11:print_format=json \
        -f null - 2>&1 | grep -A 20 '"input_')

    INPUT_I=$(echo "$LOUDNORM_STATS" | grep input_i | sed 's/[^0-9.-]//g')
    INPUT_TP=$(echo "$LOUDNORM_STATS" | grep input_tp | sed 's/[^0-9.-]//g')
    INPUT_LRA=$(echo "$LOUDNORM_STATS" | grep input_lra | sed 's/[^0-9.-]//g')
    INPUT_THRESH=$(echo "$LOUDNORM_STATS" | grep input_thresh | sed 's/[^0-9.-]//g')

    echo "  measured: I=${INPUT_I} LUFS, TP=${INPUT_TP} dBTP, LRA=${INPUT_LRA}"

    echo "  pass 2: encoding with loudnorm..."
    ffmpeg -y -f concat -safe 0 \
        -i "$CONCAT_LIST" \
        -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
        -af loudnorm=I=-14:TP=-1:LRA=11:measured_I=${INPUT_I}:measured_TP=${INPUT_TP}:measured_LRA=${INPUT_LRA}:measured_thresh=${INPUT_THRESH}:linear=true \
        -c:a aac -b:a 192k \
        -movflags +faststart \
        "$SHORTS_OUT/${SLUG}_shorts.mp4" 2>/dev/null

    echo ""
    echo "=== done ==="
    echo "shorts video: $SHORTS_OUT/${SLUG}_shorts.mp4"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# main
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

case "${1:-}" in
    record)
        if [ -n "${2:-}" ]; then
            idx=0
            for entry in "${SEGMENTS[@]}"; do
                IFS=: read -r num scene audio desc <<< "$entry"
                if [ "$num" = "$2" ]; then
                    record_segment "$num" "$scene" "$audio" "$desc" "$idx"
                    exit 0
                fi
                idx=$((idx + 1))
            done
            echo "Unknown segment: $2"
            exit 1
        else
            echo "=== voiceover recording session ==="
            echo "Each segment: see script -> video autoplays -> speak along."
            echo "Press ENTER to stop recording. 's' to skip."
            echo ""
            idx=0
            for entry in "${SEGMENTS[@]}"; do
                IFS=: read -r num scene audio desc <<< "$entry"
                record_segment "$num" "$scene" "$audio" "$desc" "$idx"
                idx=$((idx + 1))
            done
            echo ""
            echo "=== all segments recorded ==="
            do_durations
        fi
        ;;
    record-from)
        if [ -z "${2:-}" ]; then
            echo "Usage: $0 record-from <segment_number>"
            exit 1
        fi
        echo "=== voiceover recording session (from segment $2) ==="
        echo "Each segment: see script -> video autoplays -> speak along."
        echo "Press ENTER to stop recording. 's' to skip."
        echo ""
        started=false
        idx=0
        for entry in "${SEGMENTS[@]}"; do
            IFS=: read -r num scene audio desc <<< "$entry"
            if [ "$num" = "$2" ]; then
                started=true
            fi
            if $started; then
                record_segment "$num" "$scene" "$audio" "$desc" "$idx"
            fi
            idx=$((idx + 1))
        done
        if ! $started; then
            echo "Unknown segment: $2"
            exit 1
        fi
        echo ""
        echo "=== all segments recorded ==="
        do_durations
        ;;
    composite)
        do_composite
        ;;
    composite-shorts)
        do_composite_shorts
        ;;
    durations)
        do_durations
        ;;
    play)
        if [ -z "${2:-}" ]; then
            echo "Usage: $0 play <segment_number>"
            exit 1
        fi
        for entry in "${SEGMENTS[@]}"; do
            IFS=: read -r num scene audio desc <<< "$entry"
            if [ "$num" = "$2" ]; then
                echo "Playing $scene..."
                ffplay -autoexit -window_title "Segment $num" \
                    -x 960 -y 540 \
                    "$VIDEO/${scene}.mp4" 2>/dev/null
                exit 0
            fi
        done
        echo "Unknown segment: $2"
        ;;
    *)
        echo "Usage:"
        echo "  $0 record              — record all segments (video autoplays)"
        echo "  $0 record 05           — record just segment 05"
        echo "  $0 record-from 05      — record from segment 05 onwards"
        echo "  $0 durations           — compare voiceover vs video durations"
        echo "  $0 composite           — composite landscape"
        echo "  $0 composite-shorts    — composite shorts (1080x1920 vertical)"
        echo "  $0 play 05             — preview segment 05 video"
        echo ""
        echo "Segments:"
        for entry in "${SEGMENTS[@]}"; do
            IFS=: read -r num scene audio desc <<< "$entry"
            vo_file="$CLIPS/vo_${audio}.wav"
            if [ -f "$vo_file" ]; then
                echo "  $num: $desc  [recorded]"
            else
                echo "  $num: $desc"
            fi
        done
        echo ""
        echo "Workflow:"
        echo "  1. ./voiceover.sh record            — record at your natural pace"
        echo "  2. ./voiceover.sh durations         — see what needs longer animations"
        echo "  3. ask claude to adjust DUR + re-render"
        echo "  4. ./voiceover.sh composite         — build final video"
        echo "  5. ./voiceover.sh composite-shorts  — build shorts version (optional)"
        ;;
esac
