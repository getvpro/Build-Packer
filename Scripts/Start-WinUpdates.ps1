### Dec 5, 2021
### Added stop/disable MS Edge tasks

### March 13, 2022
## #control update added, but disabled

### March 14, 2022
# Added ms-settings:windowsupdate-action, not used, saved for future use as Usoclient.exe is legacy

Get-ScheduledTask -TaskName MicrosoftEdgeUpdateTaskMachine* -ErrorAction SilentlyContinue | Stop-ScheduledTask
Get-ScheduledTask -TaskName MicrosoftEdgeUpdateTaskMachine* -ErrorAction SilentlyContinue | Disable-ScheduledTask

Set-location "C:\Windows\System32"

UsoClient.exe StartInteractiveScan

# control update 
## ms-settings:windowsupdate-action

add-content -Path C:\Admin\Build\WindowsUpdates.txt -Value "$(Get-Date): Windows update via UsoClient.exe started"