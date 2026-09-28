# 02 - Joins

> Level: Data Engineer, 5 years experience. Joins are the most tested SQL topic. Beyond "what is a LEFT JOIN", interviewers probe **row multiplication (fan-out)**, **NULL keys**, **ON vs WHERE**, and **how joins behave at scale**.

## Table of Contents
1. [Concept Summary](#1-concept-summary)
2. [What Interviewers Look For](#2-what-interviewers-look-for)
3. [Sample Data Used in This Doc](#3-sample-data)
4. [Examples with Explanations](#4-examples-with-explanations)
5. [Interview Questions and Answers](#5-interview-questions-and-answers)
6. [Practice Problems](#6-practice-problems) (with setup script, expected output and self-check)
7. [Common Mistakes](#7-common-mistakes)
8. [Quick Revision Notes](#8-quick-revision-notes)

---

## 1. Concept Summary

A **join** combines rows from two tables based on a condition, usually equality between a key in each table.

### Join types

| Join | Returns | Unmatched rows |
|------|---------|----------------|
| `INNER JOIN` | Only rows with a match in **both** tables | Dropped from both sides |
| `LEFT [OUTER] JOIN` | All rows from the left table + matches from the right | Right columns are NULL |
| `RIGHT [OUTER] JOIN` | All rows from the right table + matches from the left | Left columns are NULL |
| `FULL [OUTER] JOIN` | All rows from both tables | NULLs on whichever side is missing |
| `CROSS JOIN` | Every left row paired with every right row (Cartesian product) | No condition |
| Self join | A table joined to itself (use aliases) | Any join type |

Two special *patterns* (not keywords):
- **Semi join**: return left rows that **have** a match, without pulling right columns or duplicating rows. Written with `EXISTS` or `IN`.
- **Anti join**: return left rows that have **no** match. Written with `NOT EXISTS` or `LEFT JOIN ... WHERE right.key IS NULL`.

### Cardinality (how many rows to expect)

| Relationship | Example | Row count after join |
|--------------|---------|----------------------|
| One-to-one | employee - passport | Stays the same |
| One-to-many | customer - orders | Result has as many rows as the "many" side |
| Many-to-many | students - courses | Rows can **multiply**. Danger zone |

If a key appears **m** times on the left and **n** times on the right, the join produces **m x n** rows for that key. This is **fan-out**, and it is the #1 cause of wrong numbers in reports.

### Rules to remember

1. `NULL = NULL` is UNKNOWN, so rows with NULL join keys **never match** in an equality join.
2. For `LEFT JOIN`, a condition on the **right** table in `WHERE` turns it into an inner join. Put it in `ON` to keep unmatched left rows.
3. Aggregating **after** a fan-out double counts. Aggregate first, then join.
4. Always check the **grain** (what one row represents) of both tables before joining.

---

## 2. What Interviewers Look For

- Can you pick the right join type from a business description ("customers who never ordered")?
- Do you explain **ON vs WHERE** for outer joins correctly?
- Can you predict the **row count** of a join with duplicates and NULLs?
- Do you spot and fix **fan-out** (duplicate inflation)?
- Do you know 3 ways to do an anti join and their trade-offs (`NOT IN` NULL trap)?
- At 5 years: do you know **how joins execute** (nested loop, hash, merge; broadcast and shuffle joins in distributed engines) and how to deal with skew?

---

## 3. Sample Data

Run [`02-joins-setup.sql`](./02-joins-setup.sql) to create these tables.

**departments**

| dept_id | dept_name   |
|---------|-------------|
| 10      | Engineering |
| 20      | Analytics   |
| 30      | Finance     |
| 40      | HR          |

**employees**

| emp_id | name  | dept_id | salary | hire_date  | manager_id |
|--------|-------|---------|--------|------------|------------|
| 1      | Asha  | 10      | 90000  | 2019-03-15 | NULL       |
| 2      | Ravi  | 10      | 75000  | 2020-07-01 | 1          |
| 3      | Meera | 20      | 82000  | 2021-01-10 | 1          |
| 4      | John  | 20      | 82000  | 2022-05-20 | 3          |
| 5      | Priya | 30      | NULL   | 2023-02-11 | 3          |
| 6      | Kiran | NULL    | 60000  | 2023-08-30 | 2          |

Note: HR (40) has **no employees**. Kiran has **no department**.

**customers**

| customer_id | customer_name |
|-------------|---------------|
| 1           | Anil          |
| 2           | Bina          |
| 3           | Chetan        |
| 4           | Divya         |

**orders**

| order_id | customer_id | order_date | amount |
|----------|-------------|------------|--------|
| 101      | 1           | 2024-01-05 | 500    |
| 102      | 1           | 2024-01-20 | 300    |
| 103      | 2           | 2024-02-02 | 700    |
| 104      | 5           | 2024-02-10 | 200    |

Note: Chetan and Divya have **no orders**. Order 104 belongs to customer 5, who **does not exist** (orphan).

**payments**

| payment_id | order_id | paid_amount |
|------------|----------|-------------|
| 1          | 101      | 300         |
| 2          | 101      | 200         |
| 3          | 102      | 300         |
| 4          | 103      | 400         |
| 5          | 103      | 200         |

Note: orders 101 and 103 were paid in **2 installments**. Order 104 has **no payment**.

---

## 4. Examples with Explanations

### 4.1 INNER JOIN
```sql
SELECT e.name, d.dept_name
FROM employees e
INNER JOIN departments d ON e.dept_id = d.dept_id;
```
Returns 5 rows. **Kiran** (NULL dept) and **HR** (no employees) are dropped because neither has a match.

### 4.2 LEFT JOIN
```sql
SELECT e.name, d.dept_name
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id;
```
Returns all 6 employees. Kiran's `dept_name` is NULL.

### 4.3 RIGHT JOIN (rarely used, swap tables and use LEFT instead)
```sql
SELECT e.name, d.dept_name
FROM employees e
RIGHT JOIN departments d ON e.dept_id = d.dept_id;
```
Returns 6 rows: the 5 matches + HR with NULL `name`. Kiran is dropped. Most teams standardize on `LEFT JOIN` for readability.

### 4.4 FULL OUTER JOIN
```sql
SELECT e.name, d.dept_name
FROM employees e
FULL OUTER JOIN departments d ON e.dept_id = d.dept_id;
```
Returns 7 rows: 5 matches + Kiran (NULL dept) + HR (NULL name). MySQL does not support `FULL OUTER JOIN`; emulate with `LEFT JOIN UNION RIGHT JOIN`.

### 4.5 CROSS JOIN
```sql
SELECT d.dept_name, c.customer_name
FROM departments d
CROSS JOIN customers c;         -- 4 x 4 = 16 rows
```
Use cases: generating combinations (dates x products calendar/scaffold tables), never by accident.

### 4.6 Self join (employee and manager)
```sql
SELECT e.name AS employee, m.name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.emp_id;
```
The same table appears twice under different aliases. `LEFT JOIN` keeps Asha, who has no manager.

### 4.7 Anti join: three ways
```sql
-- Departments with no employees. Expected: HR

-- (a) LEFT JOIN + IS NULL
SELECT d.dept_name
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id
WHERE e.emp_id IS NULL;

-- (b) NOT EXISTS   (NULL-safe, usually the best choice)
SELECT d.dept_name
FROM departments d
WHERE NOT EXISTS (SELECT 1 FROM employees e WHERE e.dept_id = d.dept_id);

-- (c) NOT IN   (DANGEROUS if the subquery can return NULL)
SELECT d.dept_name
FROM departments d
WHERE d.dept_id NOT IN (SELECT dept_id FROM employees);   -- Kiran's NULL makes this return 0 rows!
```
Option (c) returns **no rows** because `employees.dept_id` contains a NULL (Kiran). Fix by adding `WHERE dept_id IS NOT NULL` in the subquery.

### 4.8 Semi join
```sql
-- Customers who have placed at least one order. Expected: Anil, Bina
SELECT c.customer_name
FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id);
```
Unlike `INNER JOIN`, this does **not** duplicate Anil when he has 2 orders.

### 4.9 ON vs WHERE in a LEFT JOIN (the classic trap)
```sql
-- Filter in WHERE: behaves like an INNER JOIN, drops unmatched rows
SELECT e.name, d.dept_name
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
WHERE d.dept_name = 'Finance';
-- Result: only Priya (Kiran is gone, since NULL = 'Finance' is UNKNOWN)

-- Filter in ON: the filter applies to the right table before matching
SELECT e.name, d.dept_name
FROM employees e
LEFT JOIN departments d
       ON e.dept_id = d.dept_id AND d.dept_name = 'Finance';
-- Result: all 6 employees, but dept_name is filled only for Priya
```
Rule: to keep all left rows and filter the right table, put the condition in `ON`. To filter the final result, use `WHERE`.

### 4.10 Fan-out (row multiplication)
```sql
-- WRONG: total order amount, joined to payments
SELECT SUM(o.amount) AS total_order_amount
FROM orders o
JOIN payments p ON p.order_id = o.order_id;
-- Returns 2700 (orders 101 and 103 counted twice). Real total is 1700.

-- RIGHT: aggregate payments to one row per order FIRST, then join
SELECT o.order_id, o.amount, COALESCE(p.total_paid, 0) AS total_paid
FROM orders o
LEFT JOIN (
    SELECT order_id, SUM(paid_amount) AS total_paid
    FROM payments
    GROUP BY order_id
) p ON p.order_id = o.order_id;
```
Fix pattern: make the "many" side one row per join key before joining.

### 4.11 Join on multiple columns and non-equi joins
```sql
-- Composite key
SELECT *
FROM sales s
JOIN targets t ON s.region = t.region AND s.year = t.year;

-- Non-equi (range) join: orders within a promotion window
SELECT o.order_id, pr.promo_name
FROM orders o
JOIN promotions pr
  ON o.order_date BETWEEN pr.start_date AND pr.end_date;
```
Non-equi joins are common for SCD Type 2 lookups, but they are much more expensive than equality joins.

### 4.12 Row count cheat sheet (duplicates and NULLs)
Left key values: `1, 1, 2, NULL` (4 rows). Right key values: `1, 1, 1, NULL, 3` (5 rows).

| Join | Rows | Why |
|------|------|-----|
| INNER | 6 | Key 1: 2 x 3 = 6. NULL never matches. Key 2 has no match |
| LEFT | 8 | 6 + unmatched left rows (2 and NULL) |
| RIGHT | 8 | 6 + unmatched right rows (NULL and 3) |
| FULL | 10 | 6 + 2 unmatched left + 2 unmatched right |
| CROSS | 20 | 4 x 5 |

---

## 5. Interview Questions and Answers

### Basic

**Q1. What is the difference between INNER, LEFT, RIGHT and FULL joins?**
`INNER` keeps only matching rows. `LEFT` keeps all left rows and NULL-fills the right when unmatched. `RIGHT` is the mirror image. `FULL` keeps all rows from both sides. Give a business example for each: "employees with their department" (inner), "all customers even if they never ordered" (left).

**Q2. What is a CROSS JOIN and when would you use it?**
It returns the Cartesian product: every left row with every right row (m x n rows). Legitimate uses: building a date x product scaffold so that missing combinations show as zero, generating test data, or pairing all options. An accidental cross join (missing ON clause) is a classic performance bug.

**Q3. What is a self join? Give an example.**
A table joined with itself using aliases, for example employee and manager, or comparing a row to other rows in the same table (find employees earning more than their manager).

**Q4. What is the difference between ON and WHERE?**
`ON` defines how rows are matched **during** the join. `WHERE` filters rows **after** the join. For `INNER JOIN` the two are equivalent, but for outer joins they are not (see 4.9).

**Q5. What is the difference between JOIN and UNION?**
`JOIN` combines tables **horizontally** (adds columns) based on a key. `UNION` stacks results **vertically** (adds rows) and needs the same number and compatible types of columns.

### Intermediate

**Q6. Do NULL keys match in a join?**
No. `NULL = NULL` is UNKNOWN, so those rows are unmatched. In an `INNER JOIN` they are dropped, in a `LEFT JOIN` they are kept with NULLs on the right. To match NULLs deliberately, use a NULL-safe comparison: `IS NOT DISTINCT FROM` (Postgres, Snowflake, SQL Server 2022+), `<=>` (MySQL), or `COALESCE(a, -1) = COALESCE(b, -1)` (which can hurt index usage).

**Q7. Table A has 4 rows and B has 5. What are the min and max rows for an INNER JOIN? A LEFT JOIN?**
- INNER: min 0, max 20 (4 x 5, if all keys are the same).
- LEFT: min 4 (every left row appears at least once), max 20.
Then discuss cardinality: if B's key is unique, LEFT JOIN returns exactly 4 rows.

**Q8. You join two tables and the row count or SUM goes up. What happened and how do you fix it?**
Fan-out: the join key is not unique on one side, so rows multiply. Diagnose by checking `COUNT(*)` vs `COUNT(DISTINCT key)` on each table. Fix by deduplicating or aggregating the many-side to one row per key before the join (see 4.10), or by using `EXISTS` if you only need existence. Avoid "fixing" it with `DISTINCT` or `COUNT(DISTINCT)` on the result without understanding why, because that can hide errors (two different orders with the same amount would be collapsed).

**Q9. Three ways to find rows in A that have no match in B. Which do you prefer?**
`LEFT JOIN ... WHERE b.key IS NULL`, `NOT EXISTS`, and `NOT IN`. Prefer `NOT EXISTS` (NULL-safe, clear intent, optimizers turn it into an efficient anti join). Avoid `NOT IN` when the subquery column is nullable, because a single NULL makes the whole predicate return no rows.

**Q10. INNER JOIN vs EXISTS vs IN: when to use each?**
Use `INNER JOIN` when you need columns from both tables. Use `EXISTS` / `IN` when you only need to test existence, because they never multiply left rows. `EXISTS` short-circuits on the first match. Modern optimizers often produce the same plan for `IN` and `EXISTS`, but `IN` has the NULL trap in its negated form.

**Q11. Why does my LEFT JOIN behave like an INNER JOIN?**
A `WHERE` condition on a right-table column (for example `WHERE d.dept_name = 'Finance'`) is false for the NULL-filled rows, so they are removed. Move the condition into the `ON` clause, or add `OR d.dept_id IS NULL` if that is the intent.

**Q12. How do you join a many-to-many relationship correctly?**
Through a bridge (junction) table, for example `students - enrollments - courses`. Be aware of fan-out: aggregating student-level metrics after joining to courses will double count. Aggregate at the correct grain in a subquery/CTE first.

**Q13. How do you get "customers with their latest order" without duplicates?**
Rank orders per customer using a window function (`ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC)`), keep `rn = 1`, then join. Or join to a subquery of `MAX(order_date)` and handle ties. (Window functions are covered in Topic 5.)

### Advanced

**Q14. How does a database physically execute a join?**
Three main algorithms:
- **Nested loop join**: for each outer row, look up matching inner rows. Fast when the outer side is small and the inner side has an index.
- **Hash join**: build a hash table on the smaller input, probe with the larger. Good for large, unsorted equality joins. Needs memory.
- **Sort-merge join**: sort both sides on the key, then merge. Good when data is already sorted or for range-friendly joins.
The optimizer picks based on statistics (row counts, indexes, memory). You can inspect the choice with `EXPLAIN`.

**Q15. How do joins work in a distributed engine like Spark, Snowflake or BigQuery? What is data skew?**
Rows with the same key must end up on the same node. Options: **broadcast join** (copy the small table to every node, no shuffle of the big table) or **shuffle join** (repartition both sides by key, expensive network cost). **Skew** happens when a few keys hold most of the rows (for example `customer_id = NULL` or a "default" value), so one worker does most of the work. Mitigations: filter out or handle hot keys separately, salting the key, broadcasting the small side, and enabling adaptive skew handling (Spark AQE). More in the Spark topic.

**Q16. Why can a join on mismatched data types be slow or wrong?**
Implicit casting (for example a `VARCHAR` key joined to an `INT` key) can prevent index use, force a full scan, and cause silent mismatches (leading zeros, whitespace, case). Always join on the same type and cleaned values (`TRIM`, `UPPER`), and fix types upstream.

**Q17. How do you join a fact table to an SCD Type 2 dimension?**
Match on the business key **and** the date range:
```sql
SELECT f.order_id, d.customer_segment
FROM fact_orders f
JOIN dim_customer d
  ON f.customer_id = d.customer_id
 AND f.order_date >= d.valid_from
 AND f.order_date <  d.valid_to;
```
Make sure ranges do not overlap, or you get fan-out. (Data modeling is covered in Topic 9.)

**Q18. How do you validate that a join did not lose or duplicate rows?**
- Compare `COUNT(*)` before and after (for a `LEFT JOIN` onto a unique-key table it must equal the left count).
- Check key uniqueness: `SELECT key, COUNT(*) ... GROUP BY key HAVING COUNT(*) > 1`.
- Reconcile totals (`SUM(amount)`) before and after.
- Count unmatched keys with an anti join.
Bake these checks into pipeline data quality tests.

**Q19. Why is `NATURAL JOIN` or `USING` risky?**
`NATURAL JOIN` joins on all columns with matching names, so adding a column to a table later silently changes the join. Prefer explicit `ON` conditions. `USING(col)` is acceptable and merges the key column, but its behavior with outer joins and `SELECT *` differs by engine.

---

## 6. Practice Problems

### How to practice (write, run, test, then look at the solution)

1. **Set up the data.** Run [`02-joins-setup.sql`](./02-joins-setup.sql) in any database (Postgres, Snowflake, MySQL, SQLite, or an online tool such as DB Fiddle).
2. **Write your own query** for the problem.
3. **Compare with the Expected Output** under each problem.
4. **Run the self-check query** (template below). **0 rows returned = correct.**
5. Only then open the **Solution**.

### Self-check template

```sql
WITH my_answer AS (
    -- paste YOUR query here
    SELECT d.dept_name
    FROM departments d
    LEFT JOIN employees e ON e.dept_id = d.dept_id
    WHERE e.emp_id IS NULL
),
expected (dept_name) AS (
    VALUES ('HR')
)
SELECT 'MISSING' AS issue, m.* FROM (SELECT * FROM expected  EXCEPT SELECT * FROM my_answer) m
UNION ALL
SELECT 'EXTRA'   AS issue, e.* FROM (SELECT * FROM my_answer EXCEPT SELECT * FROM expected)  e;
```

Notes:
- Column names and order in `my_answer` must match `expected`.
- `EXCEPT` ignores row order, so for problems with `ORDER BY`, compare the order by eye.
- Dialects: BigQuery needs `EXCEPT DISTINCT`, Oracle uses `MINUS`. For SQL Server / older MySQL / SQLite use `SELECT 'HR' UNION ALL SELECT ...` instead of `VALUES`. For multiple columns: `VALUES ('Priya', NULL), ('Kiran', 60000)`.
- No `EXCEPT` available? Just compare with the Expected Output table by eye.

---

### P1. List each employee with their department name. Employees without a department must still appear.

**Expected output:**

| name  | dept_name   |
|-------|-------------|
| Asha  | Engineering |
| Ravi  | Engineering |
| Meera | Analytics   |
| John  | Analytics   |
| Priya | Finance     |
| Kiran | NULL        |

<details><summary>Solution</summary>

```sql
SELECT e.name, d.dept_name
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id;
```
</details>

### P2. Find departments that have no employees.

**Expected output:**

| dept_name |
|-----------|
| HR        |

<details><summary>Solution</summary>

```sql
SELECT d.dept_name
FROM departments d
WHERE NOT EXISTS (SELECT 1 FROM employees e WHERE e.dept_id = d.dept_id);
```
`NOT IN (SELECT dept_id FROM employees)` would return **zero rows** here because of Kiran's NULL.
</details>

### P3. Show every department with its employee count, including departments with zero employees.

**Expected output:**

| dept_name   | emp_count |
|-------------|-----------|
| Engineering | 2         |
| Analytics   | 2         |
| Finance     | 1         |
| HR          | 0         |

<details><summary>Solution</summary>

```sql
SELECT d.dept_name, COUNT(e.emp_id) AS emp_count
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id
GROUP BY d.dept_name;
```
Use `COUNT(e.emp_id)`, **not** `COUNT(*)`. `COUNT(*)` would count the NULL-filled HR row as 1.
</details>

### P4. Show each employee with their manager's name. Employees without a manager should show NULL.

**Expected output:**

| employee | manager |
|----------|---------|
| Asha     | NULL    |
| Ravi     | Asha    |
| Meera    | Asha    |
| John     | Meera   |
| Priya    | Meera   |
| Kiran    | Ravi    |

<details><summary>Solution</summary>

```sql
SELECT e.name AS employee, m.name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.emp_id;
```
</details>

### P5. List all departments together with employees hired **after 2021-01-01**. Departments with no such employees must still appear (with NULL name).

**Expected output:**

| dept_name   | name  |
|-------------|-------|
| Engineering | NULL  |
| Analytics   | Meera |
| Analytics   | John  |
| Finance     | Priya |
| HR          | NULL  |

<details><summary>Solution</summary>

```sql
SELECT d.dept_name, e.name
FROM departments d
LEFT JOIN employees e
       ON e.dept_id = d.dept_id
      AND e.hire_date > '2021-01-01';    -- filter in ON, not WHERE
```
If the date filter were in `WHERE`, Engineering and HR would disappear.
</details>

### P6. Show total order amount per customer, including customers with no orders (show 0).

**Expected output:**

| customer_name | total_amount |
|---------------|--------------|
| Anil          | 800          |
| Bina          | 700          |
| Chetan        | 0            |
| Divya         | 0            |

<details><summary>Solution</summary>

```sql
SELECT c.customer_name, COALESCE(SUM(o.amount), 0) AS total_amount
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_name;
```
</details>

### P7. For each order, show the amount, the total paid, and the balance (amount - total paid). Orders with no payments must appear with paid = 0. **Watch out for fan-out.**

**Expected output:**

| order_id | amount | total_paid | balance |
|----------|--------|------------|---------|
| 101      | 500    | 500        | 0       |
| 102      | 300    | 300        | 0       |
| 103      | 700    | 600        | 100     |
| 104      | 200    | 0          | 200     |

<details><summary>Solution</summary>

```sql
SELECT o.order_id,
       o.amount,
       COALESCE(p.total_paid, 0)              AS total_paid,
       o.amount - COALESCE(p.total_paid, 0)   AS balance
FROM orders o
LEFT JOIN (
    SELECT order_id, SUM(paid_amount) AS total_paid
    FROM payments
    GROUP BY order_id
) p ON p.order_id = o.order_id
ORDER BY o.order_id;
```
Aggregating `payments` to one row per order **before** the join keeps each order to exactly one row. Joining first and then summing would duplicate `amount` for orders 101 and 103.
</details>

### P8. Find customers who have never placed an order **and** orders that belong to no customer, in a single result.

**Expected output:**

| customer_name | order_id |
|---------------|----------|
| Chetan        | NULL     |
| Divya         | NULL     |
| NULL          | 104      |

<details><summary>Solution</summary>

```sql
SELECT c.customer_name, o.order_id
FROM customers c
FULL OUTER JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL
   OR c.customer_id IS NULL;
```
MySQL has no `FULL OUTER JOIN`. Use `LEFT JOIN ... WHERE o.order_id IS NULL` `UNION ALL` `RIGHT JOIN ... WHERE c.customer_id IS NULL`.
</details>

---

## 7. Common Mistakes

1. Filtering the right table in `WHERE` after a `LEFT JOIN` (silently becomes an inner join).
2. Using `COUNT(*)` after a `LEFT JOIN` instead of `COUNT(right_key)`, so unmatched rows are counted as 1.
3. Summing a column after a join that multiplies rows (fan-out).
4. Using `DISTINCT` to "fix" duplicates without finding the root cause.
5. Using `NOT IN` against a nullable column.
6. Forgetting the `ON` clause (accidental cross join).
7. Assuming NULL keys will match each other.
8. Joining on non-unique keys without checking the grain of each table.
9. Joining on columns with different data types or unclean values (spaces, case).
10. Using `SELECT *` after joins, which gives duplicate column names (`id`, `name`) and breaks downstream code.
11. Ordering: putting the big table on the wrong side or adding unnecessary joins that fetch unused columns.

---

## 8. Quick Revision Notes

- **INNER** = matches only. **LEFT** = all left + matches. **FULL** = everything. **CROSS** = m x n.
- Rows per key after a join = m x n. Always check the grain and key uniqueness.
- `NULL` keys never match in equality joins.
- Outer join filters: right-table condition goes in **ON** to keep left rows, in **WHERE** to filter the result.
- Anti join: use **NOT EXISTS** (avoid `NOT IN` with nullable columns).
- Semi join: use **EXISTS** to avoid duplicating left rows.
- Aggregate the many-side **before** joining to avoid fan-out.
- Use `COUNT(right.key)`, not `COUNT(*)`, after a left join.
- Join algorithms: nested loop, hash, sort-merge. Distributed: broadcast vs shuffle, watch for skew.
- Validate joins: compare row counts, check key uniqueness, reconcile totals.

---

**Previous topic:** [01 - SQL Basics](./01-basics.md)
**Next topic:** [03 - Aggregations and Conditional Logic](./03-aggregations.md)
