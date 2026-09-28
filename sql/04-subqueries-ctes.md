# 04 - Subqueries and CTEs (including Recursive)

> Level: Data Engineer, 5 years experience. Expect correlated subqueries, recursive hierarchies and "rewrite this to be faster" questions.

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

### Subqueries

A **subquery** is a `SELECT` nested inside another statement. By what it returns:

| Type | Returns | Typical use |
|------|---------|-------------|
| **Scalar** subquery | One value (1 row, 1 column) | `WHERE salary > (SELECT AVG(salary) FROM ...)` or a computed column in `SELECT` |
| **Row / column list** subquery | One column, many rows | `WHERE dept_id IN (SELECT ...)` |
| **Table (derived table)** subquery | A whole result set | `FROM (SELECT ...) AS t` |
| **Correlated** subquery | References a column of the outer query, so it is logically re-evaluated per outer row | "above the average **of their own department**" |

A scalar subquery that returns more than one row raises an error. One that returns no rows yields NULL.

### CTEs (Common Table Expressions)

A CTE is a named temporary result set defined with `WITH`, valid only for the one statement that follows.

```sql
WITH dept_avg AS (
    SELECT dept_id, AVG(salary) AS avg_salary
    FROM employees
    GROUP BY dept_id
)
SELECT e.name, e.salary, d.avg_salary
FROM employees e
JOIN dept_avg d ON d.dept_id = e.dept_id;
```

Why use them: readability (top-down steps instead of nesting), reuse (reference the same CTE several times), and recursion.

### Recursive CTEs

Used for hierarchies (org charts, category trees, bill of materials) and sequences.

```sql
WITH RECURSIVE tree AS (
    SELECT ...            -- anchor member: starting rows
    UNION ALL
    SELECT ...            -- recursive member: joins back to `tree`
    FROM source JOIN tree ON ...
)
SELECT * FROM tree;
```

Execution: run the anchor, then repeatedly run the recursive member on the **previous iteration's rows** until it returns nothing. Always make sure it terminates (a shrinking condition, a depth limit, or cycle detection). SQL Server and Oracle omit the `RECURSIVE` keyword.

### Subquery vs CTE vs temp table vs view

| Option | Lifetime | Best for |
|--------|----------|----------|
| Subquery | One place in one statement | Simple one-off logic |
| CTE | One statement | Readability, reuse within a statement, recursion |
| Temp table | Session | Reusing an expensive intermediate result across many statements, adding indexes/statistics |
| View | Persistent definition (no stored data) | Sharing logic across queries and users |
| Materialized view | Persistent, stores data | Precomputing heavy aggregates |

Performance note: a CTE is **not automatically materialized**. Postgres 12+ inlines a CTE that is referenced once (and you can force it with `MATERIALIZED`), SQL Server treats CTEs like inline views (re-evaluated at each reference), while Snowflake and BigQuery optimizers decide themselves. Do not assume a CTE caches its result.

---

## 2. What Interviewers Look For

- Can you choose between a subquery, CTE, temp table and view and justify it?
- Do you understand **correlated** subqueries and can you rewrite them as joins or window functions?
- Can you write a **recursive CTE** for a hierarchy from scratch (anchor + recursive + termination)?
- Do you know `IN` vs `EXISTS` vs `JOIN` for existence checks, and the `NOT IN` NULL trap?
- Do you write layered, readable CTE pipelines instead of deeply nested queries?
- Do you know CTEs may be re-evaluated and are not guaranteed to be materialized?

---

## 3. Sample Data

Run [`04-subqueries-ctes-setup.sql`](./04-subqueries-ctes-setup.sql) to create these tables.

**departments**

| dept_id | dept_name |
|---|---|
| 10 | Engineering |
| 20 | Analytics |
| 30 | Finance |
| 40 | HR |

HR has no employees on purpose.

**employees**

| emp_id | name | dept_id | manager_id | salary | hire_date |
|---|---|---|---|---|---|
| 1 | Asha | 10 | NULL | 150000 | 2015-01-10 |
| 2 | Ravi | 10 | 1 | 120000 | 2016-03-01 |
| 3 | Meera | 20 | 1 | 130000 | 2016-06-15 |
| 4 | John | 20 | 3 | 90000 | 2018-09-01 |
| 5 | Priya | 30 | 1 | 125000 | 2017-02-20 |
| 6 | Kiran | 10 | 2 | 95000 | 2019-07-07 |
| 7 | Sunita | 20 | 3 | 85000 | 2020-01-15 |
| 8 | Vikram | 30 | 5 | 70000 | 2021-04-04 |
| 9 | Neha | 10 | 2 | 105000 | 2020-10-10 |
| 10 | Arjun | 20 | 4 | 60000 | 2022-08-08 |

