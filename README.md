![portsdown banner](/doc/img/Portsdown_4.jpg)
# Portsdown Buster Build For RPi 4

**The Portsdown 4** is a DVB-S and DVB-S2 digital television system for the Raspberry Pi 4.  The core of the system was written by Evariste Courjaud F5OEO and is maintained by him.  This BATC Version, known as the Portsdown, has been developed by a team of BATC members for use with a LimeSDR, Pluto or a DATV Express PCB and a MiniTiouner or Knucker tuner.  The intention is that the design should be reproducible by someone who has never used Linux before.  Detailed instructions on loading the software are listed below, and further details of the complete system design and build are on the BATC Wiki at https://wiki.batc.org.uk/The_Portsdown_Transmitter.  There is a Forum for discussion of the project here: https://forum.batc.org.uk/viewforum.php?f=103

This version is based on Raspberry Pi OS Buster Lite and is only compatible with the Raspberry Pi 4 and 7 inch screen (or DFRobot 5 inch DSI Screen).  

Our thanks to Evariste, Heather, Charles and all the other contributors to this community project.  All code within the project is GPL.

# Known working Input, output and Encoding settings
| Video Source| Video Format | TX Hardware | Modulation[^1] | Encoder | Txt overlay? | Supported FPS | Quality Scale | Works with W6CX |
| :---------: | :----------: | :---------: | :----------: | :-----: | :------------: | :-----------: | :--------: | :--------: |
| Comp Vid | 4:3 (480p)   | Lime Mini | DVB-S  | MPEG-2   | Yes      | 29.97| Average| Yes, Both inputs |
| Comp Vid | 4:3 (480p)   | Lime Mini | DVB-S2 | MPEG-2   | Yes      | 30   | Average| Yes, Both inputs |
| Comp Vid | 4:3 (480p)   | Lime Mini | DVB-S2 | H264    | No       | 30   | Average| Yes, Both inputs |
| Logitech C920X[^2] | 4:3 (480p)[^3] | Lime Mini | DVB-S  | MPEG-2   | Yes      | 30   | Good| Yes, Both inputs |
| Logitech C920X[^2] | 4:3 (480p)[^3] | Lime Mini | DVB-S2 | MPEG-2   | Yes      | 30   | Good| Yes, Both inputs |
| Logitech C920X[^2] | 4:3 (D1)[^4]   | Lime Mini | DVB-S2 | H264    | No       | 30   |   Good  | Yes, Both inputs |
| Logitech C920X[^2] | 720P  | Lime Mini | DVB-S  | MPEG-2   | Yes       | 10   | Good, Low FPS | NO |
| Elgato Camlink 4K [^5] | 4:3 (480p) | Lime Mini | DVB-S | MPEG-2   | No       | 30   | Good, Aspect ratio compressed | Yes, Both inputs | 
| Elgato Camlink 4K [^5] | 720P| Lime Mini | DVB-S | MPEG-2    | No       | 30   | Good to Great, Limited by synbol rate  | Not recomended, 1273 only |
| Elgato Camlink 4K [^5] | 1080P | Lime Mini | DVB-S | MPEG-2   | No       | 30   | Good to Great, Limited by synbol rate | Not recomended, 1273 only |
| Elgato Camlink 4K [^5] | 4:3 (480p) | Lime Mini | DVB-S2| MPEG-2    | No       | 30   | Good, Aspect ratio compressed |  Yes, 1273 only |
| Elgato Camlink 4K [^5] | 720P | Lime Mini | DVB-S2 | MPEG-2    | No       | 30   | Good, Limited by synbol rate  | Not recomended, 1273 only |
| Elgato Camlink 4K [^5] | 1080P | Lime Mini | DVB-S2 | H264  | No       | 30   | Average, Limited by synbol rate |Not recomended, 1273 only |
| Elgato Camlink 4K [^5] | 4:3 (480p) | Lime Mini | DVB-S2| H264   | No       | 30   | Good, Aspect ratio compressed | Yes, 1273 only |
| Elgato Camlink 4K [^5] | 720P | Lime Mini | DVB-S2 | H264   | No       | 30   | Great | Yes, 1273 only |
| Elgato Camlink 4K [^5] | 1080P | Lime Mini | DVB-S2 | H264  | No       | 30   | Great to Amazing, Depends on synbol rate | Yes, 1273 only |


[^1]: For Modulation, We've only tested DVB-S vs S2, not each subtype of S2 (IE QPSK, 8PSK, 16PSK) or each FEC, as this doesn't really matter - It just increases the available bandwidth (and thus quality at 720p/1080p), and handles link-quality (FEC) The main item here is that S and S2 work with MPEG2 and H264.

