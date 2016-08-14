/*
**************************************************
*****~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
**************************************************
**** SQL Server and R Solution  - SQL Server 2016
**** 
****
****  R Framework for running simple statistics
****  and data analysis using 
****  sp_execute_external_script within SSMS
****
**** 
**** Author: Tomaz Kastrun
**** Contact: tomaz.kastrun@gmail.com
**** Blog: http://tomaztsql.wordpress.com
**** Twitter: @tomaz_tsql
****
**** Date Craeted: August 10, 2016
**** Last Update: August 15, 2016
**** 
**** The solution is free
**** 
**************************************************
*****~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
**************************************************
*/

/*

* R Framework Usage *

USE WideWorldImporters;
GO

EXECUTE sp_RStats
			 @QUERY = 'SELECT StockItemID, RecommendedRetailPrice, Quantity FROM WideWorldImporters.dbo.WWI_FACT_TABLE'
			,@STATS = 2
			,@ListOfVariables = 'StockItemID, RecommendedRetailPrice, Quantity'

EXECUTE sp_RStats
			 @QUERY = 'SELECT StockItemID, RecommendedRetailPrice, Quantity FROM WideWorldImporters.dbo.WWI_FACT_TABLE'
			,@STATS = 3
			,@ListOfVariables = 'StockItemID, RecommendedRetailPrice, Quantity'

*/



-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-----------------------------------------------------------------------
--
-- 1. Before installation checks 
--    SQL Server version CHECK
--    SP_CONFIGURE ('external scripts enabled', 'xp_cmdshell')  CHECK
--    ROLE db_datareader CHECK
--    
--
-----------------------------------------------------------------------
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


DECLARE @PreInstallError INT

IF (	
		SELECT LEFT(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(100)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(100)))-1) 
	) < 13
BEGIN
	RAISERROR('You need to install SQL Server 2016 version or higher.',16,1)
	SET @PreInstallError = @@ERROR
END
ELSE
BEGIN	
	PRINT 'SQL Server version OK!'
END


IF (
		SELECT CAST(value_in_use AS INT) AS run_value
		FROM sys.configurations 
		WHERE [name] = 'external scripts enabled'
	) = 0
BEGIN
	RAISERROR('You need to enable external script. Run command: EXEC SP_CONFIGURE ''external scripts enabled'',1' ,16,1)
	SET @PreInstallError = @@ERROR
END
ELSE
BEGIN	
	PRINT 'external script enabled!'
END


IF (
		SELECT CAST(value_in_use AS INT) AS run_value
		FROM sys.configurations 
		WHERE [name] = 'xp_cmdshell'
	) = 0
BEGIN
	RAISERROR('You need to enable external script. Run command: EXEC SP_CONFIGURE ''xp_cmdshell'',1' ,16,1)
	SET @PreInstallError = @@ERROR
END
ELSE
BEGIN	
	PRINT 'xp_cmdshell enabled!'
END



IF (
	SELECT IS_SRVROLEMEMBER('sysadmin') 
	) = 0
BEGIN
  RAISERROR('You need to be a member of the SysAdmin role to use R Framework.',16,1)
  SET @PreInstallError = @@ERROR
END
ELSE
BEGIN
	PRINT 'Member of sysadmin server role!'
END



-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-----------------------------------------------------------------------
--
-- 2. DATABASE, TABLES 
--    CREATE DATABASE FOR R Framework
--    CREATE Tables for statistics, libraries and logging
--    CREATE Table for command log
--    
--
-----------------------------------------------------------------------
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


USE MASTER;
GO

IF NOT EXISTS (SELECT * FROM sys.databases WHERE [name] = 'R_Framework')
-- DROP DATABASE R_Framework;

CREATE DATABASE [R_Framework]
 CONTAINMENT = NONE
GO
ALTER DATABASE [R_Framework] SET COMPATIBILITY_LEVEL = 130
GO


USE [R_Framework];
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




USE [R_Framework];
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


USE [R_Framework];
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'GeneralStatistics') 
BEGIN
CREATE TABLE dbo.GeneralStatistics
	(
		 ID INT IDENTITY NOT NULL CONSTRAINT PK_GeneralStatistics PRIMARY KEY CLUSTERED
		,StatisticsName NVARCHAR(500) NOT NULL
		,StatisticsCommand NVARCHAR(MAX) NOT NULL
		,Parallel TINYINT NULL
	)
END
ELSE 
BEGIN
	PRINT 'Objects exists'
END;
GO





USE [R_Framework];
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE [name] = 'Libraries') 
BEGIN
CREATE TABLE dbo.Libraries
	(
		 ID INT IDENTITY NOT NULL CONSTRAINT PK_RLibraries PRIMARY KEY CLUSTERED
		,Package NVARCHAR(50)
		,LibPath NVARCHAR(200)
		,[Version] NVARCHAR(20)
		,Depends NVARCHAR(200)
		,Imports NVARCHAR(200)
		,Suggests NVARCHAR(200)
		,Built NVARCHAR(20)
	)
END
ELSE 
BEGIN
	PRINT 'Objects exists'
	TRUNCATE TABLE dbo.Libraries
END;
GO


