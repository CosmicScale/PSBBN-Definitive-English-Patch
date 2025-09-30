﻿#Requires -Version 5.1

# User must open its execution policy by running
# `Set-ExecutionPolicy -ExecutionPolicy Unrestricted`
# and choose "Yes to All"

param(
  [Alias("logs", "log")]
  [switch]$LogsEnabled = $false
)

# the version of this script itself, useful to know if a user is running the latest version
$version = "1.1.0"

# the label of the WSL machine. Still based on Debian, but this label makes sure we get the
# machine created by this script and not some pre-existing Debian the user had.
$wslLabel = "PSBBN"

# the name of the exfat volume created by the psbbn installer with apajail
# this is used to attempt to detect which disks have an install of PSBBN
$oplVolumeName = "OPL"

# a list of subfolders to be created in the main folder if missing
$defaultFolders = @('DVD', 'CD', 'POPS', 'APPS', 'music', 'movie', 'photo')

# the specific git branch to be checked out
$gitBranch = "main"

# the console size that is set at the start of the script
$consoleWidth = 100
$consoleHeight = 45

# the filename of the file holding the last path used
$pathFilename = "path.cfg"

# the minimum disk size allowed to be picked, in gigabytes
$minimumDiskSize = 200

# --- DO NOT MODIFY THE VARIABLES BELOW ---

# in case $gitBranch no longer exists on the remote, use this as fallback
# DO NOT change this unless the repo has deleted the main branch or is using another branch as release
$fallbackGitBranch = "main"

# the escape character used to color text
$e = [char] 27

# this make wsl commands output utf8 instead of utf16_LE
$env:WSL_UTF8 = 1

# flag potentially raised when enabling features, signaling a reboot is necessary to finish the install
$global:IsRestartRequired = $false

# stores Get-Disk's result to avoid multiple calls
$global:diskList = $null

# stores the disk number (obtained with Get-Disk) that was selected via diskPicker
$global:selectedDisk = -1

