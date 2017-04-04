$source = "www.virusshare.com"
$type = "malicious"

$first_hashset = 0
$last_hashset = 270

## Get configuration from XML file
[xml]$Config = Get-Content "config.ioc-hunt.xml"


$conn = New-Object System.Data.SqlClient.SqlConnection
#$conn.ConnectionString = "Data Source=tcp:IP;Database=HashDB;Integrated Security=false;UID=hash_user;Password=password;"
$conn.ConnectionString = $Config.Settings.Global.SqlConnectString
$conn.open()
$cmd = New-Object System.Data.SqlClient.SqlCommand
$cmd.connection = $conn

for ($i = $first_hashset; $i -le $last_hashset; $i++) {

    $set = $i.ToString("00000")
    echo "Working on $source $set"
    $request = [System.Net.WebRequest]::Create("https://virusshare.com/hashes/VirusShare_$set.md5"); 
    $resp = $request.GetResponse();
    $reqstream = $resp.GetResponseStream()
    $sr = new-object System.IO.StreamReader $reqstream
    while ($result = $sr.ReadLine()) {
        #echo "$result $source $type"
        $cmd.commandtext = "INSERT INTO indicators (Hashes_MD5,Source,Type) VALUES('{0}','{1}','{2}')" -f $result,"$source - $set",$type
        $cmd.executenonquery()
    }
    
}
$conn.close()
