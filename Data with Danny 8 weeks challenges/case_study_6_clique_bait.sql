select * from information_schema.tables where table_schema = 'clique_bait';
set search_path = clique_bait;

select * from events; --32734
select * from event_identifier; --5
select * from campaign_identifier; --3
select * from page_hierarchy; --13
select * from users; --1782

-- Section 2 - Digital Analysis
-- Using the available datasets - answer the following questions using a single query for each one:

-- 1. How many users are there?

SELECT
	COUNT(DISTINCT user_id) AS num_of_users
FROM 
	users;

-- 2. How many cookies does each user have on average?

SELECT 
	ROUND(AVG(num_of_cookies), 2) AS avg_num_of_cookies
FROM (
	SELECT
		user_id,
		COUNT(DISTINCT cookie_id) AS num_of_cookies
	FROM
		users
	GROUP BY
		user_id
);

-- 3. What is the unique number of visits by all users per month?

SELECT
	TO_CHAR(event_time, 'Mon') AS _month,
	COUNT(DISTINCT visit_id) AS num_visits
FROM
	events
GROUP BY 
	TO_CHAR(event_time, 'Mon')
ORDER BY 
	MIN(event_time) ASC;

-- 4. What is the number of events for each event type?

select * from events; --32734
select * from event_identifier; --5

SELECT
	e.event_type,
	COUNT(*) AS num_event
FROM
	events AS e
INNER JOIN event_identifier AS ei
		ON e.event_type = ei.event_type
GROUP BY 
	e.event_type;

-- 5. What is the percentage of visits which have a purchase event?

SELECT
	ei.event_name,
	COUNT(*) AS num_of_purchase,
	ROUND(COUNT(DISTINCT visit_id)::DECIMAL / (
		SELECT 
			COUNT(DISTINCT visit_id) AS num_of_event
		FROM
			events
	) * 100 , 2) AS percentage_of_purchase
FROM
	events AS e
INNER JOIN event_identifier AS ei
		ON e.event_type = ei.event_type
WHERE 
	ei.event_name = 'Purchase'
GROUP BY 
	ei.event_name;

-- 6. What is the percentage of visits which view the checkout page but do not have a purchase event?

select * from events; --32734
select * from event_identifier; --5
select * from page_hierarchy; --13


SELECT
	c3.page_name,
	c3.num_of_visit,
	ROUND(c3.num_of_visit::DECIMAL / c2.total_checkout_page * 100 , 2) AS percentage_from_checkout_page,
	ROUND(c3.num_of_visit::DECIMAL / c1.total_all_page * 100, 2) AS percentage_from_all_page
FROM LATERAL(
SELECT
	COUNT(DISTINCT visit_id) AS total_all_page
FROM
	events AS e
INNER JOIN page_hierarchy AS ph
		ON ph.page_id = e.page_id
) AS c1,
LATERAL(
SELECT
	COUNT(DISTINCT visit_id) AS total_checkout_page
FROM
	events AS e
INNER JOIN page_hierarchy AS ph
		ON ph.page_id = e.page_id
WHERE 
	ph.page_name = 'Checkout'	
) AS c2,
LATERAL (
SELECT
	ph.page_name,
	COUNT(*) AS num_of_visit
FROM
	events AS e
INNER JOIN page_hierarchy AS ph
		ON ph.page_id = e.page_id
WHERE 
	ph.page_name = 'Checkout'
AND
	e.visit_id NOT IN (
		SELECT
			visit_id
		FROM 
			events
		WHERE
			event_type = 3
	)
GROUP BY 
	ph.page_name
) AS c3;

-- 7. What are the top 3 pages by number of views?

SET 
	SEARCH_PATH = clique_bait;
select * from events; --32734
select * from event_identifier; --5
select * from page_hierarchy; --13

WITH c1 AS (
	SELECT
		ph.page_name,
		COUNT(DISTINCT e.visit_id) AS num_of_view,
		DENSE_RANK() OVER(ORDER BY COUNT(DISTINCT e.visit_id) DESC) AS page_ranking
	FROM
		events AS e
	INNER JOIN page_hierarchy AS ph
			ON e.page_id = ph.page_id
	GROUP BY 
		ph.page_name
)
SELECT
	page_name,
	num_of_view
FROM 
	c1
WHERE
	page_ranking <= 3;

-- 8. What is the number of views and cart adds for each product category?

select * from events; --32734
select * from event_identifier; --5
select * from campaign_identifier; --3
select * from page_hierarchy; --13
select * from users; --1782

SELECT
	ph.product_category,
	COUNT(*) FILTER(WHERE ei.event_name = 'Page View') AS num_of_view,
	COUNT(*) FILTER(WHERE ei.event_name = 'Add to Cart') AS num_of_add_to_cart_event
FROM
	events AS e
INNER JOIN event_identifier AS ei
		ON e.event_type = ei.event_type
