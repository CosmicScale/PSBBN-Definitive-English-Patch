#Requires -Version 5.1

# User must open its execution policy by running
# `Set-ExecutionPolicy -ExecutionPolicy Unrestricted`
# and choose "Yes to All"

param(
  [Alias("logs", "log")]
  [switch]$LogsEnabled = $false
)

# the version of this script itself, useful to know if a user is running the latest version
$version = "1.0.1"

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
  clear
  printTitle
  Write-Host "Prepare Windows to run the PSBBN scripts.`n"

  # check if mandatory windows features are enabled
  Write-Host "Checking if the mandatory features are enabled..." -NoNewline
  $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
  $hyperVFeature = Get-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform
  $virtualMachineFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
  printOK

  # enable WSL as needed
  enableFeature($wslFeature)

  # enable Hyper V as needed
  enableFeature($hyperVFeature)

  # enable Virtual Maching Platform as needed
  enableFeature($virtualMachineFeature)
  
  # detect if virtualization is enabled in BIOS
  detectVirtualization
  
  if ($isRestartRequired) {
    Write-Host "
    You need to restart your computer in order for some newly installed features to work properly.
    Once you have restarted, just run this script again.
" -ForegroundColor Yellow
    Restart-Computer -Confirm
    Exit
  }

  # check if wsl exists
  if (-Not (Get-Command wsl -errorAction SilentlyContinue)) {
    Write-Host "WSL is not available on this computer." -ForegroundColor Yellow
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
    Write-Host "/!\ The username must start with a lowercase letter, and only contain letters and numbers." -ForegroundColor Red
    Write-Host "/!\ A password must be set." -ForegroundColor Red
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
  Write-Host "`nMounting \\.\PHYSICALDRIVE$selectedDisk on wsl...`t`t" -NoNewline
  $mountOut = wsl -d $wslLabel --mount "\\.\PHYSICALDRIVE$selectedDisk" --bare
  handleMountOutput($mountOut)
  
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
  Write-Host "Unmounting \\.\PHYSICALDRIVE$selectedDisk...`t`t" -NoNewline
  $mountOut = wsl -d $wslLabel --unmount $selectedDisk
  handleMountOutput($mountOut)
  
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

# takes a feature as parameter and enable it if needed
function enableFeature ($feature) {
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
                     ______  _________________ _   _                       
                     | ___ \/  ___| ___ \ ___ \ \ | |                      
                     | |_/ /\ ``--.| |_/ / |_/ /  \| |                      
                     |  __/  ``--. \ ___ \ ___ \ . `` |                      
                     | |    /\__/ / |_/ / |_/ / |\  |                      
                     \_|    \____/\____/\____/\_| \_/                      
       ___  ____ ____ _ _  _ _ ___ _ _  _ ____    ___  ____ ___ ____ _  _  
       |  \ |___ |___ | |\ | |  |  | |  | |___    |__] |__|  |  |    |__|  
       |__/ |___ |    | | \| |  |  |  \/  |___    |    |  |  |  |___ |  |  
                                                                           
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
  $global:diskList = Get-Disk
  $disksWithOplVolume = detectOplVolume($global:diskList)
  $global:diskList | Sort -Property Number | Format-Table -Property `
    Number, `
    @{Label="Name";Expression={$_.FriendlyName}}, `
    @{Label="Size";Expression={("{0:N2}" -f ($_.Size / 1GB)).ToString() + " GB"}}, `
    @{Label="";Expression={if ($disksWithOplVolume -contains $_.Number) { "<- PSBBN install detected on this disk" } else { "   " }}}

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
  Write-Host "Select a disk to use by typing its number or press `"r`" to refresh the list: " -NoNewline
  $keyPressed = $Host.UI.RawUI.ReadKey("IncludeKeyDown")
  try {
    $selectedDisk = [int][string]$keyPressed.Character
  } catch {
    $selectedDisk = -1
  }

  if ($keyPressed.Character -eq "r") {
    Write-Host $(" " * 45) -NoNewline
    return "r"
  }

  if ((-Not ($availableNumbers -contains $selectedDisk)) -or ($keyPressed.VirtualKeyCode -eq 13)) {
    Write-Host " - Invalid input, try again.`r" -NoNewline -ForegroundColor Red
    $selectedDisk = handleDiskSelection($maxDiskNumber)
  } else {
    # erase the "invalid output" message
    Write-Host $(" " * 45) -NoNewline
  }
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
  Write-Host "`nNext you will be asked to pick a folder where to put all your games, movies, photos, and music." -ForegroundColor Yellow

  pause

  Add-Type -AssemblyName System.Windows.Forms
  $folderselection = New-Object System.Windows.Forms.OpenFileDialog -Property @{
    InitialDirectory = [Environment]::GetFolderPath('Desktop')
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
  $driveLetter = $pickedPath.Split(":\")[0].ToLower()
  $path = $pickedPath.Split(":\")[1].Replace("\", "/")

  # create default folders if missing
  $defaultFolders.ForEach({
    if (-Not (Test-Path -Path "$pickedPath\$PSItem")) {
      New-Item -Path $pickedPath -Name $PSItem -ItemType Directory | Out-Null
    }
  })

  Write-Host "`nThe following path was chosen: $pickedPath" -ForegroundColor Green
  Write-Host "
Before you continue, you can fill this folder with your games and other media:
    • put PS2 games in /DVD or /CD (.iso or .zso files)
    • put PS1 games in /POPS (must be .vcd files)
    • put homebrew in /APPS (.elf or SAS-compliant .psu files)
    • put music in /music (.mp3, .m4a, .flac, or .ogg files)

You can refer to the PSBBN Readme to know more.
https://github.com/CosmicScale/PSBBN-Definitive-English-Patch
" -ForegroundColor Yellow

  pause

  return "/mnt/$driveLetter/$path"
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
    Get-Partition -disknumber $diskNumber | ForEach-Object {
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
