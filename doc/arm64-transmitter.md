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
It also checks Pi 4 revision decoding. A 64-bit x86_64 build proves the C
path compiles and links; it is **not** a native AArch64 binary or an RF test.

## Remaining before arm64 support can be claimed

1. Build `rpidatv` with a native AArch64 compiler on a spare Pi 4/Trixie
   installation, then compare captured encoded packets with the ARM32 path.
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
