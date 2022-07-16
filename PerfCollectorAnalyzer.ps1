﻿
param($Folder = "C:\PerfChecker\", #Folder Parameter to save the csv files 
      $server = "", #ServerName parameter to connect,for example, myserver.database.windows.net
      $user = "", #UserName parameter  to connect
      $Db = "",
      $passwordSecure = "") #Name of the elastic DB Pool if you want to filter only by elastic DB Pool.


#-----------------------------------------------------------
# Identify if the value is empty or not
#-----------------------------------------------------------

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
      [String]$Text,
      [Parameter(Mandatory=$true)]
      [String]$Separator)
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

#-----------------------------------------------------------------------------------------------------------
#Log the operations
#-----------------------------------------------------------------------------------------------------------
function logMsg
{
    Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string] $msg, ##Message to show
         [Parameter(Mandatory=$false, Position=1)]
         [int] $Color, ##Color 
         [Parameter(Mandatory=$false, Position=2)]
         [boolean] $bShowLine=$true, ## Show the line
         [Parameter(Mandatory=$false, Position=3)]
         [string] $sFileName, ##Name of the file
         [Parameter(Mandatory=$false, Position=4)]
         [boolean] $bShowDate=$true ##Show the date
    )
  try
   {
    if($bShowDate -eq $true)
    {
      $Fecha = Get-Date -format "yyyy-MM-dd HH:mm:ss"
      $msg = $Fecha + " " + $msg
    }
    $ColorString="White"
    If($Color -eq 1 )
     {
      $ColorString ="Cyan"
     }
    If($Color -eq 3 )
     {
      $ColorString ="Yellow"
     }

     if($Color -eq 2 -And $bShowLine -eq $true)
      {
        Write-Host -ForegroundColor White -BackgroundColor Red $msg 
      } 
     else 
      {
       if($bShowLine -eq $true)
       {
        Write-Host -ForegroundColor $ColorString $msg 
       }
      } 
   }
  catch
  {
    Write-Host $msg 
  }
}

Function GiveMeConnectionSource()
{ 
  for ($i=1; $i -lt 10; $i++)
  {
   try
    {
      logMsg( "Connecting to the database..." + $Db + ". Attempt #" + $i) (1) 
      $SQLConnection = New-Object System.Data.SqlClient.SqlConnection 
      $SQLConnection.ConnectionString = "Server="+$server+";Database="+$Db+";User ID="+$user+";Password="+$password+";Connection Timeout=60;Application Name=PerfCollector" 
      $SQLConnection.Open()
      logMsg("Connected to the database.." + $Db) (1)
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
#-----------------------------------------------------------------------------------------------------------
# ReadFile_All files
#-----------------------------------------------------------------------------------------------------------

function ReadAllFiles
{
    Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string] $Folder, 
         [Parameter(Mandatory=$true, Position=1)]
         [string] $Guid,
         [Parameter(Mandatory=$true, Position=2)]
         [string] $US_PREFIX
    )

 Try
 {
    logMsg -msg "Load list of files" -Color 1
    foreach ($f in ((Get-ChildItem -Path $Folder))) 
    {
      logMsg -msg ("Reading...:" + $f.FullName ) 
        $File = [string]$f.FullName
        $FileType = GiveFileType($f) 
        $FileName = [string]$f.Name
        $DBName = GiveMeSeparator -Text $FileName -Separator "_"
        If($FileType -ne "3")
        {
          ReadFile  -File $File -TypeFile $FileType -DBName $DBName.Text $Guid
        }
        else
        {
          $AcumulatedTable = $US_PREFIX + $DBName.Remaining.Substring(0,$DBName.Remaining.Length-4)
          ReadFileBCP  -File $File -TypeFile $FileType -DBName $DBName.Text $Guid $f $AcumulatedTable
        }
      logMsg -msg ("Read...:" + $F.FullName ) 
    }
  }
  catch
  {
   return "Load list of files - Error:..." + $Error[0].Exception 
  } 
}

function GiveFileType ($f)
{

  if($f.Name -like ("*_CheckCommandTimeout.Txt*")) 
  {
   Return "0"
  }
  if($f.Name -like ("*_CheckScopeConfiguration.Txt*")) 
  {
   Return "1"
  }

  if($f.Name -like ("*_TableSize.Txt*")) 
  {
   Return "2"
  }

  if($f.Name -like ("*_CheckFragmentationIndexes.Txt*")) 
  {
   Return "4"
  }

  if($f.Name -like ("*_CheckStatistics.Txt*")) 
  {
   Return "5"
  }
  
  if($f.Name -like ("*_CheckIndexesStatistics.Txt*"))
  {
   Return "6"
  }

  if($f.Name -like ("*_CheckTunningRecomendation.Txt*"))
  {
   Return "7"
  }

  if($f.Name -like ("*_CheckMissingIndexes.Txt*"))
  {
   Return "8"
  }
  
  if($f.Name -like ("*_ResourceUsage.Txt*"))
  {
   Return "9"
  }        


  if($f.Extension -in (".bcp"))   
  {
   Return "3"
  }
    
  Return "99"
}

function ReadFileBCP
{
    Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string]$File, 
         [Parameter(Mandatory=$true, Position=1)]
         [string]$TypeFile, 
         [Parameter(Mandatory=$true, Position=2)]
         [string]$DBName,
         [Parameter(Mandatory=$true, Position=3)]
         [string]$Guid, 
         [Parameter(Mandatory=$true, Position=4)]
         [System.IO.FileSystemInfo]$f,
         [Parameter(Mandatory=$true, Position=5)]
         [string]$AcumulatedTable

    )
 Try
 {

  $SQLConnectionSource = GiveMeConnectionSource 
  if($SQLConnectionSource -eq $null)
   { 
     logMsg("It is not possible to connect to the database") (2)
     exit;
   }
  
  $Folder = $f.DirectoryName + "\" 

  $QSLoadList = [System.Collections.ArrayList]::new()
  [void]$QSLoadList.Add([QSTable]::new($f.BaseName))
    
  forEach ($item in $QSLoadList) 
  {
    $SqlCommand = "exec [dbo].[GenerateTableFromXMLFormatFile] '" + ( Get-Content -Path ($Folder + $item.xmlFile)) +"','"+ $item.TableName + "',@DropExisting=1"
    ExecuteQuery $SQLConnectionSource  $SqlCommand
    $Command="BCP " + $item.TableName  + " in " + $Folder + $item.bcpFile + " -f "+ $Folder + $item.xmlFile +" -S " +$server+" -U " + $user + " -P "+$password+" -d "+$Db
    ExecuteExpression $Command
    AcumulatedTotal $SQLConnectionSource  $item.TableName $AcumulatedTable  $DBName
  }
  
 }
 catch
  {
    logMsg("QDS Script was executed incorrectly ..: " + $Error[0].Exception) (2)
  }
 finally
 {
   logMsg("QDS Script finished - Check the previous status line to know if it was success or not") (3) 
 }
} 