function main {
  # set the console size so it matches the other scripts
  $host.UI.RawUI.WindowSize = New-Object `
    -TypeName System.Management.Automation.Host.Size `
    -ArgumentList ($consoleWidth, $consoleHeight)

  $PSDefaultParameterValues['*:Encoding'] = 'utf8'

  clear
  printTitle
  Write-Host "Prepare Windows to run the PSBBN scripts.`n"

  # check if mandatory windows features are enabled
  Write-Host "Checking if the mandatory features are enabled..."
  # enable WSL as needed
  checkAndEnableFeature("Microsoft-Windows-Subsystem-Linux")
  # enable Hyper V as needed
  checkAndEnableFeature("HypervisorPlatform")
  # enable Virtual Maching Platform as needed
  checkAndEnableFeature("VirtualMachinePlatform")

  # detect if virtualization is enabled in BIOS
  detectVirtualization

  if ($isRestartRequired) {
    Write-Host "
    You need to restart your computer in order for some newly installed features to work properly.
    Once you have restarted, just run this script again.
" -ForegroundColor Yellow
    do {
      clearLines(1)
      $keyPressed = Read-Host "⚠️ You are about to restart your PC. Save your work, type `"restart`" and press ENTER"
      $keyPressed = $keyPressed.ToLower()
    } while ($keyPressed -ne 'restart')

    if ($keyPressed -eq 'restart') {
      Restart-Computer
    }
    Exit
  }

  # check if wsl exists
  if (-Not (Get-Command wsl -errorAction SilentlyContinue)) {
    Write-Host "❌ WSL is not available on this computer." -ForegroundColor Red
    Exit
  }

  # fetch the latest wsl update
  Write-Host "Check the latest WSL updates...`t`t`t" -NoNewline
  $wslUpdate = wsl --update --web-download
  printOK

  # check if a wsl distro is installed already
  $isWslInstalled = wsl --list | Select-String -SimpleMatch -Quiet $wslLabel
  if (-Not ($isWslInstalled)) {
    Write-Host "`nThe WSL distro will prompt you to set a username and a password." -ForegroundColor Yellow
    Write-Host "⚠️ The username must start with a lowercase letter, and only contain letters and numbers." -ForegroundColor Red
    Write-Host "⚠️ A password must be set." -ForegroundColor Red
    Write-Host "After this is done, you can type 'exit' and press enter to return to this script.`n" -ForegroundColor Yellow
    Write-Host "------- Linux magic starts ---------"

    wsl --install --distribution Debian --name $wslLabel
  } else {
    Write-Host "The WSL distro is already present, skipping.`t" -NoNewline
    printOK
  }

  # install git if it is missing
  wsl -d $wslLabel -- type git `&`> /dev/null `|`| `(sudo apt update `&`& sudo apt -y install git`)

  # check that git is properly installed before continuing. Some network configurations can cause apt to fail to reach the repos
  if (-Not (wsl -d $wslLabel -- type git `2`> /dev/null)) {
    Write-Host "
    ❌ The script was unable to install git so it cannot continue.
    Check your internet connection and try to run the script again.
    If the issue persists, try setting your wsl networking mode to `"mirrored`" and try again.
    To do so, open the `"WSL Settings`" app then open the `"Networking`" tab.
    There you should see the option `"Networking Mode`". Select `"Mirrored`".
    " -ForegroundColor Red
    Exit
  }

  # check if the git branch exists on the remote, and if not, use the fallback
  if (-Not (wsl -d $wslLabel --cd "~/PSBBN-Definitive-English-Patch" -- git branch -r --list origin/$gitBranch)) {
    $gitBranch = $fallbackGitBranch
  }

  # clone the PSBBN repo into ~, or pull if it's already there
  Write-Host
  wsl -d $wslLabel --cd "~" -- [ -d PSBBN-Definitive-English-Patch/.git ] `
    `&`& `( `
      cd PSBBN-Definitive-English-Patch/ `
      `&`& git fetch origin $gitBranch `
      `&`& git checkout $gitBranch `
      `&`& git pull --ff-only `
    `) `
    `|`| git clone -b $gitBranch https://github.com/CosmicScale/PSBBN-Definitive-English-Patch.git

  if (-Not ($isWslInstalled)) {
    Write-Host "------- Linux magic finishes ---------`n"
  }

  # prompt user to choose a disk
  diskPicker

  # mount the disk
  $deviceName = "\\.\PHYSICALDRIVE$global:selectedDisk"
  mountDisk($deviceName)

  # give the user the opportunity to put games/homebrew in the PSBBN folder
  $path = getTargetFolder
  clear

  # run PSBBN regular steps
  wsl -d $wslLabel --cd "~/PSBBN-Definitive-English-Patch" -- `
    ./PSBBN-Definitive-Patch.sh -wsl $global:diskList[$selectedDisk].SerialNumber $path

  # clear the terminal to get rid of the wsl-run scripts
  clear
  printTitle

  # unmount the disk before exiting
  unmountDisk($deviceName)

  # ensures wsl doesnt run out of resources if this script is ran repeatedly
  wsl --shutdown

  Write-Host "`nHave fun exploring PSBBN!`n" -ForegroundColor Green
}

# print colored `[ OK ]`
function printOK {
  Write-Host "    `t`t[ $e[92mOK$e[0m ]"
}

# print colored `[ NG ]`
function printNG {
  Write-Host "    `t`t[ $e[91mNG$e[0m ]"
}

# print colored `[ Restart required ]`
function printRestartRequired {
  Write-Host "    `t`t[ $e[93mRestart required$e[0m ]"
}

# takes a feature as parameter and enable it if needed
function checkAndEnableFeature ($featureName) {
  $feature = Get-WindowsOptionalFeature -Online -FeatureName $featureName
  if (($null -ne $feature.FeatureName) -and ($feature.State -ne "Enabled")) {
    Write-Host "  └ Enabling" $feature.DisplayName "..." -NoNewline;
    $enabled = Enable-WindowsOptionalFeature -Online -FeatureName $feature.FeatureName -All -NoRestart -WarningAction:SilentlyContinue
    if ($enabled.RestartNeeded) {
      $global:IsRestartRequired = $true
      printRestartRequired
    } else {
      printOK
    }
  } elseif ($feature.State -eq "Enabled"){
    Write-Host "  └" $feature.DisplayName 'already enabled.' -NoNewline
    printOK
  }
}

# prints the big psbbn logo and the version number
function printTitle {
  Write-Host "
______  _________________ _   _  ______      __ _       _ _   _            ______     _       _
| ___ \/  ___| ___ \ ___ \ \ | | |  _  \    / _(_)     (_) | (_)           | ___ \   | |     | |
| |_/ /\ ``--.| |_/ / |_/ /  \| | | | | |___| |_ _ _ __  _| |_ ___   _____  | |_/ /_ _| |_ ___| |__
|  __/  ``--. \ ___ \ ___ \ . `` | | | | / _ \  _| | '_ \| | __| \ \ / / _ \ |  __/ _`` | __/ __| '_ \
| |    /\__/ / |_/ / |_/ / |\  | | |/ /  __/ | | | | | | | |_| |\ V /  __/ | | | (_| | || (__| | | |
\_|    \____/\____/\____/\_| \_/ |___/ \___|_| |_|_| |_|_|\__|_| \_/ \___| \_|  \__,_|\__\___|_| |_|

                                       Created by CosmicScale
                                                ---
                                     Launcher for Windows v$version
                                          Written by Yornn

"
}

# display the available disks and prompt user for choice
function diskPicker {
  # store the current cursor position to help clear the console upon refreshing the list of disks
  $lineStart = $Host.UI.RawUI.CursorPosition.Y

  # list available disks and pick the one to be mounted
  Write-Host "`nList of available disks:"
  $global:diskList = Get-Disk | Sort -Property Number
  $disksExtras = detectDisksExtras
  $global:diskList | Format-Table -AutoSize -Property `
    Number, `
    @{Label="Name";Expression={$_.FriendlyName}}, `
    @{Label="Size";Expression={("{0:N2}" -f ($_.Size / 1GB)).ToString() + " GB"}}, `
    SerialNumber, `
    @{Label="";Expression={$disksExtras[$_.Number]}}
  
  if (($global:diskList | Where-Object -FilterScript {isTooSmall($_)}).Count -gt 0) {
    Write-Host "ℹ️ PSBBN requires a disk with a minimum capacity of 200GB.`n" -ForegroundColor Yellow
  }

  $selectedDisk = handleDiskSelection

  if ($selectedDisk -eq "r") {
    clearLines($Host.UI.RawUI.CursorPosition.Y - $lineStart)
    diskPicker
  } else {
    $global:selectedDisk = $selectedDisk
  }
}

