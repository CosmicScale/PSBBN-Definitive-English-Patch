#Requires -Version 5.1

# User must open its execution policy by running
# `Set-ExecutionPolicy -ExecutionPolicy Unrestricted`
# and choose "Yes to All"

param(
  [Alias("logs", "log")]
  [switch]$LogsEnabled = $false
)

# the version of this script itself, useful to know if a user is running the latest version
$version = "1.0.9"

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

# --- DO NOT MODIFY THE VARIABLES BELOW ---

# in case $gitBranch no longer exists on the remote, use this as fallback
# DO NOT change this unless the repo has deleted the main branch or is using another branch as release
$fallbackGitBranch = "main"

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

  Clear-Host
  printTitle
  Write-Host "Prepare Windows to run the PSBBN scripts.`n"

  # check if mandatory windows features are enabled
  Write-Host "Checking if the mandatory features are enabled..."
  
  # The underlying command differs between PowerShell for Windows and PWSH (PowerShell 7)
  checkAndInstallFeature("Microsoft-Windows-Subsystem-Linux")
  checkAndInstallFeature("HypervisorPlatform")
  checkAndInstallFeature("VirtualMachinePlatform")
  
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
      $keyPressed = $keyPressed.ToLowerInvariant()
    } while ($keyPressed -ne 'restart')

    if ($keyPressed -eq 'restart') {
      Restart-Computer
    }
    Exit
  }

  # check if wsl exists
  if (-Not (Get-Command wsl -errorAction SilentlyContinue)) {
    Write-Host "WSL is not available on this computer." -ForegroundColor Yellow
    Exit
  }
  
  # fetch the latest wsl update
  Write-Host "Check the latest WSL updates...`t`t`t" -NoNewline
  $null = wsl --update --web-download
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
  Write-Host "`nMounting $deviceName on wsl...`t`t" -NoNewline
  Set-Disk $global:selectedDisk -isOffline $true
  $mountOut = wsl -d $wslLabel --mount $deviceName --bare
  handleMountOutput($mountOut)
  
  # give the user the opportunity to put games/homebrew in the PSBBN folder
  $path = getTargetFolder
  Clear-Host
  
  # run PSBBN regular steps
  wsl -d $wslLabel --cd "~/PSBBN-Definitive-English-Patch" -- `
    ./PSBBN-Definitive-Patch.sh -wsl $global:diskList[$selectedDisk].SerialNumber $path

  # clear the terminal to get rid of the wsl-run scripts
  Clear-Host
  printTitle

  # unmount the disk before exiting
  Write-Host "Unmounting $deviceName...`t`t" -NoNewline
  $unmountOut = wsl -d $wslLabel --unmount $deviceName
  Set-Disk $global:selectedDisk -isOffline $false
  handleMountOutput($unmountOut)
  
  # ensures wsl doesnt run out of resources if this script is ran repeatedly
  wsl --shutdown

  Write-Host "`nHave fun exploring PSBBN!`n" -ForegroundColor Green
}

# print colored `[ OK ]`
function printOK {
  Write-Host "    `t`t[ " -NoNewline
  Write-Host "OK" -NoNewline -ForegroundColor Green
  Write-Host " ]"
}

# print colored `[ NG ]`
function printNG {
  Write-Host "`t`t[ " -NoNewline
  Write-Host "NG" -NoNewline -ForegroundColor Red
  Write-Host " ]"
}

# print colored `[ Restart required ]`
function printRestartRequired {
  Write-Host "    `t`t[ " -NoNewline
  Write-Host "Restart required" -NoNewline -ForegroundColor Yellow
  Write-Host " ]"
}

function checkAndInstallFeature ($feature) {
  $featureStatus = $null

  # get the status of the feature, this varies between PS5 and PS7
  if ($PSVersionTable.PSVersion.Major -eq 5) {
    $featureStatus = Get-WindowsOptionalFeature -Online -FeatureName $feature
  }
  elseif ($PSVersionTable.PSVersion.Major -ge 7) {
    try {
      # try to use windows powershell anyway for this task
      Import-Module Dism -UseWindowsPowerShell -ErrorAction Stop -WarningAction SilentlyContinue
      $featureStatus = Get-WindowsOptionalFeature -Online -FeatureName $feature
    } catch {
      # fallback to using Get-CimInstance
      $stateMap = @{ 1='Enabled'; 2='Disabled'; 3='Absent'; 4='Unknown' }
      $featureInfo = Get-CimInstance Win32_OptionalFeature -Filter "Name='$feature'"
      $featureStatus = [pscustomobject]@{
        FeatureName = $featureInfo.Name
        State = $stateMap[[int]$featureInfo.InstallState]
        DisplayName = $featureInfo.Caption
      }
    }
  }
  
  # enable the feature if possible
  $enabled = $null
  if ($null -eq $featureStatus) {
    Write-Host "  └" $feature 'unable to determine status.' -NoNewline;
    printNG
    return
  } elseif ($featureStatus.State -eq "Enabled") {
    Write-Host "  └" $featureStatus.DisplayName 'already enabled.' -NoNewline
    printOK
    return
  } else {
    if ($PSVersionTable.PSVersion.Major -eq 5) {
      Write-Host "  └ Enabling" $featureStatus.DisplayName "..." -NoNewline;
      $enabled = Enable-WindowsOptionalFeature -Online -FeatureName $featureStatus.FeatureName -All -NoRestart -WarningAction:SilentlyContinue
    } elseif ($PSVersionTable.PSVersion.Major -ge 7) {
      try {
        # try to use windows powershell anyway for this task
        Import-Module Dism -UseWindowsPowerShell -ErrorAction Stop -WarningAction SilentlyContinue
        $enabled = Enable-WindowsOptionalFeature -Online -FeatureName $featureStatus.FeatureName -All -NoRestart -WarningAction:SilentlyContinue
      } catch {
        # fallback to using dism.exe
        $featureName = $featureStatus.FeatureName
        $dismArgs = @(
          '/Online'
          '/NoRestart'
          '/Enable-Feature'
          "/FeatureName:$featureName"
          '/All'
        )

        # capture dism output and exit code
        $dismOut = & Dism.exe @dismArgs 2>&1
        $exit = $LASTEXITCODE

        # check for success exit code
        if ($exit -eq 0) {
          # janky string parsing to check if restart required under exit code 0
          $restartNeeded = [bool](
            $dismOut | Select-String -Quiet '(?i)\bRestart (Required|Needed)\s*:\s*Yes\b|restart.+required'
          )

          $enabled = [pscustomobject]@{
            Path = ''
            Online = $true
            RestartRequired = $restartNeeded
          }
        # microsoft standard exit codes for "success, restart required"
        # source: https://learn.microsoft.com/en-us/windows/win32/debug/system-error-codes--1700-3999-
        } elseif ($exit -eq 0xbc2 -or $exit -eq 0xbc3) {
          $enabled = [pscustomobject]@{
            Path = ''
            Online = $true
            RestartRequired = $true
          }
        }
      }
    }
  }

  if ($null -eq $enabled) {
    printNG
  } elseif ($enabled.RestartNeeded) {
    $global:IsRestartRequired = $true
    printRestartRequired
  } else {
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
                                        Updated by johnkiddjr

"
}

# display the available disks and prompt user for choice
function diskPicker {
  # store the current cursor position to help clear the console upon refreshing the list of disks
  $lineStart = $Host.UI.RawUI.CursorPosition.Y

  # list available disks and pick the one to be mounted
  Write-Host "`nList of available disks:"
  $global:diskList = Get-Disk | Sort-Object -Property Number
  $disksWithOplVolume = detectOplVolume($global:diskList)
  $global:diskList | Format-Table -Property `
    Number, `
    @{Label="Name";Expression={$_.FriendlyName}}, `
    @{Label="Size";Expression={("{0:N2}" -f ($_.Size / 1GB)).ToString() + " GB"}}, `
    SerialNumber, `
    @{Label="";Expression={if ($disksWithOplVolume -contains $_.Number) { "<- PSBBN detected" } else { "   " }}}

  # generate a list of disk number to validate user input
  $availableNumbers = $global:diskList | Foreach-Object {$_.Number}

  $selectedDisk = handleDiskSelection($availableNumbers)

  if ($selectedDisk -eq "r") {
    clearLines($Host.UI.RawUI.CursorPosition.Y - $lineStart)
    diskPicker
  } else {
    $global:selectedDisk = $selectedDisk
  }
}

# handles the input logic of the diskpicker
# this function calls itself recursively as long an invalid input is provided
function handleDiskSelection ($availableNumbers) {
  $prompt = 'Enter an available number ({0}) or (r)efresh and press Enter' -f ((
    $availableNumbers -split '\r?\n' | Where-Object { $_ } ) -join ', ')
  
  $diskInput = Read-Host $prompt
  $selectedDisk = -1
  $diskInput = $diskInput.ToLowerInvariant().Trim()
  # parse to int, fail silently since default is already -1
  if ($diskInput.StartsWith("r") -or ([int]::TryParse($diskInput, [ref]$selectedDisk) -and $availableNumbers -contains $selectedDisk)) {
    # erase the "invalid output" message
    Write-Host $(" " * 45) -NoNewline
    return $selectedDisk
  } else {
    Write-Host " - Invalid input, try again.`r" -NoNewline -ForegroundColor Red
    return handleDiskSelection($maxDiskNumber)
  }
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
    Virtualization is not enabled. It is mandatory to run PSBBN scripts.
    If you have an AMD CPU, enable SVM in your BIOS.
    If you have an Intel CPU, enable VT-x in your BIOS.
    Check the manual of your motherboard if you have troubles finding this setting.
