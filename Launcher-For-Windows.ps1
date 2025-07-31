#Requires -Version 5.1
#Requires -RunAsAdministrator

# User must open its execution policy by running
# `Set-ExecutionPolicy -ExecutionPolicy Unrestricted`

function main {
  printTitle
  Write-Host "Prepare Windows to run the PSBBN scripts."
  Write-Host "Make sure the drive you want to use is connected and press a key to continue.`n" -ForegroundColor Green
  $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

  # check if wsl exists
  if (-Not (Get-Command wsl -errorAction SilentlyContinue)) {
    exitScript("WSL is not available on this computer.")
  }

  # check if mandatory windows features are enabled
  Write-Host "Checking if the mandatory features are enabled..." -NoNewline
  $hyperVFeature = Get-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform
  $virtualMachineFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
  printOK

  # enable Hyper V as needed
  enableFeature($hyperVFeature)

  # enable Virtual Maching Platform as needed
  enableFeature($virtualMachineFeature)
  
  # detect if virtualization is enabled in BIOS
  detectVirtualization
  
  # fetch the latest wsl update
  Write-Host "Check the latest WSL updates...`t`t`t" -NoNewline
  $wslUpdate = wsl --update --web-download
  printOK

  # check if a wsl distro is installed already
  $isWslInstalled = wsl --list --verbose | Select-String -SimpleMatch -Quiet '* Debian'
  if (-Not $isWslInstalled) {
    Write-Host "`nThe WSL installer will prompt you to set a username and a password. After this is done, you can type 'exit' to return to this script.`n" -ForegroundColor Yellow
    Write-Host "------- Linux magic starts ---------"
    wsl --install --distribution Debian
    Write-Host "------- Linux magic finishes ---------`n"
  }

  # list available disks and pick the one to be mounted
  Write-Host "`nList of available disks:"
  $diskList = Get-Disk 
  $diskList | Format-Table -Property Number, FriendlyName, Size
  $selectedDisk = "\\.\PHYSICALDRIVE" + (handleDiskSelection($diskList.Count))
  Write-Host "`nMounting $($selectedDisk) on wsl...`t`t" -NoNewline
  try {
    # will try to mount the disk
    # if the disk is already mounted, it does NOT trigger the catch block
    $mountOutput = wsl --mount $selectedDisk --bare
  } catch {
    printNG
    # display any other error and stop the script
    Write-Host $mountOutput
    Exit
  }
  printOK
  Write-Host
  
  # install git if it is missing
  wsl -- type git `&`> /dev/null `|`| `(sudo apt update `&`& sudo apt install git`)
  
  # clone the PSBBN repo into ~, or pull if it's already there
  wsl --cd "~" -- [ -d PSBBN-Definitive-English-Patch/.git ] `&`& `(cd PSBBN-Definitive-English-Patch/ `&`& git pull --ff-only`) `|`| git clone https://github.com/CosmicScale/PSBBN-Definitive-English-Patch.git
  
  # give the user the opportunity to put games/homebrew in the PSBBN folder
  Write-Host "`nOpening the PSBBN folder in the Explorer...`t" -NoNewline
  $user = wsl -- whoami
  explorer \\wsl`$\Debian\home\$user\PSBBN-Definitive-English-Patch
  printOK
  Write-Host "
  Before you continue, you can put your games and homebrews in the PSBBN folder.
  You can refer to the PSBBN Readme to know more about how and where to put your games and homebrews.
  https://github.com/CosmicScale/PSBBN-Definitive-English-Patch
" -ForegroundColor Yellow
  Write-Host "Once you are done, press ENTER to continue." -ForegroundColor Green
  while ($keypress.VirtualKeyCode -ne 13) {
    $keypress = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
  }
  clear
  
  # run PSBBN regular steps
  wsl --cd "~/PSBBN-Definitive-English-Patch" -- ./PSBBN-Definitive-Patch.sh
  
  # clear the terminal to get rid of the wsl-run scripts
  clear
  printTitle
  
  # unmount the disk before exiting
  Write-Host "Unmounting $($selectedDisk)...`t`t" -NoNewline
  try {
    # try to unmount the disk
    # like --mount, if the disk is already unmounted, it does NOT trigger the catch block
    $unmountOutput = wsl --unmount $selectedDisk
  } catch {
    Write-Host $mountOutput
    Exit
  }
  printOK
  
  Write-Host "Have fun exploring PSBBN!" -ForegroundColor Green
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

function exitScript ($message) {
  Write-Host $message -ForegroundColor Yellow
  Write-Host "Press any key to continue...";
  $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
  Exit
}

function enableFeature ($feature) {
  if (($null -ne $feature.FeatureName) -and ($feature.State -ne "Enabled")) {
    Write-Host "  └ Enabling" $feature.DisplayName "..." -NoNewline;
    $enabled = Enable-WindowsOptionalFeature -Online -FeatureName $feature.FeatureName -All
    printOK
    if ($enabled.RestartNeeded) {
      exitScript("Restart is required. You can then launch this script again to resume.")
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
                                                                           
                          Launcher for Windows                             
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

main
