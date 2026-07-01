<#
.SYNOPSIS
    Scripts to build a trimmed-down Windows 11 image.

.DESCRIPTION
    This is a script created to automate the build of a streamlined Windows 11 image, similar to tiny10.
    My main goal is to use only Microsoft utilities like DISM, and no utilities from external sources.
    The only executable included is oscdimg.exe, which is provided in the Windows ADK and it is used to create bootable ISO images.

.PARAMETER ISO
    Drive letter given to the mounted iso (eg: E)

.PARAMETER SCRATCH
    Drive letter of the desired scratch disk (eg: D)

.EXAMPLE
    .\tiny11maker.ps1 E D
    .\tiny11maker.ps1 -ISO E -SCRATCH D
    .\tiny11maker.ps1 -SCRATCH D -ISO E
    .\tiny11maker.ps1

    *If you ordinal parameters the first one must be the mounted iso. The second is the scratch drive.
    prefer the use of full named parameter (eg: "-ISO") as you can put in the order you want.

.NOTES
    Auteur: ntdevlabs
    Date: 09-07-25
#>

#---------[ Parameters ]---------#
param (
    [ValidatePattern('^[a-zA-Z]$')][string]$ISO,
    [ValidatePattern('^[a-zA-Z]$')][string]$SCRATCH,
    [int]$Index = 1,
    [bool]$BypassReqs = $true,
    [bool]$ESDCompression = $false,
    [bool]$RemoveEdge = $false
)

if (-not $SCRATCH) {
    $ScratchDisk = $PSScriptRoot -replace '[\\]+$', ''
} else {
    $ScratchDisk = $SCRATCH + ":"
}

$adminSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
$adminGroup = $adminSID.Translate([System.Security.Principal.NTAccount])

#---------[ Functions ]---------#
function Set-RegistryValue {
    param (
        [string]$path,
        [string]$name,
        [string]$type,
        [string]$value
    )
    try {
        & 'reg' 'add' $path '/v' $name '/t' $type '/d' $value '/f' | Out-Null
        Write-Output "Set registry value: $path\$name"
    } catch {
        Write-Output "Error setting registry value: $_"
    }
}

function Remove-RegistryValue {
    param (
		[string]$path
	)
	try {
		& 'reg' 'delete' $path '/f' | Out-Null
		Write-Output "Removed registry value: $path"
	} catch {
		Write-Output "Error removing registry value: $_"
	}
}

#---------[ Execution ]---------#

# Ensure required commands are available
$UserProvidedAutounattend = Test-Path -Path "$PSScriptRoot\autounattend.xml"
if (-not $UserProvidedAutounattend) {
    Invoke-RestMethod "https://raw.githubusercontent.com/ntdevlabs/tiny11builder/refs/heads/main/autounattend.xml" -OutFile "$PSScriptRoot\autounattend.xml"
}

# Start the transcript and prepare the window
Start-Transcript -Path "$PSScriptRoot\tiny11_$(get-date -f yyyyMMdd_HHmms).log"

Write-Output "Welcome to the tiny11 image creator! Release: 09-07-25"

$hostArchitecture = $Env:PROCESSOR_ARCHITECTURE
New-Item -ItemType Directory -Force -Path "$ScratchDisk\tiny11\sources" | Out-Null
if (-not $ISO) {
    Write-Error "ISO drive letter must be specified via -ISO parameter."
    exit 1
}
$DriveLetter = $ISO + ":"
Write-Output "Drive letter set to $DriveLetter"