"
    Exit
  } else {
    printOK
  }
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
  exit
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
      $keyPressed = $keyPressed.ToLowerInvariant()
    } while (-Not ($keyPressed.StartsWith('y')) -and -Not ($keyPressed.StartsWith('n')))

    # if path is already set, and user wants to reuse it, ask if they want to open it
    if ($keyPressed.StartsWith('y')) {
      $keyPressed = ''
      do {
        clearLines(1)
        $keyPressed = Read-Host "Would you like to open that directory now? (y/n)"
        $keyPressed = $keyPressed.ToLowerInvariant()
      } while (-Not ($keyPressed.StartsWith('y')) -and -Not ($keyPressed.StartsWith('n')))

      # open the explorer window with target directory
      if ($keyPressed.StartsWith('y')) {
        explorer $initialDirectory
      }

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

# walks through each disk -> partition -> volume to find which disks have
# volumes named $oplVolumeName, and return an array of disk numbers
function detectOplVolume ($diskList) {
  $disksWithOplVolume = @()
  $diskList | ForEach-Object {
    $diskNumber = $_.Number
    Get-Partition -disknumber $diskNumber -errorAction SilentlyContinue | ForEach-Object {
      Get-Volume -partition $_ | ForEach-Object {
        $_.FileSystemLabel.GetType()
        if ($_.FileSystemLabel -eq $oplVolumeName) {
          $disksWithOplVolume += $diskNumber
        }
      }
    } | Out-Null
  }
  return $disksWithOplVolume
}

function convertPathToWsl ($windowsPath) {
  $driveLetter = $windowsPath.Split(":")[0].ToLowerInvariant()
  $path = $windowsPath.Split(":")[1].Replace("\", "/")
  return "/mnt/$driveLetter$path"
}

restartAsAdminIfNeeded

# necessary to ensure the CWD is where the script is located, in case the script was restarted as admin
Set-Location $PSScriptRoot

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