`manager_id` points to another row in the same table (the hierarchy). Asha (manager_id NULL) is the top of the tree.

---

## 4. Examples with Explanations

### 4.1 Scalar subquery in WHERE
```sql
SELECT name, salary
FROM employees
WHERE salary > (SELECT AVG(salary) FROM employees)
ORDER BY salary DESC;
```

**Result:**

| name | salary |
|---|---|
| Asha | 150000 |
| Meera | 130000 |
| Priya | 125000 |
| Ravi | 120000 |
| Neha | 105000 |

The subquery runs once and returns a single value (the company average).

### 4.2 Subquery with IN
```sql
SELECT name
FROM employees
WHERE dept_id IN (SELECT dept_id FROM departments WHERE dept_name IN ('Finance', 'HR'))
ORDER BY name;
```

**Result:**

| name |
|---|
| Priya |
| Vikram |

### 4.3 Correlated subquery: above the average of their own department
```sql
SELECT e.name, e.dept_id, e.salary
FROM employees e
WHERE e.salary > (SELECT AVG(e2.salary)
                  FROM employees e2
                  WHERE e2.dept_id = e.dept_id)
ORDER BY e.dept_id, e.salary DESC;
```

**Result:**

| name | dept_id | salary |
|---|---|---|
| Asha | 10 | 150000 |
| Ravi | 10 | 120000 |
| Meera | 20 | 130000 |
| Priya | 30 | 125000 |

The inner query references `e.dept_id` from the outer query. Logically it runs per outer row. Optimizers often decorrelate it, but on large data prefer the CTE/window version below.

### 4.4 Same logic with a CTE and a join (usually faster and easier to read)
```sql
WITH dept_avg AS (
    SELECT dept_id, AVG(salary) AS avg_salary
    FROM employees
    GROUP BY dept_id
)
SELECT e.name, e.dept_id, e.salary, ROUND(d.avg_salary) AS dept_avg
FROM employees e
JOIN dept_avg d ON d.dept_id = e.dept_id
WHERE e.salary > d.avg_salary
ORDER BY e.dept_id, e.salary DESC;
```

**Result:**

| name | dept_id | salary | dept_avg |
|---|---|---|---|
| Asha | 10 | 150000 | 117500 |
| Ravi | 10 | 120000 | 117500 |
| Meera | 20 | 130000 | 91250 |
| Priya | 30 | 125000 | 97500 |

The average is computed once per department, not once per employee.

### 4.5 Chained CTEs (a readable pipeline)
```sql
WITH dept_stats AS (
    SELECT dept_id, COUNT(*) AS headcount, SUM(salary) AS payroll
    FROM employees
    GROUP BY dept_id
),
ranked AS (
    SELECT d.dept_name, s.headcount, s.payroll
    FROM dept_stats s
    JOIN departments d ON d.dept_id = s.dept_id
)
SELECT dept_name, headcount, payroll
FROM ranked
WHERE payroll > 300000
ORDER BY payroll DESC;
```

**Result:**

| dept_name | headcount | payroll |
|---|---|---|
| Engineering | 4 | 470000 |
| Analytics | 4 | 365000 |

Each CTE is one logical step and can reference the earlier ones.

### 4.6 Derived table (subquery in FROM)
```sql
SELECT t.dept_id, t.max_salary
FROM (SELECT dept_id, MAX(salary) AS max_salary
      FROM employees
      GROUP BY dept_id) t
WHERE t.max_salary >= 130000
ORDER BY t.dept_id;
```

**Result:**

| dept_id | max_salary |
|---|---|
| 10 | 150000 |
| 20 | 130000 |

A derived table must have an alias in most engines.

### 4.7 EXISTS (semi join)
```sql
SELECT d.dept_name
FROM departments d
WHERE EXISTS (SELECT 1 FROM employees e WHERE e.dept_id = d.dept_id AND e.salary > 125000)
ORDER BY d.dept_name;
```

**Result:**

| dept_name |
|---|
| Analytics |
| Engineering |