if ((Test-Path "$DriveLetter\sources\boot.wim") -eq $false -or (Test-Path "$DriveLetter\sources\install.wim") -eq $false) {
    if ((Test-Path "$DriveLetter\sources\install.esd") -eq $true) {
        Write-Output "Found install.esd, converting to install.wim..."
        Get-WindowsImage -ImagePath $DriveLetter\sources\install.esd
        Write-Output ' '
        Write-Output 'Converting install.esd to install.wim. This may take a while...'
        Export-WindowsImage -SourceImagePath $DriveLetter\sources\install.esd -SourceIndex $Index -DestinationImagePath $ScratchDisk\tiny11\sources\install.wim -Compressiontype Maximum -CheckIntegrity
    } else {
        Write-Output "Can't find Windows OS Installation files in the specified Drive Letter.."
        Write-Output "Please enter the correct DVD Drive Letter.."
        exit
    }
}

Write-Output "Copying Windows image..."
Copy-Item -Path "$DriveLetter\*" -Destination "$ScratchDisk\tiny11" -Recurse -Force | Out-Null
if (Test-Path "$ScratchDisk\tiny11\sources\install.esd") {
    Set-ItemProperty -Path "$ScratchDisk\tiny11\sources\install.esd" -Name IsReadOnly -Value $false
    Remove-Item "$ScratchDisk\tiny11\sources\install.esd"
}
Write-Output "Copy complete!"
Start-Sleep -Seconds 2
Write-Output "Getting image information:"
$ImagesIndex = (Get-WindowsImage -ImagePath $ScratchDisk\tiny11\sources\install.wim).ImageIndex
if ($ImagesIndex -notcontains $Index) {
    Write-Error "Image index $Index not found in install.wim."
    exit 1
}
Write-Output "Mounting Windows image. This may take a while."
$wimFilePath = "$ScratchDisk\tiny11\sources\install.wim"
& takeown "/F" $wimFilePath
& icacls $wimFilePath "/grant" "$($adminGroup.Value):(F)"
try {
    Set-ItemProperty -Path $wimFilePath -Name IsReadOnly -Value $false -ErrorAction Stop
} catch {
    # This block will catch the error and suppress it.
	Write-Error "$wimFilePath not found"
}
New-Item -ItemType Directory -Force -Path "$ScratchDisk\scratchdir" > $null
Mount-WindowsImage -ImagePath $ScratchDisk\tiny11\sources\install.wim -Index $index -Path $ScratchDisk\scratchdir

$imageIntl = & dism /English /Get-Intl "/Image:$($ScratchDisk)\scratchdir"
$languageLine = $imageIntl -split '\n' | Where-Object { $_ -match 'Default system UI language : ([a-zA-Z]{2}-[a-zA-Z]{2})' }

if ($languageLine) {
    $languageCode = $Matches[1]
    Write-Output "Default system UI language code: $languageCode"
} else {
    Write-Output "Default system UI language code not found."
}

$imageInfo = & 'dism' '/English' '/Get-WimInfo' "/wimFile:$($ScratchDisk)\tiny11\sources\install.wim" "/index:$index"
$lines = $imageInfo -split '\r?\n'

foreach ($line in $lines) {
    if ($line -like '*Architecture : *') {
        $architecture = $line -replace 'Architecture : ',''
        # If the architecture is x64, replace it with amd64
        if ($architecture -eq 'x64') {
            $architecture = 'amd64'
        }
        Write-Output "Architecture: $architecture"
        break
    }
}

if (-not $architecture) {
    Write-Output "Architecture information not found."
}

Write-Output "Mounting complete! Performing removal of applications..."

$packages = & 'dism' '/English' "/image:$($ScratchDisk)\scratchdir" '/Get-ProvisionedAppxPackages' |
    ForEach-Object {
        if ($_ -match 'PackageName : (.*)') {
            $matches[1]
        }
    }

