#!/usr/bin/env bash
# Read-only Pi/Trixie inventory for the NTSC migration. No sudo is needed.
set -u

section() { printf '\n== %s ==\n' "$1"; }
value() { if [ -r "$1" ]; then tr -d '\000\n' < "$1"; else printf 'unavailable'; fi; }

section 'System'
os_codename=unknown
if [ -r /etc/os-release ]; then
  . /etc/os-release
  printf 'OS: %s\n' "${PRETTY_NAME:-unknown}"
  os_codename=${VERSION_CODENAME:-unknown}
fi
userspace_arch=$(dpkg --print-architecture 2>/dev/null || uname -m)
printf 'Userspace architecture: %s\n' "$userspace_arch"
if [ "$os_codename" = trixie ] && [ "$userspace_arch" = armhf ]; then
  printf 'Trixie 32-bit armhf target: matched\n'
else
  printf 'Trixie 32-bit armhf target: NOT matched (inventory continues)\n'
fi
printf 'Kernel: %s\n' "$(uname -r)"
printf 'Board: '; value /proc/device-tree/model; printf '\n'
awk '/^MemTotal:/ { printf "RAM: %.0f MiB\n", $2 / 1024 }' /proc/meminfo

section 'Framebuffer and DRM display'
for fb in /sys/class/graphics/fb[0-9]*; do
  [ -d "$fb" ] || continue
  printf '%s: name=' "${fb##*/}"
  value "$fb/name"
  printf ' size='
  value "$fb/virtual_size"
  printf ' bpp='
  value "$fb/bits_per_pixel"
  printf '\n'
done
for connector in /sys/class/drm/card[0-9]*-*; do
  [ -r "$connector/status" ] || continue
  [ "$(cat "$connector/status")" = connected ] || continue
  printf '%s: connected; modes=' "${connector##*/}"
  if [ -r "$connector/modes" ]; then
    paste -sd, "$connector/modes"
  else
    printf 'unavailable\n'
  fi
done
if command -v fbset >/dev/null 2>&1; then
  fbset -i 2>&1 | sed -n '1,18p'
fi

section 'Input devices (names and handlers only)'
if [ -r /proc/bus/input/devices ]; then
  awk '/^N: Name=|^H: Handlers=/' /proc/bus/input/devices
fi

section 'Capture and USB devices'
if command -v v4l2-ctl >/dev/null 2>&1; then
  v4l2-ctl --list-devices 2>&1
else
  printf 'v4l2-ctl unavailable\n'
fi
if command -v lsusb >/dev/null 2>&1; then
  lsusb
else
  printf 'lsusb unavailable\n'
fi

section 'Build/runtime tools'
for command_name in gcc make pkg-config ffmpeg ffprobe v4l2-ctl LimeUtil; do
  if command -v "$command_name" >/dev/null 2>&1; then
    printf '%s: %s\n' "$command_name" "$(command -v "$command_name")"
  else
    printf '%s: missing\n' "$command_name"
  fi
done
if command -v ffmpeg >/dev/null 2>&1; then
  ffmpeg -hide_banner -encoders 2>/dev/null | awk '$2 == "libx264" { print "libx264 encoder: available"; found=1 } END { if (!found) print "libx264 encoder: missing" }'
  if command -v timeout >/dev/null 2>&1 &&
     timeout 10s ffmpeg -hide_banner -loglevel error -nostdin \
       -f lavfi -i 'color=size=720x480:rate=30000/1001' -frames:v 1 \
       -vf format=yuv420p -c:v h264_v4l2m2m -profile:v baseline -bf 0 \
       -b:v 800000 -maxrate:v 800000 -bufsize:v 800000 \
       -f h264 -y /dev/null >/dev/null 2>&1; then
    printf 'Pi V4L2 M2M H.264 encoder: usable now\n'
  else
    printf 'Pi V4L2 M2M H.264 encoder: not usable now\n'
  fi
fi
for package_name in libfftw3-dev libjpeg-dev liblimesuite-dev libfcgi-dev wiringpi; do
  status=$(dpkg-query -W -f='${Status}' "$package_name" 2>/dev/null || true)
  if [ "$status" = 'install ok installed' ]; then
    printf '%s: installed\n' "$package_name"
  else
    printf '%s: missing\n' "$package_name"
  fi
done
