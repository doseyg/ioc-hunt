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
	[string]$syslogServer,
    [string]$readConfig,
	[switch]$dependencies,
	[switch]$cleanup
)

Set-Location "C:\Windows\temp"

## Because testing of FALSE with if returns true, set it to $null instead. This is an ugly hack, maybe someday I will have a cleaner solution
if($txtOutputFile -eq 'FALSE'){$txtOutputFile = $null}
if($httpOutputUrl -eq 'FALSE'){$httpOutputUrl = $null}
if($sqlConnectString -eq 'FALSE'){$sqlConnectString = $null}
if($syslogServer -eq 'FALSE'){$syslogServer = $null}

if($readConfig){
	## Get configuration from XML file
	[xml]$Config = Get-Content "config.ioc-hunt.xml"
    #write-host "DEBUG: Using configuration file"

	## If the flag wasn't specified, use the value from the config
	if(!$txtOutputFile){$txtOutputFile = $Config.Settings.Global.textOutputFile}
	if(!$httpOutputUrl){$httpOutputUrl = $Config.Settings.Global.httpoutputUrl}
	if(!$sqlConnectString){$sqlConnectString = $Config.Settings.Global.sqlConnectString}
	if(!$syslogServer){$syslogServer = $Config.Settings.Global.syslogServer; $syslogPort = $Config.Settings.Global.syslogPort; $syslogFacility = $Config.Settings.Global.syslogFacility}
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
## Setup a connection to the syslgo server
if ($syslogServer){
	$syslogSeverity = '1'
	$timestamp = Get-Date -Format "MMM dd HH:mm:ss"
	$priority = ([int]$syslogFacility * 8) + [int]$syslogSeverity
	$Encoding = [System.Text.Encoding]::ASCII
	$TCPClient = New-Object System.Net.Sockets.TcpClient
	$TCPClient.Connect($syslogServer, $syslogPort)
	#$syslogStream = $TCPClient.GetStream()
}


## DO whatever collection, and store the results in $output

ForEach ($NameSpace in "root\subscription","root\default") { 
	$consumers = get-wmiobject -namespace $NameSpace -query "select * from __EventConsumer" 
	$filters = Get-WmiObject -Namespace $NameSpace -Query "select * from __EventFilter"
	$bindings = Get-WmiObject -Namespace $NameSpace -Query "select * from __FilterToConsumerBinding" 
	foreach($items in $consumers,$filters,$bindings){
		foreach($item in $items){
			#echo "Item is: $item"
			$name = $item.Name
			$class = $item.__Class
			$path = $item.__Path
			$query = $item.Query
			$filter = $item.Filter
			$consumer = $item.Consumer
			$commandlinetemplate = $item.CommandLineTemplate
			$output = "$computername,$name,$class,$path,$query,$filter,$consumer,$commandlinetemplate"
			$json = "{ host: $computername, Name: $name, Class: $class, Path: $path, WmiQuery: $query, WmiFilter: $filter, WmiConsumer: $consumer, WmiCommandLineTemplate: $commandlinetemplate }"
			#$json = $item | ConvertTo-Json
			#echo $json
			
			if($txtOutputFile){
				#Write-Host "Debug: writing to text file"
				Add-Content $txtOutputFile $output
			}
			## Ouput to HTTP
			if ($httpOutputUrl){
				#Write-Host "Debug: submitting to website"
				#Invoke-WebRequest "$httpOutput?$output"
				$urloutput =  [System.Convert]::ToBase64String([System.Text.Encoding]::UNICODE.GetBytes($output))
				$request = [System.Net.WebRequest]::Create("$httpOutputUrl/$urloutput");
				$resp = $request.GetResponse();
			}
			## Output to database
			if($sqlConnectString){
				#Write-Host "Debug: inserting into database"
				$cmd.commandtext = "INSERT INTO wmievent (hostname,name,class,path,query,filter,consumer,commandlinetemplate) VALUES('{0}','{1}','{2}','{3}','{4}','{5}','{6}','{7}')" -f $computername,$name,$class,$path,$query,$filter,$consumer,$commandlinetemplate
				$cmd.executenonquery()
			}
			if($syslogServer){
				#Write-Host "Debug: sending to syslog server"
				$syslogMessage = "<{0}>{1} {2} {3}" -f $priority, $timestamp, $computerName, $json
				$ByteSyslogMessage = $Encoding.GetBytes($syslogMessage)
				$TCPClient = New-Object System.Net.Sockets.TcpClient
				$TCPClient.Connect($syslogServer, $syslogPort)
				$syslogStream = $TCPClient.GetStream()
				$syslogStream.Write($ByteSyslogMessage, 0, $ByteSyslogMessage.Length)
				$syslogStream.Close()
				$TCPClient.Close()
			}
			#If no outputs are defined, write to stdout
			if($txtOutputFile -or $httpOutputUrl -or $sqlConnectString -or $syslogServer){}
			else { write-host $output }
		}
	}
}

 
 ## Close the database connection
 if($sqlConnectString){
	$conn.close()
 }
 
 ## Close the syslog connection
 if($syslogServer){
	#$syslogStream.Close()
	$TCPClient.Close()
}

 ## If the cleanup swicth was supplied, delete this file and any dependencies
 if($cleanup){
	remove-Item "$cwd\wmievent.ps1"
	if($readConfig){
		remove-item "$cwd\config.ioc-hunt.xml"
	}
 }
