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
$ScriptLog = (Get-ChildItem C:\Admin\Build | Sort-Object -Property LastWriteTime | Where-object {$_.Name -like "WinPackerBuild*"} | Select -first 1).FullName

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

IF (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {

    Install-module pswindowsupdate -force -AllowClobber
    Write-CustomLog -ScriptLog $ScriptLog -Message "The PSWindowsUpdate module will be installed" -Level INFO
}

###

Import-Module -Name PSWindowsUpdate

$Updates = Get-WUList

If ($Updates -eq $Nul) {

    Write-CustomLog -ScriptLog $ScriptLog -Message "no windows updates to apply, start/monitor windows update tasks will be disabled and the script will exit" -Level INFO
    Get-ScheduledTask -TaskName "*WinUpdates*" | Disable-ScheduledTask
    EXIT

}

Write-CustomLog -ScriptLog $ScriptLog -Message "The following windows updates will be installed: `n $($Updates | Out-String)" -Level INFO    

write-host "Launch windows update UI"

control update

Do {

    Write-host "Check for windows update status, sleep for 30 seconds" -ForegroundColor cyan
    Start-Sleep -s 30
    $aa = Test-PendingReboot
    $bb = get-service -Name msiserver | Select-Object -ExpandProperty Status
    #$bb = get-service -Name BITS | Select-Object -ExpandProperty Status
    #$bb = Get-WUInstallerStatus | Select-Object -ExpandProperty IsBusy
}

Until ($aa -eq $True -and $bb -eq "Stopped") 

Write-CustomLog -ScriptLog $ScriptLog -Message "Windows updates have finished processing, machine will be rebooted in 60 seconds" -Level INFO

start-sleep -s 60

restart-computer -force

    


  
