###############################################################
## Glen Dosey <doseyg@r-networks.net>
## Oct 21 2018
## https://github.com/doseyg/ioc-hunt
## This requires powershell v4, PackageManagement, .Net 4.5, and Posh-SSH. Windows 8 and 10 and should work out of the box.  Windows 7 requires upgrade of PowerShell. 
## .NET 4.5 https://www.microsoft.com/en-us/download/confirmation.aspx?id=30653
## Powershell PackageManagement https://www.microsoft.com/en-us/download/confirmation.aspx?id=51451
## Windows Management Framework 5 https://www.microsoft.com/en-us/download/details.aspx?id=54616
## Install-Module Posh-SSH
## 
#################################################################


Param( 
	[string]$hostname,
	[System.Management.Automation.Credential()]$sshCred
	
)

write-output $sshCred
if ($hostname){}
else {
	write-output "Missing hostname parameter. SSH Script not running. Exiting quietly."
	return;
}

if (Get-Module -ListAvailable -Name Posh-SSH) {
	Import-Module Posh-SSH;
}
else{
	write-output "Missing Posh-SSH Library. SSH Script not running. Exiting quietly."
	return;
}
if ($sshCred) {}
else {
	Write-Host "Enter your SSH Credential in the pop-up window"
	$sshCred = Get-Credential
}



New-SSHSession -ComputerName "$hostname" -Credential $sshCred
$sshIndex = Get-SSHSession -ComputerName $hostname

$command = "show proc"
$response = Invoke-SSHCommandStream -Index $sshIndex.SessionId -Command "$command"
 
# define column breaks in descending order
$columns = 9, 15, 20, 25, 32, 38, 42, 52, 58, 65 | Sort-Object -Descending
$newDelimiter = ','
 
$array = @()
foreach ($line in $response) {
	#write-host "PreConvert $line is " $line.GetType()
	$columns | ForEach-Object {
		$line = $line.Insert($_, $newDelimiter) 
	}
	$array += $line 
}
$output = $array | ConvertFrom-Csv -Delimiter $newDelimiter 
$json = $output | ConvertTo-Json

Write-output $json

Remove-SSHSession -Index $sshIndex.SessionId 