$packagePrefixes = 'AppUp.IntelManagementandSecurityStatus',
'Clipchamp.Clipchamp', 
'DolbyLaboratories.DolbyAccess',
'DolbyLaboratories.DolbyDigitalPlusDecoderOEM',
'Microsoft.BingNews',
'Microsoft.BingSearch',
'Microsoft.BingWeather',
'Microsoft.Copilot',
'Microsoft.Windows.CrossDevice',
'Microsoft.GamingApp',
'Microsoft.GetHelp',
'Microsoft.Getstarted',
'Microsoft.Microsoft3DViewer',
'Microsoft.MicrosoftOfficeHub',
'Microsoft.MicrosoftSolitaireCollection',
'Microsoft.MicrosoftStickyNotes',
'Microsoft.MixedReality.Portal',
'Microsoft.MSPaint',
'Microsoft.Office.OneNote',
'Microsoft.OfficePushNotificationUtility',
'Microsoft.OutlookForWindows',
'Microsoft.Paint',
'Microsoft.People',
'Microsoft.PowerAutomateDesktop',
'Microsoft.SkypeApp',
'Microsoft.StartExperiencesApp',
'Microsoft.Todos',
'Microsoft.Wallet',
'Microsoft.Windows.DevHome',
'Microsoft.Windows.Copilot',
'Microsoft.Windows.Teams',
'Microsoft.WindowsAlarms',
'Microsoft.WindowsCamera',
'microsoft.windowscommunicationsapps',
'Microsoft.WindowsFeedbackHub',
'Microsoft.WindowsMaps',
'Microsoft.WindowsSoundRecorder',
'Microsoft.WindowsTerminal',
'Microsoft.Xbox.TCUI',
'Microsoft.XboxApp',
'Microsoft.XboxGameOverlay',
'Microsoft.XboxGamingOverlay',
'Microsoft.XboxIdentityProvider',
'Microsoft.XboxSpeechToTextOverlay',
'Microsoft.YourPhone',
'Microsoft.ZuneMusic',
'Microsoft.ZuneVideo',
'MicrosoftCorporationII.MicrosoftFamily',
'MicrosoftCorporationII.QuickAssist',
'MSTeams',
'MicrosoftTeams', 
'Microsoft.WindowsTerminal',
'Microsoft.549981C3F5F10'

$packagesToRemove = $packages | Where-Object {
    $packageName = $_
    $packagePrefixes -contains ($packagePrefixes | Where-Object { $packageName -like "*$_*" })
}
foreach ($package in $packagesToRemove) {
    & 'dism' '/English' "/image:$($ScratchDisk)\scratchdir" '/Remove-ProvisionedAppxPackage' "/PackageName:$package"
}

