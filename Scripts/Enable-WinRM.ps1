<#

.FUNCTIONALITY
Enable WinRM for Packer.IO integration

.SYNOPSIS
Change log

July 25, 2020
-Initial version
-Minor edit to first part which produced "access denied"

July 27, 2020
-Amended to support Win 10

Nov 28, 2021
-Added Write-CustomLog function

Nov 29, 2021
-Added netsh winsock reset catalog to end

Nov 30, 2021
-Line 83 disabled to reduce false errors: Set-NetConnectionProfile -InterfaceAlias Ethernet -NetworkCategory Private

Feb 13, 2021
-Set-NetConnectionProfile interface is fed from Get-NetConnectionProfile, as it was noted that the 'InterfaceAlias' was not always 'Ethernet', often 'Ethernet0'

.DESCRIPTION
Author oreynolds@gmail.com

.EXAMPLE
./Enable-WinRM.ps1

.NOTES

.Link
https://github.com/getvpro/Build-Packer

#>

$LogTimeStamp = (Get-Date).ToString('MM-dd-yyyy-hhmm-tt')
$ScriptLog = (Get-ChildItem C:\Admin\Build | Sort-Object -Property LastWriteTime | Where-object {$_.Name -like "WinPackerBuild*"} | Select -first 1).FullName

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


### Enable WinRM

Write-CustomLog -ScriptLog $ScriptLog -Message "Enable WinRM for integration with packer" -Level INFO

Write-CustomLog -ScriptLog $ScriptLog -Message "Set network connection profile to private" -Level INFO

Get-NetConnectionProfile  | Select InterfaceAlias | Set-NetConnectionProfile -NetworkCategory Private

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
netsh winsock reset catalog

Set-Service winrm -startuptype "auto"

Restart-Service winrm

Write-CustomLog -ScriptLog $ScriptLog -Message "WinRM enabled. The remote packer instance should now finish the build and power off the VM in 5 seconds" -Level INFO