function ExecuteQuery($connection,$SqlCommand)
{
 try
 {
   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 3600
   $command.Connection=$connection
   $command.CommandText = $SqlCommand
   $Reader = $command.ExecuteNonQuery(); 
   return $true
 }
  catch
  {
    return $false 
  } 
}

function ExecuteExpression($Command)
{
 try
 {
   $result = Invoke-Expression -Command $Command
   return $true
 }
  catch
  {
    logMsg("Not able to run statistics health checker..." + $Error[0].Exception) (2) 
    return $false 
  } 
}

function RecreateTable()
{
    Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string]$TableName, 
         [Parameter(Mandatory=$false, Position=1)]
         [string]$Columns, 
         [Parameter(Mandatory=$false, Position=2)]
         [boolean]$bCreated=$true
    )
 try
 {

   $connection = GiveMeConnectionSource 
   if($connection -eq $null)
    { 
     logMsg("It is not possible to connect to the database") (2)
     exit;
    }

   $TableList = [System.Collections.ArrayList]::new()

   $commandExecute = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $commandExecute.CommandTimeout = 3600
   $commandExecute.Connection=$connection

   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 3600
   $command.Connection=$connection
   $command.CommandText = "SELECT TOP 1 Name FROM sys.tables where Name = '" + $TableName + "'"
   $Reader = $command.ExecuteReader(); 

   $bFound=($Reader.HasRows)
   $Reader.Close()

   If($bFound)
   {
     $commandExecute.CommandText = "DROP TABLE [" + $TableName + "]" 
     $Null = $commandExecute.ExecuteNonQuery(); 
   }

   If($bCreated -eq $true)
   {
     $commandExecute.CommandText = "CREATE TABLE [" + $TableName + "] (" + $Columns + ")"
     $Null = $commandExecute.ExecuteNonQuery(); 
   }

  $connection.Close()
  return $true
  }
  catch
   {
    return $false
   } 

}



