## TLS 1.2 requires PowerShell version 3. Therefore this script now requires PowerShell Version 3

Param( 
	[switch]$useBulk
)

## Get configuration from XML file
[xml]$Config = Get-Content "config.ioc-hunt.xml"


$conn = New-Object System.Data.SqlClient.SqlConnection
#$conn.ConnectionString = "Data Source=tcp:172.16.72.131;Database=IOC-Hunt;Integrated Security=false;UID=hash_user;Password=Password1;"
$conn.ConnectionString = $Config.Settings.Global.SqlConnectString
$conn.open()
$cmd = New-Object System.Data.SqlClient.SqlCommand
$cmd.connection = $conn


#TLS v1.2 requires Powershell version3 
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;

$URI = "http://www.website.net/custom.csv"
echo "Downloading file $URI"
$webpage = Invoke-WebRequest -Uri $URI -UseBasicParsing -TimeoutSec 600
echo "Download complete"
echo "Splitting webpage into list"
$webpage_lines = $webpage -split "`n"
ForEach ($result in $webpage_lines) {
	echo $result
	$list = @($result.split(","))
	$cmd.commandtext = "SET TRANSACTION ISOLATION LEVEL SERIALIZABLE; 
		 BEGIN TRANSACTION
		 UPDATE dbo.indicators SET Hashes_MD5= '"+$list[0]+"', Source = '"+$list[1]+"', Type = '"+$list[2]+"' WHERE Hashes_MD5 = '"+$list[0]+"';
		 IF @@ROWCOUNT = 0
		 BEGIN
		 INSERT INTO indicators (Hashes_MD5,Source,Type) VALUES ('"+$list[0]+"','"+$list[1]+"','"+$list[2]+"')
		 END
		 COMMIT TRANSACTION"
	$cmd.executenonquery()
}
  
$conn.close()
