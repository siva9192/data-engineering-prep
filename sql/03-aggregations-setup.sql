-- =====================================================
-- Setup script for 03-aggregations.md practice problems
-- Works in Postgres, Snowflake, MySQL, SQLite.
-- =====================================================

DROP TABLE IF EXISTS sales;

CREATE TABLE sales (
    sale_id    INT PRIMARY KEY,
    sale_date  DATE,
    region     VARCHAR(20),
    product    VARCHAR(30),
    category   VARCHAR(30),
    quantity   INT,
    unit_price INT,
    status     VARCHAR(20)
);

INSERT INTO sales (sale_id, sale_date, region, product, category, quantity, unit_price, status) VALUES
(1,  '2024-01-05', 'North', 'Laptop',   'Electronics', 2,    800, 'completed'),
(2,  '2024-01-12', 'North', 'Mouse',    'Accessories', 10,   20,  'completed'),
(3,  '2024-01-20', 'South', 'Laptop',   'Electronics', 1,    800, 'completed'),
(4,  '2024-02-03', 'South', 'Keyboard', 'Accessories', 5,    45,  'completed'),
(5,  '2024-02-14', 'East',  'Phone',    'Electronics', 3,    600, 'completed'),
(6,  '2024-02-20', 'East',  'Mouse',    'Accessories', 8,    20,  'returned'),
(7,  '2024-02-25', 'North', 'Phone',    'Electronics', 1,    600, 'completed'),
(8,  '2024-03-02', 'West',  'Laptop',   'Electronics', 2,    800, 'completed'),
(9,  '2024-03-09', 'West',  'Keyboard', 'Accessories', NULL, 45,  'cancelled'),
(10, '2024-03-15', 'South', 'Phone',    'Electronics', 2,    600, 'completed'),
(11, '2024-03-22', 'North', 'Keyboard', 'Accessories', 4,    45,  'completed'),
(12, '2024-03-28', 'East',  'Laptop',   'Electronics', 1,    800, 'returned'),
(13, '2024-04-04', 'West',  'Mouse',    'Accessories', 6,    20,  'completed'),
(14, '2024-04-11', 'South', 'Mouse',    'Accessories', 12,   20,  'completed'),
(15, '2024-04-18', 'North', 'Laptop',   'Electronics', 3,    800, 'completed'),
(16, '2024-04-25', 'East',  'Keyboard', 'Accessories', 2,    45,  'completed');

-- Quick check. Expected row counts: sales=16
SELECT 'sales' AS table_name, COUNT(*) AS row_count FROM sales;