if ($RemoveEdge) {
    Write-Output "Removing Edge:"
    Remove-Item -Path "$ScratchDisk\scratchdir\Program Files (x86)\Microsoft\Edge" -Recurse -Force | Out-Null
    Remove-Item -Path "$ScratchDisk\scratchdir\Program Files (x86)\Microsoft\EdgeUpdate" -Recurse -Force | Out-Null
    Remove-Item -Path "$ScratchDisk\scratchdir\Program Files (x86)\Microsoft\EdgeCore" -Recurse -Force | Out-Null
    & 'takeown' '/f' "$ScratchDisk\scratchdir\Windows\System32\Microsoft-Edge-Webview" '/r' | Out-Null
    & 'icacls' "$ScratchDisk\scratchdir\Windows\System32\Microsoft-Edge-Webview" '/grant' "$($adminGroup.Value):(F)" '/T' '/C' | Out-Null
    Remove-Item -Path "$ScratchDisk\scratchdir\Windows\System32\Microsoft-Edge-Webview" -Recurse -Force | Out-Null
}
Write-Output "Removing OneDrive:"
& 'takeown' '/f' "$ScratchDisk\scratchdir\Windows\System32\OneDriveSetup.exe" | Out-Null
& 'icacls' "$ScratchDisk\scratchdir\Windows\System32\OneDriveSetup.exe" '/grant' "$($adminGroup.Value):(F)" '/T' '/C' | Out-Null
Remove-Item -Path "$ScratchDisk\scratchdir\Windows\System32\OneDriveSetup.exe" -Force | Out-Null
Write-Output "Removal complete!"
Write-Output "Loading registry..."
reg load HKLM\zCOMPONENTS $ScratchDisk\scratchdir\Windows\System32\config\COMPONENTS | Out-Null
reg load HKLM\zDEFAULT $ScratchDisk\scratchdir\Windows\System32\config\default | Out-Null
reg load HKLM\zNTUSER $ScratchDisk\scratchdir\Users\Default\ntuser.dat | Out-Null
reg load HKLM\zSOFTWARE $ScratchDisk\scratchdir\Windows\System32\config\SOFTWARE | Out-Null
reg load HKLM\zSYSTEM $ScratchDisk\scratchdir\Windows\System32\config\SYSTEM | Out-Null
if ($BypassReqs) {
    Write-Output "Bypassing system requirements(on the system image):"
    Set-RegistryValue 'HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache' 'SV1' 'REG_DWORD' '0'
    Set-RegistryValue 'HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache' 'SV2' 'REG_DWORD' '0'
    Set-RegistryValue 'HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache' 'SV1' 'REG_DWORD' '0'
    Set-RegistryValue 'HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache' 'SV2' 'REG_DWORD' '0'
    Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassCPUCheck' 'REG_DWORD' '1'
    Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassRAMCheck' 'REG_DWORD' '1'
    Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassSecureBootCheck' 'REG_DWORD' '1'
    Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassStorageCheck' 'REG_DWORD' '1'
    Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassTPMCheck' 'REG_DWORD' '1'
    Set-RegistryValue 'HKLM\zSYSTEM\Setup\MoSetup' 'AllowUpgradesWithUnsupportedTPMOrCPU' 'REG_DWORD' '1'
}
Write-Output "Disabling Sponsored Apps:"
Set-RegistryValue 'HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'OemPreInstalledAppsEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'PreInstalledAppsEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SilentInstalledAppsEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'ContentDeliveryAllowed' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zSOFTWARE\Microsoft\PolicyManager\current\device\Start' 'ConfigureStartPins' 'REG_SZ' '{"pinnedList": [{}]}'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'FeatureManagementEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'PreInstalledAppsEverEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SoftLandingEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContentEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-310093Enabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338388Enabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338389Enabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338393Enabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-353694Enabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-353696Enabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SystemPaneSuggestionsEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\PushToInstall' 'DisablePushToInstall' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\MRT' 'DontOfferThroughWUAU' 'REG_DWORD' '1'
Remove-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Subscriptions'
Remove-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SuggestedApps'
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableConsumerAccountStateContent' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableCloudOptimizedContent' 'REG_DWORD' '1'
Write-Output "Enabling Local Accounts on OOBE:"
Set-RegistryValue 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\OOBE' 'BypassNRO' 'REG_DWORD' '1'
Copy-Item -Path "$PSScriptRoot\autounattend.xml" -Destination "$ScratchDisk\scratchdir\Windows\System32\Sysprep\autounattend.xml" -Force | Out-Null

Write-Output "Disabling Reserved Storage:"
Set-RegistryValue 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager' 'ShippedWithReserves' 'REG_DWORD' '0'
Write-Output "Disabling BitLocker Device Encryption"
Set-RegistryValue 'HKLM\zSYSTEM\ControlSet001\Control\BitLocker' 'PreventDeviceEncryption' 'REG_DWORD' '1'
Write-Output "Disabling Chat icon:"
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\Windows Chat' 'ChatIcon' 'REG_DWORD' '3'
Set-RegistryValue 'HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarMn' 'REG_DWORD' '0'
Write-Output "Removing Edge related registries"
Remove-RegistryValue "HKEY_LOCAL_MACHINE\zSOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge"
Remove-RegistryValue "HKEY_LOCAL_MACHINE\zSOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge Update"
Write-Output "Disabling OneDrive folder backup"
Set-RegistryValue "HKLM\zSOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" "REG_DWORD" "1"
Write-Output "Disabling Telemetry:"
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' 'HasAccepted' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Input\TIPC' 'Enabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\InputPersonalization\TrainedDataStore' 'HarvestContacts' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Software\Microsoft\Personalization\Settings' 'AcceptedPrivacyPolicy' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zSYSTEM\ControlSet001\Services\dmwappushservice' 'Start' 'REG_DWORD' '4'
## Prevents installation of DevHome and Outlook
Write-Output "Prevents installation of DevHome and Outlook:"
Set-RegistryValue 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate' 'workCompleted' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\OutlookUpdate' 'workCompleted' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\DevHomeUpdate' 'workCompleted' 'REG_DWORD' '1'
Remove-RegistryValue 'HKLM\zSOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate'
Remove-RegistryValue 'HKLM\zSOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate'
Write-Output "Disabling Copilot"
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Edge' 'HubsSidebarEnabled' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 'REG_DWORD' '1'
Write-Output "Prevents installation of Teams:"
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Teams' 'DisableInstallation' 'REG_DWORD' '1'
Write-Output "Prevent installation of New Outlook":
Set-RegistryValue 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\Windows Mail' 'PreventRun' 'REG_DWORD' '1'

