<#

.FUNCTIONALITY
First steps after GUI launches on new Win assets built by packer/autonunattend.xml process

.SYNOPSIS
Change log

July 23, 2020
-Initial version

July 25, 2020
-Removed WinRM enablement

July 27, 2020
-Amended to support Win 10

Aug 25, 2021
-Added import of PSWindowsUpdate

Nov 25, 2021
-Install PowerShell App Deploy toolkit
-Downloaded PSWindows Update and set as scheduled task
-Setup scheduled task for initial build tasks
-Download and run Optimize-BaseImage
-Replaced reg calls with native Powershell equivalent

Nov 26, 2021
-c:\Scripts changed to c:\Admin\Scripts
-Removed search box from HKCU

Nov 27, 2021
-Additional code to download scripts from github
-Import of Windows Updates PS task
-PSADT used for installation progress
-ServiceUI is downloaded from github

Nov 28, 2021
-Start-Optimized based image no longer launched minimized
-Custom logging added

Nov 29, 2021
-Removed WinRM code @ end
-Exit it not started elevated (admin)
-Environment variables for WinPackerStart/End added
-7-Zip portable download / install
-Fr-Ca language pack download / install

Nov 30, 2021
-c:\Admin\7-Zip is no longer created, as it's covered by .zip extraction
-Updated code to remove Fr-Ca .zip file set

Dec 1, 2021
-Logging method updated to reference new environment variable pushed from autounattend.xml that's only used with packer
-Server manager disable moved to start
-Search window disable moved to start
-c:\Admin\* folders creation moved to start
-RDP/network changes moved to start
-Exit if not started as admin moved to start
-Powershell security changes for TLS 1.2
-Commented out above security changes as part of testing
-Moved $ScriptLog variable before function that uses it
-Created $PackerRegKey
-Above $PackerRegKey resolved issues with $ScriptLog not being read, pause statements removed

Dec 2, 2021
-Code to import Windows update run on boot scheduled task disabled

Dec 4, 2021
-Code to import Windows update run on boot scheduled task re-enabled
-Added code to stop/disable Edge scheduled tasks @ start
-Removed un-needed restart of explorer.exe @ start
-New PS1 /XML Start/Monitor win updates

Dec 5, 2021
-Fixed path on lines 240-245 for XML/PS1 download

Dec 17, 2021
-Added OS detection to support downloads / installs of Fr-CA language pack for both Win 10 / Win 2022

.DESCRIPTION
Author https://github.com/getvpro (Owen Reynolds)

Jan 05, 2022
-Line 327: Fixed missing * for server OS detection

Jan 06, 2022
-Detection of sys env variable from autounattend.xml to install Fr-Ca lang pack
-Various edits to Show-InstallationProgress

Jan 10, 2022
-Edit to pause for IP check

Jan 11, 2022
-Code added to read in values from StaticIP.csv to deal with non-DHCP enabled environments
-Set-TimeZone -ID "Eastern Standard Time" added @ start to resolve issues with logging

Feb 11, 2022
-Added Fr-CA support for Windows 11 21H1

Feb 13, 2022
-c:\Admin only created as required

Feb 14, 2022
-Edit to deal with stand-alone builds

.EXAMPLE
./Start-FirstSteps.ps1

.NOTES

.Link
https://github.com/getvpro/Build-Packer

#>

IF (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    write-warning "not started as elevated session, exiting"    
    EXIT

}

### Variables

# Powershell module/package management pre-reqs
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials

Set-TimeZone -ID "Eastern Standard Time"

