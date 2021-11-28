<#

.FUNCTIONALITY
Local windows update task that runs under a scheduled task

.SYNOPSIS
Local windows update task that runs under a scheduled task

.NOTES
Change log

July 25, 2020: Added write-host

Nov 8, 2020: Updated line 43 

Nov 9, 2020: Removed minimum version on Nuget install

Feb 23, 2020: Exit if not run as admin

July 12, 2021
-Added EA silently contune

Nov 26, 2021
-Updated to include ServiceUI calls for use with packer builds

Nov 27, 2021
-Amended reboot / sleep process

.DESCRIPTION
Author oreynolds@gmail.com

.EXAMPLE
./Get-WindowsUpdatesSingle.ps1

.NOTES

.Link
N/A

#>

$EventIDSrc = "PSWindowsUpdate"

IF (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    write-warning "not started as elevated session, exiting"
    EXIT

}

IF (-not([System.Diagnostics.EventLog]::SourceExists("$EventIDSrc"))) {
    
    New-EventLog -LogName SYSTEM -Source $EventIDSrc

}

IF (!(Get-PackageProvider -ListAvailable nuget) ) {

    Install-PackageProvider -Name NuGet -Force
    Write-EventLog -LogName SYSTEM -Source $EventIDSrc -EventId 0 -EntryType INFO -Message "The Nuget package manager will be installed"

}

IF (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {

    Install-module pswindowsupdate -force
    Write-host "The PSWindowsUpdate module will be installed" -foregroundcolor cyan
    Write-EventLog -LogName SYSTEM -Source $EventIDSrc -EventId 0 -EntryType INFO -Message "The PSWindowsUpdate module will be installed"

}

If (-not(Get-Module -ListAvailable -Name PSADT)) {

    Install-Module -Name PSADT -AllowClobber -Force | Import-Module -Name PSADT -Force

}

write-host "Importing PSWindowsUpdate" -ForegroundColor Cyan
Import-Module -Name PSWindowsUpdate

$Updates  = Get-WUList
$Updates = $Updates  | Select KB, Size, Title
$WU1 = $($Updates | Select-object -ExpandProperty Title | Out-String).Split("`n")[0]
$WU2 = $($Updates | Select-object -ExpandProperty Title | Out-String).Split("`n")[1]
$WU3 = $($Updates | Select-object -ExpandProperty Title | Out-String).Split("`n")[2]
$WU4 = $($Updates | Select-object -ExpandProperty Title | Out-String).Split("`n")[3]

IF  ($Updates -ne $Null) {

    Show-InstallationProgress -TopMost $False -StatusMessage `
    "The following updates will be installed: `n

    $WU1 `n
    $WU2 `n
    $WU3 `n
    $WU4 `n

    "

    Start-Sleep -Seconds 30

    Write-host "The following windows updates will be installed: `n $($Updates | Out-String)" -ForegroundColor Cyan

    Write-EventLog -LogName SYSTEM -Source $EventIDSrc -EventId 0 -EntryType INFO -Message "The following windows updates will be installed `n $($Updates | Out-String)"
    
    Get-WUInstall -MicrosoftUpdate -AcceptAll -UpdateType Software -Install

    #Get-WUInstall -MicrosoftUpdate -AcceptAll -UpdateType Software -Install -AutoReboot    

    Close-InstallationProgress

    Restart-Computer -Force
}

Else {

    Show-InstallationProgress -StatusMessage "No windows updates to install at this time"
    Write-host "No windows updates to install at this time" -foregroundcolor green
    Write-EventLog -LogName SYSTEM -Source $EventIDSrc -EventId 0 -EntryType INFO -Message "No windows updates to install at this time"
    Start-Sleep -Seconds 5
    Close-InstallationProgress

}    

