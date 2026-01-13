-- 01_create_tables.sql
-- SQLite schema for Customer Revenue Cohort Analysis

PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS returns;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
  customer_id   INTEGER PRIMARY KEY,
  signup_date   TEXT NOT NULL  -- ISO date: YYYY-MM-DD
);

CREATE TABLE orders (
  order_id      INTEGER PRIMARY KEY,
  customer_id   INTEGER NOT NULL,
  order_date    TEXT NOT NULL, -- ISO date: YYYY-MM-DD
  status        TEXT NOT NULL CHECK (status IN ('paid','cancelled','pending')),
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- NOTE: Intentionally no PK here to allow duplicates for data quality tests.
CREATE TABLE order_items (
  order_id      INTEGER NOT NULL,
  product_id    INTEGER NOT NULL,
  qty           INTEGER,        -- may be NULL if you injected nulls
  unit_price    REAL,           -- may be NULL if you injected nulls
  FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- NOTE: Intentionally no PK; multiple rows per (order_id, product_id) allowed (partial returns)
CREATE TABLE returns (
  order_id      INTEGER NOT NULL,
  product_id    INTEGER NOT NULL,
  returned_qty  INTEGER NOT NULL,
  FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- Helpful indexes for analytics queries
CREATE INDEX IF NOT EXISTS idx_orders_customer_date
ON orders(customer_id, order_date);

CREATE INDEX IF NOT EXISTS idx_order_items_order_product
ON order_items(order_id, product_id);

CREATE INDEX IF NOT EXISTS idx_returns_order_product
ON returns(order_id, product_id);

SELECT COUNT(*) AS n_customers FROM customers;
SELECT COUNT(*) AS n_orders FROM orders;
SELECT COUNT(*) AS n_items FROM order_items;
SELECT COUNT(*) AS n_returns FROM returns;

SELECT status, COUNT(*) 
FROM orders
GROUP BY status;