function DeleteAllAcumulatedData($US_PREFIX )
{
 try
 {

   $connection = GiveMeConnectionSource 
   if($connection -eq $null)
    { 
     logMsg("It is not possible to connect to the database") (2)
     exit;
    }

   $TableList = [System.Collections.ArrayList]::new()

   $commandExecute = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $commandExecute.CommandTimeout = 3600
   $commandExecute.Connection=$connection

   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 3600
   $command.Connection=$connection
   $command.CommandText = "SELECT Name FROM sys.tables where Name like '" + $US_PREFIX + "%'"
   $Reader = $command.ExecuteReader(); 

   while($Reader.Read())
   {
     $Null = $TableList.add([string]$Reader.GetValue(0))
   }
   $Reader.Close()

   foreach($Item in $TableList)
   {
     $commandExecute.CommandText = "DROP TABLE [" + $Item + "]" 
     $Null = $commandExecute.ExecuteNonQuery(); 
   }

  $connection.Close()
  return $true
  }
  catch
   {
    return $false
   } 

}

function AcumulatedTotal($connection, $TableSource, $TableTarget, $DBName )
{
 try
 {

   $commandExecute = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $commandExecute.CommandTimeout = 3600
   $commandExecute.Connection=$connection

   $commandDelete = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $commandDelete.CommandTimeout = 3600
   $commandDelete.Connection=$connection
   $commandDelete.CommandText = "DROP TABLE [" + $TableSource + "]"

   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 3600
   $command.Connection=$connection
   $command.CommandText = "SELECT TOP 1 Name FROM sys.tables where Name='" + $TableTarget + "'"
   $Reader = $command.ExecuteReader(); 

   $bFound = ($Reader.HasRows)
   $Reader.Close()
   
   If(-not $bFound)
   {
     $commandExecute.CommandText = "SELECT '" + $dbName + "' as DBName,* INTO [" + $TableTarget + "] FROM [" + $TableSource + "]" 
   }
   else
   {
     $commandExecute.CommandText = "INSERT INTO [" + $TableTarget + "] SELECT '" + $dbName + "' as DBName,* FROM [" + $TableSource + "]"
   }

   $Null = $commandExecute.ExecuteNonQuery(); 
   $Null = $commandDelete.ExecuteNonQuery(); 
  return $true
  }
  catch
   {
    return $false
   } 

}

#-----------------------------------------------------------------------------------------------------------
# ReadFile_All files
#-----------------------------------------------------------------------------------------------------------

function ReadFile
{
    Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string]$File, 
         [Parameter(Mandatory=$true, Position=1)]
         [string]$TypeFile, 
         [Parameter(Mandatory=$true, Position=2)]
         [string]$DBName,
         [Parameter(Mandatory=$true, Position=3)]
         [string]$Guid
    )
 Try
 {

  $stream_reader = New-Object System.IO.StreamReader($File)
  $line_number = 1 ##Number of lines read for the file

  $Data = $Rules = [System.Collections.ArrayList]::new() 

  $SQLConnectionSource = GiveMeConnectionSource 
  if($SQLConnectionSource -eq $null)
   { 
     logMsg("It is not possible to connect to the database") (2)
     exit;
   }

  while (($current_line =$stream_reader.ReadLine()) -ne $null) ##Read the file
  {
    $line_number++
    If( $line_number % 50 -eq 0 )
    {
      logMsg -msg ("Searching...- Line Number: " + $line_number.toString("###,####") ) 
    }

    If(-not (TestEmpty($current_line)))
     {
       $Null = $Data.Add($current_line)
     }
  }

      If($TypeFile -eq "0") 
      {
        $Null = InsertCheckCommandTimeouts $Data $SQLConnectionSource $DBName $Guid
      }

      If($TypeFile -eq "1") 
      {
        $Null = InsertCheckRecomendations $Data $SQLConnectionSource $DBName $Guid
      }

      If($TypeFile -eq "2") 
      {
        $Null = InsertCheckTableSize $Data $SQLConnectionSource $DBName $Guid
      }

      If($TypeFile -eq "4") 
      {
        $Null = InsertCheckFragmentation $Data $SQLConnectionSource $DBName $Guid
      }

      If($TypeFile -eq "5") 
      {
        $Null = InsertCheckStatistics $Data $SQLConnectionSource $DBName $Guid
      }

      If($TypeFile -eq "6") 
      {
        $Null = InsertCheckStatisticsIndexes $Data $SQLConnectionSource $DBName $Guid
      }

      If($TypeFile -eq "7") 
      {
        $Null = InsertCheckTunningRecomendation $Data $SQLConnectionSource $DBName $Guid
      }

      If($TypeFile -eq "8") 
      {
        $Null = InsertCheckMissingIndexes $Data $SQLConnectionSource $DBName $Guid
      }

      If($TypeFile -eq "9") 
      {
        $Null = InsertCheckResource $Data $SQLConnectionSource $DBName $Guid
      }

  $stream_reader.Close()
  $SQLConnectionSource.Close()
}
  catch
  {
   return "Load list of files - Error:..." + $Error[0].Exception 
  } 
}

