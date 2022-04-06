# PerfCollector
Performance Collector Checker. This Powershell script has been designed with a main idea check the main topics that could impact in your database performance.
[Additional Information](https://techcommunity.microsoft.com/t5/azure-database-support-blog/bg-p/AzureDBSupport)

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

Basically we need to configure the parameters:

## Connectivity

- **$server** = "xxxxx.database.windows.net" // Azure SQL Server name
- **$user** = "xxxxxx" // User Name
- **$passwordSecure** = "xxxxxx" // Password
- **$Db** = "xxxxxx"      // Database Name
- **$Folder** = $true     // Folder where the log file will be generated with all the issues found.

## Outcome

- **PerfChecker.Log** = Contains all the issues found.

Enjoy!
