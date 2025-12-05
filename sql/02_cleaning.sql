-- Cleaning and feature steps for Online Retail II
-- Step 1: build CLEAN_ORDERS from RAW_ORDERS
-- Step 2: split RETURNS_ORDERS
-- Step 3: build ORDER_LEVEL
-- Step 4: build CUSTOMER_METRICS
-- Step 5: build PRODUCT_METRICS

-- Step 1: build CLEAN_ORDERS from RAW_ORDERS

TRUNCATE TABLE clean_orders;

WITH typed AS (
    SELECT
        invoice_no,
        stock_code,
        description,
        CAST(quantity   AS INTEGER)         AS quantity_int,
        CAST(unit_price AS NUMERIC(10,2))   AS unit_price_num,
        CAST(customer_id AS INTEGER)        AS customer_id_int,
        country,
        to_timestamp(
            invoice_date_raw,
            'MM/DD/YYYY HH24:MI'            -- change to 'DD/MM/YYYY HH24:MI' if your dates are day/month/year
        ) AS ts
    FROM raw_orders
    WHERE invoice_date_raw IS NOT NULL
)
INSERT INTO clean_orders (
    invoice_no,
    stock_code,
    description,
    quantity,
    unit_price,
    customer_id,
    country,
    invoice_ts,
    invoice_date,
    invoice_month,
    invoice_quarter,
    line_revenue
)
SELECT
    invoice_no,
    stock_code,
    description,
    quantity_int       AS quantity,
    unit_price_num     AS unit_price,
    customer_id_int    AS customer_id,
    country,
    ts                 AS invoice_ts,
    ts::date           AS invoice_date,
    date_trunc('month', ts)::date                        AS invoice_month,
    to_char(ts, 'YYYY') || ' Q' || to_char(ts, 'Q')      AS invoice_quarter,
    quantity_int * unit_price_num                        AS line_revenue
FROM typed
WHERE
    quantity_int > 0
    AND unit_price_num IS NOT NULL;


-- Step 2: split RETURNS_ORDERS

TRUNCATE TABLE returns_orders;

WITH typed AS (
    SELECT
        invoice_no,
        stock_code,
        description,
        CAST(quantity   AS INTEGER)         AS quantity_int,
        CAST(unit_price AS NUMERIC(10,2))   AS unit_price_num,
        CAST(customer_id AS INTEGER)        AS customer_id_int,
        country,
        to_timestamp(
            invoice_date_raw,
            'MM/DD/YYYY HH24:MI'            -- same format used above
        ) AS ts
    FROM raw_orders
    WHERE invoice_date_raw IS NOT NULL
)
INSERT INTO returns_orders (
    invoice_no,
    stock_code,
    description,
    quantity,
    unit_price,
    customer_id,
    country,
    invoice_ts,
    invoice_date,
    invoice_month,
    invoice_quarter,
    line_revenue
)
SELECT
    invoice_no,
    stock_code,
    description,
    quantity_int       AS quantity,
    unit_price_num     AS unit_price,
    customer_id_int    AS customer_id,
    country,
    ts                 AS invoice_ts,
    ts::date           AS invoice_date,
    date_trunc('month', ts)::date                        AS invoice_month,
    to_char(ts, 'YYYY') || ' Q' || to_char(ts, 'Q')      AS invoice_quarter,
    quantity_int * unit_price_num                        AS line_revenue
FROM typed
WHERE
    quantity_int < 0
    AND unit_price_num IS NOT NULL;


-- Step 3: build ORDER_LEVEL

TRUNCATE TABLE order_level;

INSERT INTO order_level (
    invoice_no,
    customer_id,
    country,
    invoice_date,
    order_revenue
)
SELECT
    invoice_no,
    customer_id,
    country,
    invoice_date,
    SUM(line_revenue) AS order_revenue
FROM clean_orders
GROUP BY
    invoice_no,
    customer_id,
    country,
    invoice_date;


-- Step 4: build CUSTOMER_METRICS

TRUNCATE TABLE customer_metrics;

INSERT INTO customer_metrics (
    customer_id,
    total_revenue,
    order_count,
    first_order_date,
    last_order_date
)
SELECT
    customer_id,
    SUM(order_revenue) AS total_revenue,
    COUNT(*)           AS order_count,
    MIN(invoice_date)  AS first_order_date,
    MAX(invoice_date)  AS last_order_date
FROM order_level
WHERE customer_id IS NOT NULL
GROUP BY customer_id;


-- Step 5: build PRODUCT_METRICS

TRUNCATE TABLE product_metrics;

INSERT INTO product_metrics (
    stock_code,
    description,
    line_count,
    units_sold,
    total_revenue,
    avg_line_revenue
)
SELECT
    stock_code,
    MAX(description)       AS description,
    COUNT(*)               AS line_count,
    SUM(quantity)          AS units_sold,
    SUM(line_revenue)      AS total_revenue,
    AVG(line_revenue)      AS avg_line_revenue
FROM clean_orders
GROUP BY stock_code;

SELECT COUNT(*) AS customer_metrics_rows FROM customer_metrics;




