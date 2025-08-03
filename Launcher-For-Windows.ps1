#Requires -Version 5.1
#Requires -RunAsAdministrator

# User must open its execution policy by running
# `Set-ExecutionPolicy -ExecutionPolicy Unrestricted`
# and choose "Yes to All"

# the version of this script itself, useful to know if a user is running the latest version
$version = "0.1.6"

# the label of the WSL machine. Still based on Debian, but this label makes sure we get the 
# machine created by this script and not some pre-existing Debian the user had.
$wslLabel = "PSBBN"

# this make wsl commands output utf8 instead of utf16_LE
$env:WSL_UTF8 = 1

# flag potentially raised when enabling features, signaling a reboot is necessary to finish the install
$global:IsRestartRequired = $false

function main {
  printTitle
  Write-Host "Prepare Windows to run the PSBBN scripts."
  Write-Host "Make sure the drive you want to use is connected and press a key to continue.`n" -ForegroundColor Green
  $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

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
  
  # clone the PSBBN repo into ~, or pull if it's already there
  wsl -d $wslLabel --cd "~" -- [ -d PSBBN-Definitive-English-Patch/.git ] `&`& `(cd PSBBN-Definitive-English-Patch/ `&`& git pull --ff-only`) `|`| git clone -b test --single-branch https://github.com/CosmicScale/PSBBN-Definitive-English-Patch.git
  
  if (-Not ($isWslInstalled)) {
    Write-Host "------- Linux magic finishes ---------`n"
  }
  
  # list available disks and pick the one to be mounted
  Write-Host "`nList of available disks:"
  $diskList = Get-Disk 
  $diskList | Sort -Property Number | Format-Table -Property Number, FriendlyName, Size
  $selectedDisk = "\\.\PHYSICALDRIVE" + (handleDiskSelection($diskList.Count - 1))
  
  # mount the disk
  Write-Host "`nMounting $($selectedDisk) on wsl...`t`t" -NoNewline
  $mountOut = wsl -d $wslLabel --mount $selectedDisk --bare
  handleMountOutput($mountOut)
  Write-Host
  
  # give the user the opportunity to put games/homebrew in the PSBBN folder
  Write-Host "`nOpening the PSBBN folder in the Explorer...`t" -NoNewline
  $user = wsl -d $wslLabel -- whoami
  explorer "\\wsl`$\$wslLabel\home\$user\PSBBN-Definitive-English-Patch"
  printOK
  Write-Host "
  Before you continue, you can put your games and homebrews in the PSBBN folder.
  If the explorer doesnt open automatically, paste \\wsl`$\$wslLabel\home\$user\PSBBN-Definitive-English-Patch in the adress bar.
  You can refer to the PSBBN Readme to know more about how and where to put your games and homebrews.
  https://github.com/CosmicScale/PSBBN-Definitive-English-Patch
" -ForegroundColor Yellow
  Write-Host "Once you are done, press ENTER to continue." -ForegroundColor Green
  while ($keypress.VirtualKeyCode -ne 13) {
    $keypress = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
  }
  clear
  
  # run PSBBN regular steps
  wsl -d $wslLabel --cd "~/PSBBN-Definitive-English-Patch" -- ./PSBBN-Definitive-Patch.sh
  
  # clear the terminal to get rid of the wsl-run scripts
  clear
  printTitle
  
  # unmount the disk before exiting
  Write-Host "Unmounting $($selectedDisk)...`t`t" -NoNewline
  $mountOut = wsl -d $wslLabel --unmount $selectedDisk
  handleMountOutput($mountOut)
  
  Write-Host "`nHave fun exploring PSBBN!`n" -ForegroundColor Green
}

function printOK {
  Write-Host "    `t`t[ " -NoNewline
  Write-Host "OK" -NoNewline -ForegroundColor Green
  Write-Host " ]"
}

function printNG {
  Write-Host "`t`t[ " -NoNewline
  Write-Host "NG" -NoNewline -ForegroundColor Red
  Write-Host " ]"
}

function printRestartRequired {
  Write-Host "    `t`t[ " -NoNewline
  Write-Host "Restart required" -NoNewline -ForegroundColor Yellow
  Write-Host " ]"
}

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

function handleDiskSelection ($maxDiskNumber) {
  Write-Host "Select a disk to use by typing its number (between 0 and $($maxDiskNumber)): " -NoNewline
  $keyPressed = $Host.UI.RawUI.ReadKey("IncludeKeyDown")
  try {
    $selectedDisk = [int][string]$keyPressed.Character
  } catch {
      $selectedDisk = -1
  }
  if (($selectedDisk -lt 0) -or ($selectedDisk -gt $maxDiskNumber)) {
    Write-Host " - Invalid input, try again."
    handleDiskSelection($maxDiskNumber)
  }
  Write-Host
  return $selectedDisk
}

function detectVirtualization {
  Write-Host "Checking if virtualization is enabled in BIOS..." -NoNewline
  
  $propertyName = "HyperVRequirementVirtualizationFirmwareEnabled"
  $property = Get-ComputerInfo -property $propertyName
  
  # the property is null if the feature is enabled, false otherwise
  if ($property.$propertyName -eq $false) {
    printNG
    Write-Host @"
    
    Virtualization is not enabled. It is mandatory to run PSBBN scripts.
    If you have an AMD CPU, enable SVM in your BIOS.
    If you have an Intel CPU, enable VT-x in your BIOS.
    Check the manual of your motherboard if you have troubles finding this setting.
"@
    Exit
  } else {
    printOK
  }
}

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

main
