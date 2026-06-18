#!/bin/bash
# HATAN OS — تبديل تسجيل الشاشة (فيديو)

set -euo pipefail

HATAN_DIR="${HATAN_DIR:-/opt/hatan-os}"
PIDFILE="/tmp/hatan-recording.pid"
METAFILE="/tmp/hatan-recording.meta"
STATUSFILE="/tmp/hatan-capture-status.json"

OUT_BASE="${HOME}/${HATAN_OUTPUT_DIR:-Videos/HATAN}"
mkdir -p "$OUT_BASE"

notify() {
    if command -v notify-send &>/dev/null; then
        notify-send -a "HATAN OS" "$1" "$2" 2>/dev/null || true
    fi
}

write_status() {
    local recording="$1"
    local extra="${2:-}"
    python3 - "$recording" "$extra" <<'PY'
import json, sys, os
from datetime import datetime, timezone
recording = sys.argv[1] == 'true'
extra = sys.argv[2] if len(sys.argv) > 2 else ''
path = '/tmp/hatan-capture-status.json'
data = {}
if os.path.isfile(path):
    try:
        with open(path, encoding='utf-8') as f:
            data = json.load(f)
    except Exception:
        pass
data['recording'] = recording
data['updatedAt'] = datetime.now(timezone.utc).isoformat()
if extra and not recording:
    data['lastFile'] = extra
if recording:
    data['startedAt'] = datetime.now(timezone.utc).isoformat()
else:
    data['startedAt'] = None
with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
PY
}

stop_recording() {
    if [[ ! -f "$PIDFILE" ]]; then
        return 1
    fi
    local pid
    pid=$(cat "$PIDFILE")
    local outfile=""
    [[ -f "$METAFILE" ]] && outfile=$(cat "$METAFILE")

    if kill -0 "$pid" 2>/dev/null; then
        kill -INT "$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
        for _ in $(seq 1 20); do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.25
        done
        kill -9 "$pid" 2>/dev/null || true
    fi

    rm -f "$PIDFILE" "$METAFILE"
    write_status false "$outfile"
    notify "HATAN OS" "⏹ تم إيقاف التسجيل"
    [[ -n "$outfile" ]] && echo "$outfile"
    return 0
}

start_recording() {
    local ts outfile
    ts=$(date +%Y%m%d-%H%M%S)
    outfile="${OUT_BASE}/hatan-${ts}.mp4"
    local audio_flag=()
    [[ "${HATAN_CAPTURE_AUDIO:-1}" == "1" ]] && audio_flag=(-a)

    if command -v gpu-screen-recorder &>/dev/null; then
        gpu-screen-recorder -f mp4 -o "$outfile" "${audio_flag[@]}" &
    elif command -v wf-recorder &>/dev/null; then
        if [[ "${HATAN_CAPTURE_AUDIO:-1}" == "1" ]]; then
            wf-recorder -f "$outfile" -a &
        else
            wf-recorder -f "$outfile" &
        fi
    elif command -v ffmpeg &>/dev/null; then
        ffmpeg -y -f kmsgrab -i - -f pulse -i default -c:v libx264 -preset ultrafast "$outfile" &
    else
        notify "HATAN OS" "❌ لا يوجد برنامج تسجيل (wf-recorder / gpu-screen-recorder)"
        return 1
    fi

    echo $! > "$PIDFILE"
    echo "$outfile" > "$METAFILE"
    write_status true
    notify "HATAN OS" "🔴 جاري تسجيل الشاشة..."
    echo "$outfile"
}

case "${1:-toggle}" in
    start)  start_recording ;;
    stop)   stop_recording ;;
    status)
        if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
            echo recording
        else
            echo idle
        fi
        ;;
    toggle|*)
        if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
            stop_recording
        else
            start_recording
        fi
        ;;
esac
