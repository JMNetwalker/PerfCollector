# PerfCollector
Performance Collector Checker. This Powershell script has been designed with a main idea check the main topics that could impact in your database(s) performance. Could be possible to use for **Single Azure SQL Database, Azure SQL Elastic Pool or Azure SQL Managed Instance**.
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
- **Total amount of space and rows per schema and system table name**

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
- **DbName_PerfCheckerWaitStats.csv** = Contains the information about the wait stats per database.
- **Every check done will save two files**
  + Extension **.Txt** that contains the report of the operation done. 
  + Extension **.task** that contains a possible mitigation about the issue found. 
  + For the extraction of query data store this PowerShell script will generated two additional files per QDS table:
    + Extension **.bcp** with the information exported.
    + Extension **.xml** with the structure of this .bcp file.  

# PerfCollectorAnalyzer
Performance Collector Analyzer. This Powershell script has been designed with a main idea to read the files generated by PerfCollector. This information will be save in an specific server and database, for further analysis
[Additional Information](https://techcommunity.microsoft.com/t5/azure-database-support-blog/lesson-learned-224-hands-on-labs-checking-the-performance-with/ba-p/3574602) In this [Video](https://www.youtube.com/watch?v=pfnSdhk4Za0) you could find out more information how to use this PowerShell Script.

Please, when you copy this PowerShell Script in your local environment copy also GenerateTableFromXMLFormatFile.sql. This file is neccesary at the moment of the creation of BCP tables.

## Connectivity

- **$server** = "xxxxx.database.windows.net" // SQL Server name to save the data imported from the files.
- **$user** = "xxxxxx" // User Name
- **$passwordSecure** = "xxxxxx" // Password
- **$Db** = "xxxxxx"      // Database Name, suggested always to use an empty.
- **$Folder** = $true     // Folder where the log file are located. If this parameter is empty a new folder will ask.
- **GenerateTableFromXMLFormatFile.sql** //This file is neccesary to read the QDS file.

## Outcome

In the database created we are gone 
- **_CheckCommandTimeout.Txt** = Contains all information about command timeout ocurred for the databases.
- **_CheckFragmentationIndexes.Txt** = Contains all information about fragmented indexes per database.
- **_CheckIndexesStatistics.Txt** = Contains all information about statistics associated with indexes per database.
- **_CheckMissingIndexes.Txt** = Contains all information about missing indexes per database.
- **_CheckStatistics.Txt** = Contains all information about statistics per database.
- **_CheckTunningRecomendation.Txt** = Contains all information about tuning recomendations per database.
- **_ResourceUsage.Txt** = Contains all information about resources stats per database.
- **_TableSize.Txt** = Contains all information about tables sizes per table per database.
- **_SystemTableSize.Txt** = Contains all information about tables sizes per system table per database.
- **_xTotalxAcummulatedx_xQDSx_xyz** = Contains all information about Query Data Store accumulated per database.

Enjoy!
