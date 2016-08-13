USE WideWorldImporters;
GO

CREATE TABLE Rstats
(ID INT IDENTITY(1,1) NOT NULL
,StatsDesc VARCHAR(200)
,ListOfVariables VARCHAR(500)
)

INSERT INTO Rstats
		  SELECT 'Frequencies',''
UNION ALL SELECT 'Correlations', ''
UNION ALL SELECT 'Correlations with p-values',''




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

/* SQL Server 2016 Feature */
DROP TABLE IF EXISTS dbo.sp_RStats_temp_table;
-- IF_EXISTS (SELECT * FROM sys.objects WHERE name = 'sp_RStats_temp_table')  DROP TABLE sp_RStats_temp_table;

/* Retrieving COLUMN NAMES from SELECT LIST  */

/* resitev je salabajzerska!!!!!! NI DOBRA */
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