# handles the input logic of the diskpicker
# this function calls itself recursively as long an invalid input is provided
function handleDiskSelection {
  $selectedDisk = -1
  # generate a list of disk number to validate user input
  $availableNumbers = $global:diskList `
    | Where-Object -FilterScript {-Not (isTooSmall($_))} `
    | Foreach-Object {$_.Number}

  Write-Host "Select a disk to use by typing its number or press `"r`" to refresh the list.`n"
  $promptMessage = " "
  $validInput = $false
  do {
    clearLines(1)
    $input = Read-Host "$promptMessage"
    $input = $input.ToLower()

    if (-Not $validInput) {
      $promptMessage = "$e[91mInvalid input, try again$e[0m"
    }

    # it is necessary to check if $input is empty first, or ($input -in $availableNumbers) will return true for some reason
    $validInput = $input -And (($input -in $availableNumbers) -Or ($input -eq "r"))
  } while (-Not $validInput)

  $selectedDisk = $input

  clearLines(1)
  Write-Host "Disk number $selectedDisk picked."

  return $selectedDisk
}

# detects if bios-level virtualization is enabled or not, and display messages
function detectVirtualization {
  Write-Host "Checking if virtualization is enabled in BIOS..." -NoNewline

  $propertyName = "HyperVRequirementVirtualizationFirmwareEnabled"
  $property = Get-ComputerInfo -property $propertyName

  # the property is null if the feature is enabled, false otherwise
  if ($property.$propertyName -eq $false) {
    printNG
    Write-Host "`n
    ⚠️ Virtualization is not enabled. It is mandatory to run PSBBN scripts.
    If you have an AMD CPU, enable SVM in your BIOS.
    If you have an Intel CPU, enable VT-x in your BIOS.
    Check the manual of your motherboard if you have troubles finding this setting.
    " -ForegroundColor Yellow
    Exit
  } else {
    printOK
  }
}

