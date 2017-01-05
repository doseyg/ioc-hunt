###############################################################
## Glen Dosey
## October 24 2016
##
## This is for powershell v2 on Windows 7,8 and 10 and should work out of the box. 
## You may need to set the execution policy to unrestricted with the command 'powershell set-executionpolicy unrestricted' before running this script
## Output is to CLI unless HTTP,Text file, or SQL are specified.
#################################################################

Param(
    [string]$txtOutput,
    [string]$httpOutput,
    [string]$sqlOutput,
    [string]$computerName,
    [string]$processName,
    [string]$processId,
    [switch]$yara,
    [switch]$cleanup
)

              
## setup some variables
if($computerName){}
else {
	$computerName = Get-Content env:computername
}

$arch = Invoke-Command -Computer $computerName -ScriptBlock { Get-WmiObject win32_processor -property AddressWidth | Select AddressWidth -ExpandProperty AddressWidth}
$cwd = Convert-Path "."
$md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
$remote_drive = "c"
$remote_path = "c:\"

if ($sqlOutput){
        ## Setup a database connection
         $conn = New-Object System.Data.SqlClient.SqlConnection
        ####################################################
        ## ----! Change your database settings here !---- ##
        ####################################################
        $conn.ConnectionString = "Data Source=tcp:IP_HERE;Database=HashDB;Integrated Security=false;UID=hash_user;Password=PASSWORD_HERE;"
        $conn.open()        $cmd = New-Object System.Data.SqlClient.SqlCommand
        $cmd.connection = $conn
}
## Determine if Yara is available.
if ($yara) {
	if ( Test-Path "$cwd\yara$arch.exe","$cwd\rules.yar") {
		copy-Item "$cwd\yara$arch.exe" "\\$computerName\c`$\yara.exe"
		copy-Item "$cwd\rules$arch.yar" "\\$computerName\c`$\rules.yar"
		$yara_available = Invoke-Command -Computer $computerName -ScriptBlock { param($remotepath); Test-Path "$remote_path\yara.exe","$remote_path\rules.yar" } -ArgumentList $remotepath
	}
	else {
		$yara_available = 'FALSE' 
	}
}            

## Get a list of running processes
if     ($processName) { $processes = Invoke-Command -Computer $computerName -ScriptBlock { param($processName);Get-Process -Name $processName } -ArgumentList $processName }
elseif ($processId)   { $processes = Invoke-Command -Computer $computerName -ScriptBlock { param($processId); Get-Process -Id $processId } -ArgumentList $processId }
else                  { $processes = Invoke-Command -Computer $computerName -ScriptBlock { Get-Process } }

## for each process, identify relevant attributes, hash it, and output
foreach ($process in $processes) {
	#$filename = $process.Path
	$processID = $process.Id
	#$fileversion = $process.fileversion
	$processname = $process.name
	#$product = $process.product
	#$description = $process.description
	$hash = ''
	
	## Run the Yara command
	if ($yara_available){
		$yara_result = Invoke-Command -Computer $computerName -ScriptBlock { param($processID); c:\yara.exe -s c:\rules.yar $processID } -ArgumentList $processID
	}
	
	if($filename){
		## Calculate the md5 hash value
		#$hash = [System.BitConverter]::ToString($md5.ComputeHash([System.IO.File]::ReadAllBytes($fileName)))
		## Remove - characters from hash value
		#$hash = %{$hash -replace "-",""
	}
	$output = "$computername,$processname,$processID,$filename,$fileversion,$description,$product,$hash,$yara_result`n"
	## write to the local CSV file
	if($txtOutput){ Add-Content $txtOutput $output }
	## Ouput to HTTP
	if ($httpOutput){
		#Invoke-WebRequest "$httpOutput?$output"
		$urloutput =  [System.Convert]::ToBase64String([System.Text.Encoding]::UNICODE.GetBytes($output))
		$request = [System.Net.WebRequest]::Create("http://$httpOutput/`?task_process_scan=$urloutput");
		$resp = $request.GetResponse();
	}
	## Insert into a database
	if($sqlOutput){
		$cmd.commandtext = "INSERT INTO processes (hostname,processname,processID,filename,fileversion,description,product,md5,yara_result) VALUES('{0}','{1}','{2}','{3}','{4}','{5}','{6}','{7}','{8}')" -f $computername,$processname,$processID,$filename,$fileversion,$description,$product,$hash,[string]$yara_result
		$cmd.executenonquery()
	}
	if($txtoutput -or $httpOutput -or $sqlOutput){}
	else { write-host $output }
 }
 
 
if($sqlOutput){
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
