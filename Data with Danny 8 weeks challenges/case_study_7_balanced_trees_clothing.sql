--Case Study Questions
--The following questions can be considered key business questions and metrics that the Balanced Tree team requires for their monthly reports.
--Each question can be answered using a single query - but as you are writing the SQL to solve each individual problem, 
--keep in mind how you would generate all of these metrics in a single SQL script which the Balanced Tree team can run each month.

select * from information_schema.tables where table_schema = 'balanced_tree';

select * from balanced_tree.product_hierarchy; --18
select * from balanced_tree.product_prices; --12
select * from balanced_tree.product_details; --12
select * from balanced_tree.sales; --15095

-- Section A - High Level Sales Analysis
-- 1.What was the total quantity sold for all products?
SELECT
		pd.product_name AS product_name,
		SUM(s.qty) AS total_quantity
FROM
		balanced_tree.product_details AS pd
INNER JOIN balanced_tree.sales AS s 
		ON pd.product_id = s.prod_id
GROUP BY 
		pd.product_name;
	
-- 2.What is the total generated revenue for all products before discounts?

SELECT
		pd.product_name,
		SUM(s.price * s.qty) AS total_revenue
FROM
		balanced_tree.product_details AS pd
INNER JOIN balanced_tree.sales AS s 
		ON pd.product_id = s.prod_id
GROUP BY 
		pd.product_name;

-- 3.What was the total discount amount for all products?

SELECT
		pd.product_name AS product_name,
		ROUND(SUM((s.price * s.discount * s.qty)::DECIMAL / 100), 2) AS total_discount 
FROM 
		balanced_tree.product_details AS pd
INNER JOIN balanced_tree.sales AS s
		ON pd.product_id = s.prod_id 
GROUP BY 
		pd.product_name;

-- Section B - Transaction Analysis
-- 1.How many unique transactions were there?
select * from balanced_tree.sales; 

SELECT
		COUNT(DISTINCT txn_id) AS transaction_counts
FROM 
		balanced_tree.sales;
		
-- 2.What is the average unique products purchased in each transaction?
select * from balanced_tree.sales; 

WITH cte AS (
	SELECT
			txn_id,
			SUM(qty) AS total_quantity
	FROM
			balanced_tree.sales
	GROUP BY 
			txn_id		
)
SELECT 
		ROUND(AVG(total_quantity), 0) AS average_unique_products
FROM 
		cte;

-- 3.What are the 25th, 50th and 75th percentile values for the revenue per transaction?
select * from balanced_tree.sales; 

WITH cte AS (
	SELECT
			txn_id,
			SUM(price * qty) as total_revenue
	FROM 
			balanced_tree.sales
	GROUP BY 
			txn_id
)
SELECT
		ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP(ORDER BY total_revenue ASC)::DECIMAL, 2) AS median_25th,
		ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY total_revenue ASC)::DECIMAL, 2) AS median_50th,
		ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP(ORDER BY total_revenue ASC)::DECIMAL, 2) AS median_75th
FROM 
		cte;

-- 4.What is the average discount value per transaction?
select * from balanced_tree.sales;

WITH cte AS (
	SELECT
			txn_id,
			ROUND(SUM(qty * price * discount)::DECIMAL, 2) AS total_discount
	FROM
			balanced_tree.sales
	GROUP BY
			txn_id
)
SELECT
		ROUND(AVG(total_discount), 2) AS average_discount
FROM 
		cte;

-- 5.What is the percentage split of all transactions for members vs non-members?
select * from balanced_tree.sales;

WITH cte_1 AS (
	SELECT
			member,
			COUNT(*) AS member_count
	FROM
			balanced_tree.sales
	GROUP BY 
			member
), cte_2 AS (
	SELECT 
			COUNT(*) AS cnt
	FROM 
			balanced_tree.sales
)

SELECT
		c1.*,
		ROUND(c1.member_count::DECIMAL / c2.cnt * 100, 2) AS percentage
FROM 
		cte_1 AS c1
CROSS JOIN 
		cte_2 AS c2;

-- 6.What is the average revenue for member transactions and non-member transactions?
select * from balanced_tree.sales;

WITH cte_1 AS (
	SELECT
			member,
			txn_id,
			ROUND(SUM(qty * price), 2) as total_revenue
	FROM 
			balanced_tree.sales
	GROUP BY 
			member, txn_id
)
SELECT
		member,
		ROUND(AVG(total_revenue), 2) AS average_revenue
FROM
		cte_1
GROUP BY 
		member;

-- Section C - Product Analysis
-- 1.What are the top 3 products by total revenue before discount?
select * from balanced_tree.product_details; --12
select * from balanced_tree.sales; --15095

WITH cte_1 AS (
	SELECT
			pd.product_id,  
			pd.product_name,
			SUM(s.qty * s.price) AS total_revenue,
			DENSE_RANK() OVER(ORDER BY SUM(s.qty * s.price) DESC) AS total_revenue_rank
	FROM
			balanced_tree.product_details AS pd
	INNER JOIN balanced_tree.sales AS s
			ON pd.product_id = s.prod_id
	GROUP BY pd.product_id, pd.product_name
)
SELECT
		product_id,
		product_name,
		total_revenue