# set the disk offline and then mount it to WSL
# offline is necessary otherwise windows processes might prevent wsl from mounting
function mountDisk ($deviceName) {
  Write-Host "`nMounting $deviceName on wsl...`t`t" -NoNewline
  $null = Set-Disk $global:selectedDisk -isOffline $true -errorAction SilentlyContinue
  $mountOut = wsl -d $wslLabel --mount $deviceName --bare
  handleMountOutput($mountOut)
}

# unmount the disk and then set the disk back online
function unmountDisk ($deviceName) {
  Write-Host "Unmounting $deviceName...`t`t" -NoNewline
  $unmountOut = wsl -d $wslLabel --unmount $deviceName
  Set-Disk $global:selectedDisk -isOffline $false
  handleMountOutput($unmountOut)
}

# handles the error code returned by `wsl --mount` or wsl --unmount` and display human friendly messages
function handleMountOutput ($mountOut) {
  if ($mountOut -like "*Wsl/Service/AttachDisk/MountDisk/WSL_E_DISK_ALREADY_ATTACHED*") {
    # in the case where the disk was already attached, we just carry on and treat it as a happy path
    printOK
    Write-Host "The disk was already mounted." -ForegroundColor Green
    return
  } elseif ($mountOut -like "*Wsl/Service/DetachDisk/ERROR_FILE_NOT_FOUND*") {
    # in the case where the disk was already detached, we just carry on and treat it as a happy path
    printOK
    Write-Host "The disk was already unmounted." -ForegroundColor Green
    return
  } elseif ($mountOut -like "*Wsl/Service/AttachDisk/MountDisk/*0x8007000f*") {
    # attempting to mount a sdcard reader will return this error
    printNG
    Write-Host "❌ USB thumbdrives and SD card readers are not supported by the PSBBN Launcher for Windows." -ForegroundColor Red
    Exit
  } elseif ($mountOut -like "*Error code*") {
    printNG
    Write-Host $mountOut -ForegroundColor Red
    Exit
  }
  printOK
}

# checks if the script is running as admin, and if not launches itself in powershell instance running as admin
function restartAsAdminIfNeeded {
  if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # already running as admin, so we just carry on
    return
  }

  # if powershell 7 is installed, launch that one instead of 5.1
  $shell = "powershell"
  if (Get-Command pwsh -errorAction SilentlyContinue) {
    $shell = "pwsh"
  }

  # relaunch the script as admin, this should trigger a UAC prompt
  Start-Process $shell -Verb RunAs -ArgumentList "-NoLogo -NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`""

  # close the initial non-admin shell to avoid confusion
  Exit
}

