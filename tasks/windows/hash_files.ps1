###############################################################
## Glen Dosey
## Jan 2 2017
## 
## This is for powershell v2 on Windows 7,8 and 10 and should work out of the box.  
## You may need to set the execution policy to unrestricted with the command 'powershell set-executionpolicy unrestricted' before running this script
## 
#################################################################

Param(
	[string]$txtOutputFile,
	[string]$httpOutputUrl,
	[string]$sqlConnectString,
	[switch]$yara,
	[switch]$cleanup,
	[string]$filePath = "c:\",
	[string]$maxFileSize = '15000000'
)

## Because testing of FALSE with if returns true, set it to $null instead. This is an ugly hack, maybe someday I will have a cleaner solution
if($txtOutputFile -eq 'FALSE'){$txtOutputFile = $null}
if($httpOutputUrl -eq 'FALSE'){$httpOutputUrl = $null}
if($sqlConnectString -eq 'FALSE'){$sqlConnectString = $null}

$computerName = Get-Content env:computername
$md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
$cwd = Convert-Path "."

if ($dependencies) {
	if($yara){
		return "yara.exe,rules.yar"
	}
	else {return ""}
	exit;
}

if ($sqlConnectString){
	## Setup a database connection
	$conn = New-Object System.Data.SqlClient.SqlConnection
	#$conn.ConnectionString = "Data Source=tcp:IP_HERE;Database=HashDB;Integrated Security=false;UID=hash_user;Password=PASSWORD_HERE;"
	$conn.ConnectionString = $sqlConnectString
	$conn.open()
	$cmd = New-Object System.Data.SqlClient.SqlCommand
	$cmd.connection = $conn
}

## Determine if Yara is available. We should probably check system architecture here with get-wmiobject win32_processor
if($yara){
    $yara64 = Test-Path "$cwd\yara64.exe","$cwd\rules.yar"
    $yara32 = Test-Path "$cwd\yara32.exe","$cwd\rules.yar"
    if ($yara64 -eq $True -and $arch -eq '64') {
		$yara_cmd = "$cwd\yara64.exe"  }
    elseif ($yara32 -eq $True -and $arch -eq '32') {
 		$yara_cmd = "$cwd\yara32.exe" }
    else {        $yara_cmd = ''  }
}

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
     if ($length -lt $maxFileSize ) {
		## Calculate the md5 hash value
		$hash = [System.BitConverter]::ToString($md5.ComputeHash([System.IO.File]::ReadAllBytes($fileName)))
		# Remove - characters from hash value
		$hash = %{$hash -replace "-",""}
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
			$cmd.commandtext = "INSERT INTO hashes (hostname,filename,md5,size) VALUES('{0}','{1}','{2}','{3}')" -f $computername,$fileName,$hash,$length,[string]$yara_result
			$cmd.executenonquery()
		}
		#If no outputs are defined, write to stdout
		if($txtOutputFile -or $httpOutputUrl -or $sqlConnectString){}
		else { write-host $output }
     }
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
	remove-Item "$cwd\task_hash_files.ps1"
 }
