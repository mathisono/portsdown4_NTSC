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

## DATV-Express USB: DVB-S is not DVB-S2

The existing Portsdown `DATVEXPRESS` output is explicitly **DVB-S only**. The
GUI labels it "DATV Express DVB-S" and `EnforceValidTXMode()` changes an
attempted DVB-S2 selection back to DVB-S. Its Linux `express_server` runs
the board's DVB-S FPGA firmware, not a DVB-S2 modulator. Building that server
for AArch64 therefore does **not** meet the requested Portsdown DVB-S2 output.

The board itself is not necessarily limited to DVB-S. G4GUO's Windows
`DatvExpressTransmitter` sends software-generated DVB-S2 I/Q through the
board's raw-16-bit firmware. Portsdown already carries this raw I/Q USB path
in `src/dvb_t_stack/src/express.cpp`, plus `datvexpress16.ihx` and
`datvexpressraw16.rbf`. This is a starting point for a **new** Linux DVB-S2
backend, not proof that the present Portsdown mode supports DVB-S2.

On 12 November 2026, F5OEO `libdvbmod` commit
`eff68b37047196e5bc732b08fa7f73c2bf94107e` built natively on TANK in
`/home/leo/portsdown-s2mod-arm64.dSjSCW` (no system install). Its DVB-S2
object and probe were ELF64 AArch64. An offline probe initialized QPSK 1/2,
333 ksymbols/s, normal frame, 35% rolloff, two samples/symbol; after feeding
null transport-stream packets, it returned a 64,980-sample I/Q frame and a
reported net bitrate of 329,289 bit/s. This verifies **native I/Q generation
at one configuration only**. It did not validate a decoded waveform, USB
transfer, PTT, or RF. `lsusb -d 04b4:8613` found no board on TANK.

The reproducible offline probe is `tests/express_s2_modulator_probe.cpp`. With
the external `F5OEO/libdvbmod` checkout built, it can be compiled on either
architecture using:

```sh
g++ -std=c++17 -O2 -I/path/to/libdvbmod/libdvbmod \
  tests/express_s2_modulator_probe.cpp \
  /path/to/libdvbmod/libdvbmod/lib/libdvbmod.a -o /tmp/express-s2-probe
/tmp/express-s2-probe
```

The same committed probe passed on the local development host. The TANK
result above used an equivalent probe in its isolated build directory; this
exact committed source has not yet been rerun on TANK.

The path to a verifiable Portsdown DVB-S2/DATV-Express transmitter is:

1. Add a separate `DATVEXPRESS_S2` output/backend; preserve the working
   DVB-S mode. Consume 188-byte TS packets from the existing `videots` path
   (including a future SRT ingest connection), and generate DVB-S2 I/Q with
   `libdvbmod`. Make code rate, pilots, frame length, symbol rate, and
   rolloff explicit; reject unsupported combinations.
2. Adapt the existing Linux raw-16 USB transport for continuous I/Q. Set the
   board sample clock to symbol rate times interpolation, use its raw-16 FPGA
   image, and keep PTT in receive until configuration and buffering succeed.
   An initial ownership fix now copies each asynchronous payload and frees it
   on completion/error, and closes a per-frame leak in the raw-16 writer.
   This compiled with libusb/FFTW headers but has not been exercised on a
   board. Transfer errors, sustained pacing, and shutdown still need tests.
3. Verify the software waveform against a DVB-S2 decoder offline, then test
   USB enumeration/firmware load and sustained streaming with the board
   connected. Finally test RF into a dummy load/attenuated receiver across
   representative symbol rates and FEC modes, including stop/underrun/PTT.
   Enable the GUI choice only after this path is proven.

No DATV-Express board was present for this build. The 32-bit and 64-bit
Portsdown forks currently **do not provide verified DVB-S2 transmission via
DATV-Express**. Native AArch64 modulation is now demonstrated; the Linux USB
streaming backend and hardware verification remain outstanding.

## Existing DATV-Express USB DVB-S server

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
