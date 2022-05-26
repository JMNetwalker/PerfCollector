# PerfCollector
Performance Collector Checker. This Powershell script has been designed with a main idea check the main topics that could impact in your database performance.
[Additional Information](https://techcommunity.microsoft.com/t5/azure-database-support-blog/lesson-learned-195-performance-health-self-check-for-azure-sql/ba-p/3277878)

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

Basically we need to configure the parameters:

## Connectivity

- **$server** = "xxxxx.database.windows.net" // Azure SQL Server name
- **$user** = "xxxxxx" // User Name
- **$passwordSecure** = "xxxxxx" // Password
- **$Db** = "xxxxxx"      // Database Name, if you type the value ALL, all databases will be checked.
- **$Folder** = $true     // Folder where the log file will be generated with all the issues found.

## Outcome

- **PerfChecker.Log** = Contains all the issues found.
- **PerfCheckerWaitStats_dbname.Log** = Contains the information about the wait stats per database.

Enjoy!
