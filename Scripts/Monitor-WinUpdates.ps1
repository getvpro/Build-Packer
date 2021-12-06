<#

.FUNCTIONALITY
Checks for status of windows updates started by Start-WinUpdates.ps1 script: UsoClient.exe StartInteractiveScan
When no updates are left, the related scheduled tasks will be disabled

.SYNOPSIS
Checks for status of windows updates started by Start-WinUpdates.ps1 script: UsoClient.exe StartInteractiveScan
When no updates are left, the related scheduled tasks will be disabled


.NOTES
Change log

Dec 4, 2021
-Initial version

Dec 5, 2021
-Added logging and module logic from Get-WinUpdatesPacker.ps1 script
-ScriptLog changed to "C:\admin\Build\WindowsUpdates.txt"
-Added Show-InstallationProgress once all windows updates have applied

.DESCRIPTION
Author oreynolds@gmail.com

.EXAMPLE
./Monitor-WinUpdates.ps1

.NOTES

.Link
N/A

#>

## Variables

$LogTimeStamp = (Get-Date).ToString('MM-dd-yyyy-hhmm-tt')
$ScriptLog = "C:\admin\Build\WindowsUpdates.txt"

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

Function Test-PendingReboot {
    if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $true }
    if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $true }
    if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $true }
    try { 
        $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
        $status = $util.DetermineIfRebootPending()
        if (($status -ne $null) -and $status.RebootPending) {
            return $true
        }
    }
    catch { }

    return $false
}

###

IF (!(Get-PackageProvider -ListAvailable nuget) ) {

    Install-PackageProvider -Name NuGet -Force
    Write-CustomLog -ScriptLog $ScriptLog -Message "The Nuget package manager will be installed" -Level INFO
    Write-EventLog -LogName SYSTEM -Source $EventIDSrc -EventId 0 -EntryType INFO -Message "The Nuget package manager will be installed"

}

###
Install-module pswindowsupdate -force -AllowClobber
Import-Module -Name PSWindowsUpdate

$Updates = Get-WUList

If ($Updates -eq $Nul) {

    [Environment]::SetEnvironmentVariable("WinPackerBuildEndDate", $(Get-Date), [EnvironmentVariableTarget]::Machine)
    
    $PackerRegKey = (Get-ItemProperty -Path "hklm:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name WinPackerBuildEndDate -ErrorAction SilentlyContinue).WinPackerBuildEndDate
    
    $TotalBuildTime = [Datetime]::ParseExact($env:WinPackerBuildEndDate, 'MM/dd/yyyy HH:mm:ss', $null) - [Datetime]::ParseExact($env:WinPackerBuildStartDate, 'MM/dd/yyyy HH:mm:ss', $null) 
    
    Write-CustomLog -ScriptLog $ScriptLog -Message "no windows updates to apply, start/monitor windows update tasks will be disabled and the script will exit" -Level INFO

    Get-ScheduledTask -TaskName "*WinUpdates*" | Disable-ScheduledTask

    Show-InstallationProgress -StatusMessage "Automated Windows updates installs have completed `n
    The related scheduled tasks will be disabled and the script will exit `n
    $($Env:Computername) is ready to be joined to the domain"

    Close-InstallationProgress
    
    EXIT

}

Write-CustomLog -ScriptLog $ScriptLog -Message "The following windows updates will be installed: `n $($Updates | Out-String)" -Level INFO    

write-host "Launch windows update UI"

control update

Do {

    Write-host "Check for windows update status, sleep for 10 seconds" -ForegroundColor cyan    
    $aa = Test-PendingReboot
    $bb = get-service -Name msiserver | Select-Object -ExpandProperty Status
    Start-Sleep -s 10
}

Until ($aa -eq $True -and $bb -eq "Stopped")

Write-CustomLog -ScriptLog $ScriptLog -Message "Windows updates have finished processing, machine will be rebooted in 60 seconds" -Level INFO

import-module PSADT

start-sleep -s 60

restart-computer -force

    


  
