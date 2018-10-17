## VirusShare (as of 2018) requires TLS 1.2 to download the hashes. TLS 1.2 requires PowerShell version 3. Therefore this script now requires PowerShell Version 3
$source = "www.virusshare.com"
$type = "malicious"

$first_hashset = 0
$last_hashset = 337

## Get configuration from XML file
[xml]$Config = Get-Content "config.ioc-hunt.xml"


$conn = New-Object System.Data.SqlClient.SqlConnection
#$conn.ConnectionString = "Data Source=tcp:172.16.72.131;Database=IOC-Hunt;Integrated Security=false;UID=hash_user;Password=Password1;"
$conn.ConnectionString = $Config.Settings.Global.SqlConnectString
$conn.open()
$cmd = New-Object System.Data.SqlClient.SqlCommand
$cmd.connection = $conn

for ($i = $first_hashset; $i -le $last_hashset; $i++) {

    $set = $i.ToString("00000")
    echo "Working on $source $set"
	#TLS v1.2 requires Powershell version3 
	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
	
	$URI = "https://www.virusshare.com/hashes/VirusShare_$set.md5"
	echo "Downloading file $URI"
	$webpage = Invoke-WebRequest -Uri $URI -UseBasicParsing -TimeoutSec 600
	echo "Download complete"
	$webpage_lines = $webpage -split "`n"
    
	ForEach ($result in $webpage_lines) {
        echo "$result $source $type"
        $cmd.commandtext = "INSERT INTO indicators (Hashes_MD5,Source,Type) VALUES('{0}','{1}','{2}')" -f $result,"$source - $set",$type
        $cmd.executenonquery()
    }
    
}
$conn.close()
