## Build-Packer

* These scripts and config files can be used to build Win 10 / Win 2019 based virtual in a VMware vSphere environment

* I've provided complete step-by-step instructions w screenshots on my blog for the BIOS based build [HERE](https://getvpro.wordpress.com/2020/07/29/10-min-windows-10-server-2019-build-automation-via-osdbuilder-autounattend-xml-and-packer-io)

* The related blog post for the EFI based build I re-did in early 2022 are [HERE](https://getvpro.wordpress.com/2022/02/10/windows-build-automation-w-packer-powershell-2022-redux/)

* Windows 11 configs are ready for vSphere as of Feb 12, 2022, just note, within the HCL line 122, you'll need to extract the VMware tools ISO / PVSCSI infs to the same directory as you downloaded the various .PS1 files