DECLARE @CurrentLogin NVARCHAR(100)
SET @CurrentLogin = SYSTEM_USER 
DECLARE @UCommand NVARCHAR(MAX)
SET @UCommand = 'EXEC sp_addrolemember ''db_datareader'', '''+@CurrentLogin+''''
DECLARE @GCommand NVARCHAR(MAX)
SET @GCommand = 'GRANT EXECUTE ANY EXTERNAL SCRIPT  TO '''+@CurrentLogin+''''

IF ((
	SELECT IS_SRVROLEMEMBER('sysadmin') 
	) = 1
AND
   (
	SELECT IS_SRVROLEMEMBER('db_datareader')
    ) = 0)
BEGIN
EXECUTE SP_EXECUTESQL @UCommand
EXECUTE SP_EXECUTESQL @GCommand
END


INSERT INTO dbo.Libraries
EXECUTE sp_execute_external_script    
		@language = N'R'    
	   ,@script=N'x <- data.frame(installed.packages())
	   x2 <- x[,c(1:3,5,6,8,16)]
	   OutputDataSet<- x2'
--WITH RESULT SETS (( 
--					 Package NVARCHAR(50)
--					,LibPath NVARCHAR(200)
--					,[Version] NVARCHAR(20)
--					,Depends NVARCHAR(200)
--					,Imports NVARCHAR(200)
--					,Suggests NVARCHAR(200)
--					,Built NVARCHAR(20)
--					));



DECLARE @RPath NVARCHAR(MAX)
SELECT @RPath =  LibPath  FROM Libraries  GROUP BY LibPath
SET @RPath = REPLACE(REPLACE(@RPath,'/library',''),'/','\')
SET @RPath = '"'+@RPath+'"'

DECLARE @CMDCommand VARCHAR(8000)
SET @CMDCommand = 'icacls '+@RPath+' /grant '+@CurrentLogin+':F'
-- PRINT @CMDCommand
EXECUTE xp_cmdshell @CMDCommand




-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-----------------------------------------------------------------------
--
-- 3. STATISTICS 
--    CREATE Table of statistics for R Framework
--    CREATE Procedure for executing R Framework
--    
--
-----------------------------------------------------------------------
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


IF EXISTS (SELECT * FROM sys.objects WHERE [name] = 'GeneralStatistics') 
TRUNCATE TABLE dbo.GeneralStatistics
BEGIN

			INSERT INTO dbo.GeneralStatistics
					  SELECT 'Frequencies','',1
			UNION ALL SELECT 'Correlations', '',1
			UNION ALL SELECT 'Correlations with p-values','',1

END



-- *********************
--
--  SAMPLE PROCEDURE
-- 
-- *********************


CREATE PROCEDURE sp_RStats
(
	 @QUERY NVARCHAR(MAX)
	,@STATS SMALLINT
	,@ListOfVariables VARCHAR(500) NULL
)
AS

DECLARE @q NVARCHAR(MAX)
SET @q = @QUERY


DROP TABLE IF EXISTS dbo.sp_RStats_temp_table;
-- IF_EXISTS (SELECT * FROM sys.objects WHERE name = 'sp_RStats_temp_table')  DROP TABLE sp_RStats_temp_table;

/* Retrieving COLUMN NAMES from SELECT LIST  */

SET @q = REPLACE(@q,'FROM',' INTO sp_RStats_temp_table FROM ');

EXEC SP_EXECUTESQL @q

DROP TABLE IF EXISTS dbo.sp_RStats_temp_table_columns
SELECT 
	 COLUMN_NAME
	,ORDINAL_POSITION 
INTO sp_RStats_temp_table_columns
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'sp_RStats_temp_table'


DECLARE @Variables NVARCHAR(MAX)
SELECT @Variables = COALESCE(@Variables + ' NVARCHAR(100), ','') + column_name
	FROM sp_RStats_temp_table_columns
SET  @Variables = @Variables + ' NVARCHAR(100)'



/* se ni dinamicno!!! */

IF @STATS = 1
BEGIN

	EXECUTE sp_execute_external_script    
		   @language = N'R'    
		  ,@script=N'mytable <- table(sp_RStats_query$SupplierID, sp_RStats_query$UnitPackageID)
					fre <- data.frame(margin.table(mytable, 1))
					OutputDataSet<-fre'
		  ,@input_data_1 = @QUERY
		  ,@input_data_1_name = N'sp_RStats_query'
	WITH RESULT SETS (( 
						 Var1 NVARCHAR(100)
						,Freq NVARCHAR(100)
						));

END

IF @STATS = 2
BEGIN

DECLARE @STAT2_SQL NVARCHAR(MAX)
SET @STAT2_SQL = 'EXECUTE sp_execute_external_script    
		   @language = N''R''    
		  ,@script=N''df <- data.frame(cor(sp_RStats_query, use="complete.obs", method="pearson"))
					OutputDataSet<-df''
		  ,@input_data_1 = N'''+CAST(@QUERY AS NVARCHAR(MAX)) +'''
		  ,@input_data_1_name = N''sp_RStats_query''
	WITH RESULT SETS (( '+CAST(@Variables AS NVARCHAR(MAX))+' ));'

EXECUTE SP_EXECUTESQL @STAT2_SQL


END

IF @STATS = 3
BEGIN


DECLARE @STAT3_SQL NVARCHAR(MAX)
SET @STAT3_SQL = 'EXECUTE sp_execute_external_script    
		   @language = N''R''    
		  ,@script=N''library(Hmisc) 
					df <- data.frame(rcorr(as.matrix(sp_RStats_query), type="pearson")$P)
					OutputDataSet<-df''
		  ,@input_data_1 = N'''+CAST(@QUERY AS NVARCHAR(MAX)) +'''
		  ,@input_data_1_name = N''sp_RStats_query''
	WITH RESULT SETS (( '+CAST(@Variables AS NVARCHAR(MAX))+' ));'

EXECUTE SP_EXECUTESQL @STAT3_SQL


END