Write-Host "Deleting scheduled task definition files..."
$tasksPath = "$ScratchDisk\scratchdir\Windows\System32\Tasks"

# Application Compatibility Appraiser
Remove-Item -Path "$tasksPath\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" -Force -ErrorAction SilentlyContinue

# Customer Experience Improvement Program (removes the entire folder and all tasks within it)
Remove-Item -Path "$tasksPath\Microsoft\Windows\Customer Experience Improvement Program" -Recurse -Force -ErrorAction SilentlyContinue

# Program Data Updater
Remove-Item -Path "$tasksPath\Microsoft\Windows\Application Experience\ProgramDataUpdater" -Force -ErrorAction SilentlyContinue

# Chkdsk Proxy
Remove-Item -Path "$tasksPath\Microsoft\Windows\Chkdsk\Proxy" -Force -ErrorAction SilentlyContinue

# Windows Error Reporting (QueueReporting)
Remove-Item -Path "$tasksPath\Microsoft\Windows\Windows Error Reporting\QueueReporting" -Force -ErrorAction SilentlyContinue
Write-Host "Task files have been deleted."
Write-Host "Unmounting Registry..."
reg unload HKLM\zCOMPONENTS | Out-Null
reg unload HKLM\zDEFAULT | Out-Null
reg unload HKLM\zNTUSER | Out-Null
reg unload HKLM\zSOFTWARE | Out-Null
reg unload HKLM\zSYSTEM | Out-Null
Write-Output "Cleaning up image..."
dism.exe /Image:$ScratchDisk\scratchdir /Cleanup-Image /StartComponentCleanup /ResetBase
Write-Output "Cleanup complete."
Write-Output ' '
Write-Output "Unmounting image..."
Dismount-WindowsImage -Path $ScratchDisk\scratchdir -Save
Write-Host "Exporting image..."
Dism.exe /Export-Image /SourceImageFile:"$ScratchDisk\tiny11\sources\install.wim" /SourceIndex:$index /DestinationImageFile:"$ScratchDisk\tiny11\sources\install2.wim" /Compress:recovery
Remove-Item -Path "$ScratchDisk\tiny11\sources\install.wim" -Force | Out-Null
Rename-Item -Path "$ScratchDisk\tiny11\sources\install2.wim" -NewName "install.wim" | Out-Null
Write-Output "Windows image completed. Continuing with boot.wim."
Write-Output "Mounting boot image:"
$wimFilePath = "$ScratchDisk\tiny11\sources\boot.wim"
& takeown "/F" $wimFilePath | Out-Null
& icacls $wimFilePath "/grant" "$($adminGroup.Value):(F)"
Set-ItemProperty -Path $wimFilePath -Name IsReadOnly -Value $false
Mount-WindowsImage -ImagePath $ScratchDisk\tiny11\sources\boot.wim -Index 2 -Path $ScratchDisk\scratchdir
Write-Output "Loading registry..."
reg load HKLM\zCOMPONENTS $ScratchDisk\scratchdir\Windows\System32\config\COMPONENTS
reg load HKLM\zDEFAULT $ScratchDisk\scratchdir\Windows\System32\config\default
reg load HKLM\zNTUSER $ScratchDisk\scratchdir\Users\Default\ntuser.dat
reg load HKLM\zSOFTWARE $ScratchDisk\scratchdir\Windows\System32\config\SOFTWARE
reg load HKLM\zSYSTEM $ScratchDisk\scratchdir\Windows\System32\config\SYSTEM

