# Using run_remote_tasks

The most common example looks like this: 

	.\run_remote_tasks.ps1 -syncAD -includeConfig -task windows\services.ps1 -task_args " -cleanup "



## Flags

### -task (REQUIRED)
Specify which task to run. Will list available tasks and exit if no option is supplied. The "tasks" are the powershell scripts in the tasks folder. An example task is "windows\files_hash.ps1"

### -task_args <ARGS>
Additional arguments to pass to the script. Common example is " -cleanup "

### -includeConfig
Tells the script to copy the ioc-hunt.config.xml file over to every host the script is run on. Passes the -readConfig option the called task

### -homes

### -httpOutputUrl <URL>
This isn't fully supported. Tells the task to write output to a URL. The URL is inserted into http://$httpOutputUrl/?task_process_scan=$urloutput. You'll probably need to edit code for this to work how you want. SSL and TLS are not supported.

### -profiles

### -remote_basedir
Where to put the files on the remote host. Path without drive letter, like \windows\temp\

### -resumescan
Run against the computers in computers_skipped.txt. If computers_skipped.txt does not exist, then run against computers.txt, but skip any computers in computers_completed.txt

### -sqlConnectString <SQL_connect_String>
The full SQL connection string where results should go. Each remote host will connect and upload the results, by entry. It probably makes more sense to use the config.ioc-hunt.xml file for this.

### -syncAD
Pull a list of all computers from the Active Directory domain and append them to the computers.txt file. You probably want to truncate the computers.txt file before doing this. This requires the Active Directory Modules for Windows Powershell from the Remote Server Admin Tools

### -txtOutputFile <File_path_name>
Tells the tasks to write the results to this file on the REMOTE host. The file is the full path, for example c:\Windows\Temp\myfile.txt. 

### -httpOutputUrl <URL>
This isn't fully supported. Tells the task to write output to a URL. The URL is inserted into http://$httpOutputUrl/?task_process_scan=$urloutput. You'll probably need to edit code for this to work how you want. SSL and TLS are not supported.

### -useWMI (DEFAULT)
Use WMI to execute remote commands. This flag is assumed if you don't specify a different method.

### -usePsExec
Use PsExec to execute remote commands instead of WMI. PsExec.exe must be in the dependencies folder. 

### -useWinRM
Use WinRM to execute remote commands instead of WMI. 

### -useSSH
Use SSH to execute remote commands instead of WMI. For Linux and Cisco devices.  Posh-SSH must be installed.


## Files

### config.ioc-hunt.xml
This is the config file. Not every CLI flag has an equivalent config settings, and vice-versa. There are more options in the config file than CLI flags. 

### computers.txt
A list of computers to run the task against, one hostname or IP per line

### computers_skipped.txt
A list of computers which the task could not run on. Typically because the computer is not on, or a lack of credentials

### computers_completed.txt
A list of computers the task successfully ran against. Or at least it appears the files copied and the process started.

### computers_ignore.txt
A list of computers where the task should not run. Must match the hostname or IP exactly as listed in computers.txt
