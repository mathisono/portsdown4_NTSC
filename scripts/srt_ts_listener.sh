#!/usr/bin/env bash
# Receive one SRT caller and remux its video/audio into MPEG-TS.
# This is an ingest tool; it does not start a transmitter or control PTT.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: srt_ts_listener.sh --output FILE|FIFO|udp://HOST:PORT [--port PORT] [--bind IPv4] [--latency-ms MS]

Listen for one SRT caller (for example an ATEM Mini Pro) and copy its first
video and optional first audio stream into MPEG-TS without re-encoding.
Defaults: bind 0.0.0.0, UDP port 9000, SRT latency 200 ms.
EOF
}

bind=0.0.0.0
port=9000
latency_ms=200
output=

while (($#)); do
  case "$1" in
    --bind|--port|--latency-ms|--output)
      (($# >= 2)) || { usage >&2; exit 2; }
      case "$1" in
        --bind) bind=$2;;
        --port) port=$2;;
        --latency-ms) latency_ms=$2;;
        --output) output=$2;;
      esac
      shift 2
      ;;
    -h|--help) usage; exit 0;;
    *) usage >&2; exit 2;;
  esac
done

[[ $bind =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'bind must be an IPv4 address' >&2; exit 2; }
[[ $port =~ ^[0-9]+$ ]] && ((10#$port >= 1024 && 10#$port <= 65535)) || { echo 'port must be 1024-65535' >&2; exit 2; }
[[ $latency_ms =~ ^[0-9]+$ ]] && ((10#$latency_ms >= 20 && 10#$latency_ms <= 10000)) || { echo 'latency-ms must be 20-10000' >&2; exit 2; }
[[ -n $output ]] || { echo 'output is required' >&2; exit 2; }
command -v ffmpeg >/dev/null || { echo 'ffmpeg is required' >&2; exit 127; }

# FFmpeg's SRT latency option is in microseconds.
url="srt://${bind}:${port}?mode=listener&latency=$((10#$latency_ms * 1000))"
ffmpeg_args=(-hide_banner -loglevel info -nostdin -i "$url"
  -map 0:v:0 -map '0:a:0?' -c copy -f mpegts -muxdelay 0 -muxpreload 0)

# Existing FIFOs need -y; do not overwrite a regular recording by accident.
if [[ -p $output || $output == /dev/null ]]; then
  ffmpeg_args+=(-y)
elif [[ -e $output ]]; then
  echo "output already exists: $output" >&2
  exit 2
fi

exec ffmpeg "${ffmpeg_args[@]}" "$output"
