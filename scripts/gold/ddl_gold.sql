/*
================================================================================
DDL Script : Create Gold Views
===============================================================================
Script Purpose : 
This script creates views in the for the gold layer in the data warehouse.
The gold layer represents the final dimension and fact table(star schema)
Each view performs transformations and combines data from the Silver layer to produce a clean, enriched
and business-ready dataset.

Usage : 
These views can be queried directly for analytics and reporting
==============================================================================
*/
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
	DROP VIEW gold.dim_customers;
GO
  
CREATE VIEW gold.dim_customers AS
SELECT
	ROW_NUMBER() OVER(ORDER BY cst_id) AS customer_key,
	ci.cst_id AS customer_id,
	ci.cst_key AS customer_number, 
	ci.cst_firstname AS first_name,
	ci.cst_lastname AS last_name,
	cl.cntry AS country,
	ci.cst_marital_status AS marital_status,
	CASE WHEN ci.cst_gndr != 'N/A' THEN ci.cst_gndr
		 ELSE COALESCE(ca.gen, 'N/A')
	END AS gender,
	ca.bdate AS birth_date,
	ci.cst_create_date AS create_date
FROM silver.crm_cust_info as ci
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 cl
ON ci.cst_key = cl.cid
GO

IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
	DROP VIEW gold.dim_products;
GO
  
CREATE VIEW gold.dim_products AS
SELECT
	ROW_NUMBER() OVER(ORDER BY prd_key, prd_start_dt) AS product_key,
	pr.prd_id AS product_id,
	pr.prd_key AS product_number,
	pr.prd_nm AS product_name,
	pr.cat_id AS category_id,
	px.cat AS category,
	px.subcat AS subcategory,
	px.maintenance,
	pr.prd_cost AS cost,
	pr.prd_line AS product_line,
	pr.prd_start_dt AS start_date
FROM silver.crm_prd_info pr
LEFT JOIN silver.erp_px_cat_g1v2 px
ON pr.cat_id = px.id
WHERE prd_end_dt IS NULL
GO

IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
	DROP VIEW gold.fact_sales;
GO
  
CREATE VIEW gold.fact_sales AS
SELECT
	s.sls_ord_num AS order_number,
	pr.product_key,
	c.customer_key,
	s.sls_order_dt AS order_date,
	s.sls_ship_dt AS shipping_date,
	s.sls_due_dt AS due_date,
	s.sls_sales AS sales_amount,
	s.sls_quantity AS quantity,
	s.sls_price AS price
FROM silver.crm_sales_details s
LEFT JOIN gold.dim_products pr
ON s.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers c
ON s.sls_cust_id = c.customer_id
