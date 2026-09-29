-- =====================================================
-- Setup script for 09-data-modeling.md practice problems
-- Works in Postgres, Snowflake, MySQL, SQLite.
-- =====================================================

DROP TABLE IF EXISTS fact_sales;
DROP TABLE IF EXISTS dim_customer_scd2;

-- A small star-schema fact table (already modeled)
CREATE TABLE fact_sales (
    sale_id     INT PRIMARY KEY,
    date_key    VARCHAR(8),      -- YYYYMMDD, FK to a date dimension
    customer_id INT,
    product     VARCHAR(30),
    quantity    INT,
    revenue     INT
);

INSERT INTO fact_sales (sale_id, date_key, customer_id, product, quantity, revenue) VALUES
(1, '20240105', 101, 'Laptop', 1, 800),
(2, '20240110', 102, 'Mouse',  5, 100),
(3, '20240212', 101, 'Laptop', 1, 800),
(4, '20240301', 102, 'Phone',  2, 1200),
(5, '20240315', 102, 'Mouse',  3, 60),
(6, '20240402', 101, 'Phone',  1, 600);

-- An SCD Type 2 customer dimension: one customer (101) has 2 versions
CREATE TABLE dim_customer_scd2 (
    surrogate_key INT PRIMARY KEY,
    customer_id   INT,          -- the stable business key
    customer_name VARCHAR(50),
    segment       VARCHAR(20),
    valid_from    DATE,
    valid_to      DATE,         -- '9999-12-31' means still current
    is_current    INT           -- 1 = current row, 0 = historical
);

INSERT INTO dim_customer_scd2 VALUES
(1, 101, 'Anil', 'Standard', '2023-01-01', '2024-02-01', 0),
(2, 101, 'Anil', 'Premium',  '2024-02-01', '9999-12-31', 1),
(3, 102, 'Bina', 'Standard', '2023-06-15', '9999-12-31', 1);

-- Quick check. Expected row counts: fact_sales=6, dim_customer_scd2=3
SELECT 'fact_sales' AS table_name, COUNT(*) AS row_count FROM fact_sales
UNION ALL
SELECT 'dim_customer_scd2' AS table_name, COUNT(*) AS row_count FROM dim_customer_scd2;
