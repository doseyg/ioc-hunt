# Using files_hash

This script searches a specified path for files with specificied extensions and then hashes those files. Optionally it can also scan those files using YARA. Output to a CSV file or a SQL database.

## Default file extensions
The file extensions are hard coded, but easily changed. By default they are:
.exe,.dll,.hlp,.scr,.pif,.com,.msi,.hta,.cpl,.bat,.cmd,.scf,.inf,.reg,.job,.tmp,.ini,.bin



## Flags

### -readConfig <True|False(default)>
Use settings from config.ioc-hunt.xml (these may overwrite options provided in other flags)

### -httpOutputUrl <URL>
See run_remote_tasks documentation

### -sqlConnectString <SQL_connect_String>
See run_remote_tasks

### -txtOutputFile <File_path_name>
See run_remote_tasks documentation

### -cleanup 
Remove the script and any dependencies 

### -dependencies
List any other required files, and then exit. Checked dependencies may depend on other specified flags, such as -yara

### -yara
if specified, expect yara.exe and rules.yar in the current directory, and using yara check the file against the rules in rules.yar

### -profiles


### -homes

### -filePath <FilePath>
The path to start searching from, such as c:\users\

### maxFileSize <Bytes>
The maximum size file, in bytes, to include in hashing and output.


