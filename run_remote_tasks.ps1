### Glen Dosey
## Jan 2 2017
## 

Param( [string]$task )

## You must have "Active Directory Modules for Windows Powershell" from Remote Server Admin Tools installed on the workstation running this 
if (Get-Module -ListAvailable -Name ActiveDirectory) {
	Import-Module ActiveDirectory;
}
else {
	write-host "Missing ActiveDirectory Module.";
	write-host "Please install the Active Directory Modules for Windows Powershell from the Remote Server Admin Tools";
	exit;
}

## Figure out the current working directory
$cwd = Convert-Path "."
$date = Get-Date -format yyyyMMddHHmmss
Start-Transcript -path "$cwd\log.$date.txt"

## Get configuration from XML file
[xml]$Config = Get-Content "config.ioc-hunt.xml"

if($task){}
else {
	write-host "You must specify a task to run. ";
	$availableTasks = get-childitem -recurse -name "$cwd\tasks_windows";
	#$availableTasks += get-chilitem -recurse -name $cwd\tasks_linux
	write-host "Available tasks are $availableTasks ";
}


## Check to ensure the remote script exists for copying
if (Test-Path "$cwd\$task.ps1"){}
else{
	write-host "Missing $task from working directory: Exiting";
	Stop-Transcript;
	exit;
}

## Either read hostnames from file, or collect from AD
if (Test-Path "$cwd\skipped.txt"){
	write-host "Resuming skipped hosts from previous scan. Delete the skipped.txt file if you want to start a new scan.`n"
	$hostnames = Get-Content -Path "$cwd\skipped.txt"
	Move-Item $cwd\skipped.txt $cwd\skipped.$date.txt
}
elseif (Test-Path "$cwd\completed.txt"){
	write-host "Skipping previously completed hosts. Delete the completed.txt file if you want to start a new scan.`n"
	$completed = Get-Content -Path "$cwd\completed.txt"
	$hostnames = Get-ADComputer -Filter 'ObjectClass -eq "Computer"' | Select DNSHostName | ForEach-Object { $_.DNSHostName }
}
else{
	write-host "Starting a new scan."
	write-host "Gathering computers from Active Directory`n"
	$hostnames = Get-ADComputer -Filter 'ObjectClass -eq "Computer"' | Select DNSHostName | ForEach-Object { $_.DNSHostName }
}

## The job to copy and run the script on each remote host, called from below
$perHostJob = {
	param($hostname,$cwd)
    try {  ## use these if ps-remoting is not enabled
		Copy-Item "$cwd\processes.ps1" -Destination \\$hostname\c`$\processes.ps1 -force
		Copy-Item "$cwd\yara64.exe" -Destination \\$hostname\c`$\yara64.exe -force
		Copy-Item "$cwd\rules.yar" -Destination \\$hostname\c`$\rules.yar -force
		#wmic /NODE:"$hostname" process call create "powershell set-executionpolicy unrestricted" 2> $null
		#invoke-wmimethod win32_process -name create -argumentlist "powershell set-executionpolicy unrestricted" -Computername "$hostname"
		write-host "$hostname is online: running" -foregroundcolor "green"
		Start-Sleep 15
		#wmic /NODE:"$hostname" process call create "powershell C:\gatherhashes.ps1" 2> $null
		invoke-wmimethod win32_process -name create -argumentlist "powershell -ExecutionPolicy Bypass C:\processes.ps1" -Computername "$hostname"
		## If ps remoting was enabled we could use these instead of above
		#Invoke-Command -computername $hostname -scriptblock {set-executionpolicy unrestricted}
		#Invoke-Command -computername $hostname -scriptblock { "c:\temp\gatherhashes.ps1" }
		#Invoke-Command -computername $hostname -filepath "$cwd\gatherhashes.ps1"
		 Add-Content "$cwd\completed.txt" "$hostname`n "
	}
	catch {
		if ($hostname -ne ""){
			$skipped = "True"
			write-host "$hostname is not accessible or failed for some reason: skipping" -foregroundcolor "yellow";
			Add-Content "$cwd\skipped.txt" "$hostname`n";
		}
	}
}
 
## Loop through every host, creating a seperate job per host to copy and execute the script
foreach ($hostname in $hostnames){
	if ($completed -contains $hostname) {
		Write-Host "$hostname was already scanned";
		Continue;
	}
	if ($hostname -ne "") {
		## This line skips things named someting-something-something, which tend to be servers in most organizations. Tailor to your needs
		if ($hostname -like '*-*-*' ) { }
		else {
			write-host "$hostname" -foregroundcolor "magenta"
			Start-Job $perHostJob -ArgumentList $hostname, $cwd
			$count++
			## You can throttle performance here by adjusting the number of hosts started in a given amount of time. The below is 50 hosts every 300 seconds
			if ($count -gt 25) {
			write-host "Sleeping for 300 seconds after trying 50 hosts..."
			$sleepcount = 0
			$count = 0
			while ($sleepcount -lt 30) {
				$results = Get-Job -State "Completed" | Receive-Job 2>&1
				if ($results) { write-host "$results`n" -foregroundcolor "gray" }
				Get-Job -state "Completed" | remove-job
				Get-Job -state "Failed" | remove-job
				Start-Sleep 1
				$sleepcount++
				write-host "`b+" -NoNewLine
				Start-Sleep 1
				$sleepcount++
				write-host "`b-" -NoNewLine
			}
		}
	}
  }
}
 
## Display output from all completed jobs
$results = Get-Job | Receive-Job 2>&1
write-host "`n $results" -foregroundcolor "darkblue"
 
## Wait 120 seconds for all jobs to complete
write-host "Waiting up to 2 minutes for all jobs to complete... +" -NoNewLine
$count=1
While (Get-Job -State "Running") {
	 Start-Sleep 1
	 write-host "`b+" -NoNewLine
	 Start-Sleep 1
	 write-host "`b-" -NoNewLine
	 $count++
	 if($count -gt 61){break}
}
 
## Display output from any completed jobs
write-host "`r`n"
$results = Get-Job | Receive-Job 2>&1
write-host "$results" -foregroundcolor "darkblue"
 
## Cleanup and kill any local jobs (this does not stop scripts running on the remote systems)

write-host "Sleeping for 10 seconds, then killing the below left-over jobs. CTRL-C to cancel."
Get-Job -State "Running"
Start-Sleep 10
write-host "Forcefully killing all local jobs now (remote hashing will continue)"
Remove-Job -force *
write-host "Done. "
 
Stop-Transcript
