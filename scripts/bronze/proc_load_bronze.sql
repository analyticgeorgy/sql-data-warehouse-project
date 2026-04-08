/*
================================================
Stored Procedure : Load Bronze Layer (Source -> Bronze)
=======================================================
Script Purpose :
  This stored procedure loads data into the 'bronze' schema from external CSV files.
It performs the following actions :
  -Truncates the bronze tables before loading data.
  -Uses the BULK INSERT command to load data from CSV files to bronze tables.
Parameters :
  None
  This stored procedure does not accept any parameters or return any values.
Variables:
  We declared some variables when calculating the duration time of loading the data into tables and the duration
  of the whole batch loading process.
Usage Example (how to execute) :
  EXEC bronze.load_bronze;
===============================================
NOTE : The stored procedure has additional code that does not really take part in the loading of the data but 
they are good data checks which should be integrated within this process.

ALERT :  
  If you want to execute the whole script at once preferably in SSMS paste the below code in a chatbot and 
  ask it to add the GO batch separator after every set of query so as to avoid errors.
*/
CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME
	BEGIN TRY
		PRINT '=================================';
		SET @batch_start_time = GETDATE()
		PRINT 'Loading the Bronze Layer';
	
		PRINT '---------------------------------';
		PRINT 'Loading CRM Tables'
		
		SET @start_time = GETDATE()
		PRINT '<< Truncating Table : crm_cust_info';
		TRUNCATE TABLE bronze.crm_cust_info
		PRINT '<< Inserting Data Into : crm_cust_info';
		BULK INSERT bronze.crm_cust_info
		FROM 'C:\SQL_projects\db_warehousing1\sql-data-warehouse-project\datasets\source_crm\cust_info.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE()
		PRINT 'Load Duration is '+ CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '<< ---------------------------';
		
		SET @start_time = GETDATE()
		PRINT '<< Truncating Table : crm_prd_info';
		TRUNCATE TABLE bronze.crm_prd_info
		PRINT '<< Inserting Data Into : crm_prd_info';
		BULK INSERT bronze.crm_prd_info 
		FROM 'C:\SQL_projects\db_warehousing1\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE()
		PRINT 'Loading Duration is ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '<< -------------------------';
		
		/*SELECT * FROM bronze.crm_prd_info
		
		SELECT COUNT(*)
		FROM bronze.crm_prd_info
		*/
		
		SET @start_time = GETDATE()
		PRINT '<< Truncating Table : crm_sales_details';
		TRUNCATE TABLE bronze.crm_sales_details 
		PRINT '<< Inserting Data Into : crm_sales_details';
		BULK INSERT bronze.crm_sales_details
		FROM 'C:\SQL_projects\db_warehousing1\sql-data-warehouse-project\datasets\source_crm\sales_details.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE()
		PRINT 'Loading Duration is ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '<< ----------------------';
		
		/*SELECT * FROM bronze.crm_sales_details
		
		SELECT COUNT(*)
		FROM bronze.crm_sales_details
		*/
		PRINT '----------------------------------';
		PRINT '<< Loading ERP Tables';
		
		SET @start_time = GETDATE()
		PRINT '<< Truncating Table : erp_cust_az12';
		TRUNCATE TABLE bronze.erp_cust_az12
		PRINT '<< Inserting Data Into : erp_cust_az12';
		BULK INSERT bronze.erp_cust_az12
		FROM 'C:\SQL_projects\db_warehousing1\sql-data-warehouse-project\datasets\source_erp\CUST_AZ12.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE()
		PRINT 'Loading Duration is ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '<< --------------------';
		
		/*SELECT * FROM bronze.erp_cust_az12
		
		SELECT COUNT(*)
		FROM bronze.erp_cust_az12
		*/
		
		SET @start_time = GETDATE()
		PRINT '<< Truncating Table : erp_loc_a101';
		TRUNCATE TABLE bronze.erp_loc_a101
		PRINT '<< Inserting Data Into : erp_loc_a101';
		BULK INSERT bronze.erp_loc_a101
		FROM 'C:\SQL_projects\db_warehousing1\sql-data-warehouse-project\datasets\source_erp\LOC_A101.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE()
		PRINT 'Loading Duration is ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '<< --------------------';
		
		/*SELECT * FROM bronze.erp_loc_a101
		
		SELECT COUNT(*)
		FROM bronze.erp_loc_a101
		*/
		
		SET @start_time = GETDATE()
		PRINT '<< Truncating Table : erp_px_cat_g1v2';
		TRUNCATE TABLE bronze.erp_px_cat_g1v2
		PRINT '<< Inserting Data Into : erp_px_cat_gv12';
		BULK INSERT bronze.erp_px_cat_g1v2
		FROM 'C:\SQL_projects\db_warehousing1\sql-data-warehouse-project\datasets\source_erp\PX_CAT_G1V2.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE()
		PRINT 'Loading Duration is ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '<< -----------------';
	
		/*SELECT * FROM bronze.erp_px_cat_g1v2
		
		SELECT COUNT(*)
		FROM bronze.erp_px_cat_g1v2
		*/
		SET @batch_end_time = GETDATE()
		PRINT 'Loading Duration of the whole batch ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds'
		PRINT 'Finished Loading the Bronze Layer'
	END TRY
	BEGIN CATCH
		PRINT '============================';
		PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER';
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '=============================';
	END CATCH
END
	
--Every time we will need to get new information from the source we will have to execute the above bunch of code, and 
--in sql we know that when there is a sql script that will be executed multiple times it better to make it a stored procedure
--in that way will be just executing the store procedure

EXEC bronze.load_bronze;









