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

Nov 28 2021
-Amended reboot / sleep process
-Ignore reboot added
-Related scheduled task will be disabled when there are no more windows updates to process, should be on reboot #3

Nov 29
-Custom logging function added

.DESCRIPTION
Author oreynolds@gmail.com

.EXAMPLE
./Get-WindowsUpdatesSingle.ps1

.NOTES

.Link
N/A

#>

$EventIDSrc = "PSWindowsUpdate"
$LogTimeStamp = (Get-Date).ToString('MM-dd-yyyy-hhmm-tt')
$ScriptLog = "C:\Admin\Build\WinPackerBuild-$LogTimeStamp.log"

### Functions

Function Write-CustomLog {
    Param(
    [String]$ScriptLog,    
    [String]$Message,
    [String]$Level
    
    )

    switch ($Level) { 
        'Error' 
            {
            $LevelText = 'ERROR:' 
            $Message = "$(Get-Date): $LevelText Ran from $Env:computername by $($Env:Username): $Message"
            Write-host $Message -ForegroundColor RED            
            } 
        
        'Warn'
            { 
            $LevelText = 'WARNING:' 
            $Message = "$(Get-Date): $LevelText Ran from $Env:computername by $($Env:Username): $Message"
            Write-host $Message -ForegroundColor YELLOW            
            } 

        'Info'
            { 
            $LevelText = 'INFO:' 
            $Message = "$(Get-Date): $LevelText Ran from $Env:computername by $($Env:Username): $Message"
            Write-host $Message -ForegroundColor GREEN            
            } 

        }
        
        Add-content -value "$Message" -Path $ScriptLog
}

Write-CustomLog -ScriptLog $ScriptLog -Message "PSWindows Update Packer script started processing" -Level INFO

IF (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    write-warning "not started as elevated session, exiting"
    Write-CustomLog -ScriptLog $ScriptLog -Message "not started as elevated session, exiting" -Level ERROR
    EXIT

}

IF (-not([System.Diagnostics.EventLog]::SourceExists("$EventIDSrc"))) {
    
    New-EventLog -LogName SYSTEM -Source $EventIDSrc

}

IF (!(Get-PackageProvider -ListAvailable nuget) ) {

    Install-PackageProvider -Name NuGet -Force
    Write-CustomLog -ScriptLog $ScriptLog -Message "The Nuget package manager will be installed" -Level INFO
    Write-EventLog -LogName SYSTEM -Source $EventIDSrc -EventId 0 -EntryType INFO -Message "The Nuget package manager will be installed"

}

IF (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {

    Install-module pswindowsupdate -force
    Write-CustomLog -ScriptLog $ScriptLog -Message "The PSWindowsUpdate module will be installed" -Level INFO
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

    Write-CustomLog -ScriptLog $ScriptLog -Message "The following windows updates will be installed: `n $($Updates | Out-String)" -Level INFO    

    Write-EventLog -LogName SYSTEM -Source $EventIDSrc -EventId 0 -EntryType INFO -Message "The following windows updates will be installed `n $($Updates | Out-String)"
    
    Get-WUInstall -MicrosoftUpdate -AcceptAll -UpdateType Software -Install -IgnoreReboot    

    Close-InstallationProgress

    Restart-Computer -Force
}

Else {

    Show-InstallationProgress -StatusMessage "No windows updates to install at this time. the scheduled task will be disabled"
    Write-CustomLog -ScriptLog $ScriptLog -Message "PSWindows Update Packer script finished applying updates" -Level INFO    
    Write-EventLog -LogName SYSTEM -Source $EventIDSrc -EventId 0 -EntryType INFO -Message "PSWindows Update Packer script finished applying updates" 
    Start-Sleep -Seconds 5
    Close-InstallationProgress
    Disable-ScheduledTask -TaskName Get-WinUpdatesPacker -ErrorAction SilentlyContinue

}    

