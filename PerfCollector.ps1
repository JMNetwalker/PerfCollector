#----------------------------------------------------------------
# Application: Performance Checker
# Propose: Inform about performance recomendations
# Checks:
#    1) Check if the statistics
#        If number of rows in the statistics is different of rows_sampled.
#        If we have more than 15 days that the statistics have been updated.
#    2) Check if we have any auto-tuning recomendations
#    3) Check if the statistics associated to any index is:
#       If number of rows in the statistics is different of rows_sampled.
#       If we have more than 15 days that the statistics have been updated.
#    4) Check if MAXDOP is 0
#    5) Check if we have an index with more than 50% fragmented
#    6) Check if we have missing indexes (SQL Server Instance)
#    7) Check TSQL command execution timeouts using querying QDS
#    8) Obtain the top 10 of wait stats from QDS.
# Outcomes: 
#    In the folder specified in $Folder variable we are going to have a file called PerfChecker.Log that contains all the operations done 
#    and issues found.
#----------------------------------------------------------------

#----------------------------------------------------------------
#Parameters 
#----------------------------------------------------------------
param($server = "", #ServerName parameter to connect,for example, myserver.database.windows.net
      $user = "", #UserName parameter  to connect
      $passwordSecure = "", #Password Parameter  to connect
      $Db = "", #DBName Parameter  to connect
      $Folder = "c:\PerfChecker") #Folder Parameter to save the log and solution files, for example, c:\PerfChecker


#-------------------------------------------------------------------------------
# Check the statistics status
# 1.- Review if number of rows is different of rows_sampled
# 2.- Review if we have more than 15 days that the statistics have been updated.
#-------------------------------------------------------------------------------
function CheckStatistics($connection)
{
 try
 {
   $Item=0
   logMsg( "---- Checking Statistics health (Started) (REF: https://docs.microsoft.com/en-us/sql/t-sql/statements/update-statistics-transact-sql?view=sql-server-ver15)---- " ) (1)
   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 60
   $command.Connection=$connection
   $command.CommandText = "SELECT sp.stats_id, stat.name, o.name, filter_definition, last_updated, rows, rows_sampled, steps, unfiltered_rows, modification_counter,  DATEDIFF(DAY, last_updated , getdate()) AS Diff, schema_name(o.schema_id) as SchemaName
                           FROM sys.stats AS stat   
                           Inner join sys.objects o on stat.object_id=o.object_id
                           CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp  
                           WHERE o.type = 'U' AND stat.auto_created ='1' or stat.user_created='1' order by o.name, stat.name"
  $Reader = $command.ExecuteReader(); 
  while($Reader.Read())
   {
     if( $Reader.GetValue(5) -gt $Reader.GetValue(6)) #If number rows is different rows_sampled
     {
       $Item=$Item+1
       logMsg("Table/statistics: " + $Reader.GetValue(11).ToString() +"."+ $Reader.GetValue(2).ToString() + "/" + $Reader.GetValue(1).ToString() + " possible outdated (Rows_Sampled is less than rows of the table)") (2)
       logSolution("UPDATE STATISTICS [" + $Reader.GetValue(11).ToString() +"].["+ $Reader.GetValue(2).ToString() + "]([" + $Reader.GetValue(1).ToString() + "]) WITH FULLSCAN")
     }
     if( TestEmpty($Reader.GetValue(10))) {}
     else
     {
      if($Reader.GetValue(10) -gt 15) #if we have more than 15 days since the lastest update.
      {
       $Item=$Item+1
       logMsg("Table/statistics: " + $Reader.GetValue(11).ToString() +"."+ $Reader.GetValue(2).ToString() + "/" + $Reader.GetValue(1).ToString() + " possible outdated (15 days since the latest update).") (2)
       logSolution("UPDATE STATISTICS [" + $Reader.GetValue(11).ToString() +"].["+ $Reader.GetValue(2).ToString() + "]([" + $Reader.GetValue(1).ToString() + "]) WITH FULLSCAN")
      }
     }
   }

   $Reader.Close();
   logMsg( "---- Checking Statistics health (Finished) ---- " ) (1)
   return $Item
  }
  catch
   {
    logMsg("Not able to run statistics health checker..." + $Error[0].Exception) (2)
    return 0
   } 

}


