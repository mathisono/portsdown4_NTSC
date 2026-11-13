![portsdown banner](/doc/img/Portsdown_4.jpg)
# Portsdown Buster Build For RPi 4

## Trixie development status (12 November 2026)

The `arm64-transmitter` branch contains work toward **two distinct targets**.
Neither is an installable, RF-verified Trixie release. The installer and
instructions below this section are for the legacy **32-bit Buster** release;
do **not** run `install_portsdown.sh` or `update.sh` on Trixie.

| Target | Implemented and checked | Not yet verified |
| --- | --- | --- |
| Pi 4, Raspberry Pi OS Trixie Lite **32-bit (`armhf`)**, original 7-inch 800×480 display | NTSC/PAL FFmpeg MPEG-TS path for analog/webcam input, encoder selection, GUI framebuffer/touchscreen fixes, and an installer guard. Offline TS tests passed; hardware H.264 encoding was demonstrated on a separate **64-bit** Pi 4. | Boot/build on the actual 32-bit target, original display and touch, capture devices, GUI runtime, installer/update, and RF output. |
| Pi 4, Trixie **64-bit (`arm64`)**, DATV-Express USB board | Native AArch64 `rpidatv`, DVB-T2 stack, and DVB-S `express_server` builds. Experimental standalone DVB-S2 TS-to-I/Q-to-raw-USB backend built and generated I/Q offline on TANK. SRT listener accepted a synthetic H.264/AAC stream. | DATV-Express board USB enumeration, firmware, sustained I/Q, PTT, decoded DVB-S2/RF, GUI integration, and actual ATEM input. The board was not connected; no RF was transmitted. |

**DVB-S2 distinction:** the existing Portsdown `DATVEXPRESS` GUI mode and
`express_server` are **DVB-S only**. The new
[`src/express_s2` backend](src/express_s2/express_s2.cpp) generates DVB-S2 I/Q
and uses the raw-16 USB path, but has not been tested with a board and is not
selectable in the GUI. Neither 32-bit nor 64-bit Portsdown currently has
verified DVB-S2 transmission through DATV-Express.

### Remaining work

1. **32-bit Trixie:** test a spare Pi 4 image with the original display,
   capture device, and intended RF hardware; finish the modern installer,
   GUI/input path, remaining video sources, and install/update regression.
2. **64-bit transmitter:** validate the Pi 4 DMA and RF path, port remaining
   ARM32-only components, and test the intended output devices. A native
   build and offline modulation do not establish a working transmitter.
3. **DATV-Express DVB-S2:** connect the board to TANK with an appropriate
   dummy load or attenuated receiver; verify raw-16 firmware, USB pacing,
   errors, PTT/stop behavior, and a decoded RF signal. Then connect the
   backend to Portsdown's `videots` input, expose a separate DVB-S2 GUI mode,
   and add the required symbol-rate/FEC controls without changing DVB-S.
4. **SRT/ATEM:** capture the actual feed, measure bitrate and codecs, match it
   to DVB-S2 channel capacity, and integrate listener lifecycle and TS input.

Detailed status, build evidence, and acceptance gates:
[32-bit NTSC/Trixie migration](doc/ntsc-trixie-migration.md),
[64-bit transmitter and DATV-Express DVB-S2](doc/arm64-transmitter.md), and
[SRT ingest](doc/srt-express-ingest.md).

**The Portsdown 4** is a DVB-S and DVB-S2 digital television system for the Raspberry Pi 4.  The core of the system was written by Evariste Courjaud F5OEO and is maintained by him.  This BATC Version, known as the Portsdown, has been developed by a team of BATC members for use with a LimeSDR, Pluto or a DATV Express PCB and a MiniTiouner or Knucker tuner.  The intention is that the design should be reproducible by someone who has never used Linux before.  Detailed instructions on loading the software are listed below, and further details of the complete system design and build are on the BATC Wiki at https://wiki.batc.org.uk/The_Portsdown_Transmitter.  There is a Forum for discussion of the project here: https://forum.batc.org.uk/viewforum.php?f=103

This version is based on Raspberry Pi OS Buster Lite and is only compatible with the Raspberry Pi 4 and 7 inch screen (or DFRobot 5 inch DSI Screen).  

Our thanks to Evariste, Heather, Charles and all the other contributors to this community project.  All code within the project is GPL.

# Installation for BATC Portsdown RPi 4 Version

The preferred installation method only needs a Windows PC connected to the same (internet-connected) network as your Raspberry Pi.  Do not connect a keyboard or HDMI display directly to your Raspberry Pi.

- First download the 2023-05-03 release of Raspberry Pi OS Lite (Legacy) on to your Windows PC from here 
https://downloads.raspberrypi.org/raspios_oldstable_lite_armhf/images/raspios_oldstable_lite_armhf-2023-05-03/2023-05-03-raspios-buster-armhf-lite.img.xz

- Unzip the image (using 7zip as it is a .xz compressed file) and then transfer it to a Micro-SD Card using Win32diskimager https://sourceforge.net/projects/win32diskimager/

- Before you remove the card from your Windows PC, look at the card with windows explorer; the volume should be labeled "boot".  Create a new empty file called ssh in the top-level (root) directory by right-clicking, selecting New, Text Document, and then change the name to ssh (not ssh.txt).  You should get a window warning about changing the filename extension.  Click OK.  If you do not get this warning, you have created a file called ssh.txt and you need to rename it ssh.  IMPORTANT NOTE: by default, Windows (all versions) hides the .txt extension on the ssh file.  To change this, in Windows Explorer, select File, Options, click the View tab, and then untick "Hide extensions for known file types". Then click OK.

- If you have a Pi Camera and/or touchscreen display, you can connect them now.  Power up the RPi with the new card inserted, and a network connection.  Do not connect a keyboard or HDMI display to the Raspberry Pi. 

- Find the IP address of your Raspberry Pi using an IP Scanner (such as Advanced IP Scanner http://filehippo.com/download_advanced_ip_scanner/ for Windows, or Fing on an iPhone) to get the RPi's IP address 

- From your windows PC use Putty (http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html) to log in to the IP address that you noted earlier.  You will get a Security warning the first time you try; this is normal.

- Log in (user: pi, password: raspberry) then cut and paste the following code in, one line at a time:


```sh
wget https://raw.githubusercontent.com/Marx1/portsdown4_NTSC/master/install_portsdown.sh
chmod +x install_portsdown.sh
./install_portsdown.sh -u Marx1
```

The initial build can take between 45 minutes and one hour, however it does not need any user input, so go and make a cup of coffee and keep an eye on the touchscreen.  When the build is finished the Pi will reboot and start-up with the touchscreen menu.

Once installed. Access the portsdown menu via /home/pi/rpidatv/scripts/menu.sh
