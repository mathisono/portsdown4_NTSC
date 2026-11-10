#!/usr/bin/env bash
# H.264/MPEG-TS encoder for systems without the legacy OpenMAX avc2ts encoder.
# This script does not configure the capture device or the RF modulator.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: h264_ts_ffmpeg.sh --source /dev/videoN|testsrc --output PATH|udp://HOST:PORT
       --video-bitrate BPS --muxrate BPS [options]

Options:
  --standard ntsc|pal      NTSC is 30000/1001 fps; PAL is 25 fps (default: ntsc)
  --size WIDTHxHEIGHT      Output size (default: 720x480 for NTSC, 720x576 for PAL)
  --audio-device ALSA      Optional ALSA capture device, e.g. plughw:1,0
                           Use testtone with testsrc for an offline audio test
  --audio-bitrate BPS      AAC bitrate (default: 48000)
  --audio-channels 1|2     Capture channels (default: 2)
  --audio-rate HZ          Capture sample rate (default: 48000)
  --pmt-pid PID            PMT PID (default: 255); video/audio use PID+1/+2
  --service-id ID          MPEG-TS service ID (default: 1)
  --service-name NAME      DVB service name (default: Portsdown)
  --gop FRAMES             Maximum GOP length (default: 60)
  --video-encoder MODE      software (libx264, default), hardware (Pi V4L2 M2M),
                           or auto (probe hardware, otherwise use libx264)
  --deinterlace            Deinterlace analog capture before encoding
  --duration SECONDS       Stop after this duration (useful for offline tests)
EOF
}

fail() { printf 'h264_ts_ffmpeg: %s\n' "$*" >&2; exit 2; }
need_value() { (($# >= 2)) || fail "missing value for $1"; }
is_uint() { [[ "$1" =~ ^[0-9]+$ ]]; }

source_device=
output=
standard=ntsc
size=
video_bitrate=
muxrate=
audio_device=
audio_bitrate=48000
audio_channels=2
audio_rate=48000
pmt_pid=255
service_id=1
service_name=Portsdown
gop=60
video_encoder=software
duration=
deinterlace=false

while (($#)); do
  case "$1" in
    --source|--output|--standard|--size|--video-bitrate|--muxrate|--audio-device|--audio-bitrate|--audio-channels|--audio-rate|--pmt-pid|--service-id|--service-name|--gop|--video-encoder|--duration)
      need_value "$@"
      case "$1" in
        --source) source_device=$2;;
        --output) output=$2;;
        --standard) standard=$2;;
        --size) size=$2;;
        --video-bitrate) video_bitrate=$2;;
        --muxrate) muxrate=$2;;
        --audio-device) audio_device=$2;;
        --audio-bitrate) audio_bitrate=$2;;
        --audio-channels) audio_channels=$2;;
        --audio-rate) audio_rate=$2;;
        --pmt-pid) pmt_pid=$2;;
        --service-id) service_id=$2;;
        --service-name) service_name=$2;;
        --gop) gop=$2;;
        --video-encoder) video_encoder=$2;;
        --duration) duration=$2;;
      esac
      shift 2;;
    --deinterlace) deinterlace=true; shift;;
    --help|-h) usage; exit 0;;
    *) fail "unknown option: $1";;
  esac
done

[[ -n "$source_device" && -n "$output" ]] || fail 'source and output are required'
case "$standard" in
  ntsc) frame_rate=30000/1001; size=${size:-720x480};;
  pal) frame_rate=25; size=${size:-720x576};;
  *) fail "unsupported standard: $standard";;
esac
[[ "$size" =~ ^[0-9]+x[0-9]+$ ]] || fail 'size must be WIDTHxHEIGHT'
for number in "$video_bitrate" "$muxrate" "$audio_bitrate" "$audio_channels" "$audio_rate" "$pmt_pid" "$service_id" "$gop"; do
  is_uint "$number" || fail 'bitrate, PID, channel, rate, service ID and GOP values must be integers'
done
((video_bitrate > 0 && muxrate > video_bitrate + 16000 && gop > 0)) || fail 'invalid video bitrate, muxrate or GOP'
((pmt_pid >= 32 && pmt_pid <= 8189 && service_id >= 1 && service_id <= 65535)) || fail 'PMT PID or service ID out of range'
((audio_channels == 1 || audio_channels == 2)) || fail 'audio channels must be 1 or 2'
if [[ -n "$duration" ]]; then
  [[ "$duration" =~ ^[0-9]+([.][0-9]+)?$ ]] || fail 'duration must be a positive number'
