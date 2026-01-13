-- 02_data_quality_checks.sql
-- Output: unified "issues" table for export (one row per detected issue)

DROP TABLE IF EXISTS dq_issues;

CREATE TABLE dq_issues (
  issue_type   TEXT NOT NULL,
  severity     TEXT NOT NULL,     -- 'HIGH' | 'MEDIUM' | 'LOW'
  table_name   TEXT NOT NULL,
  order_id     INTEGER,
  customer_id  INTEGER,
  product_id   INTEGER,
  issue_detail TEXT NOT NULL
);

-- ------------------------------------------------------------
-- 1) Duplicate rows in order_items by (order_id, product_id)
--    (classic overcount risk)
-- ------------------------------------------------------------
INSERT INTO dq_issues (issue_type, severity, table_name, order_id, product_id, issue_detail)
SELECT
  'DUPLICATE_ORDER_ITEM_KEY' AS issue_type,
  'HIGH' AS severity,
  'order_items' AS table_name,
  oi.order_id,
  oi.product_id,
  'Duplicate (order_id, product_id) rows in order_items. cnt=' || COUNT(*) AS issue_detail
FROM order_items oi
GROUP BY oi.order_id, oi.product_id
HAVING COUNT(*) > 1;

-- Optional: exact duplicates (same order_id, product_id, qty, unit_price)
INSERT INTO dq_issues (issue_type, severity, table_name, order_id, product_id, issue_detail)
SELECT
  'EXACT_DUPLICATE_ORDER_ITEM_ROW' AS issue_type,
  'MEDIUM' AS severity,
  'order_items' AS table_name,
  oi.order_id,
  oi.product_id,
  'Exact duplicate rows. cnt=' || COUNT(*) AS issue_detail
FROM order_items oi
GROUP BY oi.order_id, oi.product_id, oi.qty, oi.unit_price
HAVING COUNT(*) > 1;

-- ------------------------------------------------------------
-- 2) Inconsistent unit_price for same (order_id, product_id)
-- ------------------------------------------------------------
INSERT INTO dq_issues (issue_type, severity, table_name, order_id, product_id, issue_detail)
SELECT
  'INCONSISTENT_UNIT_PRICE' AS issue_type,
  'HIGH' AS severity,
  'order_items' AS table_name,
  oi.order_id,
  oi.product_id,
  'Different unit_price values for same key. distinct_prices=' || COUNT(DISTINCT oi.unit_price) AS issue_detail
FROM order_items oi
WHERE oi.unit_price IS NOT NULL
GROUP BY oi.order_id, oi.product_id
HAVING COUNT(DISTINCT oi.unit_price) > 1;

-- ------------------------------------------------------------
-- 3) NULLs in critical fields (only if you allowed null injection)
-- ------------------------------------------------------------
INSERT INTO dq_issues (issue_type, severity, table_name, order_id, product_id, issue_detail)
SELECT
  'NULL_QTY' AS issue_type,
  'HIGH' AS severity,
  'order_items' AS table_name,
  oi.order_id,
  oi.product_id,
  'qty is NULL' AS issue_detail
FROM order_items oi
WHERE oi.qty IS NULL;

INSERT INTO dq_issues (issue_type, severity, table_name, order_id, product_id, issue_detail)
SELECT
  'NULL_UNIT_PRICE' AS issue_type,
  'HIGH' AS severity,
  'order_items' AS table_name,
  oi.order_id,
  oi.product_id,
  'unit_price is NULL' AS issue_detail
FROM order_items oi
WHERE oi.unit_price IS NULL;

-- ------------------------------------------------------------
-- 4) Non-positive values (qty <= 0, unit_price <= 0)
-- ------------------------------------------------------------
INSERT INTO dq_issues (issue_type, severity, table_name, order_id, product_id, issue_detail)
SELECT
  'NON_POSITIVE_QTY' AS issue_type,
  'MEDIUM' AS severity,
  'order_items' AS table_name,
  oi.order_id,
  oi.product_id,
  'qty <= 0. qty=' || COALESCE(CAST(oi.qty AS TEXT), 'NULL') AS issue_detail
FROM order_items oi
WHERE oi.qty IS NOT NULL AND oi.qty <= 0;

