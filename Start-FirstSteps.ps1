<#

.FUNCTIONALITY
First steps after GUI launches on new Win assets built by packer/autonunattend.xml process

.SYNOPSIS
Change log

July 23, 2020
-Initial version

.DESCRIPTION
Author oreynolds@gmail.com

.EXAMPLE
./Start-FirstSteps.ps1

.NOTES

.Link
TBD

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

### Enable WinRM

write-host "Enable WinRM for integration with packer" -ForegroundColor Cyan

$NetworkListManager = [Activator]::CreateInstance([Type]::GetTypeFromCLSID([Guid]"{DCB00C01-570F-4A9B-8D69-199FDBA5723B}"))
$Connections = $NetworkListManager.GetNetworkConnections()
$Connections | ForEach-Object { $_.GetNetwork().SetCategory(1) }

Enable-PSRemoting -Force
winrm quickconfig -q
winrm quickconfig -transport:http
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="800"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/client/auth '@{Basic="true"}'
winrm set winrm/config/listener?Address=*+Transport=HTTP '@{Port="5985"}'
netsh advfirewall firewall set rule group="Windows Remote Administration" new enable=yes
netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new enable=yes action=allow
Set-Service winrm -startuptype "auto"
Restart-Service winrm

write-host "Script compelted, moving to next step after 5 second pause" -ForegroundColor Cyan
start-sleep -Seconds 5

EXIT