`EXISTS` stops at the first match and never duplicates outer rows. The `SELECT 1` is a convention, the columns are ignored.

### 4.8 Recursive CTE: everyone under Asha (org chart traversal) with level
```sql
WITH RECURSIVE org AS (
    SELECT emp_id, name, manager_id, 1 AS level
    FROM employees
    WHERE manager_id IS NULL                 -- anchor: the top of the tree
    UNION ALL
    SELECT e.emp_id, e.name, e.manager_id, o.level + 1
    FROM employees e
    JOIN org o ON e.manager_id = o.emp_id    -- recursive step: next level down
)
SELECT name, level FROM org ORDER BY level, emp_id;
```

**Result:**

| name | level |
|---|---|
| Asha | 1 |
| Ravi | 2 |
| Meera | 2 |
| Priya | 2 |
| John | 3 |
| Kiran | 3 |
| Sunita | 3 |
| Vikram | 3 |
| Neha | 3 |
| Arjun | 4 |

Iteration 1 returns Asha. Iteration 2 returns her direct reports, iteration 3 their reports, and so on until no rows are added. Watch out for cycles in real data (A manages B manages A): add a depth limit, e.g. `WHERE o.level < 20`.

### 4.9 Recursive CTE: generating a number series
```sql
WITH RECURSIVE nums(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM nums WHERE n < 5
)
SELECT n, n * n AS square FROM nums;
```

**Result:**

| n | square |
|---|---|
| 1 | 1 |
| 2 | 4 |
| 3 | 9 |
| 4 | 16 |
| 5 | 25 |

Useful for building calendar/scaffold tables in engines without `generate_series`. In SQL Server drop the word `RECURSIVE`.

---

## 5. Interview Questions and Answers

### Basic

**Q1. What is a subquery? Name the types.**
A query nested inside another. Scalar (one value), multi-row (a list for `IN`), table/derived (used in `FROM`), and correlated (references the outer query).

**Q2. What is a CTE and why use it?**
A named result set defined with `WITH` and usable within one statement. It makes complex queries readable (step by step), lets you reference one result multiple times, and enables recursion.

**Q3. What is a correlated subquery?**
A subquery that uses columns from the outer query, so it is logically evaluated once per outer row. Example: employees earning more than the average of their own department.

**Q4. What happens when a scalar subquery returns more than one row? Zero rows?**
More than one: runtime error ("subquery returned more than one row"). Zero rows: the result is NULL.

**Q5. Difference between a view and a CTE?**
A view is a stored, named query that persists in the database and can be reused by many queries and users. A CTE exists only for the single statement it is defined in.

### Intermediate

**Q6. IN vs EXISTS vs JOIN: when do you use which?**
`JOIN` when you need columns from both tables (watch for duplicate rows). `EXISTS` / `IN` when you only need to test presence; they do not multiply rows. `EXISTS` is NULL-safe and stops at the first hit. `NOT IN` breaks when the subquery returns a NULL, so use `NOT EXISTS`. Modern optimizers usually plan `IN` and `EXISTS` the same way.

**Q7. How do you rewrite a correlated subquery to be faster?**
Compute the aggregate once per group in a CTE/derived table and join it (as in the example), or use a window function (`AVG(salary) OVER (PARTITION BY dept_id)`) and filter in an outer query. This turns per-row lookups into one grouped pass.

**Q8. Are CTEs faster than subqueries?**
Not inherently. Most engines inline them and produce the same plan. The benefit is readability and reuse. A CTE referenced multiple times may be **evaluated multiple times** (SQL Server) or materialized (depends on engine and hints). If an expensive intermediate result is reused many times, consider a temp table.

**Q9. When would you use a temp table instead of a CTE?**
When the intermediate result is expensive and reused across multiple statements, when you want to index it or collect statistics on it, when you need to break a huge query into checkpoints for debugging, or in engines where CTE re-evaluation is costly.

**Q10. Explain the structure of a recursive CTE.**
An **anchor member** (non-recursive starting rows), `UNION ALL`, and a **recursive member** that references the CTE itself. The engine repeats the recursive member using the rows produced by the previous iteration until it returns no rows. Then the outer query reads the accumulated result.

