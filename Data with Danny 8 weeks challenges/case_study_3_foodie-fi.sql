Set search_path = foodie_fi
select * from plans; -- 5
select * from subscriptions; --2650

-- Section A. Customer Journey
-- Based off the 8 sample customers provided in the sample from the subscriptions table, 
-- write a brief description about each customer’s onboarding journey.
-- Try to keep it as short as possible - you may also want to run some sort of join to make your explanations a bit easier!

-- Section B. Data Analysis Questions
-- 1. How many customers has Foodie-Fi ever had?

SELECT
		COUNT(DISTINCT customer_id) AS num_customers
FROM
		subscriptions;

-- 2. What is the monthly distribution of trial plan start_date values for our dataset - 
-- use the start of the month as the group by value

select * from plans; -- 5
select * from subscriptions; --2650

SELECT
		DATE_TRUNC('month', s.start_date)::DATE AS _month,
		COUNT(customer_id) AS cnt
FROM
		subscriptions AS s
INNER JOIN plans AS p 
		USING(plan_id) 
WHERE 
		p.plan_name = 'trial'
GROUP BY
		DATE_TRUNC('month', s.start_date)
ORDER BY 
		_month ASC;

-- 3. What plan start_date values occur after the year 2020 for our dataset? 
-- Show the breakdown by count of events for each plan_name.
select * from plans; -- 5
select * from subscriptions; --2650

SET
		SEARCH_PATH = foodie_fi;
SELECT
		p.plan_name,
		COUNT(*) AS num_of_events
FROM
		subscriptions AS s
INNER JOIN plans AS p
		ON s.plan_id = p.plan_id
WHERE 
		s.start_date >= TO_DATE('2021-01-01', 'YYYY-MM-DD')
GROUP BY 
		p.plan_name
ORDER BY 
		p.plan_name ASC;

-- 4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?

select * from plans; -- 5
select * from subscriptions; --2650

SET
		SEARCH_PATH = foodie_fi;
SELECT
		p.plan_name,
		COUNT(DISTINCT s.customer_id) AS num_customer,
		ROUND(COUNT(DISTINCT s.customer_id)::DECIMAL / tc.total_customer * 100, 1) AS percentage_of_customer
FROM
		subscriptions AS s
INNER JOIN plans AS p
		ON s.plan_id = p.plan_id,
LATERAL(
	SELECT
			COUNT(DISTINCT customer_id) AS total_customer
	FROM 
			subscriptions
) AS tc
WHERE 
		p.plan_name = 'churn'
GROUP BY
		p.plan_name,
		tc.total_customer;

-- 5. How many customers have churned straight after their initial free trial - 
-- what percentage is this rounded to the nearest whole number?

select * from plans; -- 5
select * from subscriptions; --2650

SET 
	SEARCH_PATH = foodie_fi;

SELECT
	p.plan_name,
	ROUND(COUNT(DISTINCT s.customer_id)::DECIMAL / (
		SELECT
			COUNT(DISTINCT customer_id)
		FROM
			subscriptions
		WHERE
			plan_id = 4
	) * 100) AS percentage_of_churned_after_trial,
	ROUND(COUNT(DISTINCT s.customer_id)::DECIMAL / (
		SELECT
			COUNT(DISTINCT customer_id)
		FROM
			subscriptions
	) * 100) AS percentage_of_churned_after_trial_to_all
	
FROM 
	subscriptions AS s
INNER JOIN plans AS p
		ON p.plan_id = s.plan_id
INNER JOIN (
	SELECT 
		customer_id,
		(start_date + INTERVAL'7days')::DATE AS trial_end
	FROM 
		subscriptions 
	WHERE
		plan_id = 0
) AS c1 ON c1.customer_id = s.customer_id
		AND c1.trial_end = s.start_date 
WHERE 
	s.plan_id = 4
GROUP BY 
	p.plan_name;

-- 6. What is the number and percentage of customer plans after their initial free trial?

select * from plans; -- 5
select * from subscriptions; --2650

