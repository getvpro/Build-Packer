$VM = Read-host -Prompt "Enter the exact name of the VM specified in the JSON config"

$VC = Read-host -Prompt "Enter in the FQDN of your vCenter server, ommiting the 'https://' prefix"

$VCenterCred = Get-Credential -Message "Enter in the username / password in UPN format to logon to your vCenter instance"

Set-location "C:\Program Files\Packer"
packer.exe build -force "C:\Program Files\Packer\config\JSON\Server_2022_EFI_Enterprise.json"

write-host "Build complete, $VM will now be powered back on in 5 seconds"

start-sleep -s 5

Connect-VIServer -Server $VC -Credential $VCenterCred

Start-VM -VM $VM