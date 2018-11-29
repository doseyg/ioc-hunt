###############################################################
## Glen Dosey
## October 24 2016
## https://github.com/doseyg/ioc-hunt
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
	[string]$readConfig,
	[switch]$dependencies,
	[switch]$cleanup
)

## Because testing of FALSE with if returns true, set it to $null instead. This is an ugly hack, maybe someday I will have a cleaner solution
if($txtOutputFile -eq $false){$txtOutputFile = $null}
if($httpOutputUrl -eq $false){$httpOutputUrl = $null}
if($sqlConnectString -eq $false){$sqlConnectString = $null}

if($readConfig -eq $true){
	## Get configuration from XML file
	[xml]$Config = Get-Content "config.ioc-hunt.xml"

	## If the flag wasn't specified, use the value from the config
	if(!$txtOutputFile){$txtOutputFile = $Config.Settings.Global.textOutputFile}
	if(!$httpOutputUrl){$httpOutputUrl = $Config.Settings.Global.httpoutputUrl}
	if(!$sqlConnectString){$sqlConnectString = $Config.Settings.Global.sqlConnectString}
}

## If the dependencies switch was supplied, return a comma seperated list of any files needed by this script, and then exit.
if ($dependencies) {
	if($yara){
		return ""
	}
	else {return ""}
	exit;
}

## setup some variables
$computerName = Get-Content env:computername
$arch = Invoke-Command -ScriptBlock { Get-WmiObject win32_processor -property AddressWidth | Select AddressWidth -ExpandProperty AddressWidth}
$cwd = Convert-Path "."
$md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider


## If a SQL Connection string was supplied, setup the database connection
if ($sqlConnectString){
    $conn = New-Object System.Data.SqlClient.SqlConnection
	$conn.ConnectionString = $sqlConnectString
    $conn.open()
    $cmd = New-Object System.Data.SqlClient.SqlCommand
    $cmd.connection = $conn
}


## Get a list of running processes
if ($processName) { $processes = Get-Process -Name $processName }
elseif ($processId)  { $processes =  Get-Process -Id $processId }
else { 
	## Refusing to try and dump memory for every process on the system
	exit; 
}

## for each process, identify relevant attributes, hash it, and output
foreach ($process in $processes) {
	$filename = $process.Path
	$processID = $process.Id
	$fileversion = $process.fileversion
	$processname = $process.name
	$processHandle = $process.Handle
	$product = $process.product
	$description = $process.description
	$hash = ''
	
    $WER = [PSObject].Assembly.GetType('System.Management.Automation.WindowsErrorReporting')
	$WERNativeMethods = $WER.GetNestedType('NativeMethods', 'NonPublic')
	$Flags = [Reflection.BindingFlags] 'NonPublic, Static'
	$MiniDumpWriteDump = $WERNativeMethods.GetMethod('MiniDumpWriteDump', $Flags)
	$MiniDumpWithFullMemory = [UInt32] 2
	$minidumpFile = "c:\windows\temp\$filename_$processID.dmp"
   	$stream = New-Object IO.FileStream($minidumpFile, [IO.FileMode]::Create)
	$Result = $MiniDumpWriteDump.Invoke($null, @($processHandle, $processID, $FileStream.SafeFileHandle,$MiniDumpWithFullMemory,[IntPtr]::Zero,[IntPtr]::Zero,[IntPtr]::Zero))
	$stream.Close()
	
	
	## DEBUG does anything below this make sense for a minidump ?
	
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
		$cmd.commandtext = "INSERT INTO processes (Hostname,Process_Name,PID,File_Name,fileversion,description,product,Hashes_MD5,yara_result) VALUES('{0}','{1}','{2}','{3}','{4}','{5}','{6}','{7}','{8}')" -f $computername,$processname,$processID,$filename,$fileversion,$description,$product,$hash,[string]$yara_result
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
	remove-Item "$cwd\processes_yara.ps1"
	if($readConfig){
		remove-item "$cwd\config.ioc-hunt.xml"
	}
 }