#-------------------------------------------------------------------------------
# Check if we have any auto-tunning recomendations for Azure SQL DB.
#-------------------------------------------------------------------------------

function CheckTunningRecomendations($connection)
{
 try
 {
   $Item=0
   logMsg( "---- Checking Tuning Recomendations (Started) Ref: https://docs.microsoft.com/en-us/azure/azure-sql/database/automatic-tuning-overview ---- " ) (1)
   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 60
   $command.Connection=$connection
   $command.CommandText = "select COUNT(1) from sys.dm_db_tuning_recommendations Where Execute_action_initiated_time = '1900-01-01 00:00:00.0000000'"
   $Reader = $command.ExecuteReader(); 
   while($Reader.Read())
   {
     if( $Reader.GetValue(0) -gt 0) 
     {
       $Item=$Item+1
       logMsg("----- Please, review tuning recomendations in the portal" ) (2)
     }
   }

   $Reader.Close();
   logMsg( "---- Checking tuning recomendations (Finished) ---- " ) (1)
   return $Item
  }
  catch
   {
    logMsg("Not able to run tuning recomendations..." + $Error[0].Exception) (2)
    return 0
   } 

}

#-------------------------------------------------------------------------------
# Check if you have any query that gave a command execution timeout.
#-------------------------------------------------------------------------------

function CheckCommandTimeout($connection)
{
 try
 {
   $Item=0
   logMsg( "---- Checking Command Timeout Execution (Started) Ref: https://docs.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-transact-sql?view=sql-server-ver15---- " ) (1)
   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 6000
   $command.Connection=$connection
   $command.CommandText = "SELECT
                           qst.query_sql_text,
                           qrs.execution_type,
                           qrs.execution_type_desc,
                           qpx.query_plan_xml,
                           qrs.count_executions,
                           qrs.last_execution_time
                           FROM sys.query_store_query AS qsq
                           JOIN sys.query_store_plan AS qsp on qsq.query_id=qsp.query_id
                           JOIN sys.query_store_query_text AS qst on qsq.query_text_id=qst.query_text_id
                           OUTER APPLY (SELECT TRY_CONVERT(XML, qsp.query_plan) AS query_plan_xml) AS qpx
                           JOIN sys.query_store_runtime_stats qrs on qsp.plan_id = qrs.plan_id
                           WHERE qrs.execution_type =3
                           ORDER BY qrs.last_execution_time DESC;"
      
   $Reader = $command.ExecuteReader(); 
   while($Reader.Read())
   {
       $Item=$Item+1
       logMsg("----- Please, review the following command timeout execution --------------- " ) (2)
       logMsg("----- Execution Type     : " + $Reader.GetValue(1).ToString() + "-" + $Reader.GetValue(2).ToString()) (2)
       logMsg("----- Execution Count    : " + $Reader.GetValue(4).ToString() + "- Last Execution Time: " + $Reader.GetValue(5).ToString()) (2)
       logMsg("----- TSQL               : " + $Reader.GetValue(0).ToString() ) (2)
       logMsg("----- Execution Plan XML : " + $Reader.GetValue(3).ToString() ) (2) $false
       logMsg("-----------------------------------------------------------------------------" ) (2)
   }

   $Reader.Close();
   logMsg( "---- Checking Command Timeout Execution (Finished) ---- " ) (1)
   return $Item
  }
  catch
   {
    logMsg("Not able to run Command Timeout Execution..." + $Error[0].Exception) (2)
    return 0
   } 

}



#-------------------------------------------------------------------------------
# Check missing indexes.
#-------------------------------------------------------------------------------

