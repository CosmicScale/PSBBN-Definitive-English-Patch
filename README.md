# PSBBN Definitive English Patch

This is the definitive English patch for Sony's "PlayStation Broadband Navigator" software (also known as BB Navigator or PSBBN) for the "PlayStation 2" (PS2) video game console.

You can find out more about the PSBBN software on [Wikipedia](https://en.wikipedia.org/wiki/PlayStation_Broadband_Navigator).

If you appreciate my work and want to support the continued development of the **PSBBN Definitive English Patch 2.0** and other **PS2-related projects**, you can now do so via **[Ko-fi](https://ko-fi.com/cosmicscale)**

## Video demonstration of PSBBN:

[![PSBBN in 2024](https://github.com/user-attachments/assets/298c8c0b-5726-4485-840d-9d567498fd95)](https://www.youtube.com/watch?v=kR1MVcAkW5M)

## Patch Features
- A full English translation of the stock Japanese BB Navigator version 0.32
- All binaries, XML files, textures, and pictures have been translated*
- Compatible with any fat model PS2 console regardless of region**
- DNAS authorization checks bypassed to enable online connectivity
- English translations of the online game channels from Sony, Hudson, EA, Konami, Capcom, Namco, and KOEI. Hosted courtesy of vitas155 at [psbbn.ru](https://psbbn.ru/)
- "Audio Player" feature re-added to the Music Channel from an earlier release of PSBBN, allowing compatibility with NetMD MiniDisc Recorders
- Associated manual pages and troubleshooting regarding the "Audio Player" feature translated and re-added to the user guide
- Japanese qwerty on-screen keyboard replaced with US English on-screen keyboard

## New to version 2.0
- Large HDD support. No longer limited to 128 GB, now with support for drives up to 128 PB
- Supports 700 games, all launchable from the Game Channel
- Set a custom size for your music partition. Original limit of 5 GB allowed the storage of around 7 albums. Now the partition can be up to 97 GB for around 150 albums
- exFAT partition for easy install of PS2 games
- wLaunchELF is pre-installed
- PS2 Linux is pre-installed. Just hold any button on the controller at startup to boot into Linux
- Bandai and SCEI online channels have been added to the Game Channel
- Some minor fixes to the English translation
### Update:
- Added Game ID support for the Pixel FX Retro GEM. Works for both PS1 and PS2 games
- PS2 games now launch up to 5 seconds faster
- Resolved conflict with mass storage devices (USB, iLink, MX4SIO). Games now launch without issues if these devices are connected
- OPL software now automatically updates when you sync your games
- The art downloader has been improved to grab significantly more artwork
- Improved error handling in the PSBBN installer script
- The setup script has been modified to work on live Linux environments without issues

### Note on Retro GEM support:
I would highly recommend that you install the [Retro GEM Game ID Resetter](https://github.com/CosmicScale/Retro-GEM-GameId-Resetter) on your PS2 Memory Card. With this app, when you quit a game, the Game ID is reset, and the Retro GEM settings are returned to global.

## New installation scripts

These scripts are essential for unlocking all the new features exclusive to version 2.0. They require a Linux environment to run. If Linux is not installed on your PC, you can use a live Linux environment on a bootable USB drive or a virtual machine. Debian-based distributions using `apt` and Arch-based distributions using `pacman` are supported. You will require a HDD/SSD for your PS2 that is larger than 200 GB, ideally 500 GB or larger. I highly recommend a SSD for better performance. The HDD/SSD can be connected to your PC internally or via USB.

## Video Tutorial:

[![PSBBN Definitive English Patch 2.0](https://github.com/user-attachments/assets/60f65b87-f445-4f5e-b2e1-65a4276d2ece)](https://www.youtube.com/watch?v=ooH0FjltsyE)

### Setup script:
`01-Setup.sh` installs all the necessary dependencies for the other scripts and must be run first.

### PSBBN installer script:
`02-PSBBN-Installer.sh` fully automates the installation of PSBBN

- Downloads the latest version of the `PSBBN Definitive English patch` from archive.org and installs it
- Asks how many 'OPL Launcher' partitions you'd like to create (for up to 700 games!)
- Asks how large you’d like the music partition
- Creates a __.POPS partition for PS1 games with the remaining space up to 128 GB
- Installs a custom build of OPL with exFAT and Auto Launch support for BDM devices
- Installs POPStarter
- Runs APA-Jail and creates an exFAT partition with all remaining disk space

### Game installer script: 
`03-Game-Installer.sh` fully automates the installation of PS1 and PS2 games. In the `games` folder on your computer, simply put your PS2 `ISO` or `ZSO` files in the `CD`/`DVD` folders, and your PS1 `VCD` files in the `POPS` folder.

The script will:
- Synchronise the games on your PC with your PS2's drive
- Create all game assets
- Download artwork
- Install [OPL Launcher BDM](https://github.com/CosmicScale/OPL-Launcher-BDM) into every game partition, making games bootable from the Game Channel

To add or delete games, simply add or remove them from the `games` folder on your computer, then run the script again to synchronise. All games are kept in alphabetical order and grouped by series in the Game Channel on PSBBN.

By default the `games` folder is located in the same directory you installed the scrips to. If you need to change the location of the `games` folder, edit `03-Game-Installer.sh` and modify the `GAMES_PATH` variable.


### Notes:
- PSBBN requires a Fat PS2 console** with expansion bay and an official Sony Network Adapter
- I would highly recommend using a **Kaico IDE to SATA Upgrade Kit** and a SATA SSD. The improved random access speed over a HDD really makes a big difference to the responsiveness of the PSBBN interface.
- Games in the PSBBN Game Channel listed as "Coming soon..." will launch OPL if selected
- The `root` password for Linux is `password`. There is also a `ps2` user account with the password set as `password`

### Notes on OPL:
- If OPL freezes at startup and games fail to launch from the PSBBN Game Channel, delete any existing OPL configuration files from your PS2 Memory Cards or connected USB devices.
- To display the games list in OPL, adjust the following settings:
  1. Settings > HDD (APA) Start Mode: Off
  2. Settings > BDM Start Mode: Auto
  3. Settings > BDM Devices > HDD (GPT/MBR): On
- Insert a PS2 memory card, then select `Save Changes` from the main menu.

### If, after trying the above steps, games still do not appear in the OPL games list and fail to launch from the PSBBN Game Channel, your drive may not be compatible with the exFAT version of OPL.

Possible solutions:
1. Connect the PS2 HDD/SSD directly to your PC using an internal SATA connection or a different USB adapter, then rerun the PSBBN installer.
2. Use a different HDD/SSD and rerun the PSBBN installer.

### Notes on APA-Jail:
APA-Jail, created and developed by [Berion](https://www.psx-place.com/resources/authors/berion.1431/), enables the PS2's APA partitions to coexist with an exFAT partition. This setup allows PSBBN to access the first 128 GB of the HDD/SSD directly. The remaining space on the drive is formatted as an exFAT partition, which can be accessed directly on a PC and by a [custom build of Open PS2 Loader](https://github.com/CosmicScale/Open-PS2-Loader-Retro-GEM/tree/psbbn-definitive-ver) on PS2. PS2 games in the `ISO` or `ZSO` format are stored on the exFAT partition.

![APA-Jail Type-A](https://github.com/user-attachments/assets/c1a29371-d0ff-431e-8b86-df8337ddf966)

An application called [OPL Launcher BDM](https://github.com/CosmicScale/OPL-Launcher-BDM) resides on the APA partitions, along with a [custom build of Open PS2 Loader](https://github.com/CosmicScale/Open-PS2-Loader-Retro-GEM/tree/psbbn-definitive-ver).
 
[OPL Launcher BDM](https://github.com/CosmicScale/OPL-Launcher-BDM) directs [Open PS2 Loader](https://github.com/CosmicScale/Open-PS2-Loader-Retro-GEM/tree/psbbn-definitive-ver) to launch specific PS2 games.

### Warning: Deleting or creating new partitions on your PS2 drive after setup will cause drive corruption.

## Credits
- PSBBN Definitive English Patch by [CosmicScale](https://github.com/CosmicScale)
- Online channels resurrected, translated, maintained and hosted by vitas155 at [psbbn.ru](https://psbbn.ru/)
- PlayStation Now! and Konami online channels re-translated by [CosmicScale](https://github.com/CosmicScale)
- `01-Setup.sh`, `02-PSBBN-Installer.sh`, `03-Game-Installer.sh`, `art_downloader.js` written by [CosmicScale](https://github.com/CosmicScale)
- Contains code from `list_builder.py` from [XEB+ neutrino Launcher Plugin](https://github.com/sync-on-luma/xebplus-neutrino-loader-plugin) by [sync-on-luma](https://github.com/sync-on-luma), modified by [CosmicScale](https://github.com/CosmicScale)
- Contains data from `TitlesDB_PS1_English.txt` and `TitlesDB_PS2_English.txt` from the [Title Database Scrapper](https://github.com/GDX-X/Title-Database-Scrapper), modified by [CosmicScale](https://github.com/CosmicScale)
- [OPL Launcher BDM](https://github.com/CosmicScale/OPL-Launcher-BDM) written by [CosmicScale](https://github.com/CosmicScale)
- Custom build of [Open PS2 Loader](https://github.com/CosmicScale/Open-PS2-Loader-Retro-GEM/tree/psbbn-definitive-ver) with BDM contributions from [KrahJohlito](https://github.com/KrahJohlito) and Auto Launch modifications by [CosmicScale](https://github.com/CosmicScale)
- Uses APA-Jail code from the [PS2 HDD Decryption Helper](https://www.psx-place.com/resources/ps2-hdd-decryption-helper.1507/) by [Berion](https://www.psx-place.com/resources/authors/berion.1431/)
- `APA Partition Header Checksumer` by Pinky from the [PS2 HDD Decryption Helper](https://www.psx-place.com/resources/ps2-hdd-decryption-helper.1507/) project. Linux port by Bucanero
- `ziso.py` from [Open PS2 Loader](https://github.com/ps2homebrew/Open-PS2-Loader) written by Virtuous Flame
- [PFS Shell](https://github.com/ps2homebrew/pfsshell)
- [HDL Dump](https://github.com/ps2homebrew/hdl-dump)
- [Open PS2 Loader](https://github.com/ps2homebrew/Open-PS2-Loader)  

---
<details>
<summary><font size="4"><b>Legacy versions of the PSBBN Definitive English Patch</b></font></summary>

## Version History

### v1.2 - 4th September 2024
- Fixed a bug on the Photo Channel that could potentially prevent the Digital Camera feature from being launched.
- Fixed formatting issues with a number of error messages where text was too long to fit on the screen.
- Various small adjustments and corrections to the translation throughout.

### v1.1.1 - 8th March 2024
**NEW**  
- X11 has been set to run in English. The restore, move, resize, minimize, and close buttons now show in English while using the NetFront web browser. When saving files, time stamps now also display in English formatting.

### v1.1 - 5th March 2024
**NEW**  
- The NetFront web browser is now in English. The browser can be accessed by going through the "Confirm/Change" network setting dialogs, then selecting "Change router settings".
- Atok user manual has been translated.

**BUG FIXES**  
- **General**: When a game disc was inserted while on the Top Menu, it would cause the console to freeze.  
- **Music Channel**: The number of times a track had been checked-out to a MiniDisc recorder was not displayed correctly.  
- A number of typos have been fixed.

### v1.0 - 21st September 2023
- Initial release.

---

## Installation Instructions

There are two ways to install this English patch:

1. [PS2 HDD RAW Image Install](#ps2-hdd-raw-image-install)
   - Use this method if you have access to a PC and a way to connect your PS2 HDD/SSD to your computer. This is the most straightforward option. All data on the HDD will be lost.

2. [Patch an existing PSBBN install](#patch-an-existing-psbbn-install)
   - Use this method if you already have an existing PSBBN install on your PlayStation 2 console. Also, follow these instructions to install future patch updates. No data will be lost.

---

### PS2 HDD RAW Image Install

#### What You Will Need
- Any fat model PS2 console**
- An official Sony Network Adapter
- A compatible HDD or SSD (IDE or SATA with an adapter). The drive must be 120 GB or larger
- A way to connect the PS2 HDD to a PC
- 120 GB of free space on your PC to extract the files
- Disk imaging software

#### Installation Procedure
1. Download [PSBBN_English_Patched_v1.x.x_Image.7z](https://archive.org/download/playstation-broadband-navigator-psbbn-definitive-english-patch-v1.0/PSBBN_English_Patched_v1.2_Image.7z) and uncompress it.
`PSBBN_English_Patched_v1.x.x_HDD_RAW.img` is a raw PS2 disk image of the Japanese PlayStation BB Navigator Version 0.32 with the PlayStation Broadband Navigator (PSBBN) Definitive English Patch pre-installed.
2. To write this image to your PS2 HDD, you need disk imaging software. For Windows, I recommend using HDD Raw Copy ver. 1.10 portable. You can download it [here](https://hddguru.com/software/HDD-Raw-Copy-Tool/).

---

### Patch an existing PSBBN install

#### What You Will Need
- Any fat model PS2 console**
- An official Sony Network Adapter
- A compatible HDD or SSD (IDE or SATA with an adapter)
- An existing install of PSBBN software 0.32 on your PS2 console
- A Free McBoot Memory Card
- A USB flash drive formatted as FAT32
- A USB keyboard

#### Installing the English Patch
1. Install the PSBBN software on your PS2 console if you haven't done so already. Either via a disk image or manually, see the section [Installing the Japanese PSBBN software](#installing-the-japanese-psbbn-software) below for details on a manual install.
2. Download [PSBBN_English_Patch_Installer_v1.x.x.zip](https://archive.org/download/playstation-broadband-navigator-psbbn-definitive-english-patch-v1.0/PSBBN_English_Patch_Installer_v1.2.zip) and unzip it on your PC.
3. Copy the files `kloader3.0.elf`, `config.txt`, `xrvmlinux`, `xrinitfs_install.gz`, and `PSBBN_English.tar.gz` to the root of a FAT32 formatted USB flash drive.
4. Connect the USB flash drive and a USB keyboard to the USB ports on the front of your PS2 console.
5. Turn the PS2 console on with your Free McBoot Memory Card inserted and load wLaunchELF.
6. Load `kloader3.0.elf` from the USB flash drive.
7. Eventually, you will be presented with a login prompt:  
     Type `root` and press enter.  
     Type `install` and press enter.
8. When you see the text `INIT: no more processes left in this runlevel`, hold the standby button down until the console powers off.

Remove your Free McBoot Memory Card. Power the console on and enjoy PSBBN in full English!

---

## Installing the Japanese PSBBN software

There are a number of ways this can be achieved. On a Japanese PlayStation 2 console with an **official PSBBN installation disc**, or with **Sony Utility Discs Compilation 3**.

To install via **Sony Utility Discs Compilation 3** you will need a way to boot backup discs on your console, be that a mod chip or a swap disc. If you are lucky enough to have a **SCPH-500xx** series console you can use the **MechaPwn** softmod.

### Installing with Sony Utility Discs Compilation 3

**Preparations**
1. Download the **Sony Utility Discs Compilation 3** ISO from the Internet Archive [here](https://archive.org/details/sony-utility-disc-compilation-v3).
2. **SCPH-500xx consoles only**: Patch the ISO with the [Master Disc Patcher](https://www.psx-place.com/threads/playstation-2-master-disc-patcher-for-mechapwn.36547/).
3. Burn this ISO to a writable DVD. I recommend using [ImgBurn](https://www.imgburn.com).
4. **SCPH-500xx consoles only**: MechaPwn your PS2 console with the latest release candidate, currently [MechaPwn 3.0 Release Candidate 4 (RC4)](https://github.com/MechaResearch/MechaPwn/releases/tag/3.00-rc4). It is important that you use a version of MechaPwn that does not change the **Model Name** of your console or it will break compatibility with the Kloader app, we use later in this guide. Currently the latest stable version is not compatible. More details about exactly what MechaPwn does and how to use it can be found [here](https://github.com/MechaResearch/MechaPwn).
5. Format the PS2 HDD. In wLaunchELF press the `circle` button for **FileBrowser**, then select **MISC > HddManager**. Press `R1` to open the menu and select **Format**. When done, press `triangle` to exit.
6. Launch the **Sony Utility Discs Compilation 3** DVD on your console. **SCPH-500xx consoles only:** Insert your newly burnt **Sony Utility Discs Compilation 3** DVD into the DVD drive on your PS2 console. On the first screen of wLaunchELF, press the `circle` button for **FileBrowser**, then select **MISC > PS2Disc**. The DVD will launch. On all other model consoles, launch the **Sony Utility Discs Compilation 3** DVD any way you can (e.g. Mod chip/Swap disc).
7. After the disc loads, select **HDD Utility Discs > PlayStation BB Navigator Version 0.32** from the menu to begin the installation.

**Installation**  
There's an excellent guide [here](https://bungiefan.tripod.com/psbbninstall_01.html) that talks you through the Japanese install. Because we have already formatted the hard drive, during the install you will be presented with a [different screen](https://bungiefan.tripod.com/psbbninstall_02.html). It's important that you select the 3rd install option. This will install PSBBN without re-formatting the HDD. When the install is complete you will be instructed to remove the DVD, do so but also remove your Free McBoot Memory Card, before pressing the `circle` button.

**Network Settings**  
You will be asked to enter your network settings. Make sure your Ethernet cable is connected. Everything is still in Japanese, but it's relatively straightforward:
1. Press the `circle` button on the first screen.
2. On the next screen, select the **bottom** option, "Do not use PPPoE" and press `circle`.
3. On the next screen, select the **top** option, “Auto" for you IP address and press `circle`.
4. On the next screen, select the **top** option, “Auto” for DNS settings and press `circle`.
5. Press `right` on the d-pad to proceed to the next screen.
6. Select the **bottom** option, "Do not change router settings" and press `circle`.
7. Finally, press `circle` again to confirm your settings.

For your efforts you will be given a DNAS error. This is to be expected. We'll fix that next. Press `X` and feel free to explore your fresh install of the Japanese PSBBN.

**Disable DNAS Authentication**  
1. Turn off the console and put your Free McBoot Memory Card back into a memory card slot.  
2. Turn the console on and load wLaunchELF.  
3. Go to **FileBrowser**. Navigate to `hdd0:/__contents/bn.conf/` and delete the file `default_isp.dat`. This will disable the DNAS checks.

**Please Note**
Before installing the English patch, you **must** power off your console to standby mode by holding the reset button. Failure to do so will cause issues with Kloader.

---

## Notes
- I would highly recommend using a **"Kaico IDE to SATA Upgrade Kit"** and a SATA SSD such as the **Kingston A400**. The improved random access speed over a HDD really makes a big difference to the responsiveness of the PSBBN interface.
- Use OPL-Launcher to launch PS2 games from the Game Channel. More details can be found [here](https://github.com/ps2homebrew/OPL-Launcher).

---

## Known Issues/Limitations of PSBBN
- Lacks support for large HDDs so drives larger than 130 GB cannot be taken full advantage of. PSBBN can only see the first 130,999 MB of data on your HDD/SSD (as reported by wLaunchELF). If there is 131,000 MB or more on your HDD/SSD, PSBBN will fail to launch. Delete data so there is less than 131,000 MB used, and PSBBN will launch again. In that space, I've managed to install 40 PS2 games in the ZSO format, 9 PS1 games, all bootable from the Game Channel, plus 3 homebrew apps, and Linux. Be extra careful if you have installed via the [PS2 HDD RAW Image](#ps2-hdd-raw-image-install) on a drive larger than 120 GB, going over 130,999 MB will corrupt the drive.
- Only supports dates up to the end of 2030.
- Bug with Game Manuals randomly crashing when loading pages. Manuals only work reliably on the first 5 games installed.
- Default on-screen keyboard is Japanese. US English on-screen keyboard has been added, but you have to press SELECT a number of times to access it. I've noticed a bug where the spacebar key does not function on the US English on-screen keyboard. A space can be entered by pressing the triangle button on the controller instead. I could revert back to the Japanese qwerty keyboard in the future, but I think the benefits of the US keyboard outweigh this negative.

---

</details>


\* Instances in feega where some Japanese text could not be translated because it is hard coded in an encrypted file. Atok software has not been translated. You might need to manually change the title of your "Favorite" folders if they were created before you **Patched an existing PSBBN install**.  
\** Should also be compatible with the PS2 Slim SCPH-70xxx models with an IDE Resurrector mod. PSBBN Definitive English Patch 2.0 and older versions of the **PS2 HDD RAW Image Install** are not compatible with early model Japanese PS2 consoles that have an external HDD due to space limitations. **Patch an existing PSBBN install** - Kloader might have compatibility issues with early model Japanese PS2 consoles.