function InsertCheckMissingIndexes($Data,$connection,$DBNAme,$Guid)
{
 try
 {

   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 3600
   $command.Connection=$connection
   $command.CommandText = "INSERT INTO [_CheckMissingIndexes.Txt] (ProcessID,DbName,improvement_measure,create_index_statement,avg_user_impact,Rest) VALUES(@Guid, @dbName,@improvement_measure,@create_index_statement,@avg_user_impact,@Rest)"
   $Null= $command.Parameters.Add("@Guid", [Data.SQLDBType]::VarChar)      
   $Null= $command.Parameters.Add("@DBName", [Data.SQLDBType]::VarChar)      
   $Null= $command.Parameters.Add("@improvement_measure", [Data.SQLDBType]::bigint)
   $Null= $command.Parameters.Add("@create_index_statement", [Data.SQLDBType]::VarChar)
   $Null= $command.Parameters.Add("@avg_user_impact", [Data.SQLDBType]::bigint)
   $Null= $command.Parameters.Add("@Rest", [Data.SQLDBType]::VarChar)

   for($i=0;$i -le $Data.Count; $i++)
   {
     if($Data[$i] -notlike "*---- Checking Missing Indexes (Started)*" -and $Data[$i] -notlike "*---- Missing Indexes found ----*" -and $Data[$i] -notlike "*---- Checking missing indexes (Finished) ----*")
       {
        If(-not (TestEmpty($Data[$i])))
        {
          $Array=$Data[$i].Split("||") 
          If($Array[0].Trim() -ne "runtime" )
          {
           $Tmp = GiveMeSeparator $Array[2] ","
           $Tmp1 = GiveMeSeparator $Array[6] ","
           $Null = $command.Parameters["@Guid"].Value = $Guid
           $Null = $command.Parameters["@DBName"].Value = $DbName
           $Null = $command.Parameters["@improvement_measure"].Value = [long]$Tmp.Text
           $Null = $command.Parameters["@create_index_statement"].Value = $Array[4]
           $Null = $command.Parameters["@avg_user_impact"].Value = [long]$Tmp1.Text
           $Null = $command.Parameters["@Rest"].Value =  $Data[$i]
           $Null = $command.ExecuteNonQuery()
          }
        }
       } 
   }    
  
   return $true
  }
  catch
   {
    logMsg("Not able to run Checking recomendations..." + $Error[0].Exception) (2)
    return $false
   } 

}


function InsertCheckTunningRecomendation($Data,$connection,$DBNAme,$Guid)
{
 try
 {

   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 3600
   $command.Connection=$connection
   $command.CommandText = "INSERT INTO [_CheckTunningRecomendation.Txt] (ProcessID,DbName,Recomendations) VALUES(@Guid, @dbName,@Recomendations)"
   $Null= $command.Parameters.Add("@Guid", [Data.SQLDBType]::VarChar)      
   $Null= $command.Parameters.Add("@DBName", [Data.SQLDBType]::VarChar)      
   $Null= $command.Parameters.Add("@Recomendations", [Data.SQLDBType]::VarChar)
   
   for($i=0;$i -le $Data.Count; $i++)
   {
     if($Data[$i] -notlike "*---- Checking Tuning Recomendations (Started)*" -and $Data[$i] -notlike "*---- Checking tuning recomendations (Finished)*")
       {
        If(-not (TestEmpty($Data[$i])))
        {
          $Null = $command.Parameters["@Guid"].Value = $Guid
          $Null = $command.Parameters["@DBName"].Value = $DbName
          $Null = $command.Parameters["@Recomendations"].Value = $Data[$i]
          $Null = $command.ExecuteNonQuery()
        }
       } 
   }    
  
   return $true
  }
  catch
   {
    logMsg("Not able to run Checking recomendations..." + $Error[0].Exception) (2)
    return $false
   } 

}


function InsertCheckRecomendations($Data,$connection,$DBNAme,$Guid)
{
 try
 {

   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 3600
   $command.Connection=$connection
   $command.CommandText = "INSERT INTO [_ScopeConfiguration.Txt] (ProcessID,DbName,Recomendations) VALUES(@Guid, @dbName,@Recomendations)"
   $Null= $command.Parameters.Add("@Guid", [Data.SQLDBType]::VarChar)      
   $Null= $command.Parameters.Add("@DBName", [Data.SQLDBType]::VarChar)      
   $Null= $command.Parameters.Add("@Recomendations", [Data.SQLDBType]::VarChar)
   
   for($i=0;$i -le $Data.Count; $i++)
   {
     if($Data[$i] -notlike "*---- Checking Scoped Configurations ----*" -and $Data[$i] -notlike "*---- Checking Scoped Configurations (Finished) ----*")
       {
        If(-not (TestEmpty($Data[$i])))
        {
          $Null = $command.Parameters["@Guid"].Value = $Guid
          $Null = $command.Parameters["@DBName"].Value = $DbName
          $Null = $command.Parameters["@Recomendations"].Value = $Data[$i]
          $Null = $command.ExecuteNonQuery()
        }
       } 
   }    
  
   return $true
  }
  catch
   {
    logMsg("Not able to run Checking recomendations..." + $Error[0].Exception) (2)
    return $false
   } 

}



