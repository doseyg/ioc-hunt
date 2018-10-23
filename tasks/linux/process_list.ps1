###############################################################
## Glen Dosey <doseyg@r-networks.net>
## Oct 21 2018
## https://github.com/doseyg/ioc-hunt
## This requires powershell v3 and Posh-SSH. Windows 8 and 10 and should work out of the box.  Windows 7 requires upgrade of PowerShell. 
## Install-Module Posh-SSH
## 
#################################################################

New-SSHSession -ComputerName "$hostname" -Credential $sshCred
$sshIndex = Get-SSHSession -ComputerName $hostname

$command = "ps -aux"
$response = Invoke-SSHCommandStream -Index $sshIndex.SessionId -Command "$command"
 
# define column breaks in descending order
$columns = 9, 15, 20, 25, 32, 38, 42, 52, 58, 65 | Sort-Object -Descending
$newDelimiter = ','
 
$array = @()
foreach ($line in $response) {
	write-host "PreConvert $line is " $line.GetType()
	$columns | ForEach-Object {
		$line = $line.Insert($_, $newDelimiter) 
	}
	$array += $line 
}
$output = $array | ConvertFrom-Csv -Delimiter $newDelimiter 
$json = $output | ConvertTo-Json

Remove-SSHSession -Index $sshIndex.SessionId 
