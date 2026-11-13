# SRT input for an ATEM-style hardware encoder

`scripts/srt_ts_listener.sh` is a standalone **ingest-only** tool. It accepts
one SRT caller on TANK (default UDP port 9000) and remuxes the first video and
optional audio stream to MPEG-TS without re-encoding. It does not start
`express_server`, key PTT, install firmware, or transmit RF.

On TANK, with an unused output filename:

```sh
scripts/srt_ts_listener.sh --port 9000 --output /tmp/atem-capture.ts
```

Configure the hardware encoder to **call** TANK's LAN address on SRT port
9000. After receiving a short sample, inspect what it actually sends:

```sh
ffprobe -v error -show_entries format=duration,bit_rate \
  -show_entries stream=index,codec_type,codec_name,width,height,r_frame_rate \
  -of json /tmp/atem-capture.ts
```

The output can also be a named FIFO or a `udp://HOST:PORT` URL for a later
Portsdown input bridge. SRT reception alone is **not** DATV-Express RF support:
the ATEM stream's rate may exceed the DVB-S channel capacity. Measure its
codec and bitrate, then choose a rate-matched remux/transcode path before
feeding `express_server` on local UDP port 1314. The current legacy Portsdown
scripts do not yet select SRT input or manage this listener's lifecycle.

## Verification to date

On TANK's arm64 Trixie FFmpeg 7.1.3, the listener bound UDP port 19000 and
accepted a synthetic SRT caller from another LAN host. A four-second sample
produced a 238 KiB MPEG-TS file; `ffprobe` reported H.264 video (320×240),
AAC audio, 3.82 seconds, and 509 kbit/s. The listener exited successfully
after the caller disconnected; the rover service remained active. This proves
network SRT ingest on TANK, **not** compatibility with an actual ATEM stream
or fitness for a chosen DVB-S symbol rate.
