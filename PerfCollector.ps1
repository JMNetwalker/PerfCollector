﻿#----------------------------------------------------------------
# Application: Performance Checker
# Propose: Inform about performance 
#----------------------------------------------------------------

#----------------------------------------------------------------
#Parameters 
#----------------------------------------------------------------
param($server = "", #ServerName parameter to connect 
      $user = "", #UserName parameter  to connect
      $passwordSecure = "", #Password Parameter  to connect
      $Db = "", #DBName Parameter  to connect
      $Folder = "C:\PerfChecker") #Folder Paramater to save the log and solution files 


#-------------------------------------------------------------------------------
# Check the statistics status
# 1.- Review if number of rows is different of rows_sampled
# 2.- Review if we have more than 15 days that the statistics have been updated.
#-------------------------------------------------------------------------------
function CheckStatistics($connection)
{
 try
 {
   logMsg( "---- Checking Statistics health (Started) ---- " ) (1)
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
       logMsg("Table: " + $Reader.GetValue(11).ToString() +"."+ $Reader.GetValue(2).ToString() + "/" + $Reader.GetValue(1).ToString() + " possible AUTO_STATS executed - REF: https://docs.microsoft.com/en-us/sql/t-sql/statements/update-statistics-transact-sql?view=sql-server-ver15" ) (2)
       logSolution("UPDATE STATISTICS [" + $Reader.GetValue(11).ToString() +"].["+ $Reader.GetValue(2).ToString() + "]([" + $Reader.GetValue(1).ToString() + "]) WITH FULLSCAN")
     }
     if( TestEmpty($Reader.GetValue(10))) {}
     else
     {
      if($Reader.GetValue(10) -gt 15) #if we have more than 15 days since the lastest update.
      {
       logMsg("Table: " + $Reader.GetValue(11).ToString() +"."+ $Reader.GetValue(2).ToString() + "/" + $Reader.GetValue(1).ToString() + " possible outdated - - REF: https://docs.microsoft.com/en-us/sql/t-sql/statements/update-statistics-transact-sql?view=sql-server-ver15" ) (2)
       logSolution("UPDATE STATISTICS [" + $Reader.GetValue(11).ToString() +"].["+ $Reader.GetValue(2).ToString() + "]([" + $Reader.GetValue(1).ToString() + "]) WITH FULLSCAN")
      }
     }
   }

   $Reader.Close();
   logMsg( "---- Checking Statistics health (Finished) ---- " ) (1)
  }
  catch
   {
    logMsg("Not able to run statistics health checker..." + $Error[0].Exception) (2)
   } 

}


#-------------------------------------------------------------------------------
# Check if we have any auto-tunning recomendations for Azure SQL DB.
#-------------------------------------------------------------------------------

function TunningRecomendations($connection)
{
 try
 {
   logMsg( "---- Checking Tuning Recomendations (Started) ---- " ) (1)
   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 60
   $command.Connection=$connection
   $command.CommandText = "select COUNT(1) from sys.dm_db_tuning_recommendations Where Execute_action_initiated_time = '1900-01-01 00:00:00.0000000'"
   $Reader = $command.ExecuteReader(); 
   while($Reader.Read())
   {
     if( $Reader.GetValue(0) -gt 0) 
     {
       logMsg("Please, review tuning recomendations in the portal" ) (2)
     }
   }

   $Reader.Close();
   logMsg( "---- Checking tuning recomendations (Finished) ---- " ) (1)
  }
  catch
   {
    logMsg("Not able to run tuning recomendations..." + $Error[0].Exception) (2)
   } 

}


#-------------------------------------------------------------------------------
# Check if the statistics associated to any index is: 
# 1.- Review if number of rows is different of rows_sampled
# 2.- Review if we have more than 15 days that the statistics have been updated.
#-------------------------------------------------------------------------------

function IndexesAndStatistics($connection)
{
 try
 {
   logMsg( "---- Checking Indexes and Statistics health (Started) ---- " ) (1)
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
       logMsg("Table/Index: " + $Reader.GetValue(11).ToString() +"."+ $Reader.GetValue(2).ToString() + "/" + $Reader.GetValue(1).ToString() + " possible AUTO_STATS executed - REF: https://docs.microsoft.com/en-us/sql/t-sql/statements/update-statistics-transact-sql?view=sql-server-ver15" ) (2)
       logSolution("ALTER INDEX [" + $Reader.GetValue(1).ToString() + "] ON [" + $Reader.GetValue(11).ToString() +"].["+ $Reader.GetValue(2).ToString() + "] REBUILD")
     }
     if( TestEmpty($Reader.GetValue(10))) {}
     else
     {
      if($Reader.GetValue(10) -gt 15)
      {
       logMsg("Table/Index: " + $Reader.GetValue(11).ToString() +"."+ $Reader.GetValue(2).ToString() + "/" + $Reader.GetValue(1).ToString() + " possible outdated - - REF: https://docs.microsoft.com/en-us/sql/t-sql/statements/update-statistics-transact-sql?view=sql-server-ver15" ) (2)
       logSolution("ALTER INDEX [" + $Reader.GetValue(1).ToString() + "] ON [" + $Reader.GetValue(11).ToString() +"].["+ $Reader.GetValue(2).ToString() + "] REBUILD")
      }
     }
   }

   $Reader.Close();
   logMsg( "---- Checking Indexes and Statistics health (Finished) ---- " ) (1)
  }
  catch
   {
    logMsg("Not able to run Indexes and statistics health checker..." + $Error[0].Exception) (2)
   } 

}