INNER JOIN page_hierarchy AS ph
		ON ph.page_id = e.page_id
WHERE
	ph.product_category IS NOT NULL
GROUP BY 
	ph.product_category
ORDER BY 
	ph.product_category ASC;


-- 3. Product Funnel Analysis
-- Using a single SQL query - create a new output table which has the following details:

-- How many times was each product viewed?
-- How many times was each product added to cart?
-- How many times was each product added to a cart but not purchased (abandoned)?
-- How many times was each product purchased?

select * from events; --32734
select * from event_identifier; --5
select * from campaign_identifier; --3
select * from page_hierarchy; --13
select * from users; --1782

-- Strategy: 1 Utility table, 3 Agg table that are then combined into a Master Table
CREATE TABLE prod_stat
AS (
	WITH c1 AS (
		SELECT
			e.visit_id,
			ph.page_name,
			ei.event_name
		FROM 
			events AS e
		INNER JOIN page_hierarchy AS ph
				ON e.page_id = ph.page_id
		INNER JOIN event_identifier AS ei
				ON e.event_type = ei.event_type
		WHERE
			ph.product_id IS NOT NULL
		GROUP BY 
			e.visit_id,
			ph.page_name,
			ei.event_name
	)
	SELECT 
		cc1.page_name AS product,
		cc1.num_of_view,
		cc1.num_of_added_to_cart,
		cc2.num_of_abandoned,
		cc3.num_of_purchased
	FROM (
		SELECT 
			page_name,
			COUNT(*) FILTER(WHERE event_name = 'Page View') AS num_of_view,
			COUNT(*) FILTER(WHERE event_name = 'Add to Cart') AS num_of_added_to_cart
		FROM
			c1
		GROUP BY 
			page_name
	) AS cc1 
	INNER JOIN (
		SELECT 
			page_name,
			COUNT(*) AS num_of_abandoned
		FROM 
			c1
		WHERE 
			event_name = 'Add to Cart'
		AND visit_id NOT IN (
			SELECT 
				DISTINCT visit_id
			FROM
				events
			WHERE 
				event_type = 3
		)
		GROUP BY 
			page_name
	) AS cc2 ON cc1.page_name = cc2.page_name
	INNER JOIN (
		SELECT
			page_name,
			COUNT(*) AS num_of_purchased
		FROM
			c1
		WHERE 
			event_name = 'Add to Cart'
		AND
			visit_id IN (
			SELECT 
				DISTINCT visit_id
			FROM
				events
			WHERE 
				event_type = 3
		)
		GROUP BY 
			page_name
	) AS cc3 ON cc1.page_name = cc3.page_name
)

-- Testing
select * from prod_stat; --9
	
-- Additionally, create another table which further aggregates the data for the above points 
-- but this time for each product category instead of individual products.

select * from events; --32734
select * from event_identifier; --5
select * from campaign_identifier; --3
select * from page_hierarchy; --13
select * from users; --1782
select * from prod_stat; --9

CREATE TABLE prod_ctgy_stat AS ( 	
	SELECT
		ph.product_category,
		SUM(ps.num_of_view) AS num_of_view,
		SUM(ps.num_of_added_to_cart) AS num_of_added_to_cart,
		SUM(ps.num_of_purchased) AS num_of_purchased
	FROM
		prod_stat AS ps
	INNER JOIN page_hierarchy AS ph
			ON ps.product = ph.page_name
	GROUP BY 
		ph.product_category
	ORDER BY 
		ph.product_category ASC
);

-- Testing
select * from prod_ctgy_stat; --3
	
-- Use your 2 new output tables - answer the following questions:

-- Which product had the most views, cart adds and purchases?
select * from events; --32734
select * from event_identifier; --5
select * from campaign_identifier; --3
select * from page_hierarchy; --13
select * from users; --1782
select * from prod_stat; --9
select * from prod_ctgy_stat; --3

-- product, stat_flag, num_of_records

SELECT
	*
FROM (
	SELECT
		product,
		num_of_view,
		RANK() OVER(ORDER BY num_of_view DESC) AS view_ranking
	FROM 
		prod_stat
),
LATERAL (
	SELECT
		product,
		num_of_added_to_cart,
		RANK() OVER(ORDER BY num_of_added_to_cart DESC) AS added_to_cart_ranking
	FROM 
		prod_stat
),
LATERAL (
	SELECT
		product,
		num_of_purchased,
		RANK() OVER(ORDER BY num_of_purchased DESC) AS purchased_ranking
	FROM 
		prod_stat
)
WHERE
	view_ranking = 1
AND 
	added_to_cart_ranking = 1
AND
	purchased_ranking = 1
	

-- Which product was most likely to be abandoned?

select * from events; --32734
select * from event_identifier; --5
select * from campaign_identifier; --3
select * from page_hierarchy; --13
select * from users; --1782
select * from prod_stat; --9
select * from prod_ctgy_stat; --3

