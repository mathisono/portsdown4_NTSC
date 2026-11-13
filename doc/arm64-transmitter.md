# Native 64-bit transmitter port: development status

This worktree is an **offline porting slice**, not an installable or RF-tested
arm64 Portsdown release. Keep the Buster installer guard in place; do not run
`install_portsdown.sh` or `update.sh` on Trixie.

## Implemented in the `rpidatv` core

- A portable C implementation replaces ARM32 `dvbsenco8.s` on 64-bit targets.
  Its energy and Reed–Solomon constants are generated directly from the
  existing assembly at build time; the ARM32 build still selects the assembly.
- DMA bookkeeping now keeps userspace virtual addresses in `uintptr_t` rather
  than truncating them to 32 bits. DMA bus/control-block addresses remain
  `uint32_t`, as defined by the BCM2711 DMA register interface.
- The Pi 4 BCM2711 revision maps to peripheral base `0xFE000000`. Revision
  detection falls back to the device-tree property when arm64 `/proc/cpuinfo`
  lacks a `Revision` line. Unknown boards are rejected before GPIO/DMA mapping.
- Legacy `open(path, 'r')` calls were corrected to `O_RDONLY`; the former is a
  flag value, not a file mode. `rpidatv -h` no longer runs the hardware cleanup
  routine before hardware has been initialized.
- The separate DVB-T2 stack's `PI4=1` build now omits ARM32-only `-mfpu` and
  `-mfloat-abi` flags when its compiler targets AArch64. Its RF path is not
  validated by this change.

## Offline verification

From the repository root:

```sh
python3 tests/test_portable_dvbsenco.py
make -C src
src/rpidatv -h
```

The encoder test compares 96 packets across interleaver wraparound and reset
against an independent Python translation of the ARM32 table/offset logic.
It also checks Pi 4 revision decoding.

On 10 November 2026, the committed core was copied into an isolated directory
on TANK (Pi 4 Model B Rev 1.5, Debian Trixie `aarch64`). Native `make -C src`
produced an AArch64 `rpidatv` binary. Its help path and all three tests passed,
including live BCM2711 revision detection. The source archive SHA-256 was
checked before extraction. `make -C src/dvb_t2_stack -j2 PI4=1 NO_PLUTO=1`
also produced native AArch64 `t2mod` and Lime-linked `dvb_t2_stack` binaries.
Pluto was disabled because `libiio` development files were not installed.
Neither transmitter binary was run, no RF output was activated, and the
existing `rover-web.service` remained active.

## DATV-Express USB DVB-S server

On TANK (Debian Trixie `arm64`), upstream `G4GUO/express_server` commit
`d51081f21c7306334e7f00b85c257b88d28cb58b` built natively after installing
`libusb-1.0-0-dev` version `2:1.0.28-1`. The isolated build and its log/record
are at `/home/leo/express-server-arm64.POXOxA`; the executable is an ELF64
AArch64 binary, dynamically linked to `libusb-1.0.so.0`, with SHA-256
`debdb7c1ea7aa0d4ea0e132c76189876ad9f6db47811818d73ea2a1ebdd7ccd7`.
No `make install` was run. The server was **not started** and no board, USB
firmware, PTT, or RF path was tested. This establishes a native build, not
working DATV-Express transmission.

For board verification, stage the *DVB-S* firmware from the server repository
(`datvexpress8.ihx` and `datvexpressdvbs.rbf`) under
`/lib/firmware/datvexpress`, confirm USB ID `04b4:8613`, and start the binary
from its source/config directory with output into a load/attenuated receiver.
The separate DVB-T stack uses different `*16` firmware. Inspect the board's
actual RF/PTT state before any transmission; the server initializes hardware
before reading `datvexpress.txt`, which requests `set ptt rx`.

The standalone SRT ingest tool and its separate verification are described in
[`srt-express-ingest.md`](srt-express-ingest.md). It does not yet feed or start
the server.

## Remaining before arm64 support can be claimed

1. Compare captured encoded packets with the ARM32 path on real hardware;
   the Python assembly translation is not a direct ARM32 execution oracle.
2. Audit and validate DMA channel selection, BCM2711 register offsets,
   mailbox allocation, DMA transfer pacing, GPIO/PWM/PCM setup and cleanup on
   a Pi 4 before connecting RF output. The legacy `DMA_CHANNEL * 0x40`
   expression is in `uint32_t` register units and must be resolved against the
   actual DMA channel/offset, not changed on speculation.
3. Port the separate Muntjac DVB-S2 path. `src/muntjac/dvbs2neon.S` is ARM32
   NEON assembly, and `muntjacsdr_dvb.c` passes pointers through `uint32`.
   The installer/updater also pass the ARM32-only `-mfpu=neon` flag.
4. Audit other built components and scripts: numerous utility Makefiles still link `/opt/vc`
   or `bcm_host`. A new Trixie installer and modern camera/display integration
   remain separate gates described in `ntsc-trixie-migration.md`.
5. Validate DVB-S and DVB-S2 modulation, all intended output devices, symbol
   rates, RF continuity and shutdown on hardware. No live transmitter was
   activated by this porting slice.
