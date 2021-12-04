Set-location "C:\Windows\System32"

UsoClient.exe StartInteractiveScan

add-content -Path C:\Admin\Build\WindowsUpdates.txt -Value "$(Get-Date): Windows update via UsoClient.exe started"

