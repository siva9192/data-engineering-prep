-- =====================================================
-- Setup script for 01-basics.md practice problems
-- Works in Postgres, Snowflake, MySQL, SQLite.
-- (SQL Server: replace DATE with DATE and it works as-is;
--  Oracle: use DATE '2019-03-15' literals, already used below.)
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
    salary     INT,
    hire_date  DATE,
    manager_id INT
);

INSERT INTO departments (dept_id, dept_name) VALUES
(10, 'Engineering'),
(20, 'Analytics'),
(30, 'Finance');

INSERT INTO employees (emp_id, name, dept_id, salary, hire_date, manager_id) VALUES
(1, 'Asha',  10, 90000, DATE '2019-03-15', NULL),
(2, 'Ravi',  10, 75000, DATE '2020-07-01', 1),
(3, 'Meera', 20, 82000, DATE '2021-01-10', 1),
(4, 'John',  20, 82000, DATE '2022-05-20', 3),
(5, 'Priya', 30, NULL,  DATE '2023-02-11', 3),
(6, 'Kiran', NULL, 60000, DATE '2023-08-30', 2);

-- Quick check: should return 6 and 3
SELECT COUNT(*) AS employees_loaded FROM employees;
SELECT COUNT(*) AS departments_loaded FROM departments;
