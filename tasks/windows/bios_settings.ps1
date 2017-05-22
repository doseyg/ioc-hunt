###############################################################
## Glen Dosey <doseyg@r-networks.net>
## October 24 2016
## https://github.com/doseyg/ioc-hunt
## This is for powershell v2 on Windows 7,8 and 10 and should work out of the box. 
## Output is to CLI unless HTTP,Text file, or SQL are specified.
#################################################################

Write-host "This is not a functioning task."
exit;

get-wmiobject win32_bios


## Dell Specific - http://en.community.dell.com/techcenter/systems-management/w/wiki/1774.omci-sample-scripts
gwmi -namespace root\dellomci dell_systemsummary
gwmi -namespace root\dellomci Dell_BootDeviceSequence | ft BootOrder, BootDeviceName
(gwmi -namespace root\dellomci dell_SMBIOSSEttings).ChassisIntrusionStatus

## HP Specific  - https://soykablog.wordpress.com/2012/11/03/automate-bios-configuration-for-hp-clients-anything-about-it/
Get-WmiObject -Namespace root/hp/instrumentedBIOS -Class hp_biosEnumeration 
