$keys = "hklm:\software\microsoft\windows\currentversion\run"

## for each process, identify relevant attributes, hash it, and output
foreach ($key in $keys) {
	$properties = get-itemProperty $key
	foreach ( $property in $properties) {
	write-host "Hello $property"
	$property = $_;
	$value = (Get-ItemProperty -Path . -Name $_).$_
	#write-host "$key $property $value"}
}
$output = "$computername,$key,$property,$value`n"