function InsertCheckCommandTimeouts($Data,$connection,$DBNAme,$Guid)
{
 try
 {

   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 3600
   $command.Connection=$connection
   $command.CommandText = "INSERT INTO [_CheckCommandTimeout.Txt] (ProcessID,DbName,Time, ExecutionType,ExecutionCount,TSQL,ExecutionPlan) VALUES(@Guid, @dbName,@Time,@ExecutionType,@ExecutionCount, @TSQL, @ExecutionPlan)"
   $Null= $command.Parameters.Add("@Guid", [Data.SQLDBType]::VarChar)      
   $Null= $command.Parameters.Add("@DBName", [Data.SQLDBType]::VarChar)      
   $Null= $command.Parameters.Add("@Time", [Data.SQLDBType]::VarChar)   
   $Null= $command.Parameters.Add("@ExecutionType", [Data.SQLDBType]::VarChar)
   $Null= $command.Parameters.Add("@ExecutionCount", [Data.SQLDBType]::VarChar)
   $Null= $command.Parameters.Add("@TSQL", [Data.SQLDBType]::VarChar)
   $Null= $command.Parameters.Add("@ExecutionPlan", [Data.SQLDBType]::VarChar)
   
   for($i=0;$i -le $Data.Count; $i++)
   {
     if($Data[$i]  -like "*----- Please, review the following command timeout execution ---------------*")
       {
        $lStart=$i
        $Time = $Data[$i]
       }
     if($Data[$i] -like "*-----------------------------------------------------------------------------*")
       {
        $lEnd=$i
        $ExecutionType = $Data[$lStart+1]
        $ExecutionCount = $Data[$lStart+2]
        $TSQL = $Data[$lStart+3]
        if($lEnd-($lStart+1) -eq 4)      
        {
          $XML = $Data[$lStart+4] 
        }

        $Null = $command.Parameters["@Guid"].Value = $Guid
        $Null = $command.Parameters["@DBName"].Value = $DbName
        $Null = $command.Parameters["@Time"].Value = [string]$Time.substring(0,19)
        $Null = $command.Parameters["@ExecutionType"].Value = $ExecutionType.substring(47,$ExecutionType.Length-47)
        $Null = $command.Parameters["@ExecutionCount"].Value = $ExecutionCount.substring(47,$ExecutionCount.Length-47)
        $Null = $command.Parameters["@TSQL"].Value = $TSQL.substring(47,$TSQL.Length-47)
        $Null = $command.Parameters["@ExecutionPlan"].Value=$XML.substring(47,$XML.Length-47)
        $Null = $command.ExecuteNonQuery()

        $ExecutionType = ""
        $ExecutionCount = ""
        $TSQL = ""
        $XML = ""

       } 
   }    
  
   return $true
  }
  catch
   {
    logMsg("Not able to run Checking Status per Table..." + $Error[0].Exception) (2)
    return $false
   } 

}

function InsertCheckTableSize($Data,$connection,$DBNAme,$Guid)
{
 try
 {

   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 3600
   $command.Connection=$connection
   $command.CommandText = "INSERT INTO [_TableSize.Txt] (ProcessID,DbName,Time, [Table], Rows, Space, Used) VALUES(@Guid, @dbName,@Time, @Table,@Rows,@Space, @Used)"
   $Null= $command.Parameters.Add("@Guid", [Data.SQLDBType]::VarChar)      
   $Null= $command.Parameters.Add("@DBName", [Data.SQLDBType]::VarChar) 
   $Null= $command.Parameters.Add("@Time", [Data.SQLDBType]::VarChar)           
   $Null= $command.Parameters.Add("@Table", [Data.SQLDBType]::VarChar)   
   $Null= $command.Parameters.Add("@Rows", [Data.SQLDBType]::bigint)
   $Null= $command.Parameters.Add("@Space", [Data.SQLDBType]::bigint)
   $Null= $command.Parameters.Add("@Used", [Data.SQLDBType]::bigint)
   
   for($i=0;$i -le $Data.Count; $i++)
   {
     if($Data[$i]  -like "*---- Checking Status per Table ----*")
       {
        $lStart=$i
        $Time = $Data[$i]
       }
     else
     {
        If(-not (TestEmpty($Data[$i])) -and $i -gt 2)
        {
         $Null = $command.Parameters["@Guid"].Value = $Guid
         $Null = $command.Parameters["@DBName"].Value = $DbName
         $Null = $command.Parameters["@Time"].Value = [string]$Time.substring(0,19)
         $Null = $command.Parameters["@Table"].Value = $Data[$i].substring(0,100)
         $Null = $command.Parameters["@Rows"].Value = [long]$Data[$i].substring(101,20).Replace(".","")
         $Null = $command.Parameters["@Space"].Value = [long]$Data[$i].substring(122,20).Replace(".","")
         $Null = $command.Parameters["@Used"].Value=[long]$Data[$i].substring(142,20).Replace(".","")
         $Null = $command.ExecuteNonQuery()
        } 
      }
   }    
  
   return $true
  }
  catch
   {
    logMsg("Not able to run Checking Status per Table..." + $Error[0].Exception) (2)
    return $false
   } 

}

