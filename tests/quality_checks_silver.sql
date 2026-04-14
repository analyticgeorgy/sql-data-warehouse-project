/*
====================================================================
Quality Checks 
====================================================================
Script Purpose :
This script performs various quality checks for data consistency, accuracy and standardization across the 'silver' schema.
It includes checks for:
-NULLs or duplicate primary keys
-Unwanted spaces in string fields.
-Data Standardization and Consistency.
-Invalid date ranges and orders.
-Data Consistency between related fields.

Usage Notes:
-Run these checks after loading the silver layer.
-Investigate and resolve any discrepancies found during checks.
==============================================================
*/
--Data Transformations

SELECT * FROM bronze.crm_cust_info
WHERE cst_id = 29466
--We can see that the cst_id has thre records, we will use the cst_create_date column and find out which record is the 
--latest and we will use ROW_NUMBER window function to assign unique number to each row in the result set

--Checking for duplicates in the primary key
--1.Check for NULLs and Duplicates in the primary key
--Expectation : No result
SELECT
	cst_id,
	COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL


SELECT *
FROM (
	SELECT
	*,
	ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS Rank
	FROM bronze.crm_cust_info
)t WHERE Rank = 1

--Check for unwanted spaces in the string columns,do this to all string columns
--Expectation : No results
SELECT
cst_firstname
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname)

--3.Check the consistency of values in low cardinality columns e.g marital_status and gndr, data standardization and consistency
SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info
--We can see that the column gndr consists of abbrevations, but we decided that in our datawarehouse we aim to store clear
--meaningful values rather than abbreviated terms, do the same for the marital_status column
SELECT DISTINCT cst_marital_status
FROM bronze.crm_cust_info

--Now that we have already loaded the silver crm_cust_info table with data we can perform data quality checks on it,
--replace bronze with silver in the queries above

--prd_info
--Check for NULLs and Duplicates in the primary key
--Expectation : No result
SELECT
	prd_id,
	COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL
--The above query returns no rows meaning the primary key has no issues i.e is unique and does not contain NULL values

SELECT * FROM bronze.crm_prd_info
SELECT * FROM bronze.erp_px_cat_g1v2
--We can see that the prd_key from crm_prd_info is stored together with the id from erp_px_cat_g1v2 which is likely the
--category id cat_id, we need to separate the cat_id from

--Check for unwanted spaces in the crm_prd_info prd_num string column
SELECT 
prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm)

