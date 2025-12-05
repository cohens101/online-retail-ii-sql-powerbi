-- Analysis queries for Online Retail revenue and customer insights
-- Q1: revenue by month and quarter
-- Q1a: monthly revenue and order count

SELECT
    invoice_month,
    SUM(line_revenue)                    AS monthly_revenue,
    COUNT(DISTINCT invoice_no)           AS order_count
FROM clean_orders
GROUP BY invoice_month
ORDER BY invoice_month;

-- Q1b: quarterly revenue and order count

SELECT
    invoice_quarter,
    SUM(line_revenue)                    AS quarterly_revenue,
    COUNT(DISTINCT invoice_no)           AS order_count
FROM clean_orders
GROUP BY invoice_quarter
ORDER BY invoice_quarter;

-- Q2: high value customers
-- Q2a: top 20 customers by total revenue

SELECT
    cm.customer_id,
    cm.total_revenue,
    cm.order_count,
    cm.first_order_date,
    cm.last_order_date
FROM customer_metrics cm
ORDER BY cm.total_revenue DESC
LIMIT 20;

-- Q2b: revenue share by customer decile

WITH ranked AS (
    SELECT
        customer_id,
        total_revenue,
        NTILE(10) OVER (ORDER BY total_revenue DESC) AS decile
    FROM customer_metrics
),
totals AS (
    SELECT SUM(total_revenue) AS grand_revenue
    FROM customer_metrics
)
SELECT
    r.decile,
    COUNT(*)                      AS customer_count,
    SUM(r.total_revenue)          AS decile_revenue,
    SUM(r.total_revenue) / t.grand_revenue AS revenue_share
FROM ranked r
CROSS JOIN totals t
GROUP BY r.decile, t.grand_revenue
ORDER BY r.decile;

-- Q3: product performance
-- Q3a: top 20 products by total revenue

SELECT
stock_code,
description,
units_sold,
total_revenue,
avg_line_revenue
FROM product_metrics
ORDER BY total_revenue DESC
LIMIT 20;

-- Q3b: top 20 products by units sold

SELECT
stock_code,
description,
units_sold,
total_revenue,
avg_line_revenue
FROM product_metrics
ORDER BY units_sold DESC
LIMIT 20;

-- Q3c: low volume and low revenue products

SELECT
stock_code,
description,
units_sold,
total_revenue,
avg_line_revenue
FROM product_metrics
WHERE units_sold < 50
AND total_revenue < 500
ORDER BY total_revenue ASC
LIMIT 20;

-- Q4: country performance
-- Q4a: total revenue and order count by country

SELECT
country,
COUNT(*) AS order_count,
SUM(order_revenue) AS total_revenue,
AVG(order_revenue) AS avg_order_value
FROM order_level
GROUP BY country
ORDER BY total_revenue DESC;

-- Q4b: top 10 countries by average order value (minimum order filter to reduce noise)

SELECT
country,
COUNT(*) AS order_count,
SUM(order_revenue) AS total_revenue,
AVG(order_revenue) AS avg_order_value
FROM order_level
GROUP BY country
HAVING COUNT(*) >= 100
ORDER BY avg_order_value DESC
LIMIT 10;


-- Q5: order value and ranges

-- Q5a: overall order value stats

SELECT
    AVG(order_revenue)                                            AS avg_order_value,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY order_revenue)    AS median_order_value,
    MIN(order_revenue)                                            AS min_order_value,
    MAX(order_revenue)                                            AS max_order_value
FROM order_level;


-- Q5b: order value by country

SELECT
    country,
    COUNT(*)               AS order_count,
    SUM(order_revenue)     AS total_revenue,
    AVG(order_revenue)     AS avg_order_value
FROM order_level
GROUP BY country
ORDER BY avg_order_value DESC;


-- Q5c: order value bands (low, mid, high) summary

WITH banded AS (
    SELECT
        invoice_no,
        customer_id,
        country,
        invoice_date,
        order_revenue,
        CASE
            WHEN order_revenue < 50      THEN 'low'
            WHEN order_revenue < 150     THEN 'mid'
            ELSE 'high'
        END AS value_band
    FROM order_level
)
SELECT
    value_band,
    COUNT(*)                  AS order_count,
    AVG(order_revenue)        AS avg_order_value,
    SUM(order_revenue)        AS total_revenue
FROM banded
GROUP BY value_band
ORDER BY
    CASE value_band
        WHEN 'low'  THEN 1
        WHEN 'mid'  THEN 2
        WHEN 'high' THEN 3
    END;
	
-- Q6: new vs repeat customers

-- Q6a: classify each order as first or repeat and summarize

WITH labeled_orders AS (
    SELECT
        ol.invoice_no,
        ol.customer_id,
        ol.country,
        ol.invoice_date,
        ol.order_revenue,
        CASE
            WHEN ol.invoice_date = cm.first_order_date THEN 'first'
            ELSE 'repeat'
        END AS order_type
    FROM order_level ol
    JOIN customer_metrics cm
        ON ol.customer_id = cm.customer_id
)
SELECT
    order_type,
    COUNT(*)           AS order_count,
    SUM(order_revenue) AS total_revenue,
    AVG(order_revenue) AS avg_order_value
FROM labeled_orders
GROUP BY order_type
ORDER BY order_type;

-- Q6b: revenue share for first vs repeat orders