SELECT
	plan_name,
	num_customer_after_trial,
	ROUND(num_customer_after_trial::DECIMAL / (
		SELECT
			COUNT(DISTINCT customer_id)
		FROM
			subscriptions
	) * 100, 1) AS percentage_customer_after_trial
FROM (
	SELECT 
		p.plan_id,
		p.plan_name,
		COUNT(s.customer_id) AS num_customer_after_trial
	FROM
		subscriptions AS s
	INNER JOIN plans AS p
		ON s.plan_id = p.plan_id
	INNER JOIN (
		SELECT
			customer_id,
			(start_date + INTERVAL'7 days')::DATE AS trial_end
		FROM 	
			subscriptions
		WHERE 
			plan_id = 0	
	) AS te ON te.customer_id = s.customer_id 
			AND te.trial_end = s.start_date
	WHERE 
		s.plan_id <> 0
	GROUP BY 
		p.plan_name,
		p.plan_id
)
ORDER BY 
	plan_id ASC;

-- 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?

select * from plans; -- 5
select * from subscriptions; --2650

WITH c1 AS (
	SELECT
		s.customer_id,
		p.plan_name,
		DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.start_date DESC) AS latest_plan
	FROM
		subscriptions AS s
	INNER JOIN plans AS p
			ON p.plan_id = s.plan_id
	WHERE 
		s.start_date <= '2020-12-31'::DATE
)
SELECT
	c1.plan_name,
	COUNT(DISTINCT c1.customer_id) AS customer_count,
	ROUND(COUNT(DISTINCT c1.customer_id)::DECIMAL / c2.num_customer * 100 , 1) AS percentage_of_customer
FROM c1,
LATERAL (
	SELECT
		COUNT(DISTINCT customer_id) AS num_customer
	FROM 		
		subscriptions 
) AS c2
WHERE
	c1.latest_plan = 1
GROUP BY 
	c1.plan_name,
	c2.num_customer
ORDER BY
	c1.plan_name ASC;
		
-- 8. How many customers have upgraded to an annual plan in 2020?

select * from plans; -- 5
select * from subscriptions; --2650

SELECT
	plan_name,
	COUNT(DISTINCT customer_id) AS num_customer
FROM (
	SELECT
		p.plan_name,
		s.*
	FROM
		subscriptions AS s
	INNER JOIN plans AS p
			ON s.plan_id = p.plan_id
	WHERE
		EXTRACT(year from s.start_date) = '2020'
	AND
		s.plan_id = 3
)
GROUP BY 
	plan_name;
	
-- 9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?

select * from plans; -- 5
select * from subscriptions; --2650


SELECT 
	p.plan_name,
	ROUND(AVG(c1.start_date - s.start_date)) AS avg_days
FROM 
	subscriptions AS s
INNER JOIN (
	SELECT
		*
	FROM
		subscriptions AS s
	WHERE
		plan_id = 3
) AS c1 ON s.customer_id = c1.customer_id 
		AND s.plan_id = 0
INNER JOIN plans AS p
		ON c1.plan_id = p.plan_id
GROUP BY 
		p.plan_name;

-- 10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
select * from plans; -- 5
select * from subscriptions; --2650

SET
	SEARCH_PATH = foodie_fi;
	
-- 30_days_period, number_of_customer, avg_days 	

SELECT 
	*