FROM 
		cte_1
WHERE 
		total_revenue_rank <= 3;

-- 2.What is the total quantity, revenue and discount for each segment?
select * from balanced_tree.product_details; --12
select * from balanced_tree.sales; --15095

SELECT 
		pd.segment_name,
		SUM(s.qty) AS total_quantity,
		SUM(s.qty * s.price) AS total_revenue,
		ROUND(SUM(s.qty * s.price * s.discount::DECIMAL / 100), 2) AS total_discount
FROM 
		balanced_tree.product_details AS pd
INNER JOIN balanced_tree.sales AS s
		ON pd.product_id = s.prod_id
GROUP BY 
		pd.segment_name;

-- 3.What is the top selling product for each segment?
select * from balanced_tree.product_details; --12
select * from balanced_tree.sales; --15095

WITH cte_1 AS (
	SELECT 
			pd.segment_name,
			pd.product_name,
			SUM(s.qty) AS total_selling,
			DENSE_RANK() OVER(PARTITION BY pd.segment_name ORDER BY SUM(s.qty) DESC) AS total_selling_rank
	FROM 
			balanced_tree.product_details AS pd
	INNER JOIN balanced_tree.sales AS s
			ON 	pd.product_id = s.prod_id
	GROUP BY 
			pd.segment_name, pd.product_name
)
SELECT
		segment_name, 
		product_name,
		total_selling
FROM 
		cte_1
WHERE 
		total_selling_rank = 1;

-- 4.What is the total quantity, revenue and discount for each category?
select * from balanced_tree.product_details; --12
select * from balanced_tree.sales; --15095

SELECT
		pd.category_id,
		pd.category_name,
		SUM(s.qty) AS total_quantity,
		SUM(s.qty * s.price) AS total_revenue,
		ROUND(SUM(s.qty * s.price * s.discount)::DECIMAL / 100, 2) AS total_discount
FROM balanced_tree.product_details AS pd
INNER JOIN balanced_tree.sales AS s
		ON pd.product_id = s.prod_id
GROUP BY 
		pd.category_id,
		pd.category_name
ORDER BY pd.category_id ASC;
		
-- 5.What is the top selling product for each category?
select * from balanced_tree.product_details; --12
select * from balanced_tree.sales; --15095

WITH cte_1 AS (
	SELECT 
			pd.category_id, 
			pd.category_name,
			pd.product_name,
			SUM(s.qty) AS total_selling,
			DENSE_RANK() OVER(PARTITION BY pd.category_id ORDER BY SUM(s.qty) DESC) AS total_selling_rank
	FROM balanced_tree.product_details AS pd
	INNER JOIN balanced_tree.sales AS s 
			ON pd.product_id = s.prod_id
	GROUP BY 
			pd.category_id, 
			pd.category_name,
			pd.product_name
)
SELECT
		category_id,
		category_name,
		product_name,
		total_selling
FROM 
		cte_1
WHERE 
		total_selling_rank = 1
ORDER BY 
		category_id ASC;
		
-- 6.What is the percentage split of revenue by product for each segment?
select * from balanced_tree.product_details; --12
select * from balanced_tree.sales; --15095

WITH cte_1 AS (
	SELECT
			pd.segment_id,
			pd.segment_name,
			pd.product_name,
			SUM(s.qty * s.price) AS revenue
	FROM 
			balanced_tree.product_details AS pd
	INNER JOIN balanced_tree.sales AS s
			ON pd.product_id = s.prod_id
	GROUP BY 
			pd.segment_id,
			pd.segment_name,
			pd.product_name
)
SELECT 
		segment_id,
		segment_name,
		ROUND(revenue::DECIMAL / SUM(revenue) OVER(PARTITION BY segment_id) * 100, 2) AS percentage
FROM 
		cte_1 
ORDER BY 
		segment_id ASC,
		percentage DESC;

-- 7.What is the percentage split of revenue by segment for each category?
select * from balanced_tree.product_details; --12
select * from balanced_tree.sales; --15095

WITH cte_1 AS (
	SELECT
			pd.category_id,
			pd.category_name,
			pd.segment_name,
			SUM(s.qty * s.price) AS revenue
	FROM 
			balanced_tree.product_details AS pd
	INNER JOIN balanced_tree.sales AS s
			ON pd.product_id = s.prod_id
	GROUP BY 
			pd.category_id,
			pd.category_name,
			pd.segment_name
)
SELECT 
		*,
		ROUND(revenue::DECIMAL / SUM(revenue) OVER(PARTITION BY category_id) * 100, 2) AS percentage
FROM 
		cte_1
ORDER BY 	
		category_id ASC,
		percentage DESC;


-- 8.What is the percentage split of total revenue by category?
select * from balanced_tree.product_details; --12
select * from balanced_tree.sales; --15095

