## Dec 5, 2021
# Added stop/disable MS Edge tasks

## March 13, 2022
# #control update added, but disabled

## March 14, 2022
# Added ms-settings:windowsupdate-action, not used, saved for future use as Usoclient.exe is legacy
# https://www.urtech.ca/2018/11/usoclient-documentation-switches/

# March 15, 2022
# ServiceUI used to launch windows update

## March 19, 2022
# Removed second call to "explorer ms-settings:windowsupdate-action", this has been moved to monitor windows updates instead

Get-ScheduledTask -TaskName MicrosoftEdgeUpdateTaskMachine* -ErrorAction SilentlyContinue | Stop-ScheduledTask
Get-ScheduledTask -TaskName MicrosoftEdgeUpdateTaskMachine* -ErrorAction SilentlyContinue | Disable-ScheduledTask

Set-location "C:\Windows\System32"

c:\Windows\system32\ServiceUI.exe -process:explorer.exe "c:\Windows\System32\WindowsPowershell\v1.0\powershell.exe" -WindowStyle minimized -Executionpolicy bypass -Command "UsoClient.exe ScanInstallWait"

c:\Windows\system32\ServiceUI.exe -process:explorer.exe "c:\Windows\System32\WindowsPowershell\v1.0\powershell.exe" -WindowStyle minimized -Executionpolicy bypass -Command "UsoClient.exe StartDownload"

c:\Windows\system32\ServiceUI.exe -process:explorer.exe "c:\Windows\System32\WindowsPowershell\v1.0\powershell.exe" -WindowStyle minimized -Executionpolicy bypass -Command "UsoClient.exe Startinstall"

c:\Windows\system32\ServiceUI.exe -process:explorer.exe "c:\Windows\System32\WindowsPowershell\v1.0\powershell.exe" -WindowStyle minimized -Executionpolicy bypass -Command "explorer ms-settings:windowsupdate-action"

add-content -Path C:\Admin\Build\WindowsUpdates.txt -Value "$(Get-Date): Windows update via UsoClient.exe started"