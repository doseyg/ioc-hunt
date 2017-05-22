### 
### Feb 22 2017
## 
##  Read in or Create Config file


#if (Test-Path "config.ioc-hunt.xml"){[xml]$Config = Get-Content "config.ioc-hunt.xml" }
#else {$Config = New-Object PSObject}   #Read in the config file


Write-host "Initial configuration script for IOC-Hunt."

if (Test-Path "config.ioc-hunt.xml"){
	Write-Host "It looks like a configuration file aready exists. This script does not support updating or editing and existing configuration." -foregroundcolor "yellow"
	$overWrite = Read-Host -Prompt 'Do you wish to continue and completely overwrite the existing configuation ? - Y or N'
	if($overWrite -ne 'Y'){Write-Host "Exiting"; exit;}
	write-host " "
}

$SQLOutput = Read-Host -Prompt 'Do you wish to configure output to a Microsot SQL Database? - Y or N'
if($SQLOutput -eq 'Y') {
		write-host " "
		Write-Host "The SQL server must already be installed and the current user must have DBowner on the IOC-Hunt database"
		$SQLHost = Read-Host -Prompt 'Enter the IP or hostname of the SQL server' 
		$SQLUser = Read-Host -Prompt 'Enter the SQL username of the user who will insert results' 
		$SQLPassword = Read-Host -Prompt 'Enter the SQL Password of the user who will insert results'  
		$SQLConnectString = "Data Source=tcp:$SQLHost;Database=IOC-hunt;Integrated Security=false;UID=$SQLUser;Password=$SQLPassword;"
		Write-Host "Using SQL Connection String:" -nonewline
		Write-Host $SQLConnectString -foregroundcolor 'green'
		##DEBUG write to file
		## Creating table XXX
		Write-Host "Be sure to create the 4 database tables using the files in the database directory."
}

write-host " "

$HTTPOutput = Read-Host -Prompt 'Do you wish to configure output to a Web server? - Y or N'
if($HTTPOutput -eq 'Y') {
		Write-Host "IOC-Hunt does not provide a web server or any CGI scripts to read content in from a web server. You must supply these."
		$HTTPHost = Read-Host -Prompt 'Enter the IP or hostname of the Web server'
}

write-host " "

$TextOutput = Read-Host -Prompt 'Do you wish to configure output to a text file (on the remote host) ? - Y or N'
if($TextOutput -eq 'Y') {
		Write-Host "IOC-Hunt will write a CSV file to the following path on each remote host. You may specify a network share assuming it allows every host to write to it."
		$TextOutputPath = Read-Host -Prompt 'Enter the full path, including drive letter and file name, of where you would like the content written.'
}

write-host " "

## Generate the configuration file. 
'<?xml version="1.0"?>' 										| Set-Content 'config.ioc-hunt.xml'
'<Settings>'  													| Add-Content 'config.ioc-hunt.xml'
'  <Global>'   													| Add-Content 'config.ioc-hunt.xml'
if($SQLOutput -eq 'Y') { "	<sqlConnectString>$SQLConnectString</sqlConnectString>"  	| Add-Content 'config.ioc-hunt.xml'}
if($TextOutput -eq 'Y') {"	<textOutputFile>$TextOutputPath</textOutputFile>" 			| Add-Content 'config.ioc-hunt.xml'}
if($HTTPOutput -eq 'Y') {"	<httpOutputUrl>http://$HTTPHost</httpOutputUrl>"  		| Add-Content 'config.ioc-hunt.xml'}
"	<excludeHostnamePattern>*-*-*</excludeHostnamePattern>"   	| Add-Content 'config.ioc-hunt.xml'
"	<fileCopySleep>15</fileCopySleep>"   						| Add-Content 'config.ioc-hunt.xml'
"	<hostBatchSize>50</hostBatchSize>"  						| Add-Content 'config.ioc-hunt.xml'
"	<hostBatchDelay>30</hostBatchDelay>"						| Add-Content 'config.ioc-hunt.xml'
"	<profileServer></profileServer>"  							| Add-Content 'config.ioc-hunt.xml'
"	<profilePath></profilePath>"  								| Add-Content 'config.ioc-hunt.xml'
"	<homeServer></homeServer>"  								| Add-Content 'config.ioc-hunt.xml'
"	<homePath></homePath>"  									| Add-Content 'config.ioc-hunt.xml'
"	<remote_basedir>\windows\temp\</remote_basedir>"  			| Add-Content 'config.ioc-hunt.xml'
" </Global>"  													| Add-Content 'config.ioc-hunt.xml'
" <Yara>"  														| Add-Content 'config.ioc-hunt.xml'
"	<ruleFile>rules.yar</ruleFile>"  							| Add-Content 'config.ioc-hunt.xml'
" </Yara>"  													| Add-Content 'config.ioc-hunt.xml'
" <Tasks>"  													| Add-Content 'config.ioc-hunt.xml'
"	<Autoruns>"  												| Add-Content 'config.ioc-hunt.xml'
"		<baseDir>C:\</baseDir>"  								| Add-Content 'config.ioc-hunt.xml'
"	</Autoruns>"  												| Add-Content 'config.ioc-hunt.xml'
"	<files_hash>"  												| Add-Content 'config.ioc-hunt.xml'
"		<filePath>C:\</filePath>"  								| Add-Content 'config.ioc-hunt.xml'
"		<maxFileSize>15000000</maxFileSize>"  					| Add-Content 'config.ioc-hunt.xml'
"	</files_hash>"  											| Add-Content 'config.ioc-hunt.xml'
" </Tasks>"  													| Add-Content 'config.ioc-hunt.xml'
" <HttpListener>"  												| Add-Content 'config.ioc-hunt.xml'
"	<httpPort>8008</httpPort>"  								| Add-Content 'config.ioc-hunt.xml'
" </HttpListener>"  											| Add-Content 'config.ioc-hunt.xml'
"</Settings>"  													| Add-Content 'config.ioc-hunt.xml'

Write-Host "Configuration file written."
Write-Host "A number of default values were included in the configuration."
Write-Host "Please review the configuration and adjust any values for your environment"