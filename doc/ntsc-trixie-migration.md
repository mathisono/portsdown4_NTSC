# NTSC and Trixie migration status

This is a development status note, **not a Trixie installation guide**. Do not
run `install_portsdown.sh` on Bookworm or Trixie: it rewrites apt sources for
Buster and configures the obsolete camera stack. It now exits before those
changes unless the host is 32-bit Buster.

The Trixie development target is a **Raspberry Pi 4 Model B with 2 GB RAM**
running **Raspberry Pi OS Trixie Lite 32-bit (`armhf`)**, with the **original
Raspberry Pi 7-inch 800×480 Touch Display**, analog and HDMI capture, and
LimeSDR output. Pluto and Portsdown-board output are also desired. The exact
capture-device models are not yet confirmed. The official 32-bit image is
available from the [Raspberry Pi OS Lite `armhf` archive](https://downloads.raspberrypi.com/raspios_lite_armhf/images/raspios_lite_armhf-2026-10-06/).
A headless Pi 4/Trixie **`arm64`** build and encoder test has been completed;
the target `armhf` image, touchscreen, and RF hardware remain untested.

## Repository baseline (10 November 2026)

| Source | Published branch | State |
| --- | --- | --- |
| `Marx1/portsdown4_NTSC` | `master` | Buster installer and legacy Portsdown 4 runtime |
| `Marx1/portsdown4_NTSC` | `Bookworm` | Partial experiment; skips the `avc2ts` build but scripts still call it |
| `Marx1/portsdown4_NTSC` | `Trixie` | BATC-synced development branch |
| `mathisono/portsdown4_NTSC` | `Trixie` | Merged Marx1/BATC history plus NTSC H.264 work; not a working Trixie release |
| `BritishAmateurTelevisionClub/portsdown4` | `master` | Newer Portsdown 4 code, still Buster-oriented |
| `BritishAmateurTelevisionClub/portsdown5` | `main` | Trixie/64-bit reference; different product and incomplete Portsdown 4 feature parity |

The old `avc2ts` source uses OpenMAX/MMAL and `/opt/vc`, parses `-f` with
`atoi`, uses a 25-fps DVB access-unit indicator even when passed 30 fps, and
truncates `1000 / fps` to an integer before timestamp generation. Passing
`29.97` to it is therefore not an NTSC fix. The Pi 4 hardware H.264 encoder is
**not inherently 32-bit-only**: FFmpeg used the `bcm2835-codec-encode` V4L2
device on a 64-bit Trixie Pi 4. This branch still targets 32-bit `armhf`
because other legacy components, including `src/dvbsenco8.s`, use ARM32 code.
That does **not** prove the encoder is available on the target 32-bit Trixie
image. Probe the actual target before claiming hardware acceleration there;
`libx264` remains a software fallback. Do not attempt to recompile OpenMAX as
the Trixie solution.

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
The hardware option is conditional even on 32-bit Trixie: FFmpeg may list
`h264_v4l2m2m` when the Pi kernel exposes no usable encoder. `auto` encodes a
probe frame before selection; explicit `hardware` exits with an error if that
probe fails. FFmpeg's V4L2 wrapper needs numeric H.264 Baseline profile `66`
on TANK's FFmpeg 7.1; the named `baseline` option is rejected before encoding.
Hardware encoding has now been demonstrated on a 64-bit Trixie Pi 4, not yet
on the target 32-bit image.

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
The factory `display=Element14_7` setting matches the original 800x480 screen;
the DSI mode, touch mapping, and GUI still require a live Pi test.

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
NTSC 3003-tick frame cadence on a 90 kHz TS clock, sizes/PIDs, verifies
188-byte TS packet sync, and exercises the FIFO used by RF modulators. It does
not simulate V4L2 capture, ALSA, SDR
transmission, a touchscreen, or the Pi operating system.

## Headless Pi 4/Trixie test (10 November 2026)

On a Pi 4 Model B (4 GB RAM) running Debian Trixie `arm64`, the GUI compiled
with Trixie development libraries and locally built WiringPi. The framebuffer test passed
with UBSan; there was no display to launch the GUI. The ARM32 `rpidatv` core
could not be built by the native AArch64 compiler, but cross-compiled to an
`armhf` ELF with GCC 14 after adding `-fcommon` for legacy header globals. It
was **not run** without transmitter hardware.

The four offline TS tests passed on that Pi, including `auto` selecting the
real `/dev/video11` `bcm2835-codec-encode` device. A separate 6-second FFmpeg
run showed an open file descriptor to `/dev/video11` during encoding. The
script produced decodable Baseline H.264 720×480 NTSC TS with AAC and 720×576
PAL TS. NTSC frame PTS intervals were exactly 3003 ticks at 90 kHz. FFprobe
reports an estimated `avg_frame_rate=29/1` for the hardware TS despite those
correct packet timestamps; the test checks the timestamps instead.

With the rover camera service briefly paused and restored, the attached
IMX708 also supplied live raw frames to an external `rpicam-vid` → FFmpeg
V4L2 encoder → MPEG-TS pipeline. This proves camera-to-file TS feasibility,
**not** integration of the Pi Camera into `scripts/a.sh`, touchscreen control,
or RF transmission.

## Remaining Trixie work and acceptance gates

1. Boot the Pi from a spare Raspberry Pi OS Trixie Lite **32-bit (`armhf`)**
   image. Confirm the original screen presents an 800x480 framebuffer and
   working touch input, then check the capture card and SDR/RF output. Run the
   encoder probe and confirm `h264_v4l2m2m` actually encodes. Do not merge the
   incomplete `Bookworm` branch wholesale.
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

The next meaningful hardware test is a Pi 4 with 32-bit Trixie, a known NTSC V4L2
capture card and the intended RF output. Verify decoded 720x480 30000/1001
video, AAC if selected, configured PIDs, GUI input, hardware H.264 selection,
and a sustained local TS/RF run before calling this a Trixie build.

For a read-only inventory of the Pi's display, input, capture and build tools,
run `bash scripts/trixie_probe.sh` from this branch on the Pi. It does not install
packages or change boot configuration.