function InsertCheckFragmentation($Data,$connection,$DBNAme,$Guid)
{
 try
 {

   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 3600
   $command.Connection=$connection
   $command.CommandText = "INSERT INTO [_CheckFragmentationIndexes.Txt] (ProcessID,DbName,Time, [Index], Fragmentation) VALUES(@Guid, @dbName,@Time, @Index,@Fragmentation)"
   $Null= $command.Parameters.Add("@Guid", [Data.SQLDBType]::VarChar)      
   $Null= $command.Parameters.Add("@DBName", [Data.SQLDBType]::VarChar) 
   $Null= $command.Parameters.Add("@Time", [Data.SQLDBType]::VarChar)           
   $Null= $command.Parameters.Add("@Index", [Data.SQLDBType]::VarChar)   
   $Null= $command.Parameters.Add("@Fragmentation", [Data.SQLDBType]::bigint)
   
   for($i=0;$i -le $Data.Count; $i++)
   {
     if($Data[$i]  -like "*---- Checking Index Fragmentation*")
       {
        $lStart=$i
        $Time = $Data[$i]
       }
     else
     {
        If(-not (TestEmpty($Data[$i])))
        {
         $Null = $command.Parameters["@Guid"].Value = $Guid
         $Null = $command.Parameters["@DBName"].Value = $DbName
         $Null = $command.Parameters["@Time"].Value = [string]$Time.substring(0,19)
         $Null = $command.Parameters["@Index"].Value = $Data[$i].substring(124,100)
         $Temp = GiveMeSeparator -Text $Data[$i].substring(40,80) -Separator ","
         $Null = $command.Parameters["@Fragmentation"].Value = [long]$Temp.Text
         $Null = $command.ExecuteNonQuery()
        } 
      }
   }    
  
   return $true
  }
  catch
   {
    logMsg("Not able to run Checking Status per Table..." + $Error[0].Exception) (2)
    return $false
   } 

}

function InsertCheckStatistics($Data,$connection,$DBNAme,$Guid)
{
 try
 {

   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 3600
   $command.Connection=$connection
   $command.CommandText = "INSERT INTO [_CheckStatistics.Txt] (ProcessID,DbName,Time, [Statistics], Issue) VALUES(@Guid, @dbName,@Time, @Statistics,@Issue)"
   $Null= $command.Parameters.Add("@Guid", [Data.SQLDBType]::VarChar)      
   $Null= $command.Parameters.Add("@DBName", [Data.SQLDBType]::VarChar) 
   $Null= $command.Parameters.Add("@Time", [Data.SQLDBType]::VarChar)           
   $Null= $command.Parameters.Add("@Statistics", [Data.SQLDBType]::VarChar)   
   $Null= $command.Parameters.Add("@Issue", [Data.SQLDBType]::VarChar)
   
   for($i=0;$i -le $Data.Count; $i++)
   {
     if($Data[$i]  -like "*---- Checking Statistics health (Started)*")
       {
        $lStart=$i
        $Time = $Data[$i]
       }
     else
     {
        If(-not (TestEmpty($Data[$i])) -and $Data[$i] -notlike "*---- Checking Statistics health (Finished)*")
        {
         $Null = $command.Parameters["@Guid"].Value = $Guid
         $Null = $command.Parameters["@DBName"].Value = $DbName
         $Null = $command.Parameters["@Time"].Value = [string]$Time.substring(0,19)
         $Null = $command.Parameters["@Statistics"].Value = $Data[$i].substring(124,400)
         $Null = $command.Parameters["@Issue"].Value = $Data[$i].substring(20,100)
         $Null = $command.ExecuteNonQuery()
        } 
      }
   }    
  
   return $true
  }
  catch
   {
    logMsg("Not able to run Checking Status per Table..." + $Error[0].Exception) (2)
    return $false
   } 

}

