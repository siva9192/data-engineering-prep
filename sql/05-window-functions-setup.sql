-- =====================================================
-- Setup script for 05-window-functions.md practice problems
-- Works in Postgres, Snowflake, MySQL, SQLite.
-- =====================================================

DROP TABLE IF EXISTS emp_salary;
DROP TABLE IF EXISTS daily_sales;

CREATE TABLE emp_salary (
    emp_id    INT PRIMARY KEY,
    name      VARCHAR(50),
    dept      VARCHAR(30),
    salary    INT,
    hire_date DATE
);

CREATE TABLE daily_sales (
    sale_date DATE,
    store     VARCHAR(10),
    revenue   INT
);

INSERT INTO emp_salary (emp_id, name, dept, salary, hire_date) VALUES
(1,  'Asha',   'Engineering', 150000, '2015-01-10'),
(2,  'Ravi',   'Engineering', 120000, '2016-03-01'),
(3,  'Kiran',  'Engineering', 120000, '2019-07-07'),
(4,  'Neha',   'Engineering', 105000, '2020-10-10'),
(5,  'Meera',  'Analytics',   130000, '2016-06-15'),
(6,  'John',   'Analytics',   90000,  '2018-09-01'),
(7,  'Sunita', 'Analytics',   90000,  '2020-01-15'),
(8,  'Arjun',  'Analytics',   60000,  '2022-08-08'),
(9,  'Priya',  'Finance',     125000, '2017-02-20'),
(10, 'Vikram', 'Finance',     70000,  '2021-04-04');

INSERT INTO daily_sales (sale_date, store, revenue) VALUES
('2024-03-01', 'A', 100),
('2024-03-02', 'A', 150),
('2024-03-03', 'A', 120),
('2024-03-04', 'A', 200),
('2024-03-05', 'A', 180),
('2024-03-01', 'B', 80),
('2024-03-02', 'B', 60),
('2024-03-03', 'B', 90),
('2024-03-04', 'B', 110),
('2024-03-05', 'B', 130);

-- Quick check. Expected row counts: emp_salary=10, daily_sales=10
SELECT 'emp_salary' AS table_name, COUNT(*) AS row_count FROM emp_salary
UNION ALL
SELECT 'daily_sales' AS table_name, COUNT(*) AS row_count FROM daily_sales;
