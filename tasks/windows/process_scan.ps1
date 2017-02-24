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
	[string]$processName,
	[string]$processId,
	[string]$yara,
	[string]$cleanup
)

## Because testing of FALSE with if returns true, set it to $null instead. This is an ugly hack, maybe someday I will have a cleaner solution
if($txtOutputFile -eq 'FALSE'){$txtOutputFile = $null}
if($httpOutputUrl -eq 'FALSE'){$httpOutputUrl = $null}
if($sqlConnectString -eq 'FALSE'){$sqlConnectString = $null}

if ($dependencies) {
	if($yara){
		return "yara.exe,rules.yar"
	}
	else {return ""}
	exit;
}

## setup some variables
$computerName = Get-Content env:computername
$arch = Get-WmiObject win32_processor -property AddressWidth
$cwd = Convert-Path "."
$md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
if ($sqlConnectString){
	## Setup a database connection
	$conn = New-Object System.Data.SqlClient.SqlConnection
	$conn.ConnectionString = $sqlConnectString
	#$conn.ConnectionString = "Data Source=tcp:IP_HERE;Database=HashDB;Integrated Security=false;UID=hash_user;Password=PASSWORD_HERE;"
	$conn.open()
	$cmd = New-Object System.Data.SqlClient.SqlCommand
	$cmd.connection = $conn
}
	
## Determine if Yara is available. We should probably check system architecture here with get-wmiobject win32_processor

if($yara){
	$yara64 = Test-Path "$cwd\yara64.exe","$cwd\rules.yar"
	$yara32 = Test-Path "$cwd\yara32.exe","$cwd\rules.yar"
	if ($yara64 -eq $True -and $arch -eq '64') { $yara_cmd = "$cwd\yara64.exe"}
	elseif ($yara32 -eq $True -and $arch -eq '32') { $yara_cmd = "$cwd\yara32.exe"}
	else { $yara_cmd = ''}
}

## Get a list of running processes
if ($processName) { $processes = Get-Process -Name $processName}
elseif ($processId){ $processes = Get-Process -Id $ProcessId}
else { $processes = Get-Process }

## for each process, identify relevant attributes, hash it, and output

foreach ($process in $processes) {
	$filename = $process.Path
	$processID = $process.Id
	$fileversion = $process.fileversion
	$processname = $process.name
	$product = $process.product
	$description = $process.description
	$hash = ''

	## Run the Yara command    
	if ($yara_cmd){
		$yara_result = & $yara_cmd -s rules.yar $processID 2> $null
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
			$urloutput =  [System.Convert]::ToBase64String([System.Text.Encoding]::UNICODE.GetBytes($output))
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

if($sqlConnectString){
	## Close the database connection
	$conn.close()
}
 
## Return the execution policy to restricted (if we set it to unrestricted in a seperate script so we could run this powershell script)
#set-executionPolicy restricted
## Delete this file because it contains a (mostly useless) database username and password
 
 if($cleanup){
	remove-Item "$cwd\yara64.exe"
	remove-Item "$cwd\yara32.exe"
	remove-Item "$cwd\rules.yar"
	remove-Item "$cwd\task_process_scan.ps1"
}