function InsertCheckStatisticsIndexes($Data,$connection,$DBNAme,$Guid)
{
 try
 {

   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 3600
   $command.Connection=$connection
   $command.CommandText = "INSERT INTO [_CheckIndexesStatistics.Txt] (ProcessID,DbName,Time, [Statistics], Issue) VALUES(@Guid, @dbName,@Time, @Statistics,@Issue)"
   $Null= $command.Parameters.Add("@Guid", [Data.SQLDBType]::VarChar)      
   $Null= $command.Parameters.Add("@DBName", [Data.SQLDBType]::VarChar) 
   $Null= $command.Parameters.Add("@Time", [Data.SQLDBType]::VarChar)           
   $Null= $command.Parameters.Add("@Statistics", [Data.SQLDBType]::VarChar)   
   $Null= $command.Parameters.Add("@Issue", [Data.SQLDBType]::VarChar)
   
   for($i=0;$i -le $Data.Count; $i++)
   {
     if($Data[$i]  -like "*---- Checking Indexes and Statistics health (Started)*")
       {
        $lStart=$i
        $Time = $Data[$i]
       }
     else
     {
        If(-not (TestEmpty($Data[$i])) -and $Data[$i] -notlike "*---- Checking Indexes and Statistics health (Finished) ----*")
        {
         $Null = $command.Parameters["@Guid"].Value = $Guid
         $Null = $command.Parameters["@DBName"].Value = $DbName
         $Null = $command.Parameters["@Time"].Value = [string]$Time.substring(0,19)
         $Null = $command.Parameters["@Statistics"].Value = $Data[$i].substring(124,400)
         $Null = $command.Parameters["@Issue"].Value = $Data[$i].substring(20,100)
         $Null = $command.ExecuteNonQuery()
        } 
      }
   }    
  
   return $true
  }
  catch
   {
    logMsg("Not able to run Checking Status per Table..." + $Error[0].Exception) (2)
    return $false
   } 

}

function InsertCheckResource($Data,$connection,$DBNAme,$Guid)
{
 try
 {

   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 3600
   $command.Connection=$connection
   $command.CommandText = "INSERT INTO [_ResourceUsage.Txt] (ProcessID,DbName,Time, avg_cpu, avg_Dataio, avg_log,avg_memory, Max_workers) VALUES(@Guid, @dbName,@Time, @avg_cpu, @avg_Dataio, @avg_log, @avg_memory, @Max_workers)"
   $Null= $command.Parameters.Add("@Guid", [Data.SQLDBType]::VarChar)      
   $Null= $command.Parameters.Add("@DBName", [Data.SQLDBType]::VarChar) 
   $Null= $command.Parameters.Add("@Time", [Data.SQLDBType]::VarChar)           
   $Null= $command.Parameters.Add("@avg_cpu", [Data.SQLDBType]::bigint)   
   $Null= $command.Parameters.Add("@avg_DataIO", [Data.SQLDBType]::bigint)
   $Null= $command.Parameters.Add("@avg_Log", [Data.SQLDBType]::bigint)
   $Null= $command.Parameters.Add("@avg_Memory", [Data.SQLDBType]::bigint)
   $Null= $command.Parameters.Add("@max_workers", [Data.SQLDBType]::bigint)
   
   for($i=0;$i -le $Data.Count; $i++)
   {
     if($Data[$i]  -like "*---- Checking Status per Resources ----*")
       {
        $lStart=$i
        $Time = $Data[$i]
       }
     else
     {

        If(-not (TestEmpty($Data[$i])) -and $Data[$i] -notlike "*Time                 Avg_Cpu    Avg_DataIO Avg_Log    Avg_Memory Max_Workers*")
        {
         $Null = $command.Parameters["@Guid"].Value = $Guid
         $Null = $command.Parameters["@DBName"].Value = $DbName
         $Null = $command.Parameters["@Time"].Value = [string]$Time.substring(0,19)

         $avg_cpu = GiveMeSeparator -Text $Data[$i].substring(21,10) -Separator ","
         $avg_DataIO = GiveMeSeparator -Text $Data[$i].substring(32,10) -Separator ","
         $avg_Log = GiveMeSeparator -Text $Data[$i].substring(43,10) -Separator ","
         $avg_Memory = GiveMeSeparator -Text $Data[$i].substring(53,10) -Separator ","
         $max_workers = GiveMeSeparator -Text $Data[$i].substring(62,10) -Separator ","

         
         $Null = $command.Parameters["@avg_cpu"].Value = [int]$avg_cpu.Text
         $Null = $command.Parameters["@avg_DataIO"].Value = [int]$avg_dataIO.Text
         $Null = $command.Parameters["@avg_Log"].Value = [int]$avg_log.Text
         $Null = $command.Parameters["@avg_Memory"].Value = [int]$avg_memory.Text
         $Null = $command.Parameters["@max_workers"].Value = [int]$avg_workers.Text
         $Null = $command.ExecuteNonQuery()
        } 
      }
   }    
  
   return $true
  }
  catch
   {
    logMsg("Not able to run Checking Status per Table..." + $Error[0].Exception) (2)
    return $false
   } 

}