WITH labeled_orders AS (
    SELECT
        ol.invoice_no,
        ol.customer_id,
        ol.country,
        ol.invoice_date,
        ol.order_revenue,
        CASE
            WHEN ol.invoice_date = cm.first_order_date THEN 'first'
            ELSE 'repeat'
        END AS order_type
    FROM order_level ol
    JOIN customer_metrics cm
        ON ol.customer_id = cm.customer_id
),
totals AS (
    SELECT SUM(order_revenue) AS grand_revenue
    FROM labeled_orders
)
SELECT
    lo.order_type,
    COUNT(*)                 AS order_count,
    SUM(lo.order_revenue)    AS total_revenue,
    AVG(lo.order_revenue)    AS avg_order_value,
    SUM(lo.order_revenue) / t.grand_revenue AS revenue_share
FROM labeled_orders lo
CROSS JOIN totals t
GROUP BY lo.order_type, t.grand_revenue
ORDER BY lo.order_type;

-- Q7: returns and net revenue
-- Q7a: gross revenue, returns value, net revenue, returns rate

WITH gross AS (
    SELECT
        SUM(line_revenue) AS gross_revenue
    FROM clean_orders
),
returns AS (
    SELECT
        SUM(ABS(line_revenue)) AS returns_value
    FROM returns_orders
)
SELECT
    g.gross_revenue,
    r.returns_value,
    g.gross_revenue - r.returns_value AS net_revenue,
    r.returns_value / g.gross_revenue AS returns_rate
FROM gross g
CROSS JOIN returns r;

-- Q7b: products with highest returns ratio and returns value

WITH sales AS (
    SELECT
        stock_code,
        description,
        line_count,
        units_sold,
        total_revenue AS sales_revenue
    FROM product_metrics
),
returns AS (
    SELECT
        stock_code,
        SUM(ABS(line_revenue)) AS returns_value,
        SUM(ABS(quantity))     AS units_returned
    FROM returns_orders
    GROUP BY stock_code
),
joined AS (
    SELECT
        s.stock_code,
        s.description,
        s.units_sold,
        s.sales_revenue,
        COALESCE(r.units_returned, 0) AS units_returned,
        COALESCE(r.returns_value, 0)  AS returns_value
    FROM sales s
    LEFT JOIN returns r
        ON s.stock_code = r.stock_code
)
SELECT
    stock_code,
    description,
    units_sold,
    units_returned,
    sales_revenue,
    returns_value,
    CASE
        WHEN sales_revenue > 0
        THEN returns_value / sales_revenue
        ELSE NULL
    END AS returns_rate
FROM joined
WHERE returns_value > 0
ORDER BY
    returns_rate DESC,
    returns_value DESC
LIMIT 20;

-- Q7c: returns by country, both value and rate

WITH sales AS (
    SELECT
        country,
        SUM(line_revenue) AS sales_revenue
    FROM clean_orders
    GROUP BY country
),
returns AS (
    SELECT
        country,
        SUM(ABS(line_revenue)) AS returns_value
    FROM returns_orders
    GROUP BY country
),
joined AS (
    SELECT
        s.country,
        s.sales_revenue,
        COALESCE(r.returns_value, 0) AS returns_value
    FROM sales s
    LEFT JOIN returns r
        ON s.country = r.country
)
SELECT
    country,
    sales_revenue,
    returns_value,
    CASE
        WHEN sales_revenue > 0
        THEN returns_value / sales_revenue
        ELSE NULL
    END AS returns_rate
FROM joined
WHERE sales_revenue > 0
ORDER BY
    returns_rate DESC,
    sales_revenue DESC;

-- Q8: customer spend tiers
-- Q8a: summary of low / mid / high tiers by total revenue

WITH ranked AS (
    SELECT
        customer_id,
        total_revenue,
        order_count,
        NTILE(3) OVER (ORDER BY total_revenue) AS tier_num
    FROM customer_metrics
),
tiers AS (
    SELECT
        customer_id,
        total_revenue,
        order_count,
        CASE tier_num
            WHEN 1 THEN 'low'
            WHEN 2 THEN 'mid'
            WHEN 3 THEN 'high'
        END AS spend_tier
    FROM ranked
)
SELECT
    spend_tier,
    COUNT(*)                        AS customer_count,
    SUM(total_revenue)              AS tier_revenue,
    SUM(total_revenue)
      / SUM(SUM(total_revenue)) OVER () AS revenue_share,
    SUM(order_count)                AS total_orders,
    AVG(total_revenue)              AS avg_revenue_per_customer
FROM tiers
GROUP BY spend_tier
ORDER BY
    CASE spend_tier
        WHEN 'low'  THEN 1
        WHEN 'mid'  THEN 2
        WHEN 'high' THEN 3
    END;

-- Q8b: detailed customer list with spend tier

WITH ranked AS (
    SELECT
        customer_id,
        total_revenue,
        order_count,
        NTILE(3) OVER (ORDER BY total_revenue) AS tier_num
    FROM customer_metrics
)
SELECT
    customer_id,
    total_revenue,
    order_count,
    CASE tier_num
        WHEN 1 THEN 'low'
        WHEN 2 THEN 'mid'
        WHEN 3 THEN 'high'
    END AS spend_tier
FROM ranked
ORDER BY
    CASE
        WHEN tier_num = 1 THEN 1
        WHEN tier_num = 2 THEN 2
        WHEN tier_num = 3 THEN 3
    END,
    total_revenue;