function CheckMissingIndexes($connection)
{
 try
 {
   $Item=0
   logMsg( "---- Checking Missing Indexes (Started) Ref: https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-missing-index-groups-transact-sql?view=sql-server-ver15 ---- " ) (1)
   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 60
   $command.Connection=$connection
   $command.CommandText = "SELECT CONVERT (varchar, getdate(), 126) AS runtime,
                           mig.index_group_handle, mid.index_handle,
                           CONVERT (decimal (28,1), migs.avg_total_user_cost * migs.avg_user_impact *
                           (migs.user_seeks + migs.user_scans)) AS improvement_measure,
                           'CREATE INDEX missing_index_' + CONVERT (varchar, mig.index_group_handle) + '_' +
                           CONVERT (varchar, mid.index_handle) + ' ON ' + mid.statement + '
                           (' + ISNULL (mid.equality_columns,'')
                           + CASE WHEN mid.equality_columns IS NOT NULL
                              AND mid.inequality_columns IS NOT NULL
                           THEN ',' ELSE '' END + ISNULL (mid.inequality_columns, '')
                           + ')'
                           + ISNULL (' INCLUDE (' + mid.included_columns + ')', '') AS create_index_statement,
                           migs.*,
                           mid.database_id,
                           mid.[object_id]
                           FROM sys.dm_db_missing_index_groups AS mig
                           INNER JOIN sys.dm_db_missing_index_group_stats AS migs
                           ON migs.group_handle = mig.index_group_handle
                           INNER JOIN sys.dm_db_missing_index_details AS mid
                           ON mig.index_handle = mid.index_handle
                           ORDER BY migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) DESC"
   $Reader = $command.ExecuteReader(); 
   $bFound=$false
   $bCol=$false 
   $ColName=""
   $Content  = [System.Collections.ArrayList]@()
   while($Reader.Read())
   {
     #Obtain the columns only
     if($bCol -eq $false)
     {
      for ($iColumn=0; $iColumn -lt $Reader.FieldCount; $iColumn++) 
      {
       $bCol=$true 
       $ColName=$ColName + $Reader.GetName($iColumn).ToString() + " || "
      }
     }

    #Obtain the values of every missing indexes 
    $bFound=$true 
    $TmpContent=""
    for ($iColumn=0; $iColumn -lt $Reader.FieldCount; $iColumn++) 
     {
      $TmpContent= $TmpContent + $Reader.GetValue($iColumn).ToString() + " || "
     }
     $Content.Add($TmpContent) | Out-null
   }
   if($bFound)
   {
     logMsg( "---- Missing Indexes found ---- " ) (1)
     logMsg( $ColName ) (1)
     for ($iColumn=0; $iColumn -lt $Content.Count; $iColumn++) 
     {
      logMsg( $Content[$iColumn]) (1)
      $Item=$Item+1
     }
   }
   $Reader.Close();
   logMsg( "---- Checking missing indexes (Finished) ---- " ) (1)
   return $Item
  }
  catch
   {
    logMsg("Not able to run missing indexes..." + $Error[0].Exception) (2)
    return 0
   } 

}


#-------------------------------------------------------------------------------
# Check if the statistics associated to any index is: 
# 1.- Review if number of rows is different of rows_sampled
# 2.- Review if we have more than 15 days that the statistics have been updated.
#-------------------------------------------------------------------------------

function CheckIndexesAndStatistics($connection )
{
 try
 {
   $Item=0
   logMsg( "---- Checking Indexes and Statistics health (Started) - Reference: https://docs.microsoft.com/en-us/sql/t-sql/statements/update-statistics-transact-sql?view=sql-server-ver15 -" ) (1)
   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 60
   $command.Connection=$connection
   $command.CommandText = "SELECT ind.index_id, ind.name, o.name, stat.filter_definition, sp.last_updated, sp.rows, sp.rows_sampled, sp.steps, sp.unfiltered_rows, sp.modification_counter,  DATEDIFF(DAY, last_updated , getdate()) AS Diff, schema_name(o.schema_id) as SchemaName,*
                           from sys.indexes ind
	                       Inner join sys.objects o on ind.object_id=o.object_id
	                       inner join sys.stats stat on stat.object_id=o.object_id and stat.stats_id = ind.index_id
                           CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp  
                           WHERE o.type = 'U'  order by o.name, stat.name"
  $Reader = $command.ExecuteReader();
  while($Reader.Read())
   {
     if( $Reader.GetValue(5) -gt $Reader.GetValue(6)) #If number rows is different rows_sampled
     {
       $Item=$Item+1
       logMsg("Table/Index: " + $Reader.GetValue(11).ToString() +"."+ $Reader.GetValue(2).ToString() + "/" + $Reader.GetValue(1).ToString() + " possible outdated - (Rows_Sampled is less than rows of the table)" ) (2)
       logSolution("ALTER INDEX [" + $Reader.GetValue(1).ToString() + "] ON [" + $Reader.GetValue(11).ToString() +"].["+ $Reader.GetValue(2).ToString() + "] REBUILD")
     }
     if( TestEmpty($Reader.GetValue(10))) {}
     else
     {
      if($Reader.GetValue(10) -gt 15)
      {
       $Item=$Item+1
       logMsg("Table/Index: " + $Reader.GetValue(11).ToString() +"."+ $Reader.GetValue(2).ToString() + "/" + $Reader.GetValue(1).ToString() + " possible outdated - (15 days since the latest update)" ) (2)
       logSolution("ALTER INDEX [" + $Reader.GetValue(1).ToString() + "] ON [" + $Reader.GetValue(11).ToString() +"].["+ $Reader.GetValue(2).ToString() + "] REBUILD")
      }
     }
   }

   $Reader.Close();
   logMsg( "---- Checking Indexes and Statistics health (Finished) ---- " ) (1)
   return $Item
  }
  catch
   {
    logMsg("Not able to run Indexes and statistics health checker..." + $Error[0].Exception) (2)
    return 0
   } 

}

