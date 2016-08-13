/*

**************************************************
*****~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
**************************************************
**** SQL Server and R Solution  - SQL Server 2016
**** 
****  This Script is for Maintenance and R Logging
**** 
**** Author: Tomaz Kastrun
**** Contact: tomaz.kastrun@gmail.com
**** Date Craeted: May 27, 2016
**** Last Update: May 30, 2016
**** The solution is free
**************************************************
*****~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
**************************************************

*/


/*


CREATE PROCEDURE  RStatsExecute 

			 @Command NVARCHAR(MAX)
			,@SourceType TINYTIN -- 1-SQL | 2-HADOOP | 3-SAS | 4-SAS | 5-txt | 6-CSV .....

			 @CommandType nvarchar(max)
			,@Mode int
			,@Comment nvarchar(max) = NULL
			,@DatabaseName nvarchar(max) = NULL
			,@SchemaName nvarchar(max) = NULL
			,@ObjectName nvarchar(max) = NULL
			,@ObjectType nvarchar(max) = NULL
			,@IndexName nvarchar(max) = NULL
			,@IndexType int = NULL
			,@StatisticsName nvarchar(max) = NULL
			,@PartitionNumber int = NULL
			,@ExtendedInfo xml = NULL
			,@LogToTable nvarchar(max)
			,@Execute nvarchar(max)

AS

......





-----------------------------
--
-- VERSION AND ROLES CHECK
--
-----------------------------

DECLARE @Error INT
DECLARE @Version DECIMAL(18,10)



SET @Error = 0
SET @Version = CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - 1) + '.' + REPLACE(RIGHT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)), LEN(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)))),'.','') AS numeric(18,10))


IF IS_SRVROLEMEMBER('sysadmin') = 0
BEGIN
  RAISERROR('You need to be a member of the SysAdmin server role to install the solution.',16,1)
  SET @Error = @@ERROR
END

SELECT @Version


/*
Çontrol for sp_configure 'external script enabled'
*/

DECLARE @ct TINYINT = 1

DECLARE @t TABLE
(
name VARCHAR(100)
,minimum tinyint
,maximum tinyint
,config_value tinyint
,run_value tinyint
)

INSERT INTO @t
EXECUTE sp_configure 'external scripts enabled'



IF @ct <> (SELECT config_value FROM @t) 
BEGIN
	EXECUTE sp_configure 'external scripts enabled', 1
	RECONFIGURE
	PRINT 'External Script enabled is now Enabled!'
END
ELSE
BEGIN
	PRINT 'External Script enabled was already enabled!'
END;


SELECT * FROM sys.dm_os_server_diagnostics_log_configurations

---------------------------
--
-- Database for Logging
-- and Misc stuff
--
---------------------------

SELECT * FROM 
	sys.objects AS ob 
INNER JOIN sys.schemas AS sc
ON ob.[schema_id] = sc.[schema_id] 
WHERE 
	ob.[type] = 'U' 
AND sc.name = 'dbo' 
AND ob.name = 'StatisticsLog'
  

SELECT * FROM 
	sys.objects AS ob 
INNER JOIN sys.schemas AS sc
ON ob.[schema_id] = sc.[schema_id] 
WHERE 
	ob.[type] = 'U' 
AND sc.name = 'dbo' 
AND ob.name = 'RevoStatistics'
  

-- ***********************************
---       LOGGING TABLE
-- ********************************** 

USE MASTER;
GO

IF EXISTS (SELECT * FROM sys.databases WHERE [name] = 'R_Logging')
DROP DATABASE R_Logging;

CREATE DATABASE [R_Logging]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'R_Logging', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL13.SQLSERVER2016RC3\MSSQL\DATA\R_Logging.mdf' , SIZE = 51200KB , FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'R_Logging_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL13.SQLSERVER2016RC3\MSSQL\DATA\R_Logging_log.ldf' , SIZE = 8192KB , FILEGROWTH = 65536KB )
GO
ALTER DATABASE [R_Logging] SET COMPATIBILITY_LEVEL = 130
GO


USE R_Logging;
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'StatisticsLog') 
BEGIN
CREATE TABLE dbo.StatisticsLog
	(
		 ID INT IDENTITY NOT NULL CONSTRAINT PK_StatisticsLog PRIMARY KEY CLUSTERED
		,DatabaseName SYSNAME NULL
		,SchemaName SYSNAME NULL
		,ObjectName SYSNAME NULL
		,ObjectType CHAR(2) NULL
		,IndexName SYSNAME NULL	
		,IndexType TINYINT NULL
		,StatisticsName SYSNAME NULL
		,PartitionNumber INT NULL
		,ExtendedInfo XML NULL
		,Command NVARCHAR(MAX) NOT NULL
		,CommandType NVARCHAR(60) NOT NULL
		,StartTime DATETIME NOT NULL
		,EndTime DATETIME NULL
		,ErrorNumber INT NULL
		,ErrorMessage NVARCHAR(MAX) NULL
	)
END
ELSE 
BEGIN
	PRINT 'Objects exists'
END;
GO




USE R_Logging;
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'RevoStatistics') 
BEGIN
CREATE TABLE dbo.RevoStatistics
	(
		 ID INT IDENTITY NOT NULL CONSTRAINT PK_RevoStats PRIMARY KEY CLUSTERED
		,StatisticsName NVARCHAR(500) NOT NULL
		,StatisticsCommand NVARCHAR(MAX) NOT NULL
		,InputDataName NVARCHAR(1000) NOT NULL
		,InputData NVARCHAR(MAX) NULL
		,InputDataType NVARCHAR(MAX) NULL -- 1 SQL, 2 CSV, 3 TXT, ....
		,InputDataStructure NVARCHAR(MAX) NULL
		,OutputData NVARCHAR(MAX) NULL
		,Parallel TINYINT NULL
	)
END
ELSE 
BEGIN
	PRINT 'Objects exists'
END;
GO
 

/*
-- SET OF CHECKS!!!!

RESULT DATA TYPES!!!!
R does not support Text, image, XML, CLR, HierarhyID, Geometry, Geography, Cursor, timestamp
,datetime2, datetimeoffset, time, nvarchar, nchar, ntext, sql_variant

drop table t1
create table t1
(id text,id2 image,id3 xml,id4 hierarchyID,id5 geometry,id6 geography --,id7 cursor
,id8 timestamp,id9 datetime2,id10 datetimeoffset,id11 time
,id12 nvarchar,id13 nchar,id14 ntext,id15 sql_variant)

*/

SELECT 
	 data_type
	,table_catalog
	,table_name
	,column_name 
FROM INFORMATION_SCHEMA.COLUMNS
WHERE 
	table_name = 'RevoStatistics' -- InputDataName
AND data_type in ('text','image','xml','geometry','geography','timestamp','datetime2','datetimeoffset','time','nvarchar','nchar','ntext','sql_variant','cursor','hierarchyid')
ORDER BY ordinal_position ASC





/*
Sequencing Support ? ? ?
set of sp_execute_external_scripts  support
*/


/*

--- WORKING DIRECTORY
R uses setwd({path to existing folder})
*/


  