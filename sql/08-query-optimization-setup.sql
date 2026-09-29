-- =====================================================
-- Setup script for 08-query-optimization.md practice problems
-- Works in Postgres, Snowflake, MySQL, SQLite.
-- =====================================================

DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    name        VARCHAR(50),
    city        VARCHAR(30)
);

CREATE TABLE orders (
    order_id    INT PRIMARY KEY,
    customer_id INT,
    order_date  DATE,
    status      VARCHAR(20),
    amount      INT
);

INSERT INTO customers (customer_id, name, city) VALUES
(1, 'Anil',   'Hyderabad'),
(2, 'Bina',   'Chennai'),
(3, 'Chetan', 'Hyderabad'),
(4, 'Divya',  'Mumbai'),
(5, 'Esha',   'Chennai');

INSERT INTO orders (order_id, customer_id, order_date, status, amount) VALUES
(1,  1, '2023-11-15', 'completed', 500),
(2,  1, '2024-01-05', 'completed', 300),
(3,  2, '2024-01-20', 'completed', 700),
(4,  2, '2024-02-11', 'cancelled', 150),
(5,  3, '2024-02-18', 'completed', 400),
(6,  1, '2024-03-02', 'completed', 250),
(7,  4, '2024-03-09', 'completed', 900),
(8,  5, '2024-03-15', 'pending',   120),
(9,  3, '2024-03-28', 'completed', 350),
(10, 2, '2024-04-04', 'completed', 600),
(11, 1, '2024-04-19', 'returned',  200),
(12, 4, '2023-12-24', 'completed', 800);

-- Indexes (on real tables these are what make lookups fast)
CREATE INDEX idx_orders_customer ON orders (customer_id);
CREATE INDEX idx_orders_date     ON orders (order_date);

-- Quick check. Expected row counts: customers=5, orders=12
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'orders' AS table_name, COUNT(*) AS row_count FROM orders;