fi
if [[ -n "$audio_device" ]]; then
  ((muxrate > video_bitrate + audio_bitrate + 16000)) || fail 'muxrate has insufficient room for video and AAC audio'
fi

command -v ffmpeg >/dev/null || fail 'ffmpeg is required'

# FFmpeg listing h264_v4l2m2m only proves the wrapper was compiled; it does not
# prove the Pi exposes an H.264 encoder. Encode one real frame before selecting it.
hardware_available() {
  command -v timeout >/dev/null 2>&1 || return 1
  timeout 10s ffmpeg -hide_banner -loglevel error -nostdin \
    -f lavfi -i "color=size=$size:rate=$frame_rate" -frames:v 1 \
    -vf format=yuv420p -c:v h264_v4l2m2m -profile:v baseline -bf 0 \
    -g "$gop" -b:v "$video_bitrate" -maxrate:v "$video_bitrate" \
    -bufsize:v "$video_bitrate" \
    -f h264 -y /dev/null >/dev/null 2>&1
}
case "$video_encoder" in
  software) ffmpeg_video_encoder=libx264;;
  hardware)
    hardware_available || fail 'Pi V4L2 M2M H.264 encoder is unavailable or cannot encode at this size/rate'
    ffmpeg_video_encoder=h264_v4l2m2m;;
  auto)
    if hardware_available; then
      ffmpeg_video_encoder=h264_v4l2m2m
    else
      ffmpeg_video_encoder=libx264
      printf 'h264_ts_ffmpeg: hardware H.264 unavailable; using libx264\n' >&2
    fi;;
  *) fail "unknown video encoder mode: $video_encoder";;
esac
printf 'h264_ts_ffmpeg: using %s\n' "$ffmpeg_video_encoder" >&2

ffmpeg_args=(-hide_banner -loglevel warning -nostdin)
if [[ "$source_device" == testsrc ]]; then
  ffmpeg_args+=(-f lavfi -i "testsrc2=size=$size:rate=$frame_rate")
else
  ffmpeg_args+=(-thread_queue_size 2048 -f v4l2 -i "$source_device")
fi
if [[ -n "$audio_device" ]]; then
  if [[ "$audio_device" == testtone ]]; then
    ffmpeg_args+=(-f lavfi -i "sine=frequency=1000:sample_rate=$audio_rate")
  else
    ffmpeg_args+=(-thread_queue_size 2048 -f alsa -ac "$audio_channels" -ar "$audio_rate" -i "$audio_device")
  fi
fi

filter=
if $deinterlace; then filter=yadif=mode=send_frame,; fi
filter+="fps=$frame_rate,scale=${size/x/:}:flags=fast_bilinear,format=yuv420p"
ffmpeg_args+=(-map 0:v:0 -vf "$filter" -r "$frame_rate" -c:v "$ffmpeg_video_encoder")
if [[ "$ffmpeg_video_encoder" == libx264 ]]; then
  ffmpeg_args+=(-preset ultrafast -tune zerolatency)
fi
ffmpeg_args+=(-profile:v baseline -bf 0 -g "$gop" -b:v "$video_bitrate"
  -maxrate:v "$video_bitrate" -bufsize:v "$video_bitrate")
if [[ -n "$audio_device" ]]; then
  ffmpeg_args+=(-map 1:a:0 -c:a aac -b:a "$audio_bitrate" -ac "$audio_channels" -ar 48000)
else
  ffmpeg_args+=(-an)
fi
ffmpeg_args+=(-metadata "service_provider=Portsdown" -metadata "service_name=$service_name"
  -mpegts_original_network_id 1 -mpegts_transport_stream_id 1
  -mpegts_service_id "$service_id" -mpegts_pmt_start_pid "$pmt_pid"
  -streamid "0:$((pmt_pid + 1))" -muxrate "$muxrate" -f mpegts)
if [[ -n "$audio_device" ]]; then
  ffmpeg_args+=(-streamid "1:$((pmt_pid + 2))")
fi
if [[ -n "$duration" ]]; then ffmpeg_args+=(-t "$duration"); fi
ffmpeg_args+=(-y "$output")
exec ffmpeg "${ffmpeg_args[@]}"
