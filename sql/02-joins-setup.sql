-- =====================================================
-- Setup script for 02-joins.md practice problems
-- Works in Postgres, Snowflake, MySQL, SQLite.
-- =====================================================

DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS departments;

-- ---------- HR tables ----------
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
(30, 'Finance'),
(40, 'HR');            -- HR has no employees on purpose

INSERT INTO employees (emp_id, name, dept_id, salary, hire_date, manager_id) VALUES
(1, 'Asha',  10, 90000, DATE '2019-03-15', NULL),
(2, 'Ravi',  10, 75000, DATE '2020-07-01', 1),
(3, 'Meera', 20, 82000, DATE '2021-01-10', 1),
(4, 'John',  20, 82000, DATE '2022-05-20', 3),
(5, 'Priya', 30, NULL,  DATE '2023-02-11', 3),
(6, 'Kiran', NULL, 60000, DATE '2023-08-30', 2);   -- Kiran has no department

-- ---------- Sales tables ----------
CREATE TABLE customers (
    customer_id   INT PRIMARY KEY,
    customer_name VARCHAR(50)
);

CREATE TABLE orders (
    order_id    INT PRIMARY KEY,
    customer_id INT,
    order_date  DATE,
    amount      INT
);

CREATE TABLE payments (
    payment_id  INT PRIMARY KEY,
    order_id    INT,
    paid_amount INT
);

INSERT INTO customers (customer_id, customer_name) VALUES
(1, 'Anil'),
(2, 'Bina'),
(3, 'Chetan'),         -- no orders
(4, 'Divya');          -- no orders

INSERT INTO orders (order_id, customer_id, order_date, amount) VALUES
(101, 1, DATE '2024-01-05', 500),
(102, 1, DATE '2024-01-20', 300),
(103, 2, DATE '2024-02-02', 700),
(104, 5, DATE '2024-02-10', 200);   -- customer 5 does not exist (orphan order)

INSERT INTO payments (payment_id, order_id, paid_amount) VALUES
(1, 101, 300),
(2, 101, 200),         -- order 101 paid in 2 installments
(3, 102, 300),
(4, 103, 400),
(5, 103, 200);         -- order 103 paid in 2 installments; order 104 has no payment

-- Quick check: should return 4, 6, 4, 4, 5
SELECT (SELECT COUNT(*) FROM departments) AS departments,
       (SELECT COUNT(*) FROM employees)   AS employees,
       (SELECT COUNT(*) FROM customers)   AS customers,
       (SELECT COUNT(*) FROM orders)      AS orders,
       (SELECT COUNT(*) FROM payments)    AS payments;
