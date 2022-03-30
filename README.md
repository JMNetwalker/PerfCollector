# PerfCollector
Performance Collector Checker. This Powershell script has been designed with a main idea check the main topics that could impact in your database performance.

- **Check if the statistics are outdated or has been updated automatically by SQL SERVER honored by AUTO_STATS property**

Basically we need to configure the parameters:

## Connectivity

- **$server** = "xxxxx.database.windows.net" // Azure SQL Server name
- **$user** = "xxxxxx" // User Name
- **$passwordSecure** = "xxxxxx" // Password
- **$Db** = "xxxxxx"      // Database Name
- **$Folder** = $true     // Folder where the log file will be generated with all the issues found.

Enjoy!
