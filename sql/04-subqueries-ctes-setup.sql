-- =====================================================
-- Setup script for 04-subqueries-ctes.md practice problems
-- Works in Postgres, Snowflake, MySQL, SQLite.
-- =====================================================

DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS departments;

CREATE TABLE departments (
    dept_id   INT PRIMARY KEY,
    dept_name VARCHAR(50)
);

CREATE TABLE employees (
    emp_id     INT PRIMARY KEY,
    name       VARCHAR(50),
    dept_id    INT,
    manager_id INT,
    salary     INT,
    hire_date  DATE
);

INSERT INTO departments (dept_id, dept_name) VALUES
(10, 'Engineering'),
(20, 'Analytics'),
(30, 'Finance'),
(40, 'HR');

INSERT INTO employees (emp_id, name, dept_id, manager_id, salary, hire_date) VALUES
(1,  'Asha',   10, NULL, 150000, '2015-01-10'),
(2,  'Ravi',   10, 1,    120000, '2016-03-01'),
(3,  'Meera',  20, 1,    130000, '2016-06-15'),
(4,  'John',   20, 3,    90000,  '2018-09-01'),
(5,  'Priya',  30, 1,    125000, '2017-02-20'),
(6,  'Kiran',  10, 2,    95000,  '2019-07-07'),
(7,  'Sunita', 20, 3,    85000,  '2020-01-15'),
(8,  'Vikram', 30, 5,    70000,  '2021-04-04'),
(9,  'Neha',   10, 2,    105000, '2020-10-10'),
(10, 'Arjun',  20, 4,    60000,  '2022-08-08');

-- Quick check. Expected row counts: departments=4, employees=10
SELECT 'departments' AS table_name, COUNT(*) AS row_count FROM departments
UNION ALL
SELECT 'employees' AS table_name, COUNT(*) AS row_count FROM employees;
