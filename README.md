# PlayStation Broadband Navigator (PSBBN) English Patch

This is the definitive English patch for Sony's PlayStation Broadband Navigator (PSBBN) software for the PlayStation 2 (PS2) video game console.

You can find out more about the PSBBN software [here](https://en.wikipedia.org/wiki/PlayStation_Broadband_Navigator).

## Patch Features:
- A full English translation of the stock Japanese BB Navigator version 0.32.
- All binaries, XML files, textures, and pictures have been translated.*
- DNAS authorization checks bypassed to enable online connectivity.
- Links to working mirrors of the online game channels for Sony, Hudson, EA, Konami, Capcom, Namco, and KOEI. Courtesy of vitas155 at psbbn.ru.
- "Audio Player" feature re-added to the Music Channel from an earlier release of PSBBN, allowing compatibility with NetMD MiniDisc Recorder.
- Associated manual pages and troubleshooting regarding the "Audio Player" feature translated and re-added to the user guide.
- Japanese qwerty on-screen keyboard replaced with US English on-screen keyboard.

Video demonstrating how PSBBN can be used in 2024. **Note**: Additional software and setup is required to achieve everything shown in this video.

[![IMAGE ALT TEXT HERE](https://img.youtube.com/vi/kR1MVcAkW5M/0.jpg)](https://www.youtube.com/watch?v=kR1MVcAkW5M)

PlayStation Broadband Navigator (PSBBN) Definitive English Patch can be downloaded from the Internet Archive [here](https://archive.org/details/playstation-broadband-navigator-psbbn-definitive-english-patch-v1.0)

---

## Version History:

### v1.2 - 4th September 2024
- Fixed a bug on the Photo Channel that could have prevented the Digital Camera feature from being launched.
- Fixed formatting issues for a number of error messages where text was too long to fit on the screen.
- Various small adjustments and corrections to the translation throughout.

### v1.1.1 - 8th March 2024
**NEW**  
- X11 has been set to run in English. The restore, move, resize, minimize, and close buttons now show in English while using the NetFront web browser.  
- Time stamps while saving files now display in English formatting.

### v1.1 - 5th March 2024
**NEW**  
- The NetFront web browser is now in English. The browser can be accessed by going through the "Confirm/Change" network setting dialogs, then selecting "Change router settings."
- Atok user manual has been translated.

**BUG FIXES**  
- **General**: When a game disc was inserted while on the Top Menu, it would cause the console to freeze.  
- **Music Channel**: The number of times a track had been checked-out to a MiniDisc recorder was not displayed correctly.  
- A number of typos have been fixed.

### v1.0 - 21st September 2023
- Initial release.

---

## Installation Instructions:

There are two ways to install this English patch:

1. Connect your PS2's HDD to a PC and write the disk image to it.
2. Install the PSBBN on your PS2 manually, then install the patch.

### PS2 HDD RAW Image Install

#### What You Will Need:
- Any fat model PS2 console.
- An official Sony Network Adapter.
- A compatible HDD or SSD (IDE or SATA with an adapter). The drive must be 120 GB or larger.
- A way to connect the PS2 HDD to a PC.
- 120 GB of free space on your PC to extract the files.
- Disk imaging software.

#### Installation Procedure:
1. Download `PSBBN_English_Patched_v1.x.x_Image.7z` and uncompress it.
2. `PSBBN_English_Patched_v1.x.x_HDD_RAW.img` is a raw PS2 disk image of the Japanese PlayStation BB Navigator Version 0.32 with the PlayStation Broadband Navigator (PSBBN) Definitive English Patch pre-installed.
3. To write this image to your PS2 HDD, you need disk imaging software. For Windows, I recommend using HDD Raw Copy ver. 1.10 portable.  
   You can download it [here](https://hddguru.com/software/HDD-Raw-Copy-Tool/).

---

### Manual Install and Patch

#### What You Will Need:
- Any fat model PS2 console.
- An official Sony Network Adapter.
- A compatible HDD or SSD (IDE or SATA with an adapter).
- A way to boot either the official Sony PSBBN 0.32 installation DVD or Sony Utility Discs Compilation 3.
- A Free McBoot PS2 Memory Card.
- A USB flash drive formatted as FAT32.
- A USB keyboard.

#### Installation Procedure:

If you already have PlayStation BB Navigator Version 0.32 installed on your PS2, you can skip to section 4.

1. **Format Hard Drive with uLaunchELF HddManager**
   - Format your HDD by pressing the circle button for FileBrowser, then select **MISC > HddManager**. Press R1 to open the menu and select **Format**. When done, press triangle to exit.

2. **Install PlayStation BB Navigator Version 0.32**  
   This can be done with the official Sony PSBBN installation DVD or with the Sony Utility Discs Compilation 3.

   **Installing with Sony Utility Discs Compilation 3:**
   - **SCPH-500xx consoles** can use the MechaPwn softmod to boot the installation DVD. All other model consoles will require a mod chip or swap disc.

   **Preparations:**
   - Download the ISO from the Internet Archive [here](https://archive.org/details/sony-utility-disc-compilation-v3).
   - **SCPH-500xx consoles only**: Patch the ISO with the [Master Disc Patcher](https://www.psx-place.com/threads/playstation-2-master-disc-patcher-for-mechapwn.36547/).
   - Burn this ISO to a writable DVD. I recommend using [ImgBurn](https://www.imgburn.com).
   - **SCPH-500xx consoles only**: MechaPwn your PS2 console with the latest release candidate, currently [MechaPwn 3.0 Release Candidate 4 (RC4)](https://github.com/MechaResearch/MechaPwn/releases).
     It is important that you use a version of MechaPwn that does not change the Model Name of your console or it will break compatibility with Kloader that we will be using later in this guide. Currently the latest stable version is not compatible. More details about exactly what MechaPwn does and how to use it can be found [here](https://github.com/MechaResearch/MechaPwn)

   **Installation:**
   - Insert your Free McBoot memory card into any memory card slot on your PS2.
   - Launch uLaunchELF.
   - Format your HDD by pressing the circle button for **FileBrowser**, then select **MISC > HddManager**. Press R1 to open the menu and select **Format**. When done, press triangle to exit.
   - Insert your newly burnt Sony Utility Discs Compilation 3 DVD into the drive.
   - Press the circle button for FileBrowser, then select **MISC > PS2Disc**. The DVD will launch.
   - Select **HDD Utility Discs > PlayStation BB Navigator Version 0.32** from the menu to begin the installation.

Installing PlayStation BB Navigator Version 0.32:
There's an excellent guide here that talks you through the Japanese install https://bungiefan.tripod.com/psbbninstall_01.html
Because we have already formatted the hard drive, during the install you will be presented with a different screen https://bungiefan.tripod.com/psbbninstall_02.html
It is important that you select the 3rd install option. This will install PSBBN without re-formatting the HDD.
When the install is complete you are instructed to remove the DVD, do so but also remove your Free McBoot Memory Card before pressing the circle button.

3. **Go through the PSBBN Initial Setup**  
   You will be asked to enter your network settings next. Make sure your Ethernet cable is connected. Everything is still in Japanese, but it's relatively straightforward:
   - Press the circle button on the first screen.
   - Press the circle button again.
   - On the following screen, enter the IP address, subnet mask, and gateway, then press left on the d-pad to go to the next screen.
   - Enter the IP address for a DNS server (e.g., `8.8.8.8`) and press left again.
   - Press left again to confirm your settings. Press left again and finally press the circle button.  
   You will get a DNAS error. This is to be expected. We'll fix that next. Press X and feel free to explore your fresh install of the Japanese PSBBN.

4. **Disable DNAS Authentication**  
   Turn off the console and put your FreeMcBoot Memory Card back into a memory card slot.  
   Turn the console on and launch uLaunchELF.  
   Go to **FileBrowser**. Navigate to `hdd0:/__contents/bn.conf/` and delete the file `default_isp.dat`. This will disable the DNAS checks.

   **Please Note**:  
   Before continuing to the next section, you **must** put your console into standby by holding the reset button. Failure to do so will cause issues with Kloader.

5. **Install the English Patch**  
   - Unzip `PSBBN_English_Patch_Installer_v1.x.x.zip` on your PC.
   - Copy the files `kloader3.0.elf`, `config.txt`, `xrvmlinux`, `xrinitfs_install.gz`, and `PSBBN_English.tar.gz` to the root of a FAT32 formatted USB flash drive.
   - Connect the USB flash drive and a USB keyboard to the USB ports on the front of your PS2 console.
   - Turn on the PS2 and launch uLaunchELF.
   - Launch `kloader3.0.elf` from the USB flash drive.
   - Eventually, you will be presented with a login prompt:  
     Type `root` and press enter.  
     Type `install` and press enter.
   - When you see the text `INIT: no more processes left in this runlevel`, hold the standby button down until the console powers off.
   - Remove your Free McBoot Memory Card. Power the console on and enjoy PSBBN in full English!

---

## Notes:
- If you have previously installed PSBBN via the raw image or the via the patch and would like to install the latest patch update without losing data, just follow step 5 above, "Installing the English patch."
- I would highly recommend using a "Kaico IDE to SATA Upgrade Kit" and a SATA SSD such as the Kingston A400. The improved random access speed over a HDD really makes a big difference to the responsiveness of the PSBBN interface.
- Use OPL-Launcher to install PS2 games and launch them from the Game Channel. More details can be found [here](https://github.com/ps2homebrew/OPL-Launcher).

---

## Known Issues/Limitations of PSBBN:
- Lacks support for large HDDs so drives larger than 130 GB cannot be taken full advantage of. PSBBN can only see the first 130,999 MB of data on your HDD/SSD (as reported by uLaunchELF). If there is 131,000 MB or more on your HDD/SSD, PSBBN will fail to launch. Delete data so there is less than 131,000 MB used, and PSBBN will launch again. In that space, I've managed to install 40 PS2 games in the ZSO format, 9 PS1 games, all bootable from the Game Channel, plus 3 homebrew apps, and Linux.
- Only supports dates up to the end of 2030.
- Bug with Game Manuals randomly crashing when loading pages. Manuals only work reliably on the first 5 games installed.
- "What's New" section under the PlayStation BB Guide is greyed out. I would have liked to update that with the patch release notes but couldn't get it working.
- Default on-screen keyboard is Japanese. US English on-screen keyboard has been added, but you have to press SELECT a number of times to access it.
- I've noticed a bug where the spacebar key does not function on the US English on-screen keyboard. A space can be entered by pressing the triangle button on the controller instead. I could revert back to the Japanese qwerty keyboard in the future, but I think the benefits of the US keyboard outweigh this negative.

---

\* Instances in feega where some Japanese text could not be translated because it is hard coded, most likely in an encrypted file.  
Atok software has not been translated.  
You might have to manually change the title of your "Favorite" folders if they were created before running this patch.
