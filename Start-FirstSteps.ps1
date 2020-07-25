<#

.FUNCTIONALITY
First steps after GUI launches on new Win assets built by packer/autonunattend.xml process

.SYNOPSIS
Change log

July 23, 2020
-Initial version

July 25, 2020
-Removed WinRM enablement

.DESCRIPTION
Author oreynolds@gmail.com

.EXAMPLE
./Start-FirstSteps.ps1

.NOTES

.Link
https://github.com/getvpro/Build-Packer

#>

write-host "Running first steps after GUI logon" -ForegroundColor Cyan

IF (Get-process "servermanager") {

    Stop-Process -name servermanager -Force

}

New-ItemProperty -Path HKCU:\Software\Microsoft\ServerManager -Name DoNotOpenServerManagerAtLogon -PropertyType DWORD -Value "0x1" –Force

write-host "Disable network discovery and open RDP" -ForegroundColor Cyan

### Disable network discovery
reg ADD HKLM\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff /f
netsh advfirewall firewall set rule group="Network Discovery" new enable=No

### Open RDP
netsh advfirewall firewall add rule name="Open Port 3389" dir=in action=allow protocol=TCP localport=3389
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f

# Set Temp Variable using PowerShell
write-host "Setting temp folder" -ForegroundColor Cyan

$TempFolder = "C:\TEMP"
New-Item -ItemType Directory -Force -Path $TempFolder
[Environment]::SetEnvironmentVariable("TEMP", $TempFolder, [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable("TMP", $TempFolder, [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable("TEMP", $TempFolder, [EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable("TMP", $TempFolder, [EnvironmentVariableTarget]::User)

write-host "Script completed! Moving to next step after 5 second pause" -ForegroundColor Cyan
start-sleep -s 5

