# neutrino
Small, Fast and Modular PS2 Device Emulator

## Design
A neutrino is a particle with almost zero mass, and that's what this device emulator's primary goal is. To have almost 0 mass when emulating devices to maximize compatibility.

Neutrino also does not have a user interface, instead it's meant to be integrated as a backend to a frontend (user interface). This makes neutrino much more easy to maintain, and allows many more applications to be made using neutrino as the backend.

With neutrino all modules are... modular. They are in a separate folder called `modules`. This allows the user add new and improved modules. What modules are loaded is fully configurable using TOML config files in the `config` folder.

## Environments
An environment in neutrino describes what IOP modules are loaded and defines what features the environment has. In neutrino there are 3 environments:
- Boot Environment (BE): environment neutrino is loaded from (by uLE / ps2link / ...), containing neutrino, configuration files and drivers
- Load Environment (LE): neutrino's loader.elf reboots into the LE, containing virtual disk images
- Emulation Environment (EE): neutrino's ee_core.elf reboots into the EE, emulating devices

## Backing Store Driver
A backing store driver provides a storage location for storing virtual disk images. For instance of DVD's, HDD's or MC's.
The following backing storage devices are supported:
Device             | PS2 model  | Speed                                                     | Device comp.                       | Type         | bsd      | internal
-------------------|------------|-----------------------------------------------------------|------------------------------------|--------------|----------|-----
USB                | FAT + 70k  |![x](https://progress-bar.xyz/750?scale=2200&suffix=KB/s)  | ![x](https://progress-bar.xyz/80)  | Block Device | `usb`    | `usb`
USB                | slim       |![x](https://progress-bar.xyz/900?scale=2200&suffix=KB/s)  | ![x](https://progress-bar.xyz/80)  | Block Device | `usb`    | `usb`
MX4SIO             | slim       |![x](https://progress-bar.xyz/1150?scale=2200&suffix=KB/s) | ![x](https://progress-bar.xyz/60)  | Block Device | `mx4sio` | `sdc`
MMCE               | slim       |![x](https://progress-bar.xyz/1350?scale=2200&suffix=KB/s) | ![x](https://progress-bar.xyz/100) | File System  | `mmce`   | -
MX4SIO             | FAT + 70k  |![x](https://progress-bar.xyz/1500?scale=2200&suffix=KB/s) | ![x](https://progress-bar.xyz/60)  | Block Device | `mx4sio` | `sdc`
MMCE               | FAT + 70k  |![x](https://progress-bar.xyz/1700?scale=2200&suffix=KB/s) | ![x](https://progress-bar.xyz/100) | File System  | `mmce`   | -
iLink / IEEE1394   | FAT        |![x](https://progress-bar.xyz/6?scale=2&suffix=MB/s)       | ![x](https://progress-bar.xyz/10)  | Block Device | `ilink`  | `sd`
UDPBD              | ALL        |![x](https://progress-bar.xyz/10?scale=2&suffix=MB/s)      | ![x](https://progress-bar.xyz/100) | Block Device | `udpbd`  | `udp`
ATA (internal HDD) | FAT        |![x](https://progress-bar.xyz/30?scale=2&suffix=MB/s)      | ![x](https://progress-bar.xyz/100) | Block Device | `ata`    | `ata`

PS2 model: The older FAT PS2 models and the first slim PS2 model (70k) have the original PS1 MIPS R3000 CPU. Later slim PS2 models have a new CPU with 'DECKARD' emulating the MIPS R3000. This is why there is a speed difference between those two groups of PS2 models.

Speed: USB, MX4SIO and MMCE have been tested with neutrino v1.5.0. The other speeds are based on older tests and should serve as an indication. For proper emulation of the ps2 DVD drive a speed of at least 2.2MB/s is needed. The slower the speed, the more likely video's will stutter. Due to game-bugs, some games will not even run if the device is too slow.

"Device comp.": how many devices will work with neutrino. For instance most USB sticks work, but some (mostly USB3.0 sticks) don't work. With mx4sio, many SD cards are not compatible, etc... Don't hold these values for fact, they are based on my personal observations and should give you an indication on what devices would fit your need.

On "Block Devices" the following partitioning schemes are supported:
- MBR (Master Boot Record)
- GPT (GUID Partition Table)

And the following file systems:
- exFat/FAT32, accessable as `mass:<file>.iso`
- HDLoader, accessable as `hdl:<file>`, `hdl:<file>.iso`, `hdl:<part>` or `hdl:<part>.iso`
- Block Devices, accessable as `bdfs:<blockdevice>`. Like `bdfs:udp0p0`

Note that the HDLoader backing store is currently read-ony, and limited to only emulating the DVD.

## CD/DVD emulation
The following CD/DVD emulation drivers are supported:
- No: using original CD's / DVD's in the optical drive
- ESR: using ESR patched DVD's in the optical drive
- File: using an iso file from the backing store

## ATA HDD emulation
The following HDD emulation drivers are supported:
- No: using ATA HDD in the PS2
- File: using a virtual HDD image file from the backing store

## Usage instructions
Neutrino is a command line application. To get the most out of neutrino you will need to run it from the command line, for instance using [ps2link](https://github.com/ps2dev/ps2link) and [ps2client](https://github.com/ps2dev/ps2client).

Alternatively you can use a more user friendly GUI from one of the third-party projects (see below), but with a limited feature set.

Command line usage instructions:

```
Usage: neutrino.elf options

Options:
  -bsd=<driver>     Backing store drivers, supported are:
                    - no     (uses cdvd, default)
                    - ata    (block device)
                    - usb    (block device)
                    - mx4sio (block device)
                    - udpbd  (block device)
                    - ilink  (block device)
                    - mmce   (file system)

  -bsdfs=<driver>   Backing store fileystem drivers used for block device, supported are:
                    - exfat (default)
                    - hdl   (HD Loader)
                    - bd    (Block Device)
                    NOTE: Used only for block devices (see -bsd)

  -dvd=<mode>       DVD emulation mode, supported are:
                    - no (default)
                    - esr
                    - <file>

  -ata0=<mode>      ATA HDD 0 emulation mode, supported are:
                    - no (default)
                    - <file>
                    NOTE: only both emulated, or both real.
                          mixing not possible
  -ata0id=<mode>    ATA 0 HDD ID emulation mode, supported are:
                    - no (default)
                    - <file>
                    NOTE: only supported if ata0 is present
  -ata1=<mode>      See -ata0=<mode>

  -mc0=<mode>       MC0 emulation mode, supported are:
                    - no (default)
                    - <file>
  -mc1=<mode>       See -mc0=<mode>

  -elf=<file>       ELF file to boot, supported are:
                    - auto (elf file from cd/dvd) (default)
                    - <file>

  -mt=<type>        Select media type, supported are:
                    - cd
                    - dvd
                    Defaults to cd for size<=650MiB, and dvd for size>650MiB

  -gc=<compat>      Game compatibility modes, supported are:
                    - 0: IOP: Fast reads (sceCdRead)
                    - 1: dummy
                    - 2: IOP: Sync reads (sceCdRead)
                    - 3: EE : Unhook syscalls
                    - 5: IOP: Emulate DVD-DL
                    - 7: IOP: Fix game buffer overrun
                    Multiple options possible, for example -gc=23

  -gsm=x:y:z        GS video mode

                    Parameter x = Interlaced field mode
                    A full height buffer is used by the game for displaying. Force video output to:
                    -      : don't force (default)  (480i/576i)
                    - fp   : force progressive scan (480p/576p)

                    Parameter y = Interlaced frame mode
                    A half height buffer is used by the game for displaying. Force video output to:
                    -      : don't force (default)  (480i/576i)
                    - fp1  : force progressive scan (240p/288p)
                    - fp2  : force progressive scan (480p/576p line doubling)

                    Parameter z = Compatibility mode
                    -      : no compatibility mode (default)
                    - 1    : field flipping type 1 (GSM/OPL)
                    - 2    : field flipping type 2
                    - 3    : field flipping type 3

                    Examples:
                    -gsm=fp       - recommended mode
                    -gsm=fp::1    - recommended mode, with compatibility 1
                    -gsm=fp:fp2:2 - all parameters

  -cwd=<path>       Change working directory

  -cfg=<file>       Load extra user/game specific config file (without .toml extension)

  -dbc              Enable debug colors
  -logo             Enable logo (adds rom0:PS2LOGO to arguments)
  -qb               Quick-Boot directly into load environment

  --b               Break, all following parameters are passed to the ELF

Usage examples:
  neutrino.elf -bsd=usb    -dvd=mass:path/to/filename.iso
  neutrino.elf -bsd=mx4sio -dvd=mass:path/to/filename.iso
  neutrino.elf -bsd=mmce   -dvd=mmce:path/to/filename.iso
  neutrino.elf -bsd=ilink  -dvd=mass:path/to/filename.iso
  neutrino.elf -bsd=udpbd  -dvd=mass:path/to/filename.iso
  neutrino.elf -bsd=ata    -dvd=mass:path/to/filename.iso
  neutrino.elf -bsd=ata    -dvd=hdl:filename.iso -bsdfs=hdl
  neutrino.elf -bsd=udpbd  -dvd=bdfs:udp0p0      -bsdfs=bd
```

## Third-Party Loaders
The following third-party projects use neutrino:

Loader | Author
-|-
[XEB+ neutrino Launcher Plugin](https://github.com/sync-on-luma/xebplus-neutrino-loader-plugin) | sync-on-luma
[NHDDL](https://github.com/pcm720/nhddl) | pcm720
[RETROLauncher](https://github.com/Spaghetticode-Boon-Tobias/RETROLauncher) | Boon Tobias
[OSD-XMB](https://github.com/HiroTex/OSD-XMB) | Hiro Tex
[PSBBN](https://github.com/CosmicScale/PSBBN-Definitive-English-Patch) + [BBNL](https://github.com/pcm720/bbnl) | CosmicScale + pcm720

Add your project here? Send me a PR.
