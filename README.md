# PerfCollector
Performance Collector Checker. This Powershell script has been designed with a main idea check the main topics that could impact in your database performance.
[Additional Information](https://techcommunity.microsoft.com/t5/azure-database-support-blog/lesson-learned-195-performance-health-self-check-for-azure-sql/ba-p/3277878) In this [Video](https://youtu.be/vg6S4He0rxY) you could find out more information how to use this PowerShell Script.

- **Check if the statistics** 
  + If number of rows in the statistics is different of rows_sampled.
  + If we have more than 15 days that the statistics have been updated.

- **Check if we have any auto-tuning recomendations** 

- **Check if the statistics associated to any index is:** 
  + If number of rows in the statistics is different of rows_sampled.
  + If we have more than 15 days that the statistics have been updated.

- **Check if MAXDOP is 0** 

- **Check if we have an index with more than 50% fragmented** 
- **Check if we have missing indexes** 
- **Check if we have command execution timeout** 
- **Check top 10 of wait stats** 
- **Export all the results of Query Data Store to .bcp and .xml to be able to import in a consolidate database. It is very useful when you have multiple databases in Azure SQL Managed Instance or Elastic Database Pool.**
- **Obtain resource usage per database.**
- **Total amount of space and rows per schema and table name**

Basically we need to configure the parameters:

## Connectivity

- **$server** = "xxxxx.database.windows.net" // Azure SQL Server name
- **$user** = "xxxxxx" // User Name
- **$passwordSecure** = "xxxxxx" // Password
- **$Db** = "xxxxxx"      // Database Name, if you type the value ALL, all databases will be checked.
- **$Folder** = $true     // Folder where the log file will be generated with all the issues found.
- **DropExisting** =value 1 or 0, if the previous files located on Destinatio folder will be deleted every time that you execute the process.
- **ElasticDBPoolName**. PowerShell Script will check all the databases that are associated with this elastic database pool (only for Azure SQL Database).

## Outcome

- **PerfChecker.Log** = Contains all the issues found.
- **PerfCheckerWaitStats_dbname.Log** = Contains the information about the wait stats per database.
- **Every check done will save two files**
+ Extension .Txt that contains the report of the operation done. 
+ Extension .task that contains a possible mitigation about the issue found. 
+ For the extraction of query data store this PowerShell script will generated two additional files per QDS table:
++ Extension .bcp with the information exported.
++ Extension .xml with the structure of this .bcp file.  


Enjoy!
