-- 03_revenue_metrics.sql (FIXED for SQLite)
DROP VIEW IF EXISTS revenue_by_customer;
DROP VIEW IF EXISTS revenue_monthly_by_customer;

CREATE VIEW revenue_by_customer AS
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
    (COALESCE(ia.qty, 0) * COALESCE(ia.unit_price, 0)) AS line_gross_amount,
    (COALESCE(ra.returned_qty, 0) * COALESCE(ia.unit_price, 0)) AS line_returned_amount
  FROM orders_2024_paid o
  JOIN order_items_agg ia
    ON ia.order_id = o.order_id
  LEFT JOIN returns_agg ra
    ON ra.order_id = ia.order_id
   AND ra.product_id = ia.product_id
)
SELECT
  customer_id,
  SUM(line_gross_amount) AS gross_revenue,
  SUM(line_returned_amount) AS returned_amount,
  SUM(line_gross_amount) - SUM(line_returned_amount) AS net_revenue,
  CASE
    WHEN SUM(line_gross_amount) = 0 THEN 0
    ELSE ROUND((SUM(line_returned_amount) * 1.0) / SUM(line_gross_amount), 4)
  END AS returned_rate
FROM line_calc
GROUP BY customer_id
ORDER BY net_revenue DESC;

CREATE VIEW revenue_monthly_by_customer AS
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
    (COALESCE(ia.qty, 0) * COALESCE(ia.unit_price, 0)) AS line_gross_amount,
    (COALESCE(ra.returned_qty, 0) * COALESCE(ia.unit_price, 0)) AS line_returned_amount
  FROM orders_2024_paid o
  JOIN order_items_agg ia
    ON ia.order_id = o.order_id
  LEFT JOIN returns_agg ra
    ON ra.order_id = ia.order_id
   AND ra.product_id = ia.product_id
)
SELECT
  customer_id,
  substr(order_date, 1, 7) AS year_month,
  SUM(line_gross_amount) AS gross_revenue,
  SUM(line_returned_amount) AS returned_amount,
  SUM(line_gross_amount) - SUM(line_returned_amount) AS net_revenue
FROM line_calc
GROUP BY customer_id, substr(order_date, 1, 7)
ORDER BY customer_id, year_month;