[^2]: The device tested was bought from Amazon on 11/20/2026, so it's the latest version. There are limits to it's resolution, and video format. Most cameras run MJPEG and devices convert it, however with how portsdown is done, H264 can't do this, It only supports YUYV or YUV420 - normal broadcast image formats. When the camera runs in YUYV mode, above 800x448 FPS drops off dramatically. At 720p it's 10FPS, and 1080p it's 5fps. Using MJPEG is not available at this time due to the old firmware/software. 

[^3]: The Logitech C920x does not support normal 480p or 480i natively. This is 864x480 MJPEG cut down to 720p.

[^4]: The Logitech C920x does not support normal 480p or 480i natively. This is re-sized 640x480 being handled by the avc2ts encoder, and can not be fixed due to footnote 2 above.

[^5]: The Elgato Camlink 4K was tested with a 1080p input video from a laptop. The device supports 480p,720p,1080p and 2160p inputs (and some others).  It scales video on device, and Portsdown selects one of the first 3 video sizes. While 720p and 1080p work, they do drop some frames, fast motion may be blurry.

Item of warning: Analog in (CompVid) does NOT support 720p, or 1080p. You can play with the 16:9 but it's a non-standard resolution and depending on how your repeater is setup (I.E Breaks back down to analog video vs all digital) it can cause squished video.

## What DOES NOT work, and with this build, and will probably never be supported on this base OS. (and why)


- Analog on any mode besides 4:3 - Because we're no doing any up conversion on the portsdown.
- Logitech C920x H264 720P or 1080P. This is due the H264 encoder needing the YUVU/YUV420 color space, and the camera can't physically do this at 30fps. It can do 720p @ 10fps, and 1080p @ 5fps. The camera does support MJPEG, but due to firmware and software limits, I can't modify the avs2ts encoder that is used to work with this image format. Trixie will fix this, as we're going to use FFMPEG for everything. This is why it's in B&W or doesn't work at all.
- Any of the 16:9 modes. This is a PAL one-off format that we don't use here. 
- Test Cards - This is because it uses the screen resolutions, and the repeater doesn't do well with conversions.


# Installation for BATC Portsdown RPi 4 Version

The preferred installation method only needs a Windows PC connected to the same (internet-connected) network as your Raspberry Pi.  Do not connect a keyboard or HDMI display directly to your Raspberry Pi.

- First download the 2023-05-03 release of Raspberry Pi OS Lite (Legacy) on to your Windows PC from here 
https://downloads.raspberrypi.org/raspios_oldstable_lite_armhf/images/raspios_oldstable_lite_armhf-2023-05-03/2023-05-03-raspios-buster-armhf-lite.img.xz

- Unzip the image (using 7zip as it is a .xz compressed file) and then transfer it to a Micro-SD Card using Win32diskimager https://sourceforge.net/projects/win32diskimager/ OR the offical rasbperry pi imager. (If you use the offical raspberry pi imager, DO NOT customize anything outside of adding SSH keys or timezone. The username MUST stay pi.)

- Before you remove the card from your Windows PC, look at the card with windows explorer; the volume should be labeled "boot".  Create a new empty file called ssh in the top-level (root) directory by right-clicking, selecting New, Text Document, and then change the name to ssh (not ssh.txt).  You should get a window warning about changing the filename extension.  Click OK.  If you do not get this warning, you have created a file called ssh.txt and you need to rename it ssh.  IMPORTANT NOTE: by default, Windows (all versions) hides the .txt extension on the ssh file.  To change this, in Windows Explorer, select File, Options, click the View tab, and then untick "Hide extensions for known file types". Then click OK.

- If you have a Pi Camera and/or touchscreen display, you can connect them now.  Power up the RPi with the new card inserted, and a network connection.  Do not connect a keyboard or HDMI display to the Raspberry Pi. 

- Find the IP address of your Raspberry Pi using an IP Scanner (such as Advanced IP Scanner http://filehippo.com/download_advanced_ip_scanner/ for Windows, or Fing on an iPhone) to get the RPi's IP address.

- From your windows PC use Putty (http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html) to log in to the IP address that you noted earlier.  You will get a Security warning the first time you try; this is normal.

- Log in (user: pi, password: raspberry) then cut and paste the following code in, one line at a time:


```sh
wget https://raw.githubusercontent.com/Marx1/portsdown4_NTSC/master/install_portsdown.sh
chmod +x install_portsdown.sh
./install_portsdown.sh -u Marx1
```

The initial build can take between 45 minutes and one hour, however it does not need any user input, so go and make a cup of coffee and keep an eye on the touchscreen.  When the build is finished the Pi will reboot and start-up with the touchscreen menu.

Once installed. Access the portsdown menu via /home/pi/rpidatv/scripts/menu.sh