**Q11. How do you prevent infinite recursion?**
Guarantee a termination condition (e.g. `n < 100`), track depth and cap it, keep a path/visited list and skip nodes already visited (cycle detection), or use engine limits (`MAXRECURSION` in SQL Server, default 100; Postgres `CYCLE` clause in v14+). Also keep the recursion on `UNION ALL` when you know there are no duplicates, since `UNION` adds dedupe cost.

**Q12. Can a subquery appear in SELECT, FROM, WHERE and HAVING?**
Yes in all four. In `SELECT` it must be scalar. In `FROM` it needs an alias. Be careful with scalar subqueries in `SELECT` on big tables: they can behave like a per-row lookup.

**Q13. How do you get the Nth highest value using a subquery?**
`SELECT MAX(x) FROM t WHERE x < (SELECT MAX(x) FROM t)` gives the second highest. For general N, use `DENSE_RANK()` in a subquery/CTE (Topic 5) or `LIMIT 1 OFFSET N-1` on `SELECT DISTINCT`.

### Advanced

**Q14. What is a LATERAL join / CROSS APPLY and how does it relate to correlated subqueries?**
It lets a subquery in the `FROM` clause reference columns of tables to its left, like a correlated subquery that can return multiple rows and columns. Example: "top 3 orders per customer": `FROM customers c CROSS JOIN LATERAL (SELECT ... WHERE o.customer_id = c.id ORDER BY ... LIMIT 3) t`. SQL Server: `CROSS APPLY`. Snowflake: `LATERAL`. BigQuery: correlated `UNNEST`/subqueries.

**Q15. How would you traverse a hierarchy with unknown depth and produce the full path?**
Recursive CTE that carries a path column: `name AS path` in the anchor and `o.path || ' > ' || e.name` in the recursive step (`CONCAT` in some engines). Alternatives when hierarchies are read heavily: store a closure table, materialized path, or nested sets, or flatten the hierarchy in the pipeline (ETL) instead of at query time.

**Q16. Why might a query with a scalar subquery in SELECT be slow, and what is the alternative?**
It may execute once per output row (correlated). Replace with a `LEFT JOIN` to a pre-aggregated derived table, keeping the `LEFT` so rows with no match still appear.

**Q17. What is the difference between `MATERIALIZED` and `NOT MATERIALIZED` CTEs (Postgres)?**
`MATERIALIZED` forces the CTE to be computed once and stored (an optimization fence, good for expensive reused results). `NOT MATERIALIZED` allows inlining so filters can be pushed inside. Before Postgres 12, CTEs were always materialized, which surprised many people.

**Q18. How do you break a 300-line query into something maintainable in a data pipeline?**
Split logic into layered CTEs with clear names (staging -> business logic -> final), or persist stable layers as views/tables/dbt models with tests. Each layer does one thing and has a known grain.

---

## 6. Practice Problems

### How to practice (write, run, test, then look at the solution)

1. **Set up the data.** Run [`04-subqueries-ctes-setup.sql`](./04-subqueries-ctes-setup.sql) in any database (Postgres, Snowflake, MySQL, SQLite, or an online tool such as DB Fiddle).
2. **Write your own query** for the problem.
3. **Compare with the Expected Output** under each problem.
4. **Run the self-check query** (template below). **0 rows returned = correct.**
5. Only then open the **Solution**.

### Self-check template

```sql
WITH my_answer AS (
    -- paste YOUR query here (example below is the solution to P1)
    SELECT name, salary
    FROM employees
    WHERE salary > (SELECT AVG(salary) FROM employees)
),
expected (name, salary) AS (
    VALUES ('Asha', 150000),
           ('Meera', 130000),
           ('Priya', 125000),
           ('Ravi', 120000),
           ('Neha', 105000)
)
SELECT 'MISSING' AS issue, m.* FROM (SELECT * FROM expected  EXCEPT SELECT * FROM my_answer) m
UNION ALL
SELECT 'EXTRA'   AS issue, e.* FROM (SELECT * FROM my_answer EXCEPT SELECT * FROM expected)  e;
```

Notes:
- Column names and order in `my_answer` must match `expected`.
- `EXCEPT` ignores row order, so for problems marked "order matters", also compare the order by eye.
- Dialects: BigQuery needs `EXCEPT DISTINCT`, Oracle uses `MINUS`. SQL Server / older MySQL need `SELECT ... UNION ALL SELECT ...` instead of `VALUES (...)`. SQL Server also does not allow `ORDER BY` inside a CTE, so remove it from `my_answer`.
- No `EXCEPT` available? Just compare with the Expected Output table by eye.

