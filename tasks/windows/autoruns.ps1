###############################################################
## Glen Dosey <doseyg@r-networks.net>
## October 24 2016
## 
## This is for powershell v2 on Windows 7,8 and 10 and should work out of the box. 
## Output is to CLI unless HTTP,Text file, or SQL are specified.
#################################################################

Param(
	[string]$txtOutput,
	[string]$txtOutputFile,
	[string]$httpOutput,
	[string]$httpOutputUrl,
	[string]$sqlOutput,
	[string]$sqlConnectString,
	[string]$baseDir = 'c:\windows\temp\',
	[switch]$dependencies,
    [switch]$cleanup
)

## setup some variables
#$arch = Invoke-Command -Computer $computerName -ScriptBlock { Get-WmiObject win32_processor -property AddressWidth | Select -First 1 AddressWidth -ExpandProperty AddressWidth}
$arch = Get-WmiObject win32_processor -property AddressWidth | Select -First 1 AddressWidth -ExpandProperty AddressWidth
$cwd = Convert-Path "."

## DEBUG Settings
#$baseDir = "C:\Users\user\Desktop\GatherHashes\WinRM"
#$remote_drive = "c"
#$remote_path = "c:\"

if ($dependencies) {
	#write-host "autorunsc.exe"
	return "autorunsc.exe"
	exit;
}

if ($sqlOutput){     
    ## Setup a database connection     
    $conn = New-Object System.Data.SqlClient.SqlConnection    
    #$conn.ConnectionString = "Data Source=tcp:IP;Database=HashDB;Integrated Security=false;UID=hash_user;Password=PASSWORD;"
	$conn.ConnectionString = $sqlConnectString
    $conn.open()    
    $cmd = New-Object System.Data.SqlClient.SqlCommand    
    $cmd.connection = $conn
}

## Determine if Autoruns is available.
if ( Test-Path "$baseDir\autorunsc.exe") {
	#copy-Item "$baseDir\autorunsc$arch.exe" "\\$computerName\c`$\autorunsc.exe"
	#Write-Host "autorunsc was copied from $baseDir to $computerName"
	#$autorunsc_available = Invoke-Command -Computer $computerName -ScriptBlock { param ($remotepath); Test-Path "c:\autorunsc.exe" } -ArgumentList $remotepath
	$autorunsc_available = 'TRUE';
}
else { 
	$autorunsc_available = 'FALSE';
	Write-Host "autorunsc.exe is not available in $baseDir, exiting."; 
	exit; 
}


## Run the autorunsc command    
if ($autorunsc_available)
{
	#$autoruns = [xml](Invoke-Command -Computer $computerName-ScriptBlock { param ($baseDir); Invoke-Expression "$baseDir\autorunsc.exe -x -nobanner /accepteula -h" } -ArgumentList $baseDir )
	$autoruns = [xml](Invoke-Expression "$baseDir\autorunsc.exe -x -nobanner /accepteula -h")
}
else {
	Write-Host "autoruns did not run from $basedir on $computerName, exiting."
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
	if($txtOutputFile){ Add-Content $txtOutputFile $output }    
	## Ouput to HTTP    
	if ($httpOutputUrl){        
		#Invoke-WebRequest "$httpOutput`?task_process_autorunsc=$output"        
		$urloutput =  [System.Convert]::ToBase64String([System.Text.Encoding]::UNICODE.GetBytes($output))        
		$request = [System.Net.WebRequest]::Create("http://$httpOutputUrl/`?task_process_scan=$urloutput");         
		$resp = $request.GetResponse();     
	}    
	## Output to a database    
	if($sqlConnectString){        
		$cmd.commandtext = "INSERT INTO autoruns (hostname,itemname,launchstring,filename,location,md5) VALUES('{0}','{1}','{2}','{3}','{4}','{5}')" -f $computername,$itemname,$launchstring,$filename,$location,$hash
		$cmd.executenonquery()    
	}    
	if($txtoutput -or $httpOutput -or $sqlOutput){}    
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
    #Invoke-Command -Computer $computerName -ScriptBlock { remove-Item c:\autorunsc.exe }
	remove-Item \$baseDir\autorunsc.exe
	remove-Item \$baseDir\autoruns.ps1
}