WITH c1 AS (
	SELECT
		product,
		num_of_abandoned,
		DENSE_RANK() OVER(ORDER BY num_of_abandoned DESC) AS abandoned_ranking
	FROM 
		prod_stat
)
SELECT
	product,
	num_of_abandoned
FROM
	c1
WHERE
	abandoned_ranking = 1;

-- Which product had the highest view to purchase percentage?

select * from events; --32734
select * from event_identifier; --5
select * from campaign_identifier; --3
select * from page_hierarchy; --13
select * from users; --1782
select * from prod_stat; --9
select * from prod_ctgy_stat; --3

WITH c1 AS (
	SELECT
		*,
		DENSE_RANK() OVER(ORDER BY percentage DESC) AS percentage_ranking
	FROM (
		SELECT
			product,
			ROUND(num_of_purchased::DECIMAL / num_of_view * 100, 2) AS percentage
		FROM
			prod_stat
	)
)
SELECT
	product,
	percentage
FROM
	c1
WHERE
	percentage_ranking = 1;

-- What is the average conversion rate from view to cart add?

select * from prod_stat; --9
select * from prod_ctgy_stat; --3

SELECT
	ROUND(AVG(num_of_added_to_cart::DECIMAL / num_of_view * 100), 2) AS avg_conversion_rate_of_view_to_added_to_cart
FROM
	prod_stat;


-- What is the average conversion rate from cart add to purchase?
	
SELECT
	ROUND(AVG(num_of_purchased::DECIMAL / num_of_added_to_cart * 100), 2) AS avg_conversion_rate_of_added_to_cart_to_purchased
FROM
	prod_ctgy_stat
	

-- Section 4 - Campaigns Analysis
-- Generate a table that has 1 single row for every unique visit_id record and has the following columns:
-- a) user_id
-- b) visit_id
-- c) visit_start_time: the earliest event_time for each visit
-- d) page_views: count of page views for each visit
-- e) cart_adds: count of product cart add events for each visit
-- f) purchase: 1/0 flag if a purchase event exists for each visit
-- g) campaign_name: map the visit to a campaign if the visit_start_time falls between the start_date and end_date
-- h) impression: count of ad impressions for each visit
-- i) click: count of ad clicks for each visit
-- j) Optional column) cart_products: a comma separated text value with products added to the cart sorted by 
-- 	  the order they were added to the cart (hint: use the sequence_number)
	
select * from events; --32734
select * from event_identifier; --5
select * from campaign_identifier; --3
select * from page_hierarchy; --13
select * from users; --1782
select * from prod_stat; --9
select * from prod_ctgy_stat; --3

SET 
	SEARCH_PATH = clique_bait;
	
	
	
CREATE TABLE campaign_analyze AS (	
	WITH c1 AS (
		SELECT
			u.user_id,
			e.visit_id,
			MIN(e.event_time) AS visit_start_time,
			COUNT(*) FILTER(WHERE e.event_type = 1) AS page_views,
			COUNT(*) FILTER(WHERE e.event_type = 2) AS cart_adds,
			COUNT(*) FILTER(WHERE e.event_type = 4) AS impression,
			COUNT(*) FILTER(WHERE e.event_type = 5) AS click,
			CASE WHEN e.visit_id IN (
				SELECT
					DISTINCT visit_id
				FROM
					events
				WHERE 
					event_type = 3
			) THEN 1 ELSE 0 END AS purchase
		FROM 
			events AS e
		INNER JOIN users AS u
				ON e.cookie_id = u.cookie_id
		GROUP BY 
			e.visit_id,
			u.user_id
	), c2 AS (	
	SELECT
		c1.user_id,
		c1.visit_id,
		c1.visit_start_time,
		c1.page_views,
		c1.cart_adds,
		c1.purchase,
		ci.campaign_name,
		c1.impression,
		c1.click
	FROM
		c1
	LEFT JOIN campaign_identifier AS ci
			ON visit_start_time BETWEEN ci.start_date AND ci.end_date
	ORDER BY 
		c1.user_id ASC,
		c1.visit_start_time ASC
	), c3 AS (
		SELECT 
			e.visit_id,
			ei.event_name,
			STRING_AGG(ph.page_name, ', ' ORDER BY e.sequence_number ASC) AS cart_products
		FROM 
			events AS e
		INNER JOIN page_hierarchy AS ph
			ON ph.page_id = e.page_id
		INNER JOIN event_identifier AS ei
			ON ei.event_type = e.event_type
		WHERE ei.event_name = 'Add to Cart'
		GROUP BY 
			e.visit_id,
			ei.event_name
		ORDER BY 
			e.visit_id ASC
	)
	SELECT
		c2.*,
		c3.cart_products
	FROM
		c2
	LEFT JOIN c3
			ON c2.visit_id = c3.visit_id
	ORDER BY
		c2.user_id ASC,
		c2.visit_start_time ASC
);