#-------------------------------------------------------------------------------
# Check if MAXDOP is 0 
#-------------------------------------------------------------------------------

function CheckScopeConfiguration($connection)
{
 try
 {
   $Item=0
   logMsg( "---- Checking Scoped Configurations ---- Ref: https://docs.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-scoped-configurations-transact-sql?view=sql-server-ver15" ) (1)
   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 60
   $command.Connection=$connection
   $command.CommandText = "select * from sys.database_scoped_configurations"
   $Reader = $command.ExecuteReader(); 
   while($Reader.Read())
   {
     if( $Reader.GetValue(1) -eq "MAXDOP")
     {
      if( $Reader.GetValue(2) -eq 0)
      {
       logMsg("You have MAXDOP with value 0" ) (2)
       $Item=$Item+1
      }
     }
   }
   $Reader.Close();
   logMsg( "---- Checking Scoped Configurations (Finished) ---- " ) (1)
   return $Item
  }
  catch
   {
    logMsg("Not able to run Scoped Configurations..." + $Error[0].Exception) (2)
    return 0 
   } 

}

#-------------------------------------------------------------------------------
# Check if we have an index with more than 50% of fragmentation. 
#-------------------------------------------------------------------------------

function CheckFragmentationIndexes($connection)
{
 try
 {
   $Item=0
   logMsg( "---- Checking Index Fragmentation (Note: This process may take some time and resource) - Ref: https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-index-physical-stats-transact-sql?view=sql-server-ver15 ---- " ) (1)
   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 6000
   $command.Connection=$connection
   $command.CommandText = "select 
			               ObjectSchema = OBJECT_SCHEMA_NAME(idxs.object_id)
			               ,ObjectName = object_name(idxs.object_id) 
			               ,IndexName = idxs.name
			               ,i.avg_fragmentation_in_percent
		                   from sys.indexes idxs
		                   inner join sys.dm_db_index_physical_stats(DB_ID(),NULL, NULL, NULL ,'LIMITED') i  on i.object_id = idxs.object_id and i.index_id = idxs.index_id
		                   where idxs.type in (0 /*HEAP*/,1/*CLUSTERED*/,2/*NONCLUSTERED*/,5/*CLUSTERED COLUMNSTORE*/,6/*NONCLUSTERED COLUMNSTORE*/) 
		                   and (alloc_unit_type_desc = 'IN_ROW_DATA' /*avoid LOB_DATA or ROW_OVERFLOW_DATA*/ or alloc_unit_type_desc is null /*for ColumnStore indexes*/)
		                   and OBJECT_SCHEMA_NAME(idxs.object_id) != 'sys'
		                   and idxs.is_disabled=0
		                   order by ObjectName, IndexName"
   $Reader = $command.ExecuteReader(); 
   while($Reader.Read())
   {
     if( $Reader.GetValue(3) -gt 50) #If fragmentation is greater than 50
     {
       $Item=$Item+1
       logMsg("Table/Index: " + $Reader.GetValue(1).ToString() +"."+ $Reader.GetValue(2).ToString() + "/" + $Reader.GetValue(3).ToString() + " high fragmentation" ) (2)
     }
   }
   $Reader.Close();
   logMsg( "---- Checking Index Fragmentation (Finished) ---- " ) (1)
   return $Item
  }
  catch
   {
    logMsg("Not able to run Index Fragmentation..." + $Error[0].Exception) (2)
    return 0
   } 

}

