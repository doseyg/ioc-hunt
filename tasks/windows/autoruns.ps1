###############################################################
## Glen Dosey <doseyg@r-networks.net>
## October 24 2016
## 
## This is for powershell v2 on Windows 7,8 and 10 and should work out of the box. 
## Output is to CLI unless HTTP,Text file, or SQL are specified.
#################################################################

Param(
	[string]$txtOutputFile,
	[string]$httpOutputUrl,
	[string]$sqlConnectString,
	[string]$readConfig,
	[switch]$dependencies,
    [switch]$cleanup
)

## Because testing of FALSE with if returns true, set it to $null instead. This is an ugly hack, maybe someday I will have a cleaner solution
if($txtOutputFile -eq 'FALSE'){$txtOutputFile = $null}
if($httpOutputUrl -eq 'FALSE'){$httpOutputUrl = $null}
if($sqlConnectString -eq 'FALSE'){$sqlConnectString = $null}

if($readConfig){
	## Get configuration from XML file
	[xml]$Config = Get-Content "config.ioc-hunt.xml"

	## If the flag wasn't specified, use the value from the config
	if(!$txtOutputFile){$txtOutputFile = $Config.Settings.Global.textOutputFile}
	if(!$httpOutputUrl){$httpOutputUrl = $Config.Settings.Global.httpoutputUrl}
	if(!$sqlConnectString){$sqlConnectString = $Config.Settings.Global.sqlConnectString}
}

## setup some variables
#$arch = Invoke-Command -Computer $computerName -ScriptBlock { Get-WmiObject win32_processor -property AddressWidth | Select -First 1 AddressWidth -ExpandProperty AddressWidth}
$arch = Get-WmiObject win32_processor -property AddressWidth | Select -First 1 AddressWidth -ExpandProperty AddressWidth
$computerName = Get-Content env:computername
$cwd = Convert-Path "."

## DEBUG Settings
#$cwd = "C:\Users\user\Desktop\GatherHashes\WinRM"
#$remote_path = "c:\"
#$remote_computerName=""

## If the dependencies switch was supplied, return a comma seperated list of any files needed by this script, and then exit.
if ($dependencies) {
	return "autorunsc.exe"
	exit;
}
## If a SQL Connection string was supplied, setup the database connection
if ($sqlConnectString){     
    $conn = New-Object System.Data.SqlClient.SqlConnection
	$conn.ConnectionString = $sqlConnectString
    $conn.open()
    $cmd = New-Object System.Data.SqlClient.SqlCommand
    $cmd.connection = $conn
}

## Determine if Autorunsc is available.
if ( Test-Path "$cwd\autorunsc.exe") {
	#copy-Item "$cwd\autorunsc$arch.exe" "\\$remote_computerName\c`$\autorunsc.exe"
	#Write-Host "autorunsc was copied from $cwd to $remote_computerName"
	#$autorunsc_available = Invoke-Command -Computer $remote_computerName -ScriptBlock { param ($remotepath); Test-Path "c:\autorunsc.exe" } -ArgumentList $remotepath
	$autorunsc_available = 'TRUE';
}
else { 
	$autorunsc_available = 'FALSE';
	Write-Host "autorunsc.exe is not available in $cwd, exiting."; 
	exit; 
}


## Run the autorunsc command
if ($autorunsc_available)
{
	#$autoruns = [xml](Invoke-Command -Computer $remote_computerName -ScriptBlock { param ($cwd); Invoke-Expression "$cwd\autorunsc.exe -x -nobanner /accepteula -h" } -ArgumentList $cwd )
	$autoruns = [xml](Invoke-Expression "$cwd\autorunsc.exe -x -nobanner /accepteula -h")
}
else {
	Write-Host "autoruns did not run from $cwd on $computerName, exiting."
	exit;
}


## for each autorun, identify relevant attributes, scan, hash, and output

foreach ($item in $autoruns.autoruns.item) {
	$location = $item.location
	$launchstring = $item.launchstring
	$itemname = $item.itemname
	$filename = $item.imagepath
    $hash = $item.md5hash
	
	$output = "$computername,$itemname,$launchstring,$filename,$location,$hash`n"
	  
	## Output to local CSV file
	if($txtOutputFile){ 
		Add-Content $txtOutputFile $output
	}
	## Ouput to HTTP
	if ($httpOutputUrl){
		#Invoke-WebRequest "$httpOutput`?task_process_autorunsc=$output"
		$urloutput =  [System.Convert]::ToBase64String([System.Text.Encoding]::UNICODE.GetBytes($output));
		$request = [System.Net.WebRequest]::Create("http://$httpOutputUrl/`?task_process_scan=$urloutput");
		$resp = $request.GetResponse();
	}
	## Output to a database
	if($sqlConnectString){
		$cmd.commandtext = "INSERT INTO autoruns (hostname,itemname,launchstring,filename,location,md5) VALUES('{0}','{1}','{2}','{3}','{4}','{5}')" -f $computername,$itemname,$launchstring,$filename,$location,$hash
		$cmd.executenonquery()
	}
	if($txtOutputFile -or $httpOutputUrl -or $sqlConnectString){}
	else { write-host $output }
}

if($sqlConnectString){
    ## Close the database connection
    $conn.close()
}

## Delete this file because it contains a (mostly useless) database username and password
if($cleanup){
    #Invoke-Command -Computer $computerName -ScriptBlock { remove-Item c:\autorunsc.exe }
	remove-Item $cwd\autorunsc.exe
	remove-Item $cwd\autoruns.ps1
}