WITH cte_1 AS (
	SELECT
			pd.category_name,
			SUM(s.qty * s.price) AS revenue
	FROM 
			balanced_tree.product_details AS pd
	INNER JOIN balanced_tree.sales AS s
			ON pd.product_id = s.prod_id
	GROUP BY 
			pd.category_name
), cte_2 AS (
	SELECT
			SUM(revenue) AS total_revenue
	FROM 
			cte_1
)
SELECT
		c1.category_name,
		c1.revenue,
		ROUND(c1.revenue::DECIMAL / c2.total_revenue * 100, 2) AS percentage
FROM 
		cte_1 AS c1
CROSS JOIN 
		cte_2 AS c2
ORDER BY 
		percentage DESC;

-- 9.What is the total transaction “penetration” for each product? 
--(hint: penetration = number of transactions where at least 1 quantity of a product was purchased divided by total number of transactions)
select * from balanced_tree.product_details; --12
select * from balanced_tree.sales; --15095

-- solution 1:
WITH product_transaction AS (
SELECT
		prod_id,
		COUNT(DISTINCT txn_id) AS transaction_num
FROM 
		balanced_tree.sales
GROUP BY 
		prod_id
), total_transaction AS (
	SELECT 
			COUNT(DISTINCT txn_id) AS total_transaction
	FROM 
			balanced_tree.sales
)
SELECT 
		pd.product_id,
		pd.product_name,
		pt.transaction_num,
		ROUND(pt.transaction_num::DECIMAL / tt.total_transaction * 100, 2) AS penetration_percentage
FROM
		product_transaction AS pt
CROSS JOIN 
		total_transaction AS tt
INNER JOIN balanced_tree.product_details AS pd
		ON pt.prod_id = pd.product_id
ORDER BY 
		penetration_percentage DESC;

--solution 2:

SET
		SEARCH_PATH = balanced_tree;
SELECT 
		pd.product_name,
		COUNT(product_name) AS num_of_transactions,
		ROUND(COUNT(product_name)::DECIMAL / total_transactions * 100, 2) AS penetration_percentage
FROM
		sales AS s
INNER JOIN product_details AS pd
		ON s.prod_id = pd.product_id,
LATERAL (
		SELECT 
			COUNT(DISTINCT txn_id) AS total_transactions
		FROM 
			sales
) AS ss
GROUP BY 
		pd.product_name,
		total_transactions
ORDER BY 
		penetration_percentage DESC;
		

-- 10.What is the most common combination of at least 1 quantity of any 3 products in a 1 single transaction?

-- This is a combinatorics question. We need to find all possible combinations of 3 different items from all the items in the list. 
-- The total number of items is 12, so we have 220 possible combinatations of 3 different items.
-- 12! / 3! * (12 - 3)! = 12! / 3! * 9! = 4 * 5 * 11 = 220 combinations

select * from product_hierarchy; --18
select * from product_prices; --12
select * from product_details; --12
select * from sales; --15095

SET
	SEARCH_PATH = balanced_tree;

WITH products AS (
	SELECT 
		s.txn_id,
		pd.product_name
	FROM
		sales AS s
	INNER JOIN product_details AS pd
			ON s.prod_id = pd.product_id
), c1 AS (
	SELECT 
		p1.product_name AS product_1,
		p2.product_name AS product_2,
		p3.product_name AS product_3,
		COUNT(*) AS times_bought_together,
		DENSE_RANK() OVER(ORDER BY COUNT(*) DESC) as combination_ranking	
	FROM
		products AS p1
	INNER JOIN products AS p2
			ON p1.product_name < p2.product_name
			AND p1.product_name <> p2.product_name
			AND p1.txn_id = p2.txn_id
	INNER JOIN products AS p3
			ON p1.product_name <> p3.product_name 
			AND p2.product_name <> p3.product_name
			AND p1.txn_id = p3.txn_id
			AND p2.txn_id = p3.txn_id
			AND p1.product_name < p3.product_name
			AND p2.product_name < p3.product_name
	GROUP BY 
		p1.product_name, 
		p2.product_name,
		p3.product_name 
)
SELECT
	product_1,
	product_2,
	product_3,
	times_bought_together
FROM 
	c1
WHERE
	combination_ranking = 1;
	
	
-- Bonus Challenge
-- Use a single SQL query to transform the product_hierarchy and product_prices datasets to the product_details table.

select * from product_hierarchy; --18
select * from product_prices; --12
select * from product_details; --12
select * from sales; --15095

SET
	SEARCH_PATH = balanced_tree;


WITH c1 AS (
	SELECT
		p1.id AS category_id,
		p2.id AS segment_id,
		p3.id AS style_id,
		p1.level_text AS category_name,
		p2.level_text AS segment_name,
		p3.level_text AS style_name
	FROM
		product_hierarchy AS p1
	INNER JOIN product_hierarchy AS p2
			ON p1.id = p2.parent_id
	INNER JOIN product_hierarchy AS p3
			ON p2.id = p3.parent_id
)
SELECT
	pp.product_id,
	pp.price,
	ph.level_text || ' - ' || c1.category_name AS product_name,
	c1.*
FROM
	product_prices AS pp
INNER JOIN product_hierarchy AS ph
		ON pp.id = ph.id
INNER JOIN c1 
		ON pp.id = c1.style_id
ORDER BY 
	c1.category_id ASC,
	c1.segment_id ASC,
	c1.style_id ASC;