#----------------------------------------------------------------
#Function to connect to the database using a retry-logic
#----------------------------------------------------------------

Function GiveMeConnectionSource($DBs)
{ 
  for ($i=1; $i -lt 10; $i++)
  {
   try
    {
      logMsg( "Connecting to the database..." + $DBs + ". Attempt #" + $i) (1)
      $SQLConnection = New-Object System.Data.SqlClient.SqlConnection 
      $SQLConnection.ConnectionString = "Server="+$server+";Database="+$Dbs+";User ID="+$user+";Password="+$password+";Connection Timeout=60;Application Name=PerfCollector" 
      $SQLConnection.Open()
      logMsg("Connected to the database.." + $DBs) (1)
      return $SQLConnection
      break;
    }
  catch
   {
    logMsg("Not able to connect - Retrying the connection..." + $Error[0].Exception) (2)
    Start-Sleep -s 5
   }
  }
}

#--------------------------------------------------------------
#Create a folder 
#--------------------------------------------------------------
Function CreateFolder
{ 
  Param( [Parameter(Mandatory)]$Folder ) 
  try
   {
    $FileExists = Test-Path $Folder
    if($FileExists -eq $False)
    {
     $result = New-Item $Folder -type directory 
     if($result -eq $null)
     {
      logMsg("Imposible to create the folder " + $Folder) (2)
      return $false
     }
    }
    return $true
   }
  catch
  {
   return $false
  }
 }

#-------------------------------
#Create a folder 
#-------------------------------
Function DeleteFile{ 
  Param( [Parameter(Mandatory)]$FileName ) 
  try
   {
    $FileExists = Test-Path $FileNAme
    if($FileExists -eq $True)
    {
     Remove-Item -Path $FileName -Force 
    }
    return $true 
   }
  catch
  {
   return $false
  }
 }

#--------------------------------
#Log the operations
#--------------------------------
function logMsg
{
    Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string] $msg,
         [Parameter(Mandatory=$false, Position=1)]
         [int] $Color,
         [Parameter(Mandatory=$false, Position=2)]
         [boolean] $Show=$true 
    )
  try
   {
    $Fecha = Get-Date -format "yyyy-MM-dd HH:mm:ss"
    $msg = $Fecha + " " + $msg
    Write-Output $msg | Out-File -FilePath $LogFile -Append
    $Colores="White"
    $BackGround = 
    If($Color -eq 1 )
     {
      $Colores ="Cyan"
     }
    If($Color -eq 3 )
     {
      $Colores ="Yellow"
     }

     if($Color -eq 2 -And $Show -eq $true)
      {
        Write-Host -ForegroundColor White -BackgroundColor Red $msg 
      } 
     else 
      {
       if($Show -eq $true)
       {
        Write-Host -ForegroundColor $Colores $msg 
       }
      } 


   }
  catch
  {
    Write-Host $msg 
  }
}

#--------------------------------
#Log the solution
#--------------------------------
function logSolution
{
    Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string] $msg,
         [Parameter(Mandatory=$false, Position=1)]
         [int] $Color
    )
  try
   {
    Write-Output $msg | Out-File -FilePath $LogFileSolution -Append
   }
  catch
  {
    Write-Host $msg 
  }
}


#--------------------------------
#The Folder Include "\" or not???
#--------------------------------