# handles the folder picker and return a wsl compatible path as a string
function getTargetFolder {
  # if a previously used path exists, use that in the folder picker, otherwise use "Desktop"
  $desktopDirectory = [Environment]::GetFolderPath('Desktop')
  $initialDirectory = $desktopDirectory
  $isPresetPath = $false
  if (Test-Path ".\$pathFilename" -PathType Leaf) {
    $initialDirectory = Get-Content -Path ".\$pathFilename"
    $isPresetPath = $true

    # check that the path in path.cfg still exists, if not default to "Desktop"
    if (-Not (Test-Path $initialDirectory -PathType Container)) {
      $initialDirectory = $desktopDirectory
      $isPresetPath = $false
    }
  }

  # if the path is already set, ask if the user wants to re-use it
  if ($isPresetPath) {
    Write-Host "`nThe following path was previously used: " -NoNewLine
    Write-Host "$initialDirectory`n" -ForegroundColor Green
    do {
      clearLines(1)
      $keyPressed = Read-Host "Would you like to keep using this path? (y/n)"
      $keyPressed = $keyPressed.ToLower()
    } while ($keyPressed -ne 'y' -and $keyPressed -ne 'n')

    if ($keyPressed -eq 'y') {
      explorer $initialDirectory
      return convertPathToWsl($initialDirectory)
    }
  }

  Write-Host "`nNext you will be asked to pick a folder where to put all your games, movies, photos, and music." -ForegroundColor Yellow

  pause

  # prepare and then open the folder picker
  Add-Type -AssemblyName System.Windows.Forms
  $folderselection = New-Object System.Windows.Forms.OpenFileDialog -Property @{
    InitialDirectory = $initialDirectory
    CheckFileExists = 0
    ValidateNames = 0
    FileName = "Choose Folder"
  }
  $result = $folderselection.ShowDialog()

  if($result -ne "OK") {
    Write-Host "No folder was picked, you will have to do it manually later." -ForegroundColor Yellow
    return ""
  }

  $pickedPath = Split-Path -Parent $folderselection.FileName

  # create default folders if missing
  $defaultFolders.ForEach({
    if (-Not (Test-Path -Path "$pickedPath\$PSItem")) {
      New-Item -Path $pickedPath -Name $PSItem -ItemType Directory | Out-Null
    }
  })

  Write-Host "`nThe following path was chosen: $pickedPath" -ForegroundColor Green
  Write-Host "
Before you continue, you can fill this folder with your games and other media:
    - put PS2 games in /DVD or /CD (.iso or .zso files)
    - put PS1 games in /POPS (must be .vcd files)
    - put homebrew in /APPS (.elf or SAS-compliant .psu files)
    - put music in /music (.mp3, .m4a, .flac, or .ogg files)

You can refer to the PSBBN Readme to know more.
https://github.com/CosmicScale/PSBBN-Definitive-English-Patch
" -ForegroundColor Yellow

  # store the selected path to re-use next time the script is ran
  New-Item -Path "." -Name $pathFilename -ItemType "file" -Value $pickedPath -Force | Out-Null

  explorer $pickedPath

  pause

  return convertPathToWsl($pickedPath)
}

# clears $count lines with spaces and move the cursor back
function clearLines ($count) {
  $currentLine  = $Host.UI.RawUI.CursorPosition.Y
  $consoleWidth = $Host.UI.RawUI.BufferSize.Width

  $i = 0
  for ($i; $i -le $count; $i++) {
      [Console]::SetCursorPosition(0,($currentLine - $i))
      [Console]::Write("{0,-$consoleWidth}" -f " ")
  }
  [Console]::SetCursorPosition(0,($CurrentLine - $count))
}

# for each disk, generate a message to be displayed in the diskPicker list's last column
function detectDisksExtras {
  # a keyed array of <(int) diskNumber, (string) messages>
  $messages = @{}

  $global:diskList | ForEach-Object {
    $message = "   "
    $diskNumber = $_.Number

    # walks through each partition -> volume to find which disks have volumes named $oplVolumeName
    $null = Get-Partition -disknumber $diskNumber -errorAction SilentlyContinue | ForEach-Object {
      Get-Volume -partition $_ | ForEach-Object {
        $_.FileSystemLabel.GetType()
        if ($_.FileSystemLabel -eq $oplVolumeName) {
          $message = "$e[92mPSBBN detected$e[0m"
        }
      }
    }

    # PSBBN requires disk with at least 200GB
    if (isTooSmall($_)) {
      $message = "$e[91mInsufficient size$e[0m"
    }

    $messages.Add($diskNumber, $message)
  }

  return $messages
}

function isTooSmall ($item) {
  return ($item.Size / 1GB) -lt $minimumDiskSize
}

function convertPathToWsl ($windowsPath) {
  $prefix = ""
  $path = ""

  if ($windowsPath -match '(?<driveLetter>.):\\(?<path>.+)') {
    $driveLetter = $Matches.driveLetter.ToLower()
    $prefix = "/mnt/$driveLetter/"
    $path = $Matches.path.Replace("\", "/")
  } elseif ($windowsPath -match '\\\\wsl.localhost\\PSBBN(?<path>.+)') {
    # handle the case where the user picks a wsl filesystem location
    $path = $Matches.path.Replace("\", "/")
  }

  return "$prefix$path"
}

restartAsAdminIfNeeded

# necessary to ensure the CWD is where the script is located, in case the script was restarted as admin
cd $PSScriptRoot

if ($LogsEnabled) {
  try { $null = Start-Transcript -Path ".\psbbn-windows-launcher.log" }  catch {}
  try {
    main
  } finally {
    try { $null = Stop-Transcript } catch {}
  }
} else {
  main
}
