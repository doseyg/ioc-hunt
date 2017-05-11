###############################################################
## Glen Dosey <doseyg@r-networks.net>
## March 9 2017
## https://github.com/doseyg/ioc-hunt
## This is for powershell v2 on Windows 7,8 and 10 and should work out of the box.  
## 

Param( 
	[string]$task,
	[string]$task_args,
	[string]$remote_basedir = '\windows\temp\',
	[string]$txtOutputFile,
	[string]$httpOutputUrl,
	[string]$sqlConnectString,
	[switch]$syncAD,
	[switch]$resumeScan,
	[switch]$newScan,
	[switch]$includeConfig

	
)

## Get configuration from XML file
[xml]$Config = Get-Content "config.ioc-hunt.xml"

## If the flag wasn't specified, use the value from the config
if($txtOutputFile){$task_args += " -txtOutputFile " + $txtOutputFile }
else{$task_args += " -txtOutputFile " + $Config.Settings.Global.textOutputFile }
if($httpOutputUrl){$task_args += " -httpOutputUrl " + $httpOutputUrl }
else {$task_args += " -httpOutputUrl " +  $Config.Settings.Global.httpOutputUrl }
if($sqlConnectString){$task_args += " -sqlConnectString " + $sqlConnectString }
else {$task_args += " -sqlConnectString " + $Config.Settings.Global.sqlConnectString}
if($includeConfig){$task_args += " -readConfig True "}
#$fileCopySleep = 5



## You must have "Active Directory Modules for Windows Powershell" from Remote Server Admin Tools installed on the workstation running this
if($syncAD -eq $true){
	if (Get-Module -ListAvailable -Name ActiveDirectory) {
		Import-Module ActiveDirectory;
	}
	else {
		write-host "Missing ActiveDirectory Module.";
		write-host "Please install the Active Directory Modules for Windows Powershell from the Remote Server Admin Tools";
		exit;
	}
}

## Figure out the current working directory
$cwd = Convert-Path "."
$date = Get-Date -format yyyyMMddHHmmss
Start-Transcript -path "$cwd\log.$date.txt"


if($task){}
else {
	write-host "You must specify a task to run with -task <task_name>. ";
	$availableTasks = get-childitem -recurse -name "$cwd\tasks\"  | where { ! $_.PSIsContainer };
	write-host "Available tasks are:";
	foreach ($availableTask in $availableTasks) {write-host "`t $availableTask"};
	Stop-Transcript;
	exit;
}


## Check to ensure the remote script exists for copying
if (Test-Path "$cwd\tasks\$task"){}
else{
	write-host "Missing task $task from tasks directory: Exiting";
	Stop-Transcript;
	exit;
}



## Read in computers from Active Directory or a text file.
if ($syncAD) {
	write-host "Starting a new scan."
	write-host "Gathering computers from Active Directory`n"
	$hostnames = Get-ADComputer -Filter 'ObjectClass -eq "Computer"' | Select DNSHostName | ForEach-Object { $_.DNSHostName }
	Add-Content "$cwd\computers.txt" $hostnames
}
else {
	if (Test-Path "$cwd\computers.txt"){
		write-host "Starting a new scan.`n Reading computers from file computers.txt`n"
		$hostnames = Get-Content -Path "$cwd\computers.txt"
	}
	else {
		write-host "Unable to read file computers.txt for list of hosts to run against, the -syncAD flag was not specified, and not resuming a previous scan. Exiting."
		Stop-Transcript;
		exit;
	}
}

if (Test-Path "$cwd\computers_ignore.txt"){
	$ignore_hosts = Get-Content -Path "$cwd\computers_ignore.txt"
	write-host "Skipping computers listed in computers_ignore.txt file."
}
else { $ignore_hosts = ""}

## 
if($resumeScan){
	if (Test-Path "$cwd\computers_skipped.txt"){
		write-host "Resuming skipped hosts from previous scan. Delete the computers_skipped.txt file if you want to start a new scan.`n"
		$hostnames = Get-Content -Path "$cwd\computers_skipped.txt"
		Move-Item $cwd\computers_skipped.txt $cwd\computers_skipped.$date.txt
	}
	elseif (Test-Path "$cwd\computers_completed.txt"){
		write-host "Skipping previously completed hosts. Delete the computers_completed.txt file if you want to start a new scan.`n"
		$completed = Get-Content -Path "$cwd\computers_completed.txt"
	}
}




## The job to copy and run the script on each remote host, called from below
$perHostJob = {
	param($hostname,$cwd,$remote_basedir,$task,$task_args)
	#write-host "Checking dependencies for task $task"
	$remote_task = $task.split('\')[-1]
	$dependencies = (Invoke-Expression "$cwd\tasks\$task -dependencies").split(",")
	try {  ## use these if ps-remoting is not enabled
		if($dependencies){
			foreach ($dependency in $dependencies) {
				write-host "Copying $dependency to $remote_basedir on $hostname as dependency for $task $remote_task"
				Copy-Item "$cwd\dependencies\$dependency" -Destination "\\$hostname\c`$\$remote_basedir\$dependency" -force
			}
		}
		if($includeConfig){
			write-host "Copying config.ioc-hunt.xml to $remote_basedir on $hostname"
			Copy-Item "$cwd\config.ioc-hunt.xml" -Destination "\\$hostname\c`$\$remote_basedir\config.ioc-hunt.xml" -force
		}
		Copy-Item "$cwd\tasks\$task" -Destination \\$hostname\c`$\$remote_basedir\$remote_task -force
		#wmic /NODE:"$hostname" process call create "powershell set-executionpolicy unrestricted" 2> $null
		write-host "$hostname is online: running" -foregroundcolor "green"
		write-host "DEBUG $task_args"
		## We sleep here to allow time for the file copy to complete
		Start-Sleep 5
		Invoke-WmiMethod win32_process -computername $hostname -name create -argumentlist "powershell -ExecutionPolicy Bypass -file C:\$remote_basedir\$remote_task $task_args"
		## If ps remoting was enabled we could use these instead of above
		#Invoke-Command -Computer $hostname -ScriptBlock { param ($cwd); Invoke-Expression "$cwd\tasks\$task" } -ArgumentList $cwd 
		 Add-Content "$cwd\computers_completed.txt" "$hostname`n "
	}
	catch {
		if ($hostname -ne ""){
			$skipped = "True"
			write-host "$hostname is not accessible or failed for some reason: skipping" -foregroundcolor "yellow";
			Add-Content "$cwd\computers_skipped.txt" "$hostname`n";
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
		## This line skips any pattern of hostnames, which could be servers in most organizations. Tailor to your needs
		if ($hostname -like $Config.Settings.Global.excludeHostnamePattern ) { }
		elseif ($ignore_hosts.Contains($hostname)) {}
		else {
			write-host "$hostname" -foregroundcolor "magenta"
			Start-Job $perHostJob -ArgumentList $hostname, $cwd, $remote_basedir, $task, $task_args
			$count++
			## You can throttle performance/memory usage here by adjusting the number of hosts started in a given amount of time. 
			if ($count -gt $Config.Settings.Global.hostBatchSize) {
				write-host "Sleeping for $Config.Settings.Global.hotsBatchDelay seconds after trying $Config.Settings.Global.hostBatchSize hosts..."
				$sleepcount = 0
				$count = 0
				while ($sleepcount -lt $Config.Settings.Global.hotsBatchDelay) {
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
write-host "Forcefully killing all local jobs now (remote tasks will continue)"
Remove-Job -force *
write-host "Done. "

Stop-Transcript