#-------------------------------------------------------------------------------
# Check if MAXDOP is 0 
#-------------------------------------------------------------------------------

function CheckScopeConfiguration($connection)
{
 try
 {
   logMsg( "---- Checking Scoped Configurations ---- " ) (1)
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
      }
     }
   }
   $Reader.Close();
   logMsg( "---- Checking Scoped Configurations (Finished) ---- " ) (1)
  }
  catch
   {
    logMsg("Not able to run Scoped Configurations..." + $Error[0].Exception) (2)
   } 

}

#-------------------------------------------------------------------------------
# Check if we have an index with more than 50% of fragmentation. 
#-------------------------------------------------------------------------------

function CheckFragmentationIndexes($connection)
{
 try
 {
   logMsg( "---- Checking Index Fragmentation ---- " ) (1)
   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 6000
   $command.Connection=$connection
   $command.CommandText = "select 
			               ObjectSchema = OBJECT_SCHEMA_NAME(idxs.object_id)
			               ,ObjectName = object_name(idxs.object_id) 
			               ,IndexName = idxs.name
			               ,i.avg_fragmentation_in_percent
		                   from sys.indexes idxs
		                   inner join sys.dm_db_index_physical_stats(DB_ID(),NULL, NULL, NULL ,'SAMPLED') i  on i.object_id = idxs.object_id and i.index_id = idxs.index_id
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
       logMsg("Table/Index: " + $Reader.GetValue(1).ToString() +"."+ $Reader.GetValue(2).ToString() + "/" + $Reader.GetValue(3).ToString() + " high fragmentation" ) (2)
     }
   }
   $Reader.Close();
   logMsg( "---- Checking Index Fragmentation (Finished) ---- " ) (1)
  }
  catch
   {
    logMsg("Not able to run Index Fragmentation..." + $Error[0].Exception) (2)
   } 

}

#----------------------------------------------------------------
#Function to connect to the database using a retry-logic
#----------------------------------------------------------------

Function GiveMeConnectionSource()
{ 
  for ($i=1; $i -lt 10; $i++)
  {
   try
    {
      logMsg( "Connecting to the database...Attempt #" + $i) (1)
      $SQLConnection = New-Object System.Data.SqlClient.SqlConnection 
      $SQLConnection.ConnectionString = "Server="+$server+";Database="+$Db+";User ID="+$user+";Password="+$password+";Connection Timeout=60;Application Name=PerfCollector" 
      $SQLConnection.Open()
      logMsg("Connected to the database...") (1)
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
         [int] $Color
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

     if($Color -eq 2)
      {
        Write-Host -ForegroundColor White -BackgroundColor Red $msg 
      } 
     else 
      {
        Write-Host -ForegroundColor $Colores $msg 
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
if (TestEmpty($Db))  { $Db = read-host -Prompt "Please enter a Database Name"  }
if (TestEmpty($Folder)) {  $Folder = read-host -Prompt "Please enter a Destination Folder (Don't include the past \) - Example c:\QdsExport" }

Function Remove-InvalidFileNameChars {

param([Parameter(Mandatory=$true,
    Position=0,
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
    [String]$Name
)

return [RegEx]::Replace($Name, "[{0}]" -f ([RegEx]::Escape([String][System.IO.Path]::GetInvalidFileNameChars())), '')}

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

logMsg("Deleting Log") (1)
   $result = DeleteFile($LogFile) #Delete Log file
   $result = DeleteFile($LogFileSolution) #Delete Log file
logMsg("Deleted Log") (1)

   $SQLConnectionSource = GiveMeConnectionSource #Connecting to the database.
   if($SQLConnectionSource -eq $null)
    { 
     logMsg("It is not possible to connect to the database") (2)
     exit;
    }

 CheckStatistics( $SQLConnectionSource)
 IndexesAndStatistics( $SQLConnectionSource)
 CheckScopeConfiguration( $SQLConnectionSource)
 CheckFragmentationIndexes($SQLConnectionSource)
 TunningRecomendations($SQLConnectionSource)
 
 logMsg("Closing the connection..") (1)
 $SQLConnectionSource.Close() 
 Remove-Variable password
 logMsg("Performance Collector Script was executed correctly")  (1)
}
catch
  {
    logMsg("Performance Collector Script was executed incorrectly ..: " + $Error[0].Exception) (2)
  }
finally
{
   logMsg("Performance Collector Script finished - Check the previous status line to know if it was success or not") (2)
} 