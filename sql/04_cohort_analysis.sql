-- 04_cohort_analysis.sql
-- Cohort analysis for paid orders in 2024
-- Cohort = first purchase month (YYYY-MM) per customer.
-- Output view includes monthly net revenue and cumulative net revenue per cohort.

DROP VIEW IF EXISTS cohort_monthly_revenue;
DROP VIEW IF EXISTS cohort_retention_proxy;

-- -----------------------------
-- View 1: cohort_monthly_revenue
-- -----------------------------
CREATE VIEW cohort_monthly_revenue AS
WITH
orders_2024_paid AS (
  SELECT order_id, customer_id, order_date
  FROM orders
  WHERE status = 'paid'
    AND order_date >= '2024-01-01'
    AND order_date <  '2025-01-01'
),
order_items_agg AS (
  SELECT
    order_id,
    product_id,
    SUM(COALESCE(qty, 0)) AS qty,
    MAX(unit_price) AS unit_price
  FROM order_items
  GROUP BY order_id, product_id
),
returns_agg AS (
  SELECT
    order_id,
    product_id,
    SUM(returned_qty) AS returned_qty
  FROM returns
  GROUP BY order_id, product_id
),
line_calc AS (
  SELECT
    o.customer_id,
    o.order_date,
    substr(o.order_date, 1, 7) AS year_month,  -- YYYY-MM
    (COALESCE(ia.qty, 0) * COALESCE(ia.unit_price, 0)) AS line_gross_amount,
    (COALESCE(ra.returned_qty, 0) * COALESCE(ia.unit_price, 0)) AS line_returned_amount
  FROM orders_2024_paid o
  JOIN order_items_agg ia
    ON ia.order_id = o.order_id
  LEFT JOIN returns_agg ra
    ON ra.order_id = ia.order_id
   AND ra.product_id = ia.product_id
),
customer_monthly AS (
  SELECT
    customer_id,
    year_month,
    SUM(line_gross_amount) AS gross_revenue,
    SUM(line_returned_amount) AS returned_amount,
    SUM(line_gross_amount) - SUM(line_returned_amount) AS net_revenue
  FROM line_calc
  GROUP BY customer_id, year_month
),
customer_cohort AS (
  SELECT
    customer_id,
    MIN(year_month) AS cohort_month
  FROM customer_monthly
  GROUP BY customer_id
),
cohort_monthly AS (
  SELECT
    cc.cohort_month,
    cm.year_month,
    COUNT(DISTINCT cm.customer_id) AS active_customers_in_month,
    SUM(cm.net_revenue) AS cohort_net_revenue
  FROM customer_monthly cm
  JOIN customer_cohort cc
    ON cc.customer_id = cm.customer_id
  GROUP BY cc.cohort_month, cm.year_month
),
cohort_sizes AS (
  SELECT
    cohort_month,
    COUNT(*) AS customers_in_cohort
  FROM customer_cohort
  GROUP BY cohort_month
)
SELECT
  m.cohort_month,
  m.year_month,
  s.customers_in_cohort,
  m.active_customers_in_month,
  m.cohort_net_revenue,
  SUM(m.cohort_net_revenue) OVER (
    PARTITION BY m.cohort_month
    ORDER BY m.year_month
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS cohort_cum_net_revenue
FROM cohort_monthly m
JOIN cohort_sizes s
  ON s.cohort_month = m.cohort_month
ORDER BY m.cohort_month, m.year_month;

-- -----------------------------
-- View 2 (optional): cohort_retention_proxy
-- -----------------------------
-- "Retention proxy" = how many cohort customers had any purchase in each month.
CREATE VIEW cohort_retention_proxy AS
WITH
orders_2024_paid AS (
  SELECT order_id, customer_id, order_date
  FROM orders
  WHERE status = 'paid'
    AND order_date >= '2024-01-01'
    AND order_date <  '2025-01-01'
),
customer_orders_monthly AS (
  SELECT
    customer_id,
    substr(order_date, 1, 7) AS year_month
  FROM orders_2024_paid
  GROUP BY customer_id, substr(order_date, 1, 7)
),
customer_cohort AS (
  SELECT
    customer_id,
    MIN(year_month) AS cohort_month
  FROM customer_orders_monthly
  GROUP BY customer_id
),
cohort_sizes AS (
  SELECT
    cohort_month,
    COUNT(*) AS customers_in_cohort
  FROM customer_cohort
  GROUP BY cohort_month
)
SELECT
  cc.cohort_month,
  com.year_month,
  cs.customers_in_cohort,
  COUNT(*) AS customers_with_purchase_in_month,
  ROUND(COUNT(*) * 1.0 / cs.customers_in_cohort, 4) AS active_rate
FROM customer_orders_monthly com
JOIN customer_cohort cc
  ON cc.customer_id = com.customer_id
JOIN cohort_sizes cs
  ON cs.cohort_month = cc.cohort_month
GROUP BY cc.cohort_month, com.year_month, cs.customers_in_cohort
ORDER BY cc.cohort_month, com.year_month;

SELECT * FROM cohort_monthly_revenue LIMIT 10;
SELECT * FROM cohort_retention_proxy LIMIT 10;

SELECT COUNT(*) AS total_orders_2024
FROM orders
WHERE order_date >= '2024-01-01'
  AND order_date <  '2025-01-01';

SELECT order_date, COUNT(*)
FROM orders
GROUP BY order_date
LIMIT 5;

SELECT COUNT(*) AS total_orders FROM orders;




