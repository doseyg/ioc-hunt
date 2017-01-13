$source = "www.malc0de.com"
$type = "malicious"

$first_entry = 0
$last_entry = 1


$conn = New-Object System.Data.SqlClient.SqlConnection
####################################################
## ----! Change your database settings here !---- ##
####################################################
$conn.ConnectionString = "DataSource=tcp:10.1.10.1;Database=HashDB;IntegratedSecurity=false;UID=hash_user;Password=password;"
$conn.open()
$cmd = New-Object System.Data.SqlClient.SqlCommand
$cmd.connection = $conn

$webclient = New-Object System.Net.WebClient
$rssFeed = [xml]$webclient.DownloadString('http://malc0de.com/rss/')
#$rssFeed.rss.channel.item | Select-Object title -First 5

foreach($item in $rssFeed.rss.channel.item) {
        $title = $item.title
        $link = $item.link
        $description = $item.description
        #write-host "$title $description $link"
        $array = $description.split(",")
        $rssFields = @{}
        foreach($pair in $array){
                $subarray = $pair.split(":")
				if($subarray[0].trim() -eq "MD5"){
					$MD5 = $subarray[1].trim()
				}
                $rssFields.Add($subarray[0].trim(),$subarray[1].trim())
				$rssFields
        }
		#$cmd.commandtext = "INSERT INTO knownHashes (md5,source,type)VALUES('{0}','{1}','{2}')" -f $MD5,"$source",$type
		write-host "$MD5 $source $type"
        #$rssFields
}
exit;
