
Param(
  [string]$txtOutput,
  [string]$httpOutput,
  [string]$sqlOutput
)

if ($sqlOutput){
    ## The best way to get data into the database is use SQL output here for the HTTP Output on the tasks
    ## You can still configure this if you want: you will need to configure the SQL string below.
    ## Setup a database connection 
    $conn = New-Object System.Data.SqlClient.SqlConnection
    ####################################################
    ## ----! Change your database settings here !---- ##
    ####################################################
    $conn.ConnectionString = "Data Source=tcp:IP ADDRESS HERE;Database=HashDB;Integrated Security=false;UID=hash_user;Password=PASSWORD_HERE;"
    $conn.open()
    $cmd = New-Object System.Data.SqlClient.SqlCommand
    $cmd.connection = $conn
}




    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add('http://+:8008/')
 
    $listener.Start()
 
    while ($listener.IsListening) {
 
        $context = $listener.GetContext() # blocks until request is received
        $request = $context.Request
        if ($request.Url -match '/end$') { break }
        $urloutput = $request.RawUrl
        $task = $request.QueryString
        $urloutput = $urloutput.Replace("/`?$task=","")
        $output = [System.Text.Encoding]::UNICODE.GetString([System.Convert]::FromBase64String($urloutput))
        

        ## write to the local CSV file
        if($txtOutput){
            Add-Content $txtOutput $output
        }
        ## Ouput to HTTP
        if ($httpOutput){
            #Invoke-WebRequest "$httpOutput?$output"
            $urloutput =  [System.Convert]::ToBase64String([System.Text.Encoding]::UNICODE.GetBytes($output))
            $request = [System.Net.WebRequest]::Create("http://$httpOutput/`?$task=$output"); 
            $resp = $request.GetResponse(); 
        }
        ## Insert into a database
        if($sqlOutput){
            $cmd.commandtext = "INSERT INTO processes (hostname,processname,processID,filename,fileversion,description,product,md5,yara_result) VALUES('{0}','{1}','{2}','{3}','{4}','{5}','{6}','{7}','{8}')" -f $computername,$processname,$processID,$filename,$fileversion,$description,$product,$hash,[string]$yara_result
            $cmd.executenonquery()
        }
        if($txtoutput -or $httpOutput -or $sqlOutput){}
        else { write-host $output }
               
        $response = $context.Response
        $message = "Success"
     
        [byte[]] $buffer = [System.Text.Encoding]::UTF8.GetBytes($message)
        $response.ContentLength64 = $buffer.length
        $response.StatusCode = 200
        $output = $response.OutputStream
        $output.Write($buffer, 0, $buffer.length)
        $output.Close()
        [console]::TreatControlCAsInput = $true
    }
 
    $listener.Stop()

