###############################################################
## Glen Dosey
## October 24 2016
##
## This is for powershell v2 on Windows 7,8 and 10 and should work out of the box. 
## You may need to set the execution policy to unrestricted with the command 'powershell set-executionpolicy unrestricted' before running this script
## Output is to CLI unless HTTP,Text file, or SQL are specified.
#################################################################

Param(
	[string]$txtOutputFile,
	[string]$httpOutputUrl,
	[string]$sqlConnectString,
	[string]$computerName,
	[string]$processName,
	[string]$processId,
	[switch]$dependencies,
	[switch]$yara,
	[switch]$cleanup
)

## Because testing of FALSE with if returns true, set it to $null instead. This is an ugly hack, maybe someday I will have a cleaner solution
if($txtOutputFile -eq 'FALSE'){$txtOutputFile = $null}
if($httpOutputUrl -eq 'FALSE'){$httpOutputUrl = $null}
if($sqlConnectString -eq 'FALSE'){$sqlConnectString = $null}

## If the dependencies switch was supplied, return a comma seperated list of any files needed by this script, and then exit.
if ($dependencies) {
	if($yara){
		return "yara.exe,rules.yar"
	}
	else {return ""}
	exit;
}

## setup some variables
$computerName = Get-Content env:computername
$arch = Invoke-Command -ScriptBlock { Get-WmiObject win32_processor -property AddressWidth | Select AddressWidth -ExpandProperty AddressWidth}
$cwd = Convert-Path "."
$md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
#$remote_computerName = ""
#$remote_path = "c:\"
#$remote_arch = Invoke-Command -Computer $computerName -ScriptBlock { Get-WmiObject win32_processor -property AddressWidth | Select AddressWidth -ExpandProperty AddressWidth}

## If a SQL Connection string was supplied, setup the database connection
if ($sqlConnectString){
    $conn = New-Object System.Data.SqlClient.SqlConnection
	$conn.ConnectionString = $sqlConnectString
    $conn.open()
    $cmd = New-Object System.Data.SqlClient.SqlCommand
    $cmd.connection = $conn
}


## Determine if Yara is available.
if($yara){
	if ( (Test-Path "$cwd\yara.exe") -and (Test-Path "$cwd\rules.yar") ) {
		#copy-Item "$cwd\yara$arch.exe" "\\$remote_computerName\c`$\yara.exe"
		#copy-Item "$cwd\rules$arch.yar" "\\$remote_computerName\c`$\rules.yar"
		#$yara_available = Invoke-Command -Computer $remote_computerName -ScriptBlock { param($remotepath); Test-Path "$remote_path\yara.exe","$remote_path\rules.yar" } -ArgumentList $remotepath
		$yara_available = 'TRUE'
	}
	else {
		$yara_available = 'FALSE' 
		Write-Host "yara.exe or the rules.yar file is not available in $cwd, exiting."; 
		exit; 
	}
}

## Get a list of running processes
#if ($processName) { $processes = Invoke-Command -Computer $remote_computerName -ScriptBlock { param($processName);Get-Process -Name $processName } -ArgumentList $processName }
#elseif ($processId)  { $processes = Invoke-Command -Computer $remote_computerName -ScriptBlock { param($processId); Get-Process -Id $processId } -ArgumentList $processId }
#else { $processes = Invoke-Command -Computer $remote_computerName -ScriptBlock { Get-Process } }

## Get a list of running processes
if ($processName) { $processes = Get-Process -Name $processName }
elseif ($processId)  { $processes =  Get-Process -Id $processId }
else { $processes =  Get-Process }

## for each process, identify relevant attributes, hash it, and output
foreach ($process in $processes) {
	$filename = $process.Path
	$processID = $process.Id
	#$fileversion = $process.fileversion
	$processname = $process.name
	#$product = $process.product
	#$description = $process.description
	$hash = ''
	
	## Run the Yara command
	if ($yara_available){
		#$yara_result = Invoke-Command -Computer $remote_computerName -ScriptBlock { param($processID); c:\yara.exe -s c:\rules.yar $processID } -ArgumentList $processID
		$yara_result = Invoke-Expression ("$cwd\yara.exe -s $cwd\rules.yar $processID")
	}
	
	if($filename){
		## Calculate the md5 hash value
		$hash = [System.BitConverter]::ToString($md5.ComputeHash([System.IO.File]::ReadAllBytes($fileName)))
		## Remove - characters from hash value
		$hash = %{$hash -replace "-",""}
	}
	$output = "$computername,$processname,$processID,$filename,$fileversion,$description,$product,$hash,$yara_result`n"
	## write to the local CSV file
	if($txtOutputFile){
		Add-Content $txtOutputFile $output
	}
	## Ouput to HTTP
	if ($httpOutputUrl){
		#Invoke-WebRequest "$httpOutput?$output"
		$urloutput =Â  [System.Convert]::ToBase64String([System.Text.Encoding]::UNICODE.GetBytes($output))
		$request = [System.Net.WebRequest]::Create("http://$httpOutput/`?task_process_scan=$urloutput");
		$resp = $request.GetResponse();
	}
	## Insert into a database
	if($sqlConnectString){
		$cmd.commandtext = "INSERT INTO processes (hostname,processname,processID,filename,fileversion,description,product,md5,yara_result) VALUES('{0}','{1}','{2}','{3}','{4}','{5}','{6}','{7}','{8}')" -f $computername,$processname,$processID,$filename,$fileversion,$description,$product,$hash,[string]$yara_result
		$cmd.executenonquery()
	}
	if($txtOutputFile -or $httpOutputUrl -or $sqlConnectString){}
	else { write-host $output }
 }
 
 ## Close the database connection
if($sqlConnectString){
	$conn.close()
}

## Delete this file and any dependencies if cleanup swicth was supplied
if($cleanup){
	remove-Item "$cwd\yara64.exe"
	remove-Item "$cwd\yara32.exe"
	remove-Item "$cwd\rules.yar"
	remove-Item "$cwd\processes_scan.ps1"
 }
