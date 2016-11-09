###############################################################
## Glen Dosey## October 24 2016
## 
## This is for powershell v2 on Windows 7,8 and 10 and should work out of the box. 
## You may need to set the execution policy to unrestricted with the command 'powershell set-executionpolicy unrestricted' before running this script## Output is to CLI unless HTTP,Text file, or SQL are specified.
#################################################################
　
Param(
    [string]$txtOutput,
    [string]$httpOutput,
    [string]$sqlOutput,
    [string]$computerName = $env:computername,
    [string]$processName,
	[string]$processId,
	[string]$baseDir,
    [switch]$autorunsc,
    [switch]$cleanup
)
              
## setup some variables
$arch = Invoke-Command -Computer $computerName -ScriptBlock { Get-WmiObject win32_processor -property AddressWidth | Select -First 1 AddressWidth -ExpandProperty AddressWidth}
$cwd = Convert-Path "."
　
## DEBUG Settings
$baseDir = "C:\Users\user\Desktop\GatherHashes\WinRM"
$remote_drive = "c"
$remote_path = "c:\"
　
$md5 = {    param($fileName);
            ## Calculate the md5 hash value
            $MD5csp = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
            $hash = [System.BitConverter]::ToString($MD5csp.ComputeHash([System.IO.File]::ReadAllBytes($fileName)))
            ## Remove - characters from hash value
            $hash = %{$hash -replace "-",""}
            $hash
}
　
　
if ($sqlOutput){    
    ## This is antiquated. The best way to get data into the database is use SQL output on the HTTP Listener    
    ## You can still configure this if you want: you will need to configure the SQL string below.    
    ## Setup a database connection     
    $conn = New-Object System.Data.SqlClient.SqlConnection    
    ####################################################    
    ## ----! Change your database settings here !---- ##    
    ####################################################    
    $conn.ConnectionString = "Data Source=tcp:IP;Database=HashDB;Integrated Security=false;UID=hash_user;Password=PASSWORD;"
    $conn.open()    
    $cmd = New-Object System.Data.SqlClient.SqlCommand    
    $cmd.connection = $conn
}
　
## Determine if Autoruns is available.
if ($autorunsc) {
    if ( Test-Path "$baseDir\autorunsc$arch.exe") {
		copy-Item "$baseDir\autorunsc$arch.exe" "\\$computerName\c`$\autorunsc.exe"
		Write-Host "autorunsc was copied from $baseDir to $computerName"
		$autorunsc_available = Invoke-Command -Computer $computerName -ScriptBlock { param ($remotepath); Test-Path "c:\autorunsc.exe" } -ArgumentList $remotepath
    }
	else { $autorunsc_available = 'FALSE'; Write-Host "autorunsc is not available in $baseDir" }
}
　
## Run the autorunsc command    
if ($autorunsc_available)
{
	$autoruns = [xml](Invoke-Command -Computer $computerName -ScriptBlock { c:\autorunsc.exe -x -a } -ArgumentList $processID ) 
}
　
　
　
## for each autorun, identify relevant attributes, scan, hash, and output
　
foreach ($item in $autoruns.autoruns.item) {
	$location = $item.location
	$launchstring = $item.launchstring
	$itenName = $item.itemname
	$filename = $item.imagepath
        $hash = ''        
　
        if($filename){
            $hash = Invoke-Command -Computer $computerName -ScriptBlock $md5 -ArgumentList $fileName
        }       
        $output = "$computername,$processname,$processID,$filename,$fileversion,$description,$product,$hash,$autorunsc_result`n"
          
        ## Output to local CSV file    
        if($txtOutput){ Add-Content $txtOutput $output }    
        ## Ouput to HTTP    
        if ($httpOutput){        
            #Invoke-WebRequest "$httpOutput`?task_process_autorunsc=$output"        
            $urloutput =  [System.Convert]::ToBase64String([System.Text.Encoding]::UNICODE.GetBytes($output))        
            $request = [System.Net.WebRequest]::Create("http://$httpOutput/`?task_process_scan=$urloutput");         
            $resp = $request.GetResponse();     
        }    
        ## Output to a database    
        if($sqlOutput){        
            $cmd.commandtext = "INSERT INTO processes (hostname,processname,processID,filename,fileversion,description,product,md5,autorunsc_result) VALUES('{0}','{1}','{2}','{3}','{4}','{5}','{6}','{7}','{8}')" -f $computername,$processname,$processID,$filename,$fileversion,$description,$product,$hash,[string]$autorunsc_result        
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
    Invoke-Command -Computer $computerName -ScriptBlock { remove-Item c:\autorunsc.exe }
}