---

### P1. Employees who earn more than the company-wide average salary.

Return `name` and `salary`, highest salary first.

**Expected output (order matters):**

| name | salary |
|---|---|
| Asha | 150000 |
| Meera | 130000 |
| Priya | 125000 |
| Ravi | 120000 |
| Neha | 105000 |

<details><summary>Solution</summary>

```sql
SELECT name, salary
FROM employees
WHERE salary > (SELECT AVG(salary) FROM employees)
ORDER BY salary DESC
```
The average salary is 103,000. The scalar subquery runs once.
</details>

### P2. Employees who earn more than the average salary of **their own department**.

Return `name`, `dept_id`, `salary`. Order by `dept_id`, then salary descending.

**Expected output (order matters):**

| name | dept_id | salary |
|---|---|---|
| Asha | 10 | 150000 |
| Ravi | 10 | 120000 |
| Meera | 20 | 130000 |
| Priya | 30 | 125000 |

<details><summary>Solution</summary>

```sql
SELECT e.name, e.dept_id, e.salary
FROM employees e
WHERE e.salary > (SELECT AVG(e2.salary)
                  FROM employees e2
                  WHERE e2.dept_id = e.dept_id)
ORDER BY e.dept_id, e.salary DESC
```
Correlated subquery. A CTE + join gives the same result.
</details>

### P3. For every department (including those with no employees) show headcount and average salary rounded to a whole number.

Return `dept_name`, `headcount`, `avg_salary`. Order by `dept_id`. HR has 0 employees and a NULL average. Use a CTE.

**Expected output (order matters):**

| dept_name | headcount | avg_salary |
|---|---|---|
| Engineering | 4 | 117500 |
| Analytics | 4 | 91250 |
| Finance | 2 | 97500 |
| HR | 0 | NULL |

<details><summary>Solution</summary>

```sql
WITH stats AS (
    SELECT dept_id, COUNT(*) AS headcount, ROUND(AVG(salary)) AS avg_salary
    FROM employees
    GROUP BY dept_id
)
SELECT d.dept_name,
       COALESCE(s.headcount, 0) AS headcount,
       s.avg_salary
FROM departments d
LEFT JOIN stats s ON s.dept_id = d.dept_id
ORDER BY d.dept_id
```
`LEFT JOIN` keeps HR. `COALESCE` turns the missing headcount into 0, while the average correctly stays NULL.
</details>

### P4. Departments that have at least one employee earning more than 120,000 (use EXISTS).

Return `dept_name`, alphabetically.

**Expected output (order matters):**

| dept_name |
|---|
| Analytics |
| Engineering |
| Finance |

<details><summary>Solution</summary>

```sql
SELECT d.dept_name
FROM departments d
WHERE EXISTS (SELECT 1
              FROM employees e
              WHERE e.dept_id = d.dept_id
                AND e.salary > 120000)
ORDER BY d.dept_name
```
</details>

### P5. All direct and indirect reports of Meera (emp_id 3). Use a recursive CTE.

Return `name` ordered by `emp_id`. Do not include Meera herself.

**Expected output (order matters):**

| name |
|---|
| John |
| Sunita |
| Arjun |

<details><summary>Solution</summary>

```sql
WITH RECURSIVE reports AS (
    SELECT emp_id, name
    FROM employees
    WHERE manager_id = 3                       -- anchor: Meera's direct reports
    UNION ALL
    SELECT e.emp_id, e.name
    FROM employees e
    JOIN reports r ON e.manager_id = r.emp_id  -- their reports, and so on
)
SELECT name FROM reports ORDER BY emp_id
```
John and Sunita report directly to Meera. Arjun reports to John, so he is an indirect report.
</details>

### P6. Show every employee with their level in the reporting hierarchy (the top person is level 1).

Return `name` and `level`, ordered by level, then `emp_id`.

**Expected output (order matters):**

| name | level |
|---|---|
| Asha | 1 |
| Ravi | 2 |
| Meera | 2 |
| Priya | 2 |
| John | 3 |
| Kiran | 3 |
| Sunita | 3 |
| Vikram | 3 |
| Neha | 3 |
| Arjun | 4 |

<details><summary>Solution</summary>