Write-Output "Bypassing system requirements(on the setup image):"
Set-RegistryValue 'HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache' 'SV1' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache' 'SV2' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache' 'SV1' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache' 'SV2' 'REG_DWORD' '0'
Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassCPUCheck' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassRAMCheck' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassSecureBootCheck' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassStorageCheck' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSYSTEM\Setup\LabConfig' 'BypassTPMCheck' 'REG_DWORD' '1'
Set-RegistryValue 'HKLM\zSYSTEM\Setup\MoSetup' 'AllowUpgradesWithUnsupportedTPMOrCPU' 'REG_DWORD' '1'
Write-Output "Tweaking complete!"

Write-Output "Unmounting Registry..."
reg unload HKLM\zCOMPONENTS | Out-Null
reg unload HKLM\zDEFAULT | Out-Null
reg unload HKLM\zNTUSER | Out-Null
reg unload HKLM\zSOFTWARE | Out-Null
reg unload HKLM\zSYSTEM | Out-Null

Write-Output "Unmounting image..."
Dismount-WindowsImage -Path $ScratchDisk\scratchdir -Save
if ($ESDCompression) {
    Write-Output "Compressing install.wim to install.esd (This will take a long time)..."
    Export-WindowsImage -SourceImagePath "$ScratchDisk\tiny11\sources\install.wim" -SourceIndex 1 -DestinationImagePath "$ScratchDisk\tiny11\sources\install.esd" -CompressionType Recovery -CheckIntegrity
    Remove-Item "$ScratchDisk\tiny11\sources\install.wim" -Force
}
Write-Output "The tiny11 image is now completed. Proceeding with the making of the ISO..."
Write-Output "Copying unattended file and custom ISOFILES..."
Copy-Item -Path "$PSScriptRoot\autounattend.xml" -Destination "$ScratchDisk\tiny11\autounattend.xml" -Force -ErrorAction SilentlyContinue | Out-Null
if (Test-Path "$PSScriptRoot\ISOFILES") {
    $customFiles = @(Get-ChildItem -Path "$PSScriptRoot\ISOFILES" -File -Recurse | Where-Object { $_.BaseName -ne 'Add files.md' })
    if ($customFiles.Count -gt 0) {
        Write-Output "Copying custom files from ISOFILES to the ISO root..."
        Copy-Item -Path "$PSScriptRoot\ISOFILES\*" -Destination "$ScratchDisk\tiny11\" -Recurse -Force | Out-Null
    }
}
Write-Output "Creating ISO image..."
$ADKDepTools = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\$hostarchitecture\Oscdimg"
$localOSCDIMGPath = "$PSScriptRoot\oscdimg.exe"

if ([System.IO.Directory]::Exists($ADKDepTools)) {
    Write-Output "Will be using oscdimg.exe from system ADK."
    $OSCDIMG = "$ADKDepTools\oscdimg.exe"
} else {
    Write-Output "ADK folder not found. Will be using bundled oscdimg.exe."
    $url = "https://msdl.microsoft.com/download/symbols/oscdimg.exe/3D44737265000/oscdimg.exe"

    if (-not (Test-Path -Path $localOSCDIMGPath)) {
        Write-Output "Downloading oscdimg.exe..."
        Invoke-WebRequest -Uri $url -OutFile $localOSCDIMGPath

        if (Test-Path $localOSCDIMGPath) {
            Write-Output "oscdimg.exe downloaded successfully."
        } else {
            Write-Error "Failed to download oscdimg.exe."
            exit 1
        }
    } else {
        Write-Output "oscdimg.exe already exists locally."
    }

    $OSCDIMG = $localOSCDIMGPath
}

