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
-PSADT installed as required
-Added Close-InstallationProgress
-Line 163, 3rd script called for reboot etc
-ServiceUI.exe is now called externally for various show-installation messages

Jan 7, 2022
-Various edits to get around issues with Close-InstallationProgress windows not working as of 2022
-Removed check on windows update service running before reboot, as it's a false positive
-Updated Do/Loop to use PSWindowSUpdate module
-Using wscript for some pop up messages 

Feb 13, 2022
-Get-WUList is now filtered for sofware only, no longer checking for optional driver updates such as VMware

March 19, 2022
-Line 174 updated to actually start windows update

March 27, 2022
-Additional work to improve detection for windows update completion
-If ((Get-WUList | Where-Object {$_.Title -NotLike "*defender*"} | Measure).Count -eq 0) {
If ((Get-WUList -UpdateType Software | Where-Object {$_.Title -NotLike "*defender*"} | Measure).Count -eq 0)

March 28, 2022
-Line 148 updated to filter out defender updates
-Restart-computer @ end added back

April 1, 2022
-Stop-process -Name Systemsettings -Force added to two places to close out windows update settings window so that Powershell pop-up windows show first

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

if (-not(test-path "C:\admin\Build" -ErrorAction SilentlyContinue)) {

    new-item -Path "C:\admin\Build" -ItemType Directory
}

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
}

IF (!(Get-Module -ListAvailable PSADT) ) {

    Write-CustomLog -ScriptLog $ScriptLog -Message "The PSADT module will be installed" -Level INFO
    Install-Module -name PSADT -AllowClobber -Force
}

IF (!(Get-Module -ListAvailable PSWindowsUpdate) ) {

    Write-CustomLog -ScriptLog $ScriptLog -Message "The PSWindowsUpdate module will be installed" -Level INFO
    Install-module PSWindowsUpdate -force -AllowClobber
}

###

Write-CustomLog -ScriptLog $ScriptLog -Message "Importing PS Windows update module and checking for any updates to apply" -Level INFO

Import-Module -Name PSWindowsUpdate

#$Updates = Get-WUList | Where-Object {$_.Title -notLike "VMware*"}
#$Updates = Get-WUList -UpdateType Software 
$Updates = Get-WUList -UpdateType Software | Where-Object {$_.Title -NotLike "*defender*"}

If ($Updates -eq $Nul) {

    [Environment]::SetEnvironmentVariable("WinPackerBuildEndDate", $(Get-Date), [EnvironmentVariableTarget]::Machine)
    
    $WinPackerBuildEndDate = (Get-ItemProperty -Path "hklm:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name WinPackerBuildEndDate -ErrorAction SilentlyContinue).WinPackerBuildEndDate
    
    $TotalBuildTime = [Datetime]::ParseExact($WinPackerBuildEndDate , 'MM/dd/yyyy HH:mm:ss', $null) - [Datetime]::ParseExact($env:WinPackerBuildStartDate, 'MM/dd/yyyy HH:mm:ss', $null)
    $TotalHours = $TotalBuildTime | Select-Object -ExpandProperty Hours
    $TotalMinutes = $TotalBuildTime | Select-Object -ExpandProperty Minutes
    $TotalSeconds = $TotalBuildTime | Select-Object -ExpandProperty Seconds
    
	stop-process -Name Systemsettings -Force
    
    Write-CustomLog -ScriptLog $ScriptLog -Message "No windows updates to apply, start/monitor windows update tasks will be disabled and the script will exit" -Level INFO
    Write-CustomLog -ScriptLog $ScriptLog -Message "Build completed $TotalBuildTime" -Level INFO       

    Get-ScheduledTask -TaskName "*WinUpdates*" | Disable-ScheduledTask

    $BuildCompleteText = "
    The Windows updates phase has now completed `n
    The total build time was $TotalHours hours $TotalMinutes minutes $TotalSeconds seconds `n
    The related schedled tasks will be disabled and the script will exit `n
    $($Env:Computername) is ready to be joined to the domain `n
    Press [OK] now to EXIT `n    "

    c:\Windows\system32\ServiceUI.exe -process:explorer.exe "c:\Windows\System32\WindowsPowershell\v1.0\powershell.exe" -WindowStyle minimized -Executionpolicy bypass -Command "
    Add-Type -AssemblyName System.Windows.Forms;
    [System.Windows.Forms.MessageBox]::Show('$BuildCompleteText', 'Base Windows Build Complete', 0,0)
    "

    Write-CustomLog -ScriptLog $ScriptLog -Message "Windows updates completed, build is ready for the next phase" -Level INFO
    
    EXIT
}

Else {

    Write-CustomLog -ScriptLog $ScriptLog -Message "The following windows updates will be installed: `n $($Updates | Out-String)" -Level INFO

    write-host "Launch windows update UI"
    
    c:\Windows\system32\ServiceUI.exe -process:explorer.exe "c:\Windows\System32\WindowsPowershell\v1.0\powershell.exe" -WindowStyle minimized -Executionpolicy bypass -Command "explorer ms-settings:windowsupdate-action"

    Do {

        Write-host "Check for windows update status, sleep for 10 seconds" -ForegroundColor cyan
        
        Write-CustomLog -ScriptLog $ScriptLog -Message "Check for windows update status, sleep for 10 seconds" -Level INFO

        $aa = Test-PendingReboot

        If ((Get-WUList -UpdateType Software | Where-Object {$_.Title -NotLike "*defender*"} | Measure).Count -eq 0) {
         
            $bb = $True
        }

        Else {

            $bb = $false

        }        
        
        <#
        if ((Get-Service -name TrustedInstaller).StartType -eq "Manual") {

            $bb = $True

        }

        Else {
        
            $bb = $false

        }

        #>       

        write-host "Pending reboot is now $aa"
        write-host "Windows updates remaining to process is now $bb"
        Start-Sleep -s 10
    }    
    
    Until ($aa -eq "True" -and $bb -eq $True)

    ### End of the line

    Write-CustomLog -ScriptLog $ScriptLog -Message "Windows updates have finished processing, machine will be rebooted in 60 seconds" -Level INFO

    stop-process -Name Systemsettings -Force

    c:\Windows\system32\ServiceUI.exe -process:explorer.exe "c:\Windows\System32\WindowsPowershell\v1.0\powershell.exe" -WindowStyle minimized -Executionpolicy bypass `
    -Command "(New-Object -comObject Wscript.Shell).Popup('Windows updates have finished processing click OK to reboot or now, or wait 60 seconds',60,'INFO',0+64)    
    "
    Write-CustomLog -ScriptLog $ScriptLog -Message "End of logging before graceful reboot" -Level INFO
    
    Restart-Computer -Force

}


