<#

.FUNCTIONALITY
1 - This script used with the packer.io
2 - It's called from line 14 of the related autounattend.xml
3 - When first run, it copies itself over from the mounted a:\ drive and creates a shortcut on the desktop of the current user
4 - When called a second time, it prompts to join AD, and removes the shortcut (.LNK) created in step 3

.SYNOPSIS
Change log

July 25, 2020
 -Initial version

July 26, 2020
 -Various edits to cover script copy/LNK creation before code that actually prompts for domain join

.DESCRIPTION
Author oreynolds@gmail.com

.EXAMPLE
./Start-DomainJoin.ps1

.NOTES

.Link
https://github.com/getvpro/Build-Packer

#>

Add-Type -AssemblyName System.Windows.Forms

$text = "The $OS build has now completed.`
`
Do you want to join the computer to the domain ?"

$OS = (Get-WMIObject -class win32_operatingsystem).Caption

IF (-not(Test-path c:\Scripts)) {

    New-Item -ItemType Directory "C:\Scripts" 

}

IF (-not(Test-path "C:\Scripts\Start-DomainJoin.ps1" -ErrorAction SilentlyContinue)) {
    
    Copy-item a:\Start-DomainJoin.ps1 C:\Scripts -Force -ErrorAction SilentlyContinue
    
    ### Shortcut creation    
    
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$Home\Desktop\Join Active Directory.lnk")
    $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"    
    $Shortcut.Arguments = '-NoProfile -NoLogo -NonInteractive -ExecutionPolicy Bypass -File "C:\Scripts\Start-DomainJoin.ps1"'
    $Shortcut.IconLocation = ",0"
    $Shortcut.WindowStyle = 7 #Minimized
    $Shortcut.WorkingDirectory = "C:\Scripts"
    $Shortcut.Description ="Join Active Directory"
    $Shortcut.Save()

    write-host "`r`n"
    write-host "$Home\Desktop\Start-DomainJoin.ps1 created" -ForegroundColor Cyan
    write-host "`r`n"
    write-host "The script will now exit, the Start-DomainJoin.ps1 script can be called when the build has completed" -ForegroundColor Cyan    
    start-sleep -s 3
    EXIT
}

IF (test-path C:\Scripts\Start-DomainJoin.ps1) {

    $UserResponse = [System.Windows.Forms.MessageBox]::Show($Text,"Domain Join" , 4, 32)

    If ($UserResponse -eq "Yes") {

        write-host "You will prompted for valid domain credentials to join the computer to the domain" -ForegroundColor Cyan
        Add-Computer
        remove-item "$Home\Desktop\Join Active Directory.lnk" -Force
    }

}
