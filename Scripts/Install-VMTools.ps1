<#
.FUNCTIONALITY
This is a VMWare tools install script that re-attempts the install if it finds that the VMWARE tools service has failed to install on the first attempt 1

.SYNOPSIS
- This script can be used as part of automating windows 10/2019 builds via autounattend.xml with packer.io based builds
- The Packer instance requires the VMWare tools service to be running at the end of the build, else, it will fail
- Due to an issue Windows "VMware tools service" failing to install on the first attempt, the code in this script compltes a re-install of the VMWARE tools package
- The below code is mostly based on the script within the following blog post: 
- https://scriptech.io/automatically-reinstalling-vmware-tools-on-server2016-after-the-first-attempt-fails-to-install-the-vmtools-service/

.NOTES
Change log

July 24, 2020
- Initial version

Nov 28, 2021
-Added Write-CustomLog function

Nov 30, 2021
-Updated code to ID correct log name
-Added Show-Status function

Feb 13, 2022
-Logging changed to new file, rather than adding to existing WinPackerBuild-date.txt file

.DESCRIPTION
Author oreynolds@gmail.com and Tim from the scriptech.io blog
https://scriptech.io/automatically-reinstalling-vmware-tools-on-server2016-after-the-first-attempt-fails-to-install-the-vmtools-service/

.EXAMPLE
./Install-VMTools.ps1

.NOTES

.Link
https://scriptech.io/automatically-reinstalling-vmware-tools-on-server2016-after-the-first-attempt-fails-to-install-the-vmtools-service/
https://github.com/getvpro/Build-Packer

#>

Function Get-VMToolsInstalled {
    
    IF (((Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall") | Where-Object { $_.GetValue( "DisplayName" ) -like "*VMware Tools*" } ).Length -gt 0) {
        
        [int]$Version = "32"
    }

    IF (((Get-ChildItem "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") | Where-Object { $_.GetValue( "DisplayName" ) -like "*VMware Tools*" } ).Length -gt 0) {

       [int]$Version = "64"
    }    

    return $Version
}

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

Function Show-Status {

    import-module PSADT -Force

    Show-InstallationProgress -StatusMessage "VMware tools is installed `n
    The remote packer instance will power off the VM to complete phase 1 of the build process `n
    The PowerCLI script running on the same machine running packer will then power the VM back on `n
    With the VM powered back on, phase 2 will start, where a custom Windows Update task / script will be downloaded/imported/ran to fully patch the system"

    Start-Sleep -Seconds 5

    Close-InstallationProgress

}

### End functions

### Create directory structure as required

If (-not(test-path c:\admin -ErrorAction SilentlyContinue)) {

    new-item -ItemType Directory -Path "c:\Admin\Scripts"
    new-item -ItemType Directory -Path "C:\Admin\Build"
    new-item -ItemType Directory -Path "C:\Admin\Language Pack"

}

$LogTimeStamp = (Get-Date).ToString('MM-dd-yyyy-hhmm-tt')
$ScriptLog = "c:\Admin\Build\WinPackerBuild-VMwareTools-$LogTimeStamp.txt"

### 1 - Set the current working directory to whichever drive corresponds to the mounted VMWare Tools installation ISO

Set-Location e:

### 2 - Install attempt #1
Write-CustomLog -ScriptLog $ScriptLog -Message "Starting VMware tools install first attempt 1" -Level INFO

Start-Process "setup64.exe" -ArgumentList '/s /v "/qb REBOOT=R"' -Wait

### 3 - After the installation is finished, check to see if the 'VMTools' service enters the 'Running' state every 2 seconds for 10 seconds
$Running = $false
$iRepeat = 0

while (-not$Running -and $iRepeat -lt 5) {

  write-host "Pause for 2 seconds to check running state on VMware tools service" -ForegroundColor cyan 
  Start-Sleep -s 2
  $Service = Get-Service "VMTools" -ErrorAction SilentlyContinue
  $Servicestatus = $Service.Status

  if ($ServiceStatus -notlike "Running") {

    $iRepeat++

  }
  else {

    $Running = $true
    Write-CustomLog -ScriptLog $ScriptLog -Message "VMware tools service found to be running state after first install attempt" -Level INFO
  }

}
### 4 - If the service never enters the 'Running' state, re-install VMWare Tools
if (-not$Running) {

  #Uninstall VMWare Tools
  Write-CustomLog -ScriptLog $ScriptLog -Message "Running un-install on first attempt of VMware tools install" -Level WARN

  IF (Get-VMToolsInstalled -eq "32") {
  
    $GUID = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -Like '*VMWARE Tools*' }).PSChildName

  }

  Else {
  
    $GUID = (Get-ItemProperty HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -Like '*VMWARE Tools*' }).PSChildName

  }

  ### 5 - Un-install VMWARe tools based on 32-bit/64-bit install GUIDs captured via Get-VMToolsIsInstalled function
  
  Start-Process -FilePath msiexec.exe -ArgumentList "/X $GUID /quiet /norestart" -Wait  

  Write-CustomLog -ScriptLog $ScriptLog -Message "Running re-install of VMware tools install" -Level INFO
    
  #Install VMWare Tools
  Start-Process "setup64.exe" -ArgumentList '/s /v "/qb REBOOT=R"' -Wait

  ### 6 - Re-check again if VMTools service has been installed and is started

 Write-CustomLog -ScriptLog $ScriptLog -Message "Re-checking if VMTools service has been installed and is started" -Level INFO 
  
$iRepeat = 0
while (-not$Running -and $iRepeat -lt 5) {

    Start-Sleep -s 2
    $Service = Get-Service "VMTools" -ErrorAction SilentlyContinue
    $ServiceStatus = $Service.Status
    
    If ($ServiceStatus -notlike "Running") {

      $iRepeat++

    }

    Else {

      $Running = $true
      Write-CustomLog -ScriptLog $ScriptLog -Message "VMware tools service found to be running state after SECOND install attempt" -Level INFO
      Show-Status
    }

  }

  ### 7 If after the reinstall, the service is still not running, this is a failed deployment

  IF (-not$Running) {
    Write-CustomLog -ScriptLog $ScriptLog -Message "VMWare Tools is still not installed correctly. The packer automated deployment will not process any further until VMWare Tools is installed" -Level ERROR    
    
    Show-InstallationProgress -StatusMessage "VMWare Tools is still NOT installed correctly `n
    The packer automated deployment will not process any further until the VMTools Windows service is started, check under services.msc `n
    Please troubleshoot `n
    This progress window will remain up for 5 minutes, then auto-close `n
    If you want to close this progress window now, run 'close-InstallationProgress from the parent Powershell process"
        
    Start-Sleep -Seconds 300
    Close-InstallationProgress
    EXIT

  }

}