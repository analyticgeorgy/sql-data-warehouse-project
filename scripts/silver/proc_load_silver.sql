/*
================================================
Stored Procedure : Load Silver Layer (Bronze -> Silver)
=======================================================
Script Purpose :
  This stored procedure loads data into the 'silver' schema from the bronze layer.(ETL Process)
It performs the following actions :
  -Truncates the silver tables before loading data.
  -Inserts clean transformed data into the silver tables.
Parameters :
  None
  This stored procedure does not accept any parameters or return any values.
Variables:
  We declared some variables when calculating the duration time of loading the data into tables and the duration
  of the whole batch loading process.
Usage Example (how to execute) :
  EXEC silver.load_silver;
===============================================
NOTE : The stored procedure has additional code that does not really take part in the loading of the data but 
they are good data checks which should be integrated within this process.

ALERT :  
  If you want to execute the whole script at once preferably in SSMS paste the below code in a chatbot and 
  ask it to add the GO batch separator after every set of query so as to avoid errors.
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME
	BEGIN TRY
		PRINT '============================';
		PRINT 'Loading the Silver Layer';
		PRINT '===========================';
		SET @batch_start_time = GETDATE()
		PRINT 'Source System CRM...........';
		SET @start_time = GETDATE()
		PRINT '<<Truncating Table : silver.crm_cust_info';
		TRUNCATE TABLE silver.crm_cust_info
		PRINT '<< Inserting Into Table : silver.crm_cust_info';
		INSERT INTO silver.crm_cust_info(cst_id, cst_key, cst_firstname, cst_lastname,cst_marital_status, cst_gndr, cst_create_date)
		SELECT 
			cst_id,
			cst_key,
			TRIM(cst_firstname) AS cst_firstname,
			TRIM(cst_lastname) AS cst_lastname,
			CASE WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
				WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
				ELSE 'N/A'
			END AS cst_marital_status,
			CASE WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
				WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
				ELSE 'N/A'
			END AS cst_gndr,
			cst_create_date
		FROM (
			SELECT *,
			ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS Rank
			FROM bronze.crm_cust_info
			WHERE cst_id IS NOT NULL
		)t WHERE Rank = 1;
		SET @end_time = GETDATE()
		PRINT 'Loading Duration is ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		
		--SELECT * FROM silver.crm_cust_info
		--Now the cust_info table in set, lets move on to prd_info
		
		--SELECT * FROM bronze.crm_prd_info
		--SELECT * FROM bronze.erp_px_cat_g1v2
		--We can see that the prd_key from crm_prd_info is stored together with the id from erp_px_cat_g1v2 which is likely the
		--category id cat_id, we need to separate the cat_id from the prd_key
		
		SET @start_time = GETDATE()
		PRINT '<< Truncating Table : silver.crm_prd_info';
		TRUNCATE TABLE silver.crm_prd_info
		PRINT '<< Inserting Into Table : silver.crm_prd_info';
		INSERT INTO silver.crm_prd_info(prd_id, cat_id, prd_key, prd_nm, prd_cost, prd_line, prd_start_dt, prd_end_dt)
		SELECT
		prd_id,
		REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
		SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,
		prd_nm,
		COALESCE(prd_cost, 0) AS prd_cost,
		CASE WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
			 WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
			 WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
			 WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
			 ELSE 'N/A'
		END AS prd_line,
		CAST(prd_start_dt AS DATE) AS prd_start_dt,
		CAST(LEAD(DATEADD(DAY, -1, prd_start_dt)) OVER(PARTITION BY prd_key ORDER BY prd_start_dt) AS DATE) AS prd_end_dt
		FROM bronze.crm_prd_info;
		SET @end_time = GETDATE()
		PRINT 'Loading Duration is ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		
		--SELECT * FROM silver.crm_prd_info
		
		--Now we move on to the crm_sales_details
		--SELECT * FROM bronze.crm_sales_details
		SET @start_time = GETDATE()
		PRINT '<< Truncating Table : silver.crm_sales_details';
		TRUNCATE TABLE silver.crm_sales_details
		PRINT '<< Inserting Into Table : silver.crm_sales_details';
		INSERT INTO silver.crm_sales_details
		(sls_ord_num, sls_prd_key, sls_cust_id, sls_order_dt, sls_ship_dt, sls_due_dt, sls_sales, sls_quantity, sls_price)
		SELECT
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		CASE WHEN sls_order_dt <= 0 OR LEN(sls_order_dt) != 8 THEN NULL
		     ELSE CAST(CAST(sls_order_dt AS NVARCHAR) AS DATE)
		END AS sls_order_dt,
		CASE WHEN sls_ship_dt <= 0 OR LEN(sls_ship_dt) != 8 THEN NULL
			 ELSE CAST(CAST(sls_ship_dt AS NVARCHAR) AS DATE)
		END AS sls_ship_dt,
		CASE WHEN sls_due_dt <= 0 OR LEN(sls_due_dt) != 8 THEN NULL
		     ELSE CAST(CAST(sls_due_dt AS NVARCHAR) AS DATE)
		END AS sls_due_dt,
		CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
			 THEN sls_quantity * ABS(sls_price)
			 ELSE sls_sales
		END AS sls_sales,
		sls_quantity AS quantity,
		CASE WHEN sls_price IS NULL OR sls_price <= 0
			 THEN sls_sales / NULLIF(sls_quantity, 0)
			 ELSE sls_price
		END AS sls_price
		FROM bronze.crm_sales_details;
		SET @end_time = GETDATE()
		PRINT 'Loading Duration is ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		
		--SELECT * FROM silver.crm_sales_details
		
		--Now lets move on to the erp source system 
		--erp_cust_az12 silver layer
		PRINT 'Source System ERP..........';
		SET @start_time = GETDATE()
		PRINT '<< Truncating Table : silver.erp_cust_az12';
		TRUNCATE TABLE silver.erp_cust_az12
		PRINT '<< Inserting Into Table : silver.erp_cust_az12'
		INSERT INTO silver.erp_cust_az12(cid, bdate, gen)
		SELECT 
		CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
			 ELSE cid
		END AS cid,
		CASE WHEN bdate > GETDATE() THEN NULL
			 ELSE bdate
		END AS bdate,
		CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
			 WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
			 ELSE 'N/A'
		END AS gen
		FROM bronze.erp_cust_az12;
		SET @end_time = GETDATE()
		PRINT 'Loading Duration is ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		
		--SELECT * FROM silver.erp_cust_az12
		
		--Now lets move on to erp_loc_a101
		SET @start_time = GETDATE()
		PRINT '<< Truncating Table : silver.erp_loc_a101';
		TRUNCATE TABLE silver.erp_loc_a101
		PRINT '<< Inserting Into Table : silver.erp_loc_a101';
		INSERT INTO silver.erp_loc_a101 (cid, cntry)
		SELECT
		REPLACE(cid, '-', '') AS cid,
		CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
			 WHEN TRIM(cntry) IN ('USA', 'US') THEN 'United States'
			 WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'N/A'
			 ELSE TRIM(cntry)
		END AS cntry
		FROM bronze.erp_loc_a101;
		SET @end_time = GETDATE()
		PRINT 'Loading Duration is ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		
		--SELECT * FROM silver.erp_loc_a101
		
		--Now lets move on to erp_px_cat_g1v2
		SET @start_time = GETDATE()
		PRINT '<< Truncating Table : silver.erp_px_cat_g1v2';
		TRUNCATE TABLE silver.erp_px_cat_g1v2
		PRINT '<< Inserting Into Table : silver.erp_px_cat_g1v2';
		INSERT INTO silver.erp_px_cat_g1v2(id, cat, subcat, maintenance)
		SELECT 
		id,
		cat,
		subcat,
		maintenance
		FROM bronze.erp_px_cat_g1v2;
		SET @end_time = GETDATE()
		PRINT 'Loading Duration is ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '<<<<<<<<<<<<<<<<<<<<<<<<<<';
		
		SET @batch_end_time = GETDATE()
		PRINT 'Loading the whole batch ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT 'Finished Loading the whole batch';
	END TRY
	
	BEGIN CATCH
		PRINT '=============================================';
		PRINT 'AN ERROR OCCURED DURING LOADING THE SILVER LAYER';
		PRINT 'Error Message ' + ERROR_MESSAGE();
		PRINT 'Error Message ' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message ' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '==============================================';
	END CATCH
END




















