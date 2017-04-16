###############################################################
## Glen Dosey <doseyg@r-networks.net>
## Mar 9 2017
## https://github.com/doseyg/ioc-hunt
## This is for powershell v2 on Windows 7,8 and 10 and should work out of the box.  
## 
## 
#################################################################

Param(
	[string]$txtOutputFile,
	[string]$httpOutputUrl,
	[string]$sqlConnectString,
	[switch]$yara,
	[switch]$cleanup,
	[switch]$dependencies,
	[string]$readConfig,
	[switch]$profiles,
	[switch]$homes,
	[string]$filePath = "c:\users",
	[string]$maxFileSize = '15000000'
)

## Because testing of FALSE with if returns true, set it to $null instead. This is an ugly hack, maybe someday I will have a cleaner solution
if($txtOutputFile -eq $false){$txtOutputFile = $null}
if($httpOutputUrl -eq $false){$httpOutputUrl = $null}
if($sqlConnectString -eq $false){$sqlConnectString = $null}

if($readConfig -eq $true){
	## Get configuration from XML file
	[xml]$Config = Get-Content "config.ioc-hunt.xml"
	
	## Map and script specific variables
	$filePath = $Config.Settings.Tasks.files_hash.filePath
	$maxFileSize = $Config.Settings.Tasks.files_hash.maxFileSize
	$homeServer = $Config.Settings.Global.homeServer
	$homePath = $Config.Settings.Global.homePath
	$profileServer = $Config.Settings.Global.profileServer
	$profilePath = $Config.Settings.Global.profilePath

	## If the flag wasn't specified, use the value from the config
	if(!$txtOutputFile){$txtOutputFile = $Config.Settings.Global.textOutputFile}
	if(!$httpOutputUrl){$httpOutputUrl = $Config.Settings.Global.httpoutputUrl}
	if(!$sqlConnectString){$sqlConnectString = $Config.Settings.Global.sqlConnectString}
}


## If the dependencies switch was supplied, return a comma seperated list of any files needed by this script, and then exit.
if ($dependencies) {
	if($yara){
		return "yara.exe,rules.yar"
	}
	else {return ""}
	exit;
}

## Setup some variables
$computerName = Get-Content env:computername
$md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
$cwd = Convert-Path "."


## If a SQL Connection string was supplied, setup the database connection
if ($sqlConnectString){
	$conn = New-Object System.Data.SqlClient.SqlConnection
	$conn.ConnectionString = $sqlConnectString
	$conn.open()
	$cmd = New-Object System.Data.SqlClient.SqlCommand
	$cmd.connection = $conn
}

## Determine if Yara is available. We should probably check system architecture here with get-wmiobject win32_processor
if($yara){
	if ( (Test-Path "$cwd\yara.exe") -and (Test-Path "$cwd\rules.yar") ) {
			$yara_available = 'TRUE'
	}
	else {
		$yara_available = 'FALSE' 
		Write-Host "yara.exe or the rules.yar file is not available in $cwd, exiting."; 
		exit; 
	}
}


$main_task = {
	## Search for specified files in $filePath
	$searchResults = (Get-ChildItem -Recurse -Force $filePath -ErrorAction SilentlyContinue | Where-Object { !($_.Attributes -match "ReparsePoint") -and ( $_.extension -eq ".exe" `
	        -or $_.extension -eq ".dll" `
	        -or $_.extension -eq ".hlp" `
	        -or $_.extension -eq ".scr" `
	        -or $_.extension -eq ".pif" `
	        -or $_.extension -eq ".com" `
	        -or $_.extension -eq ".msi" `
	        -or $_.extension -eq ".hta" `
	        -or $_.extension -eq ".cpl" `
	        -or $_.extension -eq ".bat" `
	        -or $_.extension -eq ".cmd" `
	        -or $_.extension -eq ".scf" `
	        -or $_.extension -eq ".inf" `
	        -or $_.extension -eq ".reg" `
	        -or $_.extension -eq ".job" `
	        -or $_.extension -eq ".tmp" `
	        -or $_.extension -eq ".ini" `
	        -or $_.extension -eq ".bin" ) } )

	## for each file found, determine its length and if less than 15MB, hash it, write to CSV, and insert into database
	 foreach ($file in $searchResults) {
	    $length = $file.length
	    $fileName = $file.fullName
		$hash = ""
	    if ($length -lt $maxFileSize ) {
			## Calculate the md5 hash value
			$hash = [System.BitConverter]::ToString($md5.ComputeHash([System.IO.File]::ReadAllBytes($fileName)))
			# Remove - characters from hash value
			$hash = %{$hash -replace "-",""}
			
			## Run the Yara command
			if ($yara_available){
				$yara_result = Invoke-Expression ("$cwd\yara.exe -s $cwd\rules.yar $file")
			}
			else {
				$yara_result = "not_checked"
			}
			
			
			$output = "$computername,'$fileName',$hash,$length`n"
			## write to the local CSV file
			if($txtOutputFile){
				Add-Content $txtOutputFile $output
			}
			## Ouput to HTTP
			if ($httpOutputUrl){
				#Invoke-WebRequest "$httpOutput?$output"
				$urloutput =  [System.Convert]::ToBase64String([System.Text.Encoding]::UNICODE.GetBytes($output))
				$request = [System.Net.WebRequest]::Create("$httpOutputUrl/$urloutput");
				$resp = $request.GetResponse();
			}
			## Insert into a database
			if($sqlConnectString){
				$cmd.commandtext = "INSERT INTO files (Hostname,File_Name,Hashes_MD5,Size_In_Bytes,yara_result) VALUES('{0}','{1}','{2}','{3}','{4}')" -f $computername,$fileName,$hash,$length,[string]$yara_result
				$cmd.executenonquery()
			}
			#If no outputs are defined, write to stdout
			if($txtOutputFile -or $httpOutputUrl -or $sqlConnectString){}
			else { write-host $output }
		}
	}
}
 
 if($profiles -eq $true){
	if($computerName -eq $profileServer){
		write-host "DEBUG working on profiles"
		$profiles = Get-ChildItem $profilePath | ?{ $_.PSIsContainer }
		foreach($myfilepath in $profiles){
			$filePath = $myfilePath.fullName
			&$main_task;
			Start-Sleep 5;
		}
	}
 }
 if($homes -eq $true){
 	if($computerName -eq $homeServer){
		write-host "DEBUG working on homes"
		$homes = Get-ChildItem $homePath | ?{ $_.PSIsContainer } 
		foreach($myfilepath in $homes){
			$filePath = $myfilePath.fullName
			&$main_task;
			Start-Sleep 5;
		}
	}
 }
## Run the searching and hashing
&$main_task

  
 ## Close the database connection
 if($sqlConnectString){
	$conn.close()
 }
 

 ## Delete this script and any dependencies
 if($cleanup){
	remove-Item "$cwd\yara64.exe"
	remove-Item "$cwd\yara32.exe"
	remove-Item "$cwd\rules.yar"
	remove-Item "$cwd\files_hash.ps1"
 }
