-- =====================================================
-- Setup script for 07-set-operations.md practice problems
-- Works in Postgres, Snowflake, MySQL, SQLite.
-- =====================================================

DROP TABLE IF EXISTS users_jan;
DROP TABLE IF EXISTS users_feb;
DROP TABLE IF EXISTS blocked_users;
DROP TABLE IF EXISTS src_orders;
DROP TABLE IF EXISTS tgt_orders;

CREATE TABLE users_jan (
    user_id INT PRIMARY KEY,
    name    VARCHAR(50)
);

-- users_feb has NO primary key: user 4 was loaded twice on purpose
CREATE TABLE users_feb (
    user_id INT,
    name    VARCHAR(50)
);

-- blocked_users contains a NULL on purpose (bad data)
CREATE TABLE blocked_users (
    user_id INT
);

CREATE TABLE src_orders (
    order_id INT PRIMARY KEY,
    amount   INT
);

CREATE TABLE tgt_orders (
    order_id INT PRIMARY KEY,
    amount   INT
);

INSERT INTO users_jan (user_id, name) VALUES
(1, 'Asha'), (2, 'Ravi'), (3, 'Meera'), (4, 'John'), (5, 'Priya');

INSERT INTO users_feb (user_id, name) VALUES
(3, 'Meera'), (4, 'John'), (4, 'John'), (6, 'Kiran'), (7, 'Neha');

INSERT INTO blocked_users (user_id) VALUES (2), (NULL), (7);

INSERT INTO src_orders (order_id, amount) VALUES
(1, 100), (2, 200), (3, 300), (4, 400), (5, 500);

INSERT INTO tgt_orders (order_id, amount) VALUES
(1, 100), (2, 250), (3, 300), (5, 500), (6, 600);

-- Quick check. Expected row counts: users_jan=5, users_feb=5, blocked_users=3, src_orders=5, tgt_orders=5
SELECT 'users_jan' AS table_name, COUNT(*) AS row_count FROM users_jan
UNION ALL
SELECT 'users_feb' AS table_name, COUNT(*) AS row_count FROM users_feb
UNION ALL
SELECT 'blocked_users' AS table_name, COUNT(*) AS row_count FROM blocked_users
UNION ALL
SELECT 'src_orders' AS table_name, COUNT(*) AS row_count FROM src_orders
UNION ALL
SELECT 'tgt_orders' AS table_name, COUNT(*) AS row_count FROM tgt_orders;