#-------------------------------
#Delete the file
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
#Remove invalid chars for a name of a file
#--------------------------------

Function Remove-InvalidFileNameChars {

param([Parameter(Mandatory=$true,
    Position=0,
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
    [String]$Name
)
return [RegEx]::Replace($Name, "[{0}]" -f ([RegEx]::Escape([String][System.IO.Path]::GetInvalidFileNameChars())), '')}


Class ReadDataLine
{
    [boolean]$IsHeader=$true
    [string]$ReadLine = ""
}

class QSTable {
        [string]$TableName
        [string]$bcpFile
        [string]$xmlFile
        [boolean]$Validated
    
        QSTable([string]$pTableName){
            $this.TableName = $pTableName
            $this.bcpFile = $pTableName + ".bcp"
            $this.xmlFile = $pTableName + ".xml"
        }    
   }

$US_PREFIX = "_xTotalxAcummulatedx_xQDSx_"

clear
 try
 {

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

     if(TestEmpty($Folder))
     {
        $FileBrowser = New-Object System.Windows.Forms.FolderBrowserDialog -Property 
        $null = $FileBrowser.Description = "Select a directory"
        $null = $FileBrowser.ShowNewFolderButton = $false
        $null = $FileBrowser.SelectedPath = [Environment]::GetFolderPath("Desktop")
        $Folder = $FileBrowser.SelectedPath 
        if(TestEmpty($Folder))
        { 
         logMsg -msg "Folder was not selected" -Color 2 -bSaveOnFile $false
         exit;
        }
     }
     
      logMsg -msg "-- Reading all files--" -Color 1

         $Null = DeleteAllAcumulatedData $US_PREFIX
         $Null = RecreateTable  "_TableSize.Txt" "ProcessID VARCHAR(MAX), dbName VARCHAR(MAX), Time VARCHAR(MAX), [Table] VARCHAR(MAX), Rows bigint, Space bigint, Used bigint"
         $Null = RecreateTable  "_ScopeConfiguration.Txt" "ProcessID VARCHAR(MAX), dbName VARCHAR(MAX), Recomendations VARCHAR(MAX)"
         $Null = RecreateTable  "_CheckCommandTimeout.Txt" "ProcessID VARCHAR(MAX), dbName VARCHAR(MAX), Time VARCHAR(MAX), ExecutionType VARCHAR(MAX),ExecutionCount VARCHAR(MAX),TSQL VARCHAR(MAX),ExecutionPlan VARCHAR(MAX)"
         $Null = RecreateTable  "_CheckFragmentationIndexes.Txt" "ProcessID VARCHAR(MAX), dbName VARCHAR(MAX), Time VARCHAR(MAX), [Index] VARCHAR(MAX), [Fragmentation] bigint"
         $Null = RecreateTable  "_CheckStatistics.Txt" "ProcessID VARCHAR(MAX), dbName VARCHAR(MAX), Time VARCHAR(MAX), [Statistics] VARCHAR(MAX),[Issue] VARCHAR(MAX)"
         $Null = RecreateTable  "_CheckIndexesStatistics.Txt" "ProcessID VARCHAR(MAX), dbName VARCHAR(MAX), Time VARCHAR(MAX), [Statistics] VARCHAR(MAX),[Issue] VARCHAR(MAX)"
         $Null = RecreateTable  "_CheckTunningRecomendation.Txt" "ProcessID VARCHAR(MAX), dbName VARCHAR(MAX), Recomendations VARCHAR(MAX)"         
         $Null = RecreateTable  "_CheckMissingIndexes.Txt" "ProcessID VARCHAR(MAX), dbName VARCHAR(MAX), improvement_measure bigint,create_index_statement VARCHAR(MAX),avg_user_impact bigint,Rest varchar(max)" 
         $Null = RecreateTable  "_ResourceUsage.Txt" "ProcessID VARCHAR(MAX), dbName VARCHAR(MAX), Time varchar(max), avg_cpu bigint, avg_Dataio bigint, avg_log bigint,avg_memory bigint, Max_workers bigint" 
         
         $Guid = [guid]::NewGuid().Guid
         ReadAllFiles -Folder $Folder $Guid $US_PREFIX
      logMsg -msg "-- Process Finished --" -Color 1
 }
 catch
 {
    logMsg -msg ("Error:..." + $Error[0].Exception) -Color 2
 }