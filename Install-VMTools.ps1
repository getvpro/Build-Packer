<#
.FUNCTIONALITY
This is a VMWare tools install script that re-attempts the install if it finds that the VMWARE tools service has failed to install on the first attempt 1

.SYNOPSIS
I call this script as part of automating windows 10/2019 builds via autounattend.xml with packer.io based builds
the Packer instance requires the VMWare tools service to be running at the end of the build, else, it will fail
There's a long-standing issue with the VMware tools service failing to install on windows builds, the code in this script gets around it, by trigerring a re-install when the service fails to install on the first attempt
The below code is based on the following blog post: https://scriptech.io/automatically-reinstalling-vmware-tools-on-server2016-after-the-first-attempt-fails-to-install-the-vmtools-service/
I wasn't able to contact the author to get his permission (Hi Tim!) I hope he's ok with me using it :-)
The code I made from Tim's script were to add write-host to show status, the use of the "Get-VMToolsInstalled" function which is used to automate the un-install process

.NOTES
Change log

July 23, 2020
-Initial version

.DESCRIPTION
Author oreynolds@gmail.com
99% of the code in this script comes from the following script from Tim's script posted here:
https://scriptech.io/automatically-reinstalling-vmware-tools-on-server2016-after-the-first-attempt-fails-to-install-the-vmtools-service/

.EXAMPLE
./Install-VMTools.ps1

.NOTES

.Link
https://scriptech.io/automatically-reinstalling-vmware-tools-on-server2016-after-the-first-attempt-fails-to-install-the-vmtools-service/
and TBD GIT HUB

#>

#Install VMWare Tools # REBOOT=R means supress reboot

Function Get-VMToolsInstalled {
    
    IF (((Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall") | Where-Object { $_.GetValue( "DisplayName" ) -like "*VMware Tools*" } ).Length -gt 0) {
        
        [int]$Version = "32"
    }

    IF (((Get-ChildItem "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") | Where-Object { $_.GetValue( "DisplayName" ) -like "*VMware Tools*" } ).Length -gt 0) {

       [int]$Version = "64"
    }    

    return $Version
}


### 1 - Set the current working directory to whichever drive corresponds to the mounted VMWare Tools installation ISO

Set-Location e:

### 2 - Install attempt #1

write-host "Starting VMware tools install first attempt 1" -ForegroundColor cyan
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
    write-host "VMware tools service found to be running state after first install attempt" -ForegroundColor green

  }

}

### 4 - If the service never enters the 'Running' state, re-install VMWare Tools
if (-not$Running) {

  #Uninstall VMWare Tools
  write-host "Running un-install on first attempt of VMware tools install" -ForegroundColor cyan

  IF (Get-VMToolsInstalled -eq "32") {
  
    $GUID = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -Like '*VMWARE Tools*' }).PSChildName

  }

  Else {
  
    $GUID = (Get-ItemProperty HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -Like '*VMWARE Tools*' }).PSChildName

  }

  ### 5 - Un-install VMWARe tools based on 32-bit/64-bit install GUIDs captured via Get-VMToolsIsInstalled function
  
  Start-Process -FilePath msiexec.exe -ArgumentList "/X $GUID /quiet /norestart" -Wait  

  write-host "Running re-install of VMware tools install" -ForegroundColor cyan 
  #Install VMWare Tools
  Start-Process "setup64.exe" -ArgumentList '/s /v "/qb REBOOT=R"' -Wait

  ### 6 - Re-check again if VMTools service has been installed and is started

Write-host "Re-check again if VMTools service has been installed and is started" -ForegroundColor Cyan
  
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
      write-host "VMware tools service found to be running state after SECOND install attempt" -ForegroundColor green

    }

  }

  ### 7 If after the reinstall, the service is still not running, this is a failed deployment

  IF (-not$Running) {
    
    Write-Host -ForegroundColor Red "VMWare Tools are still not installed correctly. This is a failed deployment."
    Pause

  }

}