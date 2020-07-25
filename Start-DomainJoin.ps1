<#

.FUNCTIONALITY
Prompts to join domain at end of windows build

.SYNOPSIS
Change log

July 25, 2020
-Initial version

.DESCRIPTION
Author oreynolds@gmail.com

.EXAMPLE
./Start-DomainJoin.ps1

.NOTES

.Link
https://github.com/getvpro/Build-Packer

#>

Add-Type -AssemblyName System.Windows.Forms

$OS = (Get-WMIObject -class win32_operatingsystem).Caption

$UserResponse = [System.Windows.Forms.MessageBox]::Show("The $OS build has now completed.`
`
Do you want to join the computer to the domain ?","Domain Join" , 4, 32)

If ($UserResponse -eq "Yes") {

    write-host "You will prompted for valid domain credentials to join the computer to the domain" -ForegroundColor Cyan
    Add-Computer

}