--Check for NULLs and Negative values in the prd_cost numeric column
SELECT
prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL
--We can see that we dont have negative values in the column which is great, use COALESCE to replace the NULLs with zero
--ofcourse it depends with the business rules (some would like NULLs to be zero others wouldn't)

--Perform Data Standardization / Normalization to the low cardinality column prd_line, we'll do that in the other script
--here we just finding out the unique values in the column
SELECT DISTINCT prd_line
FROM bronze.crm_prd_info


--Fixing invalid date orders in the crm_prd_info table
SELECT
	prd_id,
	prd_key,
	prd_nm,
	prd_cost,
	prd_line,
	prd_start_dt,
	prd_end_dt
FROM silver.crm_prd_info
WHERE prd_start_dt > prd_end_dt
--We can see that for some records the prd_start_end comes after the prd_end_dt which makes no sense. We cant just switch
--the columns too because there are also some records where the prd_end_dt comes after the prd_start_dt. We have decided to
--do away with prd_end_dt and only use the prd_start_dt. We will derive a more meaningful end_dt column by setting it to
--the day before the following prd_start_dt (Use the LEAD() to access the following record values) as below
SELECT
	prd_id,
	prd_key,
	prd_nm,
	prd_cost,
	prd_line,
	prd_start_dt,
	LEAD(DATEADD(DAY, -1, prd_start_dt)) OVER(PARTITION BY prd_key ORDER BY prd_start_dt) AS prd_end_dt_test,
	prd_end_dt
FROM bronze.crm_prd_info
WHERE prd_key IN ('AC-HE-HL-U509-R', 'AC-HE-HL-U509')

--We can also see that the prd_start_dt and prd_end_dt are stored as DATETIME but they are all zero, no record about the
--time. We should convert it to DATE data type

--We now have a clean crm_prd_info. Notice that we have added another column cat_id and changed the data type of some
--columns during transformations, in order to insert the clean data into the table we have to go back to the table's
--DDL scripts and make the necessary changes like in this case we should add the cat_id column and set its data type and
--we should also change the data type of the columns prd_start_dt and prd_end_dt to DATE. After all this now you can insert
--your clean data into the silver layer crm_prd_info

--Now we move on to the crm_sales_details
SELECT * FROM bronze.crm_sales_details

--We start with the first 2 string columns, check if there are unwanted spaces in the columns
SELECT
sls_ord_num
FROM bronze.crm_sales_details
WHERE sls_ord_num != TRIM(sls_ord_num)

SELECT
sls_prd_key
FROM bronze.crm_sales_details
WHERE sls_prd_key != TRIM(sls_prd_key)
--We can see that there are no unwanted spaces in our first 2 string columns, so we can move on to the next columns
--We want to make sure that the sls_cust_id column can be used to join with the crm_cust_info table cst_id by using the
--NOT IN to find customers whose order informations is not in the sales_order_details
SELECT
*
FROM bronze.crm_sales_details
WHERE sls_cust_id NOT IN (
SELECT cst_id FROM bronze.crm_cust_info
)
--the above query returns no result meaning all existing customers in the table crm_cust_info table cst_id column have a
--record they are associated with in the sales_order_details, enabling the joining of the two tables

--we can also try to find products in the crm_prd_info which does not have a record in the sales_order_details
--NOTE that here we checked for the prd_info in the silver layer because the sls_prd_key corresponds to the newly derived
--prd_key in the silver layer not the original one, for the cst_id its just as it was thus not harm in querying the bronze
SELECT
*
FROM bronze.crm_sales_details
WHERE sls_prd_key NOT IN(
SELECT prd_key FROM silver.crm_prd_info
)
--the above query also returns no results suggesting that all the products in the silver's layer crm_prd_info have an 
--associated record in the sales_order_details hence enabling the joining of the tables
--The above 2 checks is known as Checking the Integrity of potential columns used for joining tables.

--Now lets move on to the DATE columns
--We can see that their data type is not DATE but INT, we will have to fix that
--First we will check if there are non-meaningful values in the columns like a zero
SELECT
sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0
--We can see that there are zeros in the column and that just not make sense, we will use NULLIF to replace the zero with 
--a NULL
SELECT
NULLIF(sls_order_dt, 0)
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0
--This is just here in the transformation script but when inserting clean data we will use a CASE statement 
--Second, we need to make sure that all the values in the column has a length of 8 for it to be regarded as a meaninful date
SELECT 
sls_order_dt
FROM bronze.crm_sales_details
WHERE LEN(sls_order_dt) != 8
--We can see that there are values in the column that does not have a length of 8, we will use a CASE statement to map
--the records meeting the above 2 criteria as NULL.
--NOTE that we have three columns that need to undergo these valid DATE column checks so just replace the column names

--Last check in the date columns is us checking the validility of the  date columns i.e the sls_order_dt should come earlier
--than both the sls_ship_dt and the sls_due_dt
SELECT * 
FROM bronze.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt
--The above returns no result meaning the date columns orders have no issues

--We move on to the last three columns in the sales_details table
--Check  Data Consistency : Between Sales, Quantity and Price
-- >> Sales = Quantity * Price
-- >> Values must not be NULL, negative or zero

SELECT DISTINCT
	sls_sales,
	sls_quantity,
	sls_price
FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0 
ORDER BY sls_sales, sls_quantity, sls_price
--Looking at the result of the above query we see that there are a lot of data issues coming directly from the source system
--We can decide to go talk to the source experts and tell about the data issues encountered or we can just decide to fix
--the data issues ourselves in the datawarehouse
--We will fix the data issues by ourselves guided by the below rules unanimously agreed upon between us and the source experts
--1.If Sales is negative, zero or NULL derive it using Quantity and Price
--2.If Price is zero or NULL, calculate it using Sales and Quantity
--3.If Price is negative, convert it to a positive value (USE ABS())
--NOTE : The sls_quantity has no issues as we can see so there is no need applying the checks on it
--The code to do all this will be available in the other script

--We have already provided a query for a cleaned crm_sales_details table but before executing it and inserting into the
--silver layer we must compare it with the silver layer crm_sales_details DDL and make sure our query has the same order
--of columns and the same data type too, if not we'll need to modify the DDL script

--Now lets move on to the erp source system, we want create a silver layer for the erp
SELECT * FROM bronze.erp_cust_az12
--The cid column in this table should be used to join this table with the crm's cust_info so lets visually compare them
--to see if they have matching data
SELECT
cid
FROM bronze.erp_cust_az12
WHERE cid NOT IN (
SELECT DISTINCT cst_key FROM silver.crm_cust_info
)
--We can see that the cid's from erp_cust_az12 have unmatching data for the cid that start with the prefix 'NAS' lets
--perform a basic transformation and remove the NAS to see if we will still find unmatching data
SELECT
CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
 	 ELSE cid 
END AS cid
FROM bronze.erp_cust_az12
WHERE CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
 	 ELSE cid END NOT IN(SELECT DISTINCT cst_key FROM silver.crm_cust_info)
--The above query returns no result suggesting that after removing the prefix 'NAS' in the records that contained it now
--all the transformed cid have matching data in the crm_cust_info table.
--Already provided a cleaned solution to the cid column now lets move on to the bdate
--Lets check if there are records with a bdate higher than the current date which screams bad data quality
SELECT
bdate 
FROM bronze.erp_cust_az12
WHERE bdate > GETDATE()
--We can see there are and that just does not make any sense, lets set them to NULL
SELECT
CASE WHEN bdate > GETDATE() THEN NULL
	 ELSE bdate 
END AS bdate
FROM bronze.erp_cust_az12
--Lets move to the last column in the table which is the gen column. It is a low cardinality column and a string column too
--so use UPPER() for case uniformity and TRIM() to remove any unwanted spaces
--First lets look at the unique values in the column
SELECT DISTINCT 
gen 
FROM bronze.erp_cust_az12
--Now apply a transformation solution
SELECT 
CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
	 WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
	 ELSE 'N/A'
END AS gen 
FROM bronze.erp_cust_az12

--Now that we already have a cleaned version of each column,lets insert it into the erp_cust_az12 silver layer. We didn't
--change the data type of any column or added any so there is no need to alter the DDL

--Now lets perform some two quality checks on the erp_cust_az12 silver layer table
SELECT
cid 
FROM silver.erp_cust_az12
WHERE cid NOT IN (
SELECT DISTINCT cst_key FROM silver.crm_cust_info
)
--No rows returned suggesting presence of matching data, good news

SELECT 
bdate
FROM silver.erp_cust_az12
WHERE bdate > GETDATE()
--No one born after the current date, good news

SELECT DISTINCT
gen
FROM silver.erp_cust_az12
--Only three consistent meaningful values, good news

--Now lets move on to erp_loc_a101
SELECT * FROM bronze.erp_loc_a101
--We can see than there is a cid column which you can join it with table crm_cust_info cst_key, lets check the integrity
--of the column cid in the erp_loc_a101
SELECT 
cid
FROM bronze.erp_loc_a101
WHERE cid NOT IN (
SELECT cst_key FROM silver.crm_cust_info
)
--Presence of unamatching data
--We can see that the cid column from erp_loc_a101 has a hyphen in it which shouldn't be there, lets replace the hyphen
--with an empty string (nothing) then try to find unmatching data
SELECT 
REPLACE(cid, '-', '') AS cid
FROM bronze.erp_loc_a101
WHERE REPLACE(cid, '-', '') NOT IN (
SELECT cst_key FROM silver.crm_cust_info
)
--No presence of unamtching data meaning the transformation solution on the cid column is correct and will be used in the
--clean silver's erp_loc_a101 DML

--Lets move to the next column which is cntry, a string column
--It is a low cardinality column so lets output the unique values in it
SELECT DISTINCT 
cntry
FROM bronze.erp_loc_a101
--Apply a data standardization transformation to clean that column
SELECT
CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
	 WHEN TRIM(cntry) IN ('USA', 'US') THEN 'United States'
	 WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'N/A'
	 ELSE TRIM(cntry)
END AS cntry
FROM bronze.erp_loc_a101
--Now insert the cleaned version into the erp_loc_a101 silver layer
--Perform data quality checks on the silver layer erp_loc_a101
--First check the integrity of the cid column
SELECT
cid
FROM silver.erp_loc_a101
WHERE cid NOT IN(
SELECT cst_key FROM silver.crm_cust_info
)
--No rows returned, good news

--Now check the unique values in the cntry column
SELECT DISTINCT 
cntry
FROM silver.erp_loc_a101

--Now lets move on to erp_px_cat_g1v2
SELECT * FROM bronze.erp_px_cat_g1v2
--The id column from the above table looks very similar to the cat_id column from silver crm_prd_info, lets check to
--see if there are unmatching data
SELECT
id
FROM bronze.erp_px_cat_g1v2
WHERE id NOT IN(
SELECT cat_id FROM silver.crm_prd_info
)
--We can see that there is only one unmatching data meaning that product id does not have a record associated with it
--in the crm_prd_info table but the two columns can be used to join the tables
--The id column is okay now lets move on to the next column cat which is a string column
--It is a low cardinality column so lets check its distinct values
SELECT DISTINCT 
cat
FROM bronze.erp_px_cat_g1v2
--The values in the column look okay no need for any data standardization
--Lets check if there is presence of unwanted spaces in the column
SELECT 
cat
FROM bronze.erp_px_cat_g1v2
WHERE cat != TRIM(cat)
--No rows returned, good news
--Lets move to the subcat column, check there distinct values
SELECT DISTINCT 
subcat
FROM bronze.erp_px_cat_g1v2
--The values look great no need for any data standardization
--Now lets check to see if there is presence of unwanted spaces in the column
SELECT 
subcat
FROM bronze.erp_px_cat_g1v2
WHERE subcat != TRIM(subcat)
--No rows returned, good news 
--Finally, the maintenance column, check its distinct values
SELECT DISTINCT 
maintenance
FROM bronze.erp_px_cat_g1v2
--Just Yes and No, good news
--Lets check to see if there is presence of unwanted spaces
SELECT
maintenance
FROM bronze.erp_px_cat_g1v2
WHERE maintenance != TRIM(maintenance)
--No rows returned, good news
--Suprisingly, it looks like the erp_px_cat_g1v2 table has no data quality issues, so we can just load it in the silver 
--layer as it is


















































