<#

.FUNCTIONALITY
-used to start Win 11 or Win 2022 packer based builds

.SYNOPSIS
-used to start Win 11 or Win 2022 packer based builds

.NOTES
Change log

Feb 1, 2022
-Initial version

Feb 13, 2022
-Added menu system

#>

Function Select-PackerBuildOS {
    param (
        [string]$Title = 'Build environment selection'
    )
    Clear-Host
    Write-Host "================ $Title ================"    
    Write-Host "`r"
    Write-Host "1: Press '1' Windows 11 EFI"
    Write-Host "`r"
    Write-Host "2: Press '2' Windows Server 2022 EFI"
    Write-Host "`r"
    Write-Host "Q: Press 'Q' to quit"
}

do {
    Select-PackerBuildOS
    Write-Host "`r"
    $input = Read-Host "Please make a selection"
    switch ($input) {
        '1' {
            Clear-Host
            $PackerConfigFile = "C:\Program Files\Packer\config\HCL\Win11_EFI_Enterprise.json.pkr.hcl"
            $ChosenOS = "Windows 11"
         
        }

        '2' {
            Clear-Host
            $ChosenOS = "Server 2022"
            $PackerConfigFile = "C:\Program Files\Packer\config\JSON\Server_2022_EFI_Enterprise.json"           

        }       

        'q' {
            Write-Warning "Script will now exit"
            EXIT
        }
    }

    "OS chosen is $ChosenOS associated to packer config file: $PackerConfigFile"
    Write-Host "`r"
    Pause
}
until ($input -ne $null)

$VM = Read-host -Prompt "Enter the exact name of the VM specified in the Packer config"

$VC = Read-host -Prompt "Enter in the FQDN of your vCenter server, ommiting the 'https://' prefix"

$VCenterCred = Get-Credential -Message "Enter in the username / password in UPN format to logon to your vCenter instance"

Connect-VIServer -Server $VC -Credential $VCenterCred

if (-not(Get-VM -Name $VM -ErrorAction SilentlyContinue)) {

    Set-location "C:\Program Files\Packer"

    packer.exe build $PackerConfigFile

    write-host "Build complete, $VM will now be powered back on in 5 seconds"

    start-sleep -s 5

    Start-VM -VM $VM

}

Else {

    Write-Warning "$VM already exists! Please delete it if it's not being used, or choose another VM name!"
    write-warning "Press any key to EXIT now"    
    PAUSE
    EXIT 

}