```sql
WITH RECURSIVE org AS (
    SELECT emp_id, name, 1 AS level
    FROM employees
    WHERE manager_id IS NULL
    UNION ALL
    SELECT e.emp_id, e.name, o.level + 1
    FROM employees e
    JOIN org o ON e.manager_id = o.emp_id
)
SELECT name, level
FROM org
ORDER BY level, emp_id
```
</details>

### P7. Generate the numbers 1 to 7 together with their cubes using a recursive CTE.

Return columns `n` and `cube`.

**Expected output (order matters):**

| n | cube |
|---|---|
| 1 | 1 |
| 2 | 8 |
| 3 | 27 |
| 4 | 64 |
| 5 | 125 |
| 6 | 216 |
| 7 | 343 |

<details><summary>Solution</summary>

```sql
WITH RECURSIVE nums(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM nums WHERE n < 7
)
SELECT n, n * n * n AS cube
FROM nums
ORDER BY n
```
SQL Server: remove the word `RECURSIVE`. Postgres/BigQuery/Snowflake also offer `generate_series` / `GENERATE_ARRAY`.
</details>

### P8. List the managers (people with at least one direct report) and how many direct reports each has. Use a derived table or CTE.

Return `name` and `direct_reports`. Most reports first, ties by name.

**Expected output (order matters):**

| name | direct_reports |
|---|---|
| Asha | 3 |
| Meera | 2 |
| Ravi | 2 |
| John | 1 |
| Priya | 1 |

<details><summary>Solution</summary>

```sql
WITH report_counts AS (
    SELECT manager_id, COUNT(*) AS direct_reports
    FROM employees
    WHERE manager_id IS NOT NULL
    GROUP BY manager_id
)
SELECT e.name, r.direct_reports
FROM employees e
JOIN report_counts r ON r.manager_id = e.emp_id
ORDER BY r.direct_reports DESC, e.name
```
</details>

### P9. The most recently hired employee in each department (use a correlated subquery on `MAX(hire_date)`).

Return `name`, `dept_id`, `hire_date`, ordered by `dept_id`.

**Expected output (order matters):**

| name | dept_id | hire_date |
|---|---|---|
| Neha | 10 | 2020-10-10 |
| Arjun | 20 | 2022-08-08 |
| Vikram | 30 | 2021-04-04 |

<details><summary>Solution</summary>

```sql
SELECT e.name, e.dept_id, e.hire_date
FROM employees e
WHERE e.hire_date = (SELECT MAX(e2.hire_date)
                     FROM employees e2
                     WHERE e2.dept_id = e.dept_id)
ORDER BY e.dept_id
```
If two people shared the latest date both would be returned. A `ROW_NUMBER()` window (Topic 5) is the tool when you need exactly one.
</details>

---

## 7. Common Mistakes

1. Using `NOT IN` with a subquery that can return NULL.
2. A scalar subquery that can return more than one row (runtime error).
3. Forgetting the alias on a derived table.
4. Recursive CTE with no termination condition or with cyclic data (infinite loop).
5. Using `UNION` instead of `UNION ALL` in a recursive CTE (unneeded dedupe, or masks cycles unpredictably).
6. Assuming a CTE is cached. It may be recomputed on every reference.
7. Correlated subquery in `SELECT` on a large table where a join to a pre-aggregated table is better.
8. Deeply nested subqueries that nobody can read. Use named CTEs.
9. Using `SELECT *` inside a CTE and then breaking when upstream columns change.
10. Joining to a CTE that has duplicates on the join key (fan-out).

---

## 8. Quick Revision Notes

- Subquery types: scalar, list, derived table, correlated.
- Scalar subquery: 1 row or error; 0 rows gives NULL.
- Correlated = references outer query. Rewrite as CTE + join or window for speed.
- `EXISTS` for presence checks, `NOT EXISTS` instead of `NOT IN`.
- CTE = readability and reuse, not a guaranteed cache. Temp table for reuse across statements.
- Recursive CTE = anchor + `UNION ALL` + recursive member + termination. Cap the depth.
- Hierarchy pattern: anchor `manager_id IS NULL`, recurse `e.manager_id = o.emp_id`, carry `level`/`path`.
- `LATERAL` / `CROSS APPLY` = correlated subquery in FROM (top N per group).
- SQL Server/Oracle: no `RECURSIVE` keyword.

---

**Previous topic:** [03 - Aggregations](./03-aggregations.md)
**Next topic:** [05 - Window Functions](./05-window-functions.md)
