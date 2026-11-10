# NTSC and Trixie migration status

This is a development status note, **not a Trixie installation guide**. Do not
run `install_portsdown.sh` on Bookworm or Trixie: it rewrites apt sources for
Buster and configures the obsolete camera stack. It now exits before those
changes unless the host is 32-bit Buster.

The Trixie development target is a **Raspberry Pi 4 Model B with 2 GB RAM**,
the official Pi touchscreen, analog and HDMI capture, and LimeSDR output.
Pluto and Portsdown-board output are also desired. The Trixie image architecture,
touchscreen revision, and exact capture-device models are not yet confirmed.
No Pi 4/Trixie build or hardware test has been completed.

## Repository baseline (9 November 2026)

| Source | Published branch | State |
| --- | --- | --- |
| `Marx1/portsdown4_NTSC` | `master` | Buster installer and legacy Portsdown 4 runtime |
| `Marx1/portsdown4_NTSC` | `Bookworm` | Partial experiment; skips the `avc2ts` build but scripts still call it |
| `Marx1/portsdown4_NTSC` | Trixie | No published branch found |
| `mathisono/portsdown4_NTSC` | `Trixie` | Development branch based on the NTSC H.264 foundation; not a working Trixie release |
| `BritishAmateurTelevisionClub/portsdown4` | `master` | Newer Portsdown 4 code, still Buster-oriented |
| `BritishAmateurTelevisionClub/portsdown5` | `main` | Trixie/64-bit reference; different product and incomplete Portsdown 4 feature parity |

The old `avc2ts` source uses OpenMAX/MMAL and `/opt/vc`, parses `-f` with
`atoi`, uses a 25-fps DVB access-unit indicator even when passed 30 fps, and
truncates `1000 / fps` to an integer before timestamp generation. Passing
`29.97` to it is therefore not an NTSC fix. Portsdown 5's own README notes
that the Pi 4's old H.264 hardware encoder is not accessible from its 64-bit
Trixie environment. The modern migration path should use FFmpeg/libx264 or
another supported encoder, not attempt to recompile OpenMAX.

## Implemented first slice

`scripts/h264_ts_ffmpeg.sh` encodes 720x480 at **30000/1001 fps** for NTSC,
or 720x576 at **25 fps** for PAL, into constant-mux-rate MPEG-TS with explicit
PMT/video/audio PIDs and optional AAC audio. It accepts a V4L2 capture device,
or `testsrc`/`testtone` for offline verification. It writes either a TS file,
the existing `videots` FIFO, or a UDP TS URL.

Analog and webcam H.264 modes in `scripts/a.sh` can opt in with
`h264backend=ffmpeg` in `scripts/portsdown_config.txt`, or the
`PORTSDOWN_H264_BACKEND=ffmpeg` environment variable. The factory setting
on the `Trixie` branch is `ffmpeg`, while existing installations without the
key stay on legacy. `h264encoder=software|hardware|auto` selects FFmpeg's
`libx264`, the Pi V4L2 M2M H.264 encoder, or a hardware probe with software
fallback. The `PORTSDOWN_H264_ENCODER` environment variable can override it.
The Trixie factory selects `auto` and `outputstandard=480` for NTSC; use
`outputstandard=576` for PAL. Set the
analog capture card to its matching input standard separately, using the
existing `analogcamstandard` setting and the standards actually reported by
`v4l2-ctl --list-standards` for that card. The Pluto RTMP, Pi Camera, desktop,
test-card, HDMI, and other H.264 paths **have not** been ported to this backend.
The hardware option is conditional: FFmpeg may list `h264_v4l2m2m` even when
the Pi kernel exposes no usable encoder. `auto` encodes a probe frame before
selection; explicit `hardware` exits with an error if that probe fails. No
hardware encoding on Pi 4/Trixie has been demonstrated yet.

The GUI no longer links the unused `bcm_host` library and now reports
framebuffer open/mapping/pixel-layout failures instead of continuing with an
invalid pointer. This removes one known build dependency and one crash path;
it does **not** establish that the whole GUI works on Trixie.

On the `Trixie` branch, the 800x480 GUI framebuffer path also supports 16-bit
RGB565 and 32-bit RGB with padded rows, rather than only tightly packed 32-bit
pixels. Touchscreen discovery checks later evdev nodes so connected capture
devices do not displace the touchscreen outside the first seven entries. The
legacy display-configuration script refuses to alter modern `/boot/firmware`
setups, and a missing touchscreen no longer triggers a Trixie reboot loop.
The official touchscreen and GUI still require a live Pi test.

The updater no longer deletes `avc2ts.cpp` before downloading from a
nonexistent `Marx1/avc2ts:portsdown4_NTSC` branch. It downloads the BATC
`portsdown4` version used by the original installer and retains the previous
source/installed binary if download or build fails. This preserves the legacy
path, but it does not cure its PAL-only timing metadata.

## Offline verification

On a host with FFmpeg/libx264, `ffprobe`, and Python 3:

```sh
python3 tests/test_h264_ts_ffmpeg.py
bash -n scripts/a.sh scripts/h264_ts_ffmpeg.sh install_portsdown.sh update.sh
gcc -Wall -Wno-unused-function -fsyntax-only -x c src/gui/Graphics.h
gcc -O1 -g -fsanitize=address,undefined tests/test_gui_framebuffer.c -o /tmp/test_gui_framebuffer_portsdown
/tmp/test_gui_framebuffer_portsdown
```

The TS test decodes and probes NTSC+AAC and PAL examples, checks the exact
frame rates/sizes/PIDs, verifies 188-byte TS packet sync, and exercises the
FIFO used by RF modulators. It does not simulate V4L2 capture, ALSA, SDR
transmission, a touchscreen, or the Pi operating system.

## Remaining Trixie work and acceptance gates

1. Confirm the Pi's Trixie OS image architecture, display, capture card, and
   SDR/RF output. Do not merge the incomplete `Bookworm` branch wholesale.
2. Build a new, non-destructive Trixie installer using available packages and
   a fresh image; replace obsolete `omxplayer`, `/opt/vc`, camera, boot-config,
   and Debian package assumptions. Confirm every source download and build.
3. Port the remaining GUI dependencies and display/input path (WiringPi,
   LimeSuite, DRM framebuffer/touchscreen); compile and launch it on the target
   Pi. A successful source-level syntax check is not a GUI runtime test.
4. Port remaining H.264 sources/output modes. Measure libx264 CPU and memory
   use on the 2 GB Pi, continuity/PCR, audio synchronization, and stable RF
   transmission at the intended symbol rates. Keep PAL functional as an
   explicit regression gate.
5. Test fresh install, update preserving user configuration, shutdown/reboot,
   and rollback on a spare SD card before use on an operational transmitter.

The next meaningful hardware test is a Pi 4 with Trixie, a known NTSC V4L2
capture card and the intended RF output. Verify decoded 720x480 30000/1001
video, AAC if selected, configured PIDs, GUI input, and a sustained local TS/RF
run before calling this a Trixie build.

For a read-only inventory of the Pi's display, input, capture and build tools,
run `bash scripts/trixie_probe.sh` from this branch on the Pi. It does not install
packages or change boot configuration.
