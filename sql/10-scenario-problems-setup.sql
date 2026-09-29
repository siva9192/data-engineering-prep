-- =====================================================
-- Setup script for 10-scenario-problems.md practice problems
-- Works in Postgres, Snowflake, MySQL, SQLite.
-- =====================================================

DROP TABLE IF EXISTS logins;
DROP TABLE IF EXISTS server_status;
DROP TABLE IF EXISTS page_views;
DROP TABLE IF EXISTS emp_salary2;

-- Retention / login activity
CREATE TABLE logins (
    user_id    INT,
    login_date DATE
);
INSERT INTO logins (user_id, login_date) VALUES
(1, '2024-01-01'), (1, '2024-01-02'), (1, '2024-02-05'),
(2, '2024-01-01'), (2, '2024-02-01'),
(3, '2024-01-15'),
(1, '2024-03-01'), (2, '2024-03-01'), (3, '2024-03-02');

-- Gaps and islands: server up/down log
CREATE TABLE server_status (
    day_num INT,
    status  VARCHAR(10)
);
INSERT INTO server_status (day_num, status) VALUES
(1, 'up'), (2, 'up'), (3, 'up'), (4, 'down'), (5, 'down'),
(6, 'up'), (7, 'up'), (8, 'down'), (9, 'up'), (10, 'up'), (11, 'up');

-- Sessionization: page view events with gaps
CREATE TABLE page_views (
    user_id    INT,
    view_time  VARCHAR(19)     -- 'YYYY-MM-DD HH:MM:SS' text, sortable
);
INSERT INTO page_views (user_id, view_time) VALUES
(1, '2024-01-01 10:00:00'),
(1, '2024-01-01 10:05:00'),
(1, '2024-01-01 10:07:00'),
(1, '2024-01-01 10:40:00'),
(1, '2024-01-01 10:41:00'),
(2, '2024-01-01 09:00:00'),
(2, '2024-01-01 09:20:00'),
(2, '2024-01-01 11:00:00');

-- Reused from Topic 1/5 for the Nth-salary problem
CREATE TABLE emp_salary2 (
    emp_id INT PRIMARY KEY,
    name   VARCHAR(50),
    dept   VARCHAR(30),
    salary INT
);
INSERT INTO emp_salary2 (emp_id, name, dept, salary) VALUES
(1, 'Asha',  'Engineering', 150000),
(2, 'Ravi',  'Engineering', 120000),
(3, 'Kiran', 'Engineering', 120000),
(4, 'Neha',  'Engineering', 105000),
(5, 'Meera', 'Analytics',   130000),
(6, 'John',  'Analytics',   90000);

-- Quick check. Expected row counts: logins=9, server_status=11, page_views=8, emp_salary2=6
SELECT 'logins' AS table_name, COUNT(*) AS row_count FROM logins
UNION ALL
SELECT 'server_status' AS table_name, COUNT(*) AS row_count FROM server_status
UNION ALL
SELECT 'page_views' AS table_name, COUNT(*) AS row_count FROM page_views
UNION ALL
SELECT 'emp_salary2' AS table_name, COUNT(*) AS row_count FROM emp_salary2;