INSERT INTO dq_issues (issue_type, severity, table_name, order_id, product_id, issue_detail)
SELECT
  'NON_POSITIVE_UNIT_PRICE' AS issue_type,
  'MEDIUM' AS severity,
  'order_items' AS table_name,
  oi.order_id,
  oi.product_id,
  'unit_price <= 0. unit_price=' || COALESCE(CAST(oi.unit_price AS TEXT), 'NULL') AS issue_detail
FROM order_items oi
WHERE oi.unit_price IS NOT NULL AND oi.unit_price <= 0;

-- ------------------------------------------------------------
-- 5) Orphan foreign keys (should be rare; indicates load issues)
-- ------------------------------------------------------------
INSERT INTO dq_issues (issue_type, severity, table_name, order_id, issue_detail)
SELECT
  'ORPHAN_ORDER_ITEMS_ORDER' AS issue_type,
  'HIGH' AS severity,
  'order_items' AS table_name,
  oi.order_id,
  'order_items.order_id not found in orders' AS issue_detail
FROM order_items oi
LEFT JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_id IS NULL;

INSERT INTO dq_issues (issue_type, severity, table_name, order_id, issue_detail)
SELECT
  'ORPHAN_RETURNS_ORDER' AS issue_type,
  'HIGH' AS severity,
  'returns' AS table_name,
  r.order_id,
  'returns.order_id not found in orders' AS issue_detail
FROM returns r
LEFT JOIN orders o ON o.order_id = r.order_id
WHERE o.order_id IS NULL;

-- ------------------------------------------------------------
-- 6) Returns > Sold qty (critical business rule)
--    Important: handle duplicates in order_items by aggregating sold qty first.
-- ------------------------------------------------------------
WITH sold AS (
  SELECT
    order_id,
    product_id,
    SUM(COALESCE(qty, 0)) AS sold_qty
  FROM order_items
  GROUP BY order_id, product_id
),
ret AS (
  SELECT
    order_id,
    product_id,
    SUM(returned_qty) AS returned_qty
  FROM returns
  GROUP BY order_id, product_id
)
INSERT INTO dq_issues (issue_type, severity, table_name, order_id, product_id, issue_detail)
SELECT
  'RETURN_EXCEEDS_SOLD_QTY' AS issue_type,
  'HIGH' AS severity,
  'returns' AS table_name,
  ret.order_id,
  ret.product_id,
  'returned_qty=' || ret.returned_qty || ' > sold_qty=' || COALESCE(sold.sold_qty, 0) AS issue_detail
FROM ret
LEFT JOIN sold
  ON sold.order_id = ret.order_id
 AND sold.product_id = ret.product_id
WHERE ret.returned_qty > COALESCE(sold.sold_qty, 0);

-- ------------------------------------------------------------
-- 7) Paid orders with zero items (could be legit but suspicious)
-- ------------------------------------------------------------
INSERT INTO dq_issues (issue_type, severity, table_name, order_id, customer_id, issue_detail)
SELECT
  'PAID_ORDER_WITHOUT_ITEMS' AS issue_type,
  'MEDIUM' AS severity,
  'orders' AS table_name,
  o.order_id,
  o.customer_id,
  'Paid order has no order_items rows' AS issue_detail
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status = 'paid'
GROUP BY o.order_id, o.customer_id
HAVING COUNT(oi.order_id) = 0;

-- ------------------------------------------------------------
-- 8) Customers without orders (LOW severity; depends on use case)
-- ------------------------------------------------------------
INSERT INTO dq_issues (issue_type, severity, table_name, customer_id, issue_detail)
SELECT
  'CUSTOMER_WITHOUT_ORDERS' AS issue_type,
  'LOW' AS severity,
  'customers' AS table_name,
  c.customer_id,
  'Customer has no orders' AS issue_detail
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.customer_id IS NULL;

-- ------------------------------------------------------------
-- Quick summary view (optional)
-- ------------------------------------------------------------
DROP VIEW IF EXISTS dq_issues_summary;
CREATE VIEW dq_issues_summary AS
SELECT
  issue_type,
  severity,
  table_name,
  COUNT(*) AS cnt
FROM dq_issues
GROUP BY issue_type, severity, table_name
ORDER BY
  CASE severity WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,
  cnt DESC;