FROM (
	SELECT
		p.plan_name,
		CASE WHEN c1.start_date - s.start_date <= 30 THEN '0-30 days'
			 WHEN c1.start_date - s.start_date BETWEEN 31 AND 60 THEN '31-60 days'
			 WHEN c1.start_date - s.start_date BETWEEN 61 AND 90 THEN '61-90 days'
			 WHEN c1.start_date - s.start_date BETWEEN 91 AND 120 THEN '91-120 days'
			 WHEN c1.start_date - s.start_date BETWEEN 121 AND 150 THEN '121-150 days'
			 WHEN c1.start_date - s.start_date BETWEEN 151 AND 180 THEN '151-180 days'
			 WHEN c1.start_date - s.start_date BETWEEN 181 AND 210 THEN '181-210 days'
			 WHEN c1.start_date - s.start_date BETWEEN 211 AND 240 THEN '211-240 days'
			 WHEN c1.start_date - s.start_date BETWEEN 241 AND 270 THEN '241-270 days'
			 WHEN c1.start_date - s.start_date BETWEEN 271 AND 300 THEN '271-300 days'
			 WHEN c1.start_date - s.start_date BETWEEN 301 AND 330 THEN '301-330 days'
			 WHEN c1.start_date - s.start_date BETWEEN 331 AND 360 THEN '331-360 days'
			 WHEN c1.start_date - s.start_date >= 361 THEN '360+ days'
		END AS _30_days_period,
		COUNT(DISTINCT s.customer_id) AS num_of_customer,
		ROUND(AVG(c1.start_date - s.start_date)) AS avg_days
	FROM 
		subscriptions AS s
	INNER JOIN plans AS p
			ON s.plan_id = p.plan_id
	INNER JOIN(
		SELECT 
			*
		FROM
			subscriptions
		WHERE 
			plan_id = 3
	) AS c1 ON c1.customer_id = s.customer_id
			AND s.plan_id = 0
	GROUP BY 
		p.plan_name,
		CASE WHEN c1.start_date - s.start_date <= 30 THEN '0-30 days'
			 WHEN c1.start_date - s.start_date BETWEEN 31 AND 60 THEN '31-60 days'
			 WHEN c1.start_date - s.start_date BETWEEN 61 AND 90 THEN '61-90 days'
			 WHEN c1.start_date - s.start_date BETWEEN 91 AND 120 THEN '91-120 days'
			 WHEN c1.start_date - s.start_date BETWEEN 121 AND 150 THEN '121-150 days'
			 WHEN c1.start_date - s.start_date BETWEEN 151 AND 180 THEN '151-180 days'
			 WHEN c1.start_date - s.start_date BETWEEN 181 AND 210 THEN '181-210 days'
			 WHEN c1.start_date - s.start_date BETWEEN 211 AND 240 THEN '211-240 days'
			 WHEN c1.start_date - s.start_date BETWEEN 241 AND 270 THEN '241-270 days'
			 WHEN c1.start_date - s.start_date BETWEEN 271 AND 300 THEN '271-300 days'
			 WHEN c1.start_date - s.start_date BETWEEN 301 AND 330 THEN '301-330 days'
			 WHEN c1.start_date - s.start_date BETWEEN 331 AND 360 THEN '331-360 days'
			 WHEN c1.start_date - s.start_date >= 361 THEN '360+ days'
		END
)
ORDER BY 
	avg_days ASC;

-- 11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
select * from plans; -- 5
select * from subscriptions; --2650


SELECT
	COUNT(DISTINCT s.customer_id) AS num_downgraded_customer
FROM 
	subscriptions AS s
INNER JOIN (
SELECT
	*
FROM
	subscriptions
WHERE 
	EXTRACT(YEAR FROM start_date) = 2020
AND 
	plan_id = 3
) AS c1 ON s.customer_id = c1.customer_id
		AND s.plan_id = 1
		AND s.start_date >= c1.start_date;

-- Section D. Outside The Box Questions
-- The following are open ended questions which might be asked during a technical interview for this case study 
-- - there are no right or wrong answers, but answers that make sense from both a technical and 
-- a business perspective make an amazing impression!

-- 1. How would you calculate the rate of growth for Foodie-Fi?
select * from plans; -- 5
select * from subscriptions; --2650

WITH c1 AS (
	SELECT
		DATE_TRUNC('MONTH', start_date) AS _month,
		COUNT(customer_id) AS current_num_of_customer,
		LAG(COUNT(*), 1) OVER(ORDER BY DATE_TRUNC('MONTH', start_date) ASC) AS past_num_of_customer
	FROM 
		subscriptions
	WHERE 
		plan_id NOT IN (0, 4) 
	GROUP BY 
		DATE_TRUNC('MONTH', start_date)
)
SELECT
	*,
	ROUND((current_num_of_customer - past_num_of_customer)::DECIMAL / past_num_of_customer * 100, 2) || '%' AS grwth_rate
FROM 
	c1;
