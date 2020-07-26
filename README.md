These scripts and config files can be used to build Win 10 / Win 2019 based virtual assets on vSphere / vmware based assets
On a windows based asset, you would take the following steps to provision a Win 10 / Win 2019 asset via packer in a vpshere environment

1. Download the latest version of the packer.io exe for windows from the following link: https://www.packer.io/downloads
2. Refer to install instructions from packer.io
3. With step 2 completed, create a sub-directory to where you extracted the packer.exe called scripts
4. Download all the .ps1 scripts to the scripts folder created in step 3
5. Download the autounattend.xml for your choice OS (Win 10 or Win 2019), place it in the root folder where the packer.exe resides
6. Download the .json for your choice OS (Win 10 or Win 2019), place it in the root folder where the packer.exe resides
7. Amend the sample autounattend.xml for Win 10 / Win 2019 to your environment

NOTE: Starting at line 114 of the autounattend.xml file, you will see multiple entries that are formatted as such:

<SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -File a:\Start-FirstSteps.ps1</CommandLine>
                    <Description>Start first steps after GUI logon</Description>
                    <Order>10</Order>
</SynchronousCommand>

-These are hard-coded entries based on corresponding entires that are contained within the associated .JSON 

-Packer will attach and copy over the .ps1 files from the directory created in step 3 to the remote shell once it's booted

-In turn, the autounattend.xml parsed by the windows setup.exe will attempt to run the scripts listed, in the sample XML, the scripts have the number order of 10,11,12,13
you can remove them if you don't want to use them

-That being said, I culled/edited/created these scripts based on a review of existing Packer > vSphere > Windows templates from 2017-2018, I would suggest keeping them

8. The most important settings to edit within the XML, are the password for the local admin account, as this is used in step 11
9. With the autounattend.xml edited for your environment, you will need to edit the sample Win_10.json or server_2019.json config file for your environment 
10. Leave the floppy_files section intact, unless you edited the related autounattend.xml file in step 7
11. Put in your local admin password specfied in step 8
12. Amend all entries where "YOUR" is mentioned, as in "YourDataStoreHere", etc
13. You should now be ready to run the packer.exe against your newly edited .JSON config file
14. open an admin command prompt on your windows box, and CD to c:\Program Files\Packer (or the path where you extracted it to)
15. Run packer.exe build server_2019.json / packer.exe build win_10.json
16. Wait for the process to complete, the only prompt you should receive after step 15, is for the 3rd script that asks about joining your AD domain
17. Once you answer the "yes/no" prompt on step 16, WinRM will be enabled by the final script, the remote packer.exe instance you started on step 15 should connect to the remote VM and complete the build and power off the VM

