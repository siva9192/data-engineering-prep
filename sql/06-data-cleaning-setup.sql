-- =====================================================
-- Setup script for 06-data-cleaning.md practice problems
-- Works in Postgres, Snowflake, MySQL, SQLite.
-- =====================================================

DROP TABLE IF EXISTS stg_customers;

-- A raw staging table, as it might arrive from a source system.
-- Everything is text, exactly like a real landing/bronze layer.
CREATE TABLE stg_customers (
    row_id      INT PRIMARY KEY,
    full_name   VARCHAR(50),
    email       VARCHAR(80),
    phone       VARCHAR(30),
    signup_date VARCHAR(20),
    city        VARCHAR(30),
    loaded_at   VARCHAR(25)
);

INSERT INTO stg_customers (row_id, full_name, email, phone, signup_date, city, loaded_at) VALUES
(1, '  asha  rao ',  'Asha.Rao@Gmail.com ',  '98765-43210',    '2024-01-05', 'Hyderabad', '2024-01-06 09:00:00'),
(2, 'RAVI KUMAR',    'ravi@company.com',     '9876543211',     '2024-01-10', 'hyderabad', '2024-01-11 09:00:00'),
(3, 'meera nair',    NULL,                   '',               '2024-02-01', 'Chennai ',  '2024-02-02 09:00:00'),
(4, 'John Doe',      'john@gmail.com',       '(987) 654-3212', '',           'Bengaluru', '2024-02-10 09:00:00'),
(5, 'Priya S',       'priya@yahoo.com',      '9876543213',     '2024-13-45', 'NA',        '2024-02-12 09:00:00'),
(6, 'Asha Rao',      'asha.rao@gmail.com',   '9876543210',     '2024-01-05', 'Hyderabad', '2024-03-01 09:00:00'),
(7, 'Kiran',         'kiran@company.com',    '9876543215',     '2024-03-20', NULL,        '2024-03-21 09:00:00'),
(8, 'Ravi Kumar',    'ravi@company.com',     '9876543211',     '2024-01-10', 'Hyderabad', '2024-02-15 09:00:00');

-- Quick check. Expected row counts: stg_customers=8
SELECT 'stg_customers' AS table_name, COUNT(*) AS row_count FROM stg_customers;