function GiveMeFolderName([Parameter(Mandatory)]$FolderSalida)
{
  try
   {
    $Pos = $FolderSalida.Substring($FolderSalida.Length-1,1)
    If( $Pos -ne "\" )
     {return $FolderSalida + "\"}
    else
     {return $FolderSalida}
   }
  catch
  {
    return $FolderSalida
  }
}

#--------------------------------
#Validate Param
#--------------------------------
function TestEmpty($s)
{
if ([string]::IsNullOrWhitespace($s))
  {
    return $true;
  }
else
  {
    return $false;
  }
}

#--------------------------------
#Separator
#--------------------------------

function GiveMeSeparator
{
Param([Parameter(Mandatory=$true)]
      [System.String]$Text,
      [Parameter(Mandatory=$true)]
      [System.String]$Separator)
  try
   {
    [hashtable]$return=@{}
    $Pos = $Text.IndexOf($Separator)
    $return.Text= $Text.substring(0, $Pos) 
    $return.Remaining = $Text.substring( $Pos+1 ) 
    return $Return
   }
  catch
  {
    $return.Text= $Text
    $return.Remaining = ""
    return $Return
  }
}

Function Remove-InvalidFileNameChars {

param([Parameter(Mandatory=$true,
    Position=0,
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
    [String]$Name
)

return [RegEx]::Replace($Name, "[{0}]" -f ([RegEx]::Escape([String][System.IO.Path]::GetInvalidFileNameChars())), '')}

#-------------------------------------------------------------------------------
# Check queries with more waits stats querying QDS
# Save the result in a csv file on the choosen folder
# 
#-------------------------------------------------------------------------------
function Checkwaits{
 Param([Parameter(Mandatory=$true)]
       [System.String]$DBAccess,
       [Parameter(Mandatory=$true)]
       [System.String]$File)

  try {
    logMsg( "---- Checking Waits health (Started) (REF: https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-wait-stats-transact-sql?view=sql-server-ver16)---- " ) (1)
    $selectdata = "
select TOP 10 wqds.wait_category_desc,
wqds.total_query_wait_time_ms, 
wqds.avg_query_wait_time_ms, 
wqds.execution_type_desc, 
qdsp.query_id,
replace(replace(tex.query_sql_text,CHAR(13),' '),CHAR(10),' ') AS query_sql_text,
CASE
  WHEN
    wqds.wait_category_desc = 'Network IO'
      THEN
        'Please check  - ASYNC_NETWORK_IO, NET_WAITFOR_PACKET, PROXY_NETWORK_IO, EXTERNAL_SCRIPT_NETWORK_IO  - information https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-wait-stats-azure-sql-database?view=azuresqldb-current'
 WHEN
    wqds.wait_category_desc = 'Memory'
      THEN
        'Please check - RESOURCE_SEMAPHORE, CMEMTHREAD, CMEMPARTITIONED, EE_PMOLOCK, MEMORY_ALLOCATION_EXT, RESERVED_MEMORY_ALLOCATION_EXT, MEMORY_GRANT_UPDATE - information https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-wait-stats-azure-sql-database?view=azuresqldb-current'
 WHEN
    wqds.wait_category_desc = 'CPU'
      THEN
        'Please check  - SOS_SCHEDULER_YIELD  - information https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-wait-stats-azure-sql-database?view=azuresqldb-current'
		 WHEN
    wqds.wait_category_desc = 'Buffer IO'
      THEN
        'Please check - PAGEIOLATCH_% - information https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-wait-stats-azure-sql-database?view=azuresqldb-current'
		    WHEN
		   wqds.wait_category_desc = 'Idle'
      THEN
        'Please check  - SLEEP_%, LAZYWRITER_SLEEP, SQLTRACE_BUFFER_FLUSH, SQLTRACE_INCREMENTAL_FLUSH_SLEEP, SQLTRACE_WAIT_ENTRIES, FT_IFTS_SCHEDULER_IDLE_WAIT, XE_DISPATCHER_WAIT, REQUEST_FOR_DEADLOCK_SEARCH, LOGMGR_QUEUE, ONDEMAND_TASK_QUEUE, CHECKPOINT_QUEUE, XE_TIMER_EVENT - information https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-wait-stats-azure-sql-database?view=azuresqldb-current'
		ELSE
		'Please check the link for more information https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-wait-stats-azure-sql-database?view=azuresqldb-current'
END AS Recoommendation
from sys.query_store_wait_stats as wqds
join sys.query_store_plan as qdsp 
on qdsp.plan_id = wqds.plan_id
join sys.query_store_query as query
on query.query_id = qdsp.query_id
join sys.query_store_query_text as tex
on query.query_text_id = tex.query_text_id
order by total_query_wait_time_ms desc

"
               
    Invoke-Sqlcmd -ServerInstance $server -Database $DBAccess -Query $selectdata  -Username $user -Password $password -Verbose | Export-Csv $File  -Delimiter "," -NoTypeInformation
    
    logMsg( "----------------------------------------- " ) (1)
    logMsg( "---- Checking waits stats (Finished) ---- " ) (1)
    logMsg( "----------------------------------------- " ) (1)
    logMsg( "---- Please check " + $File + " to check all the information about the waits" ) (3)
    logMsg( "----------------------------------------- " ) (1)
  }
  catch {
    logMsg("Not able to run waits stats..." + $Error[0].Exception) (2)
  } 
            
}

try
{
Clear

#--------------------------------
#Check the parameters.
#--------------------------------

if (TestEmpty($server)) { $server = read-host -Prompt "Please enter a Server Name" }
if (TestEmpty($user))  { $user = read-host -Prompt "Please enter a User Name"   }
if (TestEmpty($passwordSecure))  
    {  
    $passwordSecure = read-host -Prompt "Please enter a password"  -assecurestring  
    $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($passwordSecure))
    }
else
    {$password = $passwordSecure} 
if (TestEmpty($Db))  { $Db = read-host -Prompt "Please enter a Database Name, type ALL to check all databases"  }
if (TestEmpty($Folder)) {  $Folder = read-host -Prompt "Please enter a Destination Folder (Don't include the last \) - Example c:\PerfChecker" }

$DbsArray = [System.Collections.ArrayList]::new() 


#--------------------------------
#Variables
#--------------------------------
 $CheckStatistics=0
 $CheckIndexesAndStatistics=0
 $CheckMissingIndexes=0
 $CheckScopeConfiguration=0
 $CheckTunningRecomendations=0
 $CheckFragmentationIndexes=0
 $CheckCommandTimeout=0
 $CheckWaits=0

 $TotalCheckStatistics=0
 $TotalCheckIndexesAndStatistics=0
 $TotalCheckMissingIndexes=0
 $TotalCheckScopeConfiguration=0
 $TotalCheckTunningRecomendations=0
 $TotalCheckFragmentationIndexes=0
 $TotalCheckCommandTimeout=0
 $TotalCheckWaits=0

#--------------------------------
#Run the process
#--------------------------------


logMsg("Creating the folder " + $Folder) (1)
   $result = CreateFolder($Folder) #Creating the folder that we are going to have the results, log and zip.
   If( $result -eq $false)
    { 
     logMsg("Was not possible to create the folder") (2)
     exit;
    }
logMsg("Created the folder " + $Folder) (1)

$sFolderV = GiveMeFolderName($Folder) #Creating a correct folder adding at the end \.

$LogFile = $sFolderV + "PerfChecker.Log"                  #Logging the operations.
$LogFileSolution = $sFolderV + "PerfCheckerSolution.Log"  #Logging the solution.

logMsg("Deleting Logs") (1)
   $result = DeleteFile($LogFile)         #Delete Log file
   $result = DeleteFile($LogFileSolution) #Delete Log Solution file
logMsg("Deleted Logs") (1)

if($Db -eq "ALL")
{

   $SQLConnectionSource = GiveMeConnectionSource "master" #Connecting to the database.
   if($SQLConnectionSource -eq $null)
    { 
     logMsg("It is not possible to connect to the database") (2)
     exit;
    }
   $commandDB = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $commandDB.CommandTimeout = 6000
   $commandDB.Connection=$SQLConnectionSource
   $commandDB.CommandText = "SELECT name from sys.databases where name <> 'master' order by name"
      
   $ReaderDB = $commandDB.ExecuteReader(); 
   while($ReaderDB.Read())
   {
      $DbsArray.Add($ReaderDB.GetValue(0).ToString())
   }

   $ReaderDB.Close();
   $SQLConnectionSource.Close() 
}
else
{
  $DbsArray.Add($DB)
}

 for($iDBs=0;$iDBs -lt $DbsArray.Count; $iDBs=$iDBs+1)
 {
   logMsg("Connecting to database.." + $DbsArray[$iDBs]) (1) 
   $SQLConnectionSource = GiveMeConnectionSource($DbsArray[$iDBs]) #Connecting to the database.
   if($SQLConnectionSource -eq $null)
    { 
     logMsg("It is not possible to connect to the database " + $DbsArray[$iDBs] ) (2)
     exit;
    }

     logMsg("Connected to database.." + $DbsArray[$iDBs]) (1) 

     $CheckStatistics=0
     $CheckIndexesAndStatistics=0
     $CheckMissingIndexes=0
     $CheckScopeConfiguration=0
     $CheckTunningRecomendations=0
     $CheckFragmentationIndexes=0
     $CheckCommandTimeout=0
     $CheckWaits=0

     $CheckStatistics = CheckStatistics($SQLConnectionSource)
     $CheckIndexesAndStatistics = CheckIndexesAndStatistics($SQLConnectionSource)
     $CheckMissingIndexes = CheckMissingIndexes($SQLConnectionSource)
     $CheckScopeConfiguration = CheckScopeConfiguration( $SQLConnectionSource)
     $CheckTunningRecomendations = CheckTunningRecomendations($SQLConnectionSource)
     $CheckFragmentationIndexes = CheckFragmentationIndexes($SQLConnectionSource)
     $CheckCommandTimeout = CheckCommandTimeout($SQLConnectionSource)

     $FileName=Remove-InvalidFileNameChars($DbsArray[$iDBs])

     $FileWaitStat = $sFolderV + "PerfCheckerWaitStats_" + $FileName + ".csv"    #Logging the wait stats per DB
     $result = DeleteFile($FileWaitStat)                                         #Delete Wait Stats per DB

     Checkwaits $DbsArray[$iDBs] $FileWaitStat
   
     $TotalCheckStatistics=$TotalCheckStatistics+$CheckStatistics
     $TotalCheckIndexesAndStatistics=$TotalCheckIndexesAndStatistics+$CheckIndexesAndStatistics
     $TotalCheckMissingIndexes=$TotalCheckMissingIndexes+$CheckMissingIndexes
     $TotalCheckScopeConfiguration=$TotalCheckScopeConfiguration+$CheckScopeConfiguration
     $TotalCheckTunningRecomendations=$TotalCheckTunningRecomendations+$CheckTunningRecomendations
     $TotalCheckFragmentationIndexes=$TotalCheckFragmentationIndexes+$CheckFragmentationIndexes
     $TotalCheckCommandTimeout=$TotalCheckCommandTimeout+$CheckCommandTimeout
     $TotalCheckWaits=$TotalCheckWaits+$CheckWaits
     
 
   logMsg("Closing the connection and summary for " + $DbsArray[$iDBs]) (3)
   logMsg("Number of Issues with statistics           : " + $CheckStatistics )  (1)
   logMsg("Number of Issues with statistics/indexes   : " + $CheckIndexesAndStatistics )  (1)
   logMsg("Number of Issues with Timeouts             : " + $CheckCommandTimeout )  (1)
   logMsg("Number of Issues with Indexes Fragmentation: " + $CheckFragmentationIndexes )  (1)
   logMsg("Number of Issues with Scoped Configuration : " + $CheckScopeConfiguration )  (1)
   logMsg("Number of Issues with Tuning Recomendation : " + $CheckTunningRecomendations )  (1)
   logMsg("Number of Issues with Missing Indexes      : " + $CheckMissingIndexes )  (1)
   
   $SQLConnectionSource.Close() 
 }
 Remove-Variable password
 logMsg("Performance Collector Script was executed correctly")  (3)
 logMsg("Total Number of Issues with statistics           : " + $TotalCheckStatistics )  (1)
 logMsg("Total Number of Issues with statistics/indexes   : " + $TotalCheckIndexesAndStatistics )  (1)
 logMsg("Total Number of Issues with Timeouts             : " + $TotalCheckCommandTimeout )  (1)
 logMsg("Total Number of Issues with Indexes Fragmentation: " + $TotalCheckFragmentationIndexes )  (1)
 logMsg("Total Number of Issues with Scoped Configuration : " + $TotalCheckScopeConfiguration )  (1)
 logMsg("Total Number of Issues with Tuning Recomendation : " + $TotalCheckTunningRecomendations )  (1)
 logMsg("Total Number of Issues with Missing Indexes      : " + $TotalCheckMissingIndexes )  (1)

}
catch
  {
    logMsg("Performance Collector Script was executed incorrectly ..: " + $Error[0].Exception) (2)
  }
finally
{
   logMsg("Performance Collector Script finished - Check the previous status line to know if it was success or not") (2)
} 