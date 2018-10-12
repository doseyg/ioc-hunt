###############################################################
## Glen Dosey
## Jan 2 2017
## 
## This is for powershell v2 on Windows 7,8 and 10 and should work out of the box.  
## You may need to set the execution policy to unrestricted with the command 'powershell set-executionpolicy unrestricted' before running this script
## 
#################################################################

## Collect command line parameters
Param(
	[string]$txtOutputFile,
	[string]$httpOutputUrl,
	[string]$sqlConnectString,
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

$computerName = Get-Content env:computername
$cwd = Convert-Path "."

## If the dependencies switch was supplied, return a comma seperated list of any files needed by this script, and then exit.
if ($dependencies) {
	return ""
	exit;
}

## If a SQL Connection string was supplied, setup the database connection
## #$conn.ConnectionString = "Data Source=tcp:IP_HERE;Database=HashDB;Integrated Security=false;UID=hash_user;Password=PASSWORD_HERE;"
if ($sqlConnectString){
	$conn = New-Object System.Data.SqlClient.SqlConnection
	$conn.ConnectionString = $sqlConnectString
	$conn.open()
	$cmd = New-Object System.Data.SqlClient.SqlCommand
	$cmd.connection = $conn
}



## DO whatever collection, and store the results in $output
$services = Get-WmiObject win32_service | Select-Object Name, PathName, DisplayName, StartName, StartMode, State, Description 

foreach ($service in $services){
	    $servicename = $service.Name
	    $filename = $service.PathName
        $description = $service.DisplayName
	    $state = $service.State
        $runas = $service.StartName
        $output = "$servicename,$filename,$description,$state,$runas"
		## Output to a local file
		if($txtOutputFile){
			Add-Content $txtOutputFile $output
		}
		## Ouput to HTTP
		if ($httpOutputUrl){
			#Invoke-WebRequest "$httpOutput?$output"
			$urloutput =  [System.Convert]::ToBase64String([System.Text.Encoding]::UNICODE.GetBytes($output))
			$request = [System.Net.WebRequest]::Create("$httpOutputUrl/$urloutput");
			$resp = $request.GetResponse();
		}
		## Output to database
		if($sqlConnectString){
			$cmd.commandtext = "INSERT INTO hashes (hostname,servicename,filename,description,state,runas) VALUES('{0}','{1}','{2}','{3}','{4}','{5}','{6}')" -f $computername,$servicename,$filename,$description,$state,$runas
			$cmd.executenonquery()
		}
		#If no outputs are defined, write to stdout
		if($txtOutputFile -or $httpOutputUrl -or $sqlConnectString){}
		else { write-host $output }
     
 }
 
 ## Close the database connection
 if($sqlConnectString){
	$conn.close()
 }
 

 ## If the cleanup swicth was supplied, delete this file and any dependencies
 if($cleanup){
	remove-Item "$cwd\services.ps1"
 }

