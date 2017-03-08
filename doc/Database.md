# Database Setup 

You have to use Microsoft SQL Server for the database. 


## Installation
If you don't a SQL server already, download SQL Server Express and install it (Basic Install)

You will want SQL Server Management Studio (SSMS) on your computer as well. Download and install it.

## Database Creation

Open SSMS and click connect

Right click on databases and choose new database.

Name it "IOC-Hunt". under Options set Containment to partial, then click OK to create it.

## Table Creation

Click on the new IOC-Hunt database so it it highlighted Blue, then click on New Query in the top bar.

Copy the contents of a file from the database folder into the query, and then hit Execute.
You should not get any errors, and the output should be "Command(s) completed successfully."
Repeat the above steps for the next 3 files. Make sure the Query window is empty before pasting each. 

## User Creation & Permissions

Your SQL server must be in mixed mode for authentication. If you installed SQL express, it is. If you're using an existing SQL server, ask your DBA.

	exec sp_configure 'contained database authentication', 1
	go
	reconfigure
	go

	alter database [IOC-Hunt]
	set containment = partial
	go 

Create a local (non-integrated) user named hash_user. Type this in the Query Window and then hit execute
	use [IOC-hunt]
	GO
	CREATE USER hash_user WITH PASSWORD = 'Password1'
	GO

Grant that user privileges to connect and insert.
	GRANT INSERT ON [dbo].[indicators] TO hash_user
	GRANT INSERT ON [dbo].[files] TO hash_user
	GRANT INSERT ON [dbo].[processes] TO hash_user
	GRANT INSERT ON [dbo].[autoruns] TO hash_user

Grant your users (who can be AD integrated) full permissions on ioc-hunt.

## SQL Connection String

Example:
Data Source=tcp:10.1.10.1;Database=IOC-hunt;Integrated Security=false;UID=hash_user;Password=Password1;