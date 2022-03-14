### Dec 5, 2021
### Added stop/disable MS Edge tasks

### March 13, 2022
## #control update added, but disabled

Get-ScheduledTask -TaskName MicrosoftEdgeUpdateTaskMachine* -ErrorAction SilentlyContinue | Stop-ScheduledTask
Get-ScheduledTask -TaskName MicrosoftEdgeUpdateTaskMachine* -ErrorAction SilentlyContinue | Disable-ScheduledTask

Set-location "C:\Windows\System32"

UsoClient.exe StartInteractiveScan

#control update 

add-content -Path C:\Admin\Build\WindowsUpdates.txt -Value "$(Get-Date): Windows update via UsoClient.exe started"