& "$OSCDIMG" '-m' '-o' '-u2' '-udfver102' "-bootdata:2#p0,e,b$ScratchDisk\tiny11\boot\etfsboot.com#pEF,e,b$ScratchDisk\tiny11\efi\microsoft\boot\efisys.bin" "$ScratchDisk\tiny11" "$PSScriptRoot\tiny11.iso"

# Finishing up
Write-Output "Creation completed!"
Write-Output "Performing Cleanup..."
Remove-Item -Path "$ScratchDisk\tiny11" -Recurse -Force | Out-Null
Remove-Item -Path "$ScratchDisk\scratchdir" -Recurse -Force | Out-Null
Write-Output "Ejecting Iso drive"
Get-Volume -DriveLetter $DriveLetter[0] | Get-DiskImage | Dismount-DiskImage
Write-Output "Iso drive ejected"
Write-Output "Removing oscdimg.exe..."
Remove-Item -Path "$PSScriptRoot\oscdimg.exe" -Force -ErrorAction SilentlyContinue
if (-not $UserProvidedAutounattend) {
    Write-Output "Removing downloaded autounattend.xml..."
    Remove-Item -Path "$PSScriptRoot\autounattend.xml" -Force -ErrorAction SilentlyContinue
}

Write-Output "Cleanup check :"
if (Test-Path -Path "$ScratchDisk\tiny11") {
    Write-Output "tiny11 folder still exists. Attempting to remove it again..."
    Remove-Item -Path "$ScratchDisk\tiny11" -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -Path "$ScratchDisk\tiny11") {
        Write-Output "Failed to remove tiny11 folder."
    } else {
        Write-Output "tiny11 folder removed successfully."
    }
} else {
    Write-Output "tiny11 folder does not exist. No action needed."
}
if (Test-Path -Path "$ScratchDisk\scratchdir") {
    Write-Output "scratchdir folder still exists. Attempting to remove it again..."
    Remove-Item -Path "$ScratchDisk\scratchdir" -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -Path "$ScratchDisk\scratchdir") {
        Write-Output "Failed to remove scratchdir folder."
    } else {
        Write-Output "scratchdir folder removed successfully."
    }
} else {
    Write-Output "scratchdir folder does not exist. No action needed."
}
if (Test-Path -Path "$PSScriptRoot\oscdimg.exe") {
    Write-Output "oscdimg.exe still exists. Attempting to remove it again..."
    Remove-Item -Path "$PSScriptRoot\oscdimg.exe" -Force -ErrorAction SilentlyContinue
    if (Test-Path -Path "$PSScriptRoot\oscdimg.exe") {
        Write-Output "Failed to remove oscdimg.exe."
    } else {
        Write-Output "oscdimg.exe removed successfully."
    }
} else {
    Write-Output "oscdimg.exe does not exist. No action needed."
}
if (-not $UserProvidedAutounattend) {
    if (Test-Path -Path "$PSScriptRoot\autounattend.xml") {
        Write-Output "autounattend.xml still exists. Attempting to remove it again..."
        Remove-Item -Path "$PSScriptRoot\autounattend.xml" -Force -ErrorAction SilentlyContinue
        if (Test-Path -Path "$PSScriptRoot\autounattend.xml") {
            Write-Output "Failed to remove autounattend.xml."
        } else {
            Write-Output "autounattend.xml removed successfully."
        }
    } else {
        Write-Output "autounattend.xml does not exist. No action needed."
    }
} else {
    Write-Output "Keeping custom user-provided autounattend.xml."
}

# Stop the transcript
Stop-Transcript

exit

