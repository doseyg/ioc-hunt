Write-host "Download and unzip the hashset from http://www.nsrl.nist.gov/Downloads.htm"
Write-host "This script will read the NSRLFile.txt hash set into the database"

$source = "NSRL RDS 2.55"
$type = ""
## Get configuration from XML file
[xml]$Config = Get-Content "config.ioc-hunt.xml"

$conn = New-Object System.Data.SqlClient.SqlConnection
#$conn.ConnectionString = "DataSource=tcp:10.1.10.1;Database=HashDB;IntegratedSecurity=false;UID=hash_user;Password=password;"
$conn.ConnectionString = $Config.Settings.Global.SqlConnectionString
$conn.open()
$cmd = New-Object System.Data.SqlClient.SqlCommand
$cmd.connection = $conn

$sr = [System.IO.File]::OpenText("NSRLFile.txt")
## We use this to skip the first line with headers
$headers = $sr.ReadLine()

## Read the file line by line and insert into database, because we don't want to do 13GB inserts
while ($result = $sr.ReadLine()) {
        $line = ConvertFrom-CSV -Header "SHA-1","MD5","CRC32","FileName","FileSize","ProductCode","OpSystemCode","SpecialCode" -InputObject $result
        #No need to insert the same hash multiple times, the NSRLFile appears to be sorted, so this is a simple fix
        if ($line.MD5 -eq $lastMD5) { Continue; }
        $lastMD5 = $line.MD5

        #write-host $line.MD5 $line.FileName
        $cmd.commandtext = "INSERT INTO indicators (Hashes_MD5,Source,Type)VALUES('{0}','{1}','{2}')" -f $line.MD5,"$source",$type
        $cmd.executenonquery()
}

$reader.Close()
$conn.close()
