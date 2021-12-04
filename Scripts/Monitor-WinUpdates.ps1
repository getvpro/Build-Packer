Function Test-PendingReboot {
    if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $true }
    if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $true }
    if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $true }
    try { 
        $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
        $status = $util.DetermineIfRebootPending()
        if (($status -ne $null) -and $status.RebootPending) {
            return $true
        }
    }
    catch { }

    return $false
}

control update

write-host "Start windows update"

Do {

    Write-host "Check for pending restart, sleep for 30 seconds"
    Start-Sleep -s 30
    $aa = Test-PendingReboot
    $bb = get-service -Name BITS | Select-Object -ExpandProperty Status
}

Until ($aa -eq $True -and $bb -eq "Stopped") 

### Need extra line to stop when no new updates required

### install-module PSWindowsUpdate
### Updates = Get-WUList

write-warning "Reboot detected, rebooting in 30 seconds"
start-sleep -s 30
restart-computer -force

    


  