$OS = (Get-WMIobject -class win32_operatingsystem).Caption
$LogTimeStamp = (Get-Date).ToString('MM-dd-yyyy-hhmm-tt')
$PackerRegKey = (Get-ItemProperty -Path "hklm:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name PackerLaunched -ErrorAction SilentlyContinue).PackerLaunched
$FrenchCaLangPack = (Get-ItemProperty -Path "hklm:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name FrenchCaLangPack -ErrorAction SilentlyContinue).FrenchCaLangPack
$PackerStaticIP = (Get-ItemProperty -Path "hklm:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name PackerStaticIP -ErrorAction SilentlyContinue).PackerStaticIP

If (-not(test-path c:\admin)) {

    new-item -ItemType Directory -Path "c:\Admin\Scripts"
    new-item -ItemType Directory -Path "C:\Admin\Build"
    new-item -ItemType Directory -Path "C:\Admin\Language Pack"

}

# Set log path based on being launched by packer, or not

IF ($PackerRegKey -eq 1) {

    $ScriptLog = "c:\Admin\Build\WinPackerBuild-$LogTimeStamp.txt"
    
}

Else {

    $ScriptLog = "c:\Admin\Build\WinPackerBuild-$LogTimeStamp.txt"
    #$ScriptLog = (Get-ChildItem C:\Admin\Build | Sort-Object -Property LastWriteTime | Where-object {$_.Name -like "WinPackerBuild*"} | Select -first 1).FullName

}

if (-not(Get-Variable ScriptLog -ErrorAction SilentlyContinue)) {

	Write-warning "Script log not set, script will exit"	
	EXIT
}

### End Variables

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
        
        Add-content -value "$Message" -Path "$ScriptLog"
}

### Part 1 - Start of script processing, first steps, requires no internet connection

If ($PackerStaticIP -eq 1) {

    write-host "Attempting to set IP based on StaticIP.CSV info" -ForegroundColor Cyan

    $StaticIPcsv = import-csv "a:\StaticIP.csv"
    $IPAddr = ($StaticIPcsv)[0].Value
    $IPGW = ($StaticIPcsv)[1].Value
    $DNS1 = ($StaticIPcsv)[2].Value
    $DNS2 = ($StaticIPcsv)[3].Value

    write-host "Changing IP address to $IPAddr. Seting defaults for gateway and DNS servers" -ForegroundColor cyan
    Get-NetAdapter | Where Status -eq UP | New-NetIPAddress -IPAddress $IPAddr -PrefixLength 24 -DefaultGateway $IPGW
    Get-NetAdapter | Where Status -eq UP | Set-DnsClientServerAddress -ServerAddresses $DNS1, $DNS2

    IF ((Test-NetConnection $IPGW -ErrorAction SilentlyContinue).PingSucceeded -eq $True) {

        Write-host "$IPGW pings back as expected" -ForegroundColor Green

    }

    Else {

        Write-warning "Default gateway is not pinglabe"

    }

    write-host "Pause for IP check" -ForegroundColor Cyan

    PAUSE

}

write-host "Start of part 1 in 3 seconds . . ." -ForegroundColor Cyan
start-sleep -s 3

[Environment]::SetEnvironmentVariable("WinPackerBuildStartDate", $(Get-Date), [EnvironmentVariableTarget]::Machine)

Get-ScheduledTask -TaskName MicrosoftEdgeUpdateTaskMachine* -ErrorAction SilentlyContinue | Stop-ScheduledTask
Get-ScheduledTask -TaskName MicrosoftEdgeUpdateTaskMachine* -ErrorAction SilentlyContinue | Disable-ScheduledTask

New-ItemProperty -Path "HKCU:\Software\Microsoft\ServerManager" -Name "DoNotOpenServerManagerAtLogon" -PropertyType DWORD -Value "0x1" –Force
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -PropertyType DWORD -Value "0x1" -Force

IF (Get-process "servermanager" -ErrorAction SilentlyContinue) {

    Stop-Process -name servermanager -Force    
}

New-Item -Path HKLM:\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff -Force

netsh advfirewall firewall set rule group="Network Discovery" new enable=No

### Open RDP
netsh advfirewall firewall add rule name="Open Port 3389" dir=in action=allow protocol=TCP localport=3389

New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -name fDenyTSConnections -PropertyType DWORD -Value 0 -Force

Write-host "Restart explorer"

stop-process -Name explorer

### Part 2 - Requires internet connection, install Powershell package managers and modules

Write-CustomLog -ScriptLog $ScriptLog -Message "Installing PowershellGet / nuget package providers" -Level INFO

Install-PackageProvider -Name PowerShellGet -Force -Confirm:$False
Install-PackageProvider -Name Nuget -Force -Confirm:$False

Write-CustomLog -ScriptLog $ScriptLog -Message "Installing Powershell App Deploy ToolKit module" -Level INFO
Install-Module -Name PSADT -AllowClobber -Force -Confirm:$False

if (Get-module -ListAvailable -name PSADT) {

 Write-host "Pre-req PSADT is installed, script will continue" -ForegroundColor Green

}

Else {
 
 Write-CustomLog -ScriptLog $ScriptLog -Message "Internet / Proxy / Firewall issues are preventing the installation of pre-req modules, please resolve and re-try, script will exit" -Level ERROR 
 EXIT

}

$TempFolder = "C:\TEMP"
New-Item -ItemType Directory -Force -Path $TempFolder
[Environment]::SetEnvironmentVariable("TEMP", $TempFolder, [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable("TMP", $TempFolder, [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable("TEMP", $TempFolder, [EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable("TMP", $TempFolder, [EnvironmentVariableTarget]::User)

### Part 3

Show-InstallationProgress -StatusMessage "Scripts will be downloaded from git hub"

start-sleep -s 3

Write-CustomLog -ScriptLog $ScriptLog -Message "Downloading scripts and binaries from github repo getvpro" -Level INFO

Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/getvpro/Standard-WinBuilds/master/Start-OptimizeBaseImage.ps1 -OutFile c:\admin\Scripts\Start-OptimizeBaseImage.ps1

Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/getvpro/Build-Packer/master/Scripts/Start-WinUpdates.ps1 -OutFile c:\admin\Scripts\Start-WinUpdates.ps1
Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/getvpro/Build-Packer/master/Scripts/Start-WinUpdates.xml -OutFile c:\admin\Scripts\Start-WinUpdates.xml

Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/getvpro/Build-Packer/master/Scripts/Monitor-WinUpdates.ps1 -OutFile c:\admin\Scripts\Monitor-WinUpdates.ps1
Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/getvpro/Build-Packer/master/Scripts/Monitor-WinUpdates.xml -OutFile c:\admin\Scripts\Monitor-WinUpdates.xml

$EXEGIT = "https://github.com/getvpro/Build-Packer/raw/master/ServiceUI.exe"
$File = Invoke-WebRequest -Uri $EXEGIT -UseDefaultCredentials -Method Get -UseBasicParsing
[System.IO.File]::WriteAllBytes("C:\Windows\System32\ServiceUI.exe", $File.Content)

Close-InstallationProgress

set-location C:\admin\Scripts

Write-CustomLog -ScriptLog $ScriptLog -Message "Running Optimize Base image script" -Level INFO

Show-InstallationProgress -StatusMessage "Running Optimize Base image script"

powershell.exe -executionpolicy bypass -file .\Start-OptimizeBaseImage.ps1

Close-InstallationProgress

Write-CustomLog -ScriptLog $ScriptLog -Message "Importing Windows Update task" -Level INFO

Register-ScheduledTask -XML (Get-content "C:\Admin\Scripts\Start-WinUpdates.xml" | Out-String) -TaskName Start-WinUpdates -Force

Register-ScheduledTask -XML (Get-content "C:\Admin\Scripts\Monitor-WinUpdates.xml" | Out-String) -TaskName Monitor-WinUpdates -Force

New-Shortcut -Path C:\users\packman\desktop\BuildLogs.lnk -TargetPath C:\Admin\Build

### Fr-ca language pack download for Server 2022 systems / Win 10 21H1 is pending

If ($FrenchCaLangPack -eq 1) {

    Write-CustomLog -ScriptLog $ScriptLog -Message "FrenchCaLangPack key is set to 1, proceeeding with extra steps to provision Fr-Ca lang pack" -Level INFO

    Write-CustomLog -ScriptLog $ScriptLog -Message "Downloading / installing 7-zip" -Level INFO

    Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/getvpro/Build-Packer/blob/master/Binaries/7-ZipPortable.zip?raw=true" -OutFile "c:\Admin\7-Zip.zip"

    Expand-Archive "C:\Admin\7-Zip.zip" -DestinationPath "C:\Admin\"

    Remove-item "C:\Admin\7-Zip.zip" -Force

    Write-CustomLog -ScriptLog $ScriptLog -Message "Downloading Fr-ca.cab multi-part 7 zip file from git hub" -Level INFO

    IF ($OS -like "Windows 10*") {

        Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/getvpro/Build-Packer/blob/master/Language%20Packs/Win%2010%202004,%2020H1,%2021H2/Win10-21H1-x64-Fr-Ca.zip.001?raw=true" `
        -OutFile "C:\Admin\Language Pack\Win10-21H1-x64-Fr-Ca.zip.001"

        Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/getvpro/Build-Packer/blob/master/Language%20Packs/Win%2010%202004,%2020H1,%2021H2/Win10-21H1-x64-Fr-Ca.zip.002?raw=true" `
        -OutFile "C:\Admin\Language Pack\Win10-21H1-x64-Fr-Ca.zip.002"

    }    
    
    IF ($OS -like "Windows 11*") {

        Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/getvpro/Build-Packer/blob/master/Language%20Packs/Win%2011%2021H1/Microsoft-Windows-Client-Language-Pack_x64_fr-ca.7z.001?raw=true" `
        -OutFile "C:\Admin\Language Pack\Win11-21H1-x64-Fr-Ca.zip.001"

        Invoke-WebRequest -UseBasicParsing -Uri https://github.com/getvpro/Build-Packer/blob/master/Language%20Packs/Win%2011%2021H1/Microsoft-Windows-Client-Language-Pack_x64_fr-ca.7z.002?raw=true `
        -OutFile "C:\Admin\Language Pack\Win11-21H1-x64-Fr-Ca.zip.002"
    }

    IF ($OS -like "*Windows Server*") {

        Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/getvpro/Build-Packer/blob/master/Language%20Packs/Server%202022/Server-2022-x64-Fr-Ca.zip.001?raw=true" `
        -OutFile "C:\Admin\Language Pack\Server-2022-x64-Fr-Ca.zip.001"

        Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/getvpro/Build-Packer/blob/master/Language%20Packs/Server%202022/Server-2022-x64-Fr-Ca.zip.002?raw=true" `
        -OutFile "C:\Admin\Language Pack\Server-2022-x64-Fr-Ca.zip.002"

        Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/getvpro/Build-Packer/blob/master/Language%20Packs/Server%202022/Server-2022-x64-Fr-Ca.zip.003?raw=true" `
        -OutFile "C:\Admin\Language Pack\Server-2022-x64-Fr-Ca.zip.003"

    }

    Set-Location 'C:\Admin\Language Pack'

    Write-CustomLog -ScriptLog $ScriptLog -Message "Extracting Fr-ca.cab multi-part 7-zip" -Level INFO

    start-process "C:\Admin\7-ZipPortable\App\7-Zip64\7z.exe" -ArgumentList "e *.zip*"

    Write-CustomLog -ScriptLog $ScriptLog -Message "Installing Fr-ca.cab, this process can be up to 10 mins" -Level INFO

    Show-InstallationProgress -StatusMessage "Installing Fr-ca language pack from downloaded .CAB for $OS `
     Note, this process can be up to 10 mins"

    IF ($OS -like "*Windows 10*") {

        Add-WindowsPackage -Online -PackagePath "C:\Admin\Language Pack\Win11-21H1-x64-Fr-Ca.cab" -LogPath "C:\admin\Build\Fr-ca-Install.log" -NoRestart
        
        Write-CustomLog -ScriptLog $ScriptLog -Message "Adding Fr-Ca to preferred display languages" -Level INFO

		$OldList = Get-WinUserLanguageList
		$OldList.Add("fr-CA")
		Set-WinUserLanguageList -LanguageList $OldList -Confirm:$False -Force
    
    } 
    
    IF ($OS -like "*Windows 11*") {

        Add-WindowsPackage -Online -PackagePath "C:\Admin\Language Pack\Win11-21H1-x64-Fr-Ca.cab" -LogPath "C:\admin\Build\Fr-ca-Install.log" -NoRestart
        
        Write-CustomLog -ScriptLog $ScriptLog -Message "Adding Fr-Ca to preferred display languages" -Level INFO

		$OldList = Get-WinUserLanguageList
		$OldList.Add("fr-CA")
		Set-WinUserLanguageList -LanguageList $OldList -Confirm:$False -Force
    
    } 


    IF ($OS -like "*Windows Server*") {

        Add-WindowsPackage -Online -PackagePath "C:\Admin\Language Pack\Server-2022-x64-Fr-Ca.cab" -LogPath "C:\admin\Build\Fr-ca-Install.log" -NoRestart
        
        Write-CustomLog -ScriptLog $ScriptLog -Message "Adding Fr-Ca to preferred display languages" -Level INFO

		$OldList = Get-WinUserLanguageList
		$OldList.Add("fr-CA")
		Set-WinUserLanguageList -LanguageList $OldList -Confirm:$False -Force
    
    }

    
    Write-CustomLog -ScriptLog $ScriptLog -Message "Remove .zip files that contained Fr-ca.cab" -Level INFO

    Get-ChildItem -Path "C:\Admin\Language Pack" -Exclude *.cab | Remove-Item -Force

    Close-InstallationProgress

}

Else {

    Write-CustomLog -ScriptLog $ScriptLog -Message "FrenchCaLangPack key is not set to 1. Only En-US will be enabled on this system" -Level INFO

}

### END

Write-CustomLog -ScriptLog $ScriptLog -Message "Start-FirstSteps script completed, the script will close in 5 seconds" -Level INFO

Show-InstallationProgress -StatusMessage "Start-FirstSteps script completed, the script will close in 5 seconds"

start-sleep -s 5

Get-process | Where {$_.MainWindowTitle -like "PS App Deploy Toolkit*"} | Where {$_.Name -eq "Powershell"} | Stop-Process -force