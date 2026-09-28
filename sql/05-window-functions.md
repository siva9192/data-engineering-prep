# 05 - Window Functions

> Level: Data Engineer, 5 years experience. This is the most important SQL topic for interviews: ranking, top-N per group, running totals, LAG/LEAD and frames.

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

A **window function** computes a value for each row using a set of **related rows (the window)**, **without collapsing rows** like `GROUP BY` does.

```sql
function_name(args) OVER (
    PARTITION BY col1, col2        -- split rows into independent groups (optional)
    ORDER BY col3                  -- order inside each partition (needed for ranking, running totals)
    ROWS BETWEEN ... AND ...       -- frame: which rows around the current row (optional)
)
```

### Families of window functions

| Family | Functions | Purpose |
|--------|-----------|---------|
| **Ranking** | `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `NTILE(n)`, `PERCENT_RANK`, `CUME_DIST` | Position of a row within its partition |
| **Value / offset** | `LAG`, `LEAD`, `FIRST_VALUE`, `LAST_VALUE`, `NTH_VALUE` | Read a value from another row |
| **Aggregate as window** | `SUM`, `AVG`, `COUNT`, `MIN`, `MAX` with `OVER` | Running totals, moving averages, share of total |

### ROW_NUMBER vs RANK vs DENSE_RANK (with a tie)

For salaries `150, 120, 120, 105` ordered descending:

| salary | ROW_NUMBER | RANK | DENSE_RANK |
|--------|-----------|------|------------|
| 150 | 1 | 1 | 1 |
| 120 | 2 | 2 | 2 |
| 120 | 3 | 2 | 2 |
| 105 | 4 | **4** (gap) | **3** (no gap) |

`ROW_NUMBER` is always unique (arbitrary among ties unless you add a tiebreaker). `RANK` leaves gaps after ties. `DENSE_RANK` has no gaps.

### Frames (the part people get wrong)

A frame is the subset of the partition used by aggregate/offset-value functions.

- `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`: exactly the physical rows (a 3-row moving window).
- `RANGE BETWEEN ...`: logical range by value, so **rows with equal `ORDER BY` values (peers) are treated together**.
- **Default frame** when you have `ORDER BY` and no frame: `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`. Consequences: a running `SUM` includes all tied peers at once, and `LAST_VALUE` returns the current row's value instead of the partition's last. Always write `ROWS ...` explicitly for running totals and `LAST_VALUE`.
- No `ORDER BY` in `OVER`: the frame is the whole partition.

### Where window functions run (execution order)

`FROM -> WHERE -> GROUP BY -> HAVING -> **WINDOW** -> SELECT -> DISTINCT -> ORDER BY -> LIMIT`

So you **cannot filter on a window result in the same query's `WHERE`**. Wrap it in a subquery/CTE, or use `QUALIFY` where supported.

```sql
-- Snowflake, BigQuery, Databricks, Teradata: QUALIFY filters window results directly
SELECT * FROM emp_salary
QUALIFY ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary DESC) = 1;
```
Postgres, MySQL, SQL Server, Oracle do not have `QUALIFY`: use a CTE + `WHERE rn = 1`.

---

## 2. What Interviewers Look For

- Can you explain `ROW_NUMBER` vs `RANK` vs `DENSE_RANK` and pick one for a given requirement (ties!)?
- Do you solve **top N per group** with a window function in a CTE?
- Do you know `LAG`/`LEAD` for period-over-period comparisons?
- Do you understand **frames** (`ROWS` vs `RANGE`) and the default-frame trap?
- Can you replace self joins and correlated subqueries with windows?
- Do you know windows run after `WHERE`/`GROUP BY` and cannot be filtered directly (`QUALIFY`)?
- Do you always add a **deterministic tiebreaker** to `ORDER BY` inside `OVER`?

---

## 3. Sample Data

Run [`05-window-functions-setup.sql`](./05-window-functions-setup.sql) to create these tables.

**emp_salary**

| emp_id | name | dept | salary | hire_date |
|---|---|---|---|---|
| 1 | Asha | Engineering | 150000 | 2015-01-10 |
| 2 | Ravi | Engineering | 120000 | 2016-03-01 |
| 3 | Kiran | Engineering | 120000 | 2019-07-07 |
| 4 | Neha | Engineering | 105000 | 2020-10-10 |
| 5 | Meera | Analytics | 130000 | 2016-06-15 |
| 6 | John | Analytics | 90000 | 2018-09-01 |
| 7 | Sunita | Analytics | 90000 | 2020-01-15 |
| 8 | Arjun | Analytics | 60000 | 2022-08-08 |
| 9 | Priya | Finance | 125000 | 2017-02-20 |
| 10 | Vikram | Finance | 70000 | 2021-04-04 |

Ties on purpose: Ravi and Kiran (120,000), John and Sunita (90,000).

**daily_sales**

| sale_date | store | revenue |
|---|---|---|
| 2024-03-01 | A | 100 |
| 2024-03-02 | A | 150 |
| 2024-03-03 | A | 120 |
| 2024-03-04 | A | 200 |
| 2024-03-05 | A | 180 |
| 2024-03-01 | B | 80 |
| 2024-03-02 | B | 60 |
| 2024-03-03 | B | 90 |
| 2024-03-04 | B | 110 |
| 2024-03-05 | B | 130 |

Five consecutive days for each of two stores.

---

## 4. Examples with Explanations

### 4.1 ROW_NUMBER, RANK and DENSE_RANK side by side
```sql
SELECT name, dept, salary,
       ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary DESC, name) AS rn,
       RANK()       OVER (PARTITION BY dept ORDER BY salary DESC)       AS rnk,
       DENSE_RANK() OVER (PARTITION BY dept ORDER BY salary DESC)       AS drnk
FROM emp_salary
ORDER BY dept, salary DESC, name;
```

**Result:**

| name | dept | salary | rn | rnk | drnk |
|---|---|---|---|---|---|
| Meera | Analytics | 130000 | 1 | 1 | 1 |
| John | Analytics | 90000 | 2 | 2 | 2 |
| Sunita | Analytics | 90000 | 3 | 2 | 2 |
| Arjun | Analytics | 60000 | 4 | 4 | 3 |
| Asha | Engineering | 150000 | 1 | 1 | 1 |
| Kiran | Engineering | 120000 | 2 | 2 | 2 |
| Ravi | Engineering | 120000 | 3 | 2 | 2 |
| Neha | Engineering | 105000 | 4 | 4 | 3 |
| Priya | Finance | 125000 | 1 | 1 | 1 |
| Vikram | Finance | 70000 | 2 | 2 | 2 |

Look at Engineering: Kiran and Ravi tie at 120,000. Both get RANK 2, the next person (Neha) gets RANK 4 but DENSE_RANK 3. `ROW_NUMBER` breaks the tie using the `name` tiebreaker.

### 4.2 Top 1 per group with a CTE (filtering on a window result)
```sql
WITH ranked AS (
    SELECT name, dept, salary,
           ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary DESC, name) AS rn
    FROM emp_salary
)
SELECT name, dept, salary
FROM ranked
WHERE rn = 1
ORDER BY dept;
```

**Result:**

| name | dept | salary |
|---|---|---|
| Meera | Analytics | 130000 |
| Asha | Engineering | 150000 |
| Priya | Finance | 125000 |

You cannot write `WHERE rn = 1` in the same `SELECT` that defines `rn`, because `WHERE` runs before window functions.

### 4.3 LAG and LEAD
```sql
SELECT sale_date, revenue,
       LAG(revenue)  OVER (ORDER BY sale_date) AS prev_day,
       LEAD(revenue) OVER (ORDER BY sale_date) AS next_day
FROM daily_sales
WHERE store = 'A'
ORDER BY sale_date;
```

**Result:**

| sale_date | revenue | prev_day | next_day |
|---|---|---|---|
| 2024-03-01 | 100 | NULL | 150 |
| 2024-03-02 | 150 | 100 | 120 |
| 2024-03-03 | 120 | 150 | 200 |
| 2024-03-04 | 200 | 120 | 180 |
| 2024-03-05 | 180 | 200 | NULL |

The first row has no previous row (NULL) and the last has no next row (NULL). You can pass a default: `LAG(revenue, 1, 0)`.

### 4.4 Running total: ROWS vs the default RANGE frame
```sql
SELECT name, salary,
       SUM(salary) OVER (ORDER BY salary)                                            AS default_frame,
       SUM(salary) OVER (ORDER BY salary ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS rows_frame
FROM emp_salary
WHERE dept = 'Analytics'
ORDER BY salary, name;
```

**Result:**

| name | salary | default_frame | rows_frame |
|---|---|---|---|
| Arjun | 60000 | 60000 | 60000 |
| John | 90000 | 240000 | 150000 |
| Sunita | 90000 | 240000 | 240000 |
| Meera | 130000 | 370000 | 370000 |

John and Sunita both earn 90,000. With the default `RANGE` frame both rows show the same running total (peers are included together). With `ROWS` the total grows row by row. Use `ROWS` unless you deliberately want peer grouping.

### 4.5 The LAST_VALUE trap
```sql
SELECT name, salary,
       LAST_VALUE(name) OVER (ORDER BY salary)                                                        AS wrong_last,
       LAST_VALUE(name) OVER (ORDER BY salary ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS real_last
FROM emp_salary
WHERE dept = 'Finance'
ORDER BY salary;
```

**Result:**

| name | salary | wrong_last | real_last |
|---|---|---|---|
| Vikram | 70000 | Vikram | Priya |
| Priya | 125000 | Priya | Priya |

With the default frame, `LAST_VALUE` stops at the current row, so it just returns the current row's own value. Extend the frame to `UNBOUNDED FOLLOWING` to get the true last value (or flip the sort and use `FIRST_VALUE`).

### 4.6 Share of total using an aggregate window (no GROUP BY needed)
```sql
SELECT name, dept, salary,
       SUM(salary) OVER (PARTITION BY dept) AS dept_total,
       ROUND(100.0 * salary / SUM(salary) OVER (PARTITION BY dept), 1) AS pct_of_dept
FROM emp_salary
WHERE dept = 'Finance'
ORDER BY salary DESC;
```

**Result:**

| name | dept | salary | dept_total | pct_of_dept |
|---|---|---|---|---|
| Priya | Finance | 125000 | 195000 | 64.1 |
| Vikram | Finance | 70000 | 195000 | 35.9 |

Every row keeps its detail and also sees the partition total.

### 4.7 Named windows (avoid repeating the OVER clause)
```sql
SELECT name, salary,
       RANK()       OVER w AS rnk,
       DENSE_RANK() OVER w AS drnk
FROM emp_salary
WINDOW w AS (PARTITION BY dept ORDER BY salary DESC)
ORDER BY dept, salary DESC, name;
```

**Result:**

| name | salary | rnk | drnk |
|---|---|---|---|
| Meera | 130000 | 1 | 1 |
| John | 90000 | 2 | 2 |
| Sunita | 90000 | 2 | 2 |
| Arjun | 60000 | 4 | 3 |
| Asha | 150000 | 1 | 1 |
| Kiran | 120000 | 2 | 2 |
| Ravi | 120000 | 2 | 2 |
| Neha | 105000 | 4 | 3 |
| Priya | 125000 | 1 | 1 |
| Vikram | 70000 | 2 | 2 |

Supported in Postgres, MySQL 8, SQLite, BigQuery, Snowflake. Not in SQL Server.

---

## 5. Interview Questions and Answers

### Basic

**Q1. What is a window function? How is it different from GROUP BY?**
`GROUP BY` collapses rows into one row per group. A window function keeps every input row and adds a value computed over a related set of rows (the window). You can mix detail columns and aggregates in one result.

**Q2. Explain `PARTITION BY` and `ORDER BY` inside `OVER`.**
`PARTITION BY` splits rows into independent groups, like `GROUP BY` without collapsing. `ORDER BY` defines the order inside each partition, needed for ranking, `LAG/LEAD` and running totals. Omitting `PARTITION BY` treats the whole result as one partition.

**Q3. ROW_NUMBER vs RANK vs DENSE_RANK?**
`ROW_NUMBER` gives unique sequential numbers (ties broken arbitrarily). `RANK` gives ties the same rank and skips the next numbers (1, 2, 2, 4). `DENSE_RANK` gives ties the same rank without gaps (1, 2, 2, 3).

**Q4. What do LAG and LEAD do?**
`LAG(col, n, default)` reads the value from n rows **before** the current row, `LEAD` from n rows **after**, within the partition and order. Used for day-over-day change, time between events, detecting changes.

**Q5. How do you find the top N rows per group?**
Rank inside a CTE/subquery with `ROW_NUMBER` (exactly N rows) or `DENSE_RANK`/`RANK` (include ties), then filter `rank <= N` in the outer query. With `QUALIFY` you can filter directly.

### Intermediate

**Q6. Find the 2nd highest salary per department. Which ranking function and why?**
`DENSE_RANK() = 2` gives the second highest **distinct** salary even with ties at the top. `ROW_NUMBER() = 2` would return a duplicate of the top salary if the top is tied, and `RANK() = 2` may return nothing if three people tie for first (ranks 1,1,1,4). Confirm the tie semantics with the interviewer.

**Q7. What is a window frame? Explain `ROWS` vs `RANGE`.**
The frame is the subset of the partition used by the function for the current row. `ROWS` counts physical rows. `RANGE` uses value ranges on the `ORDER BY` column, so ties (peers) are included together. Default with `ORDER BY` is `RANGE UNBOUNDED PRECEDING TO CURRENT ROW`.

**Q8. Why does `LAST_VALUE` often return the current row instead of the last row?**
Because of the default frame, which ends at the current row (and its peers). Specify `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`, or use `FIRST_VALUE` with the reverse ordering.

**Q9. How do you compute a moving average over the last 3 days?**
`AVG(x) OVER (PARTITION BY key ORDER BY dt ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)`. The first two rows use a partial window. Decide whether to output NULL for incomplete windows (e.g. `CASE WHEN COUNT(*) OVER (...) = 3 THEN ... END`). Note: `ROWS` assumes one row per day; if days are missing, use a date-range frame (`RANGE BETWEEN INTERVAL '2' DAY PRECEDING AND CURRENT ROW` in Postgres) or a calendar table.

**Q10. Can you use a window function in `WHERE`, `GROUP BY` or `HAVING`?**
No. They are evaluated after those clauses. Use a subquery/CTE, or `QUALIFY` where available. Window functions may only appear in `SELECT` and `ORDER BY`.

**Q11. How do you remove duplicates keeping the latest row per key?**
`ROW_NUMBER() OVER (PARTITION BY business_key ORDER BY updated_at DESC, id DESC)` in a CTE, keep `rn = 1`. The extra tiebreaker makes the choice deterministic.

**Q12. Can you combine GROUP BY and window functions in one query?**
Yes. The window runs on the grouped result: `SELECT dept, SUM(salary) AS total, RANK() OVER (ORDER BY SUM(salary) DESC) FROM t GROUP BY dept`. You can nest an aggregate inside a window function.

**Q13. How do you compute percent of total, cumulative percent and quartiles?**
Percent of total: `x / SUM(x) OVER ()`. Cumulative percent: `SUM(x) OVER (ORDER BY ... ROWS UNBOUNDED PRECEDING) / SUM(x) OVER ()`. Quartiles: `NTILE(4)`. Percentile position: `PERCENT_RANK()` or `CUME_DIST()`.

### Advanced

**Q14. Why is a window function query slow and how do you tune it?**
Each distinct `PARTITION BY` / `ORDER BY` combination needs a sort (or hash partition), which is memory and shuffle heavy. Tips: reuse the same window spec across functions so one sort is shared, filter rows **before** the window (in a CTE or `WHERE`), reduce columns, avoid skewed partitions (one huge key, or `NULL` partitions), and in distributed engines watch for a single-partition `OVER ()` (everything goes to one node).

**Q15. How do you do gaps and islands / sessionization with windows?**
Assign each row a group identifier, then aggregate per group. Gaps and islands: `value - ROW_NUMBER() OVER (ORDER BY value)` is constant within a consecutive run. Sessionization: `LAG(ts)`, flag `1` when the gap exceeds the timeout, then a running `SUM(flag)` gives the session number. See Topic 10.

**Q16. What is the difference between `COUNT(*) OVER (PARTITION BY x)` and `COUNT(DISTINCT y) OVER (...)`?**
The first counts rows in each partition. Many engines do **not** allow `DISTINCT` inside window aggregates (Postgres, SQL Server, Redshift do not). Workaround: `DENSE_RANK()` trick (`MAX(dr) OVER (...)` of a dense rank over `y`), or aggregate in a separate CTE and join.

**Q17. Explain `NTILE` and how uneven sizes are handled.**
`NTILE(n)` splits ordered rows into n buckets as evenly as possible. When rows do not divide evenly, the **first** buckets get one extra row (10 rows in 4 buckets gives sizes 3, 3, 2, 2).

**Q18. How do NULLs sort inside `ORDER BY` of a window, and how do you control it?**
The default varies by engine (Postgres/Oracle/Snowflake: NULLs are "largest", so last in ASC and first in DESC; MySQL/SQL Server/SQLite: NULLs are "smallest"). Use `NULLS FIRST` / `NULLS LAST` where supported, or `ORDER BY col IS NULL, col`.

---

## 6. Practice Problems

### How to practice (write, run, test, then look at the solution)

1. **Set up the data.** Run [`05-window-functions-setup.sql`](./05-window-functions-setup.sql) in any database (Postgres, Snowflake, MySQL, SQLite, or an online tool such as DB Fiddle).
2. **Write your own query** for the problem.
3. **Compare with the Expected Output** under each problem.
4. **Run the self-check query** (template below). **0 rows returned = correct.**
5. Only then open the **Solution**.

### Self-check template

```sql
WITH my_answer AS (
    -- paste YOUR query here (example below is the solution to P1)
    SELECT name, dept, salary,
           ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary DESC, name) AS rn,
           RANK()       OVER (PARTITION BY dept ORDER BY salary DESC)       AS rnk,
           DENSE_RANK() OVER (PARTITION BY dept ORDER BY salary DESC)       AS drnk
    FROM emp_salary
),
expected (name, dept, salary, rn, rnk, drnk) AS (
    VALUES ('Meera', 'Analytics', 130000, 1, 1, 1),
           ('John', 'Analytics', 90000, 2, 2, 2),
           ('Sunita', 'Analytics', 90000, 3, 2, 2),
           ('Arjun', 'Analytics', 60000, 4, 4, 3),
           ('Asha', 'Engineering', 150000, 1, 1, 1),
           ('Kiran', 'Engineering', 120000, 2, 2, 2),
           ('Ravi', 'Engineering', 120000, 3, 2, 2),
           ('Neha', 'Engineering', 105000, 4, 4, 3),
           ('Priya', 'Finance', 125000, 1, 1, 1),
           ('Vikram', 'Finance', 70000, 2, 2, 2)
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

### P1. Rank employees within each department by salary (highest first) using `ROW_NUMBER`, `RANK` and `DENSE_RANK` side by side.

Return `name`, `dept`, `salary`, `rn`, `rnk`, `drnk`. In the `ROW_NUMBER` window break ties by `name`. Order by `dept`, salary descending, `name`.

**Expected output (order matters):**

| name | dept | salary | rn | rnk | drnk |
|---|---|---|---|---|---|
| Meera | Analytics | 130000 | 1 | 1 | 1 |
| John | Analytics | 90000 | 2 | 2 | 2 |
| Sunita | Analytics | 90000 | 3 | 2 | 2 |
| Arjun | Analytics | 60000 | 4 | 4 | 3 |
| Asha | Engineering | 150000 | 1 | 1 | 1 |
| Kiran | Engineering | 120000 | 2 | 2 | 2 |
| Ravi | Engineering | 120000 | 3 | 2 | 2 |
| Neha | Engineering | 105000 | 4 | 4 | 3 |
| Priya | Finance | 125000 | 1 | 1 | 1 |
| Vikram | Finance | 70000 | 2 | 2 | 2 |

<details><summary>Solution</summary>

```sql
SELECT name, dept, salary,
       ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary DESC, name) AS rn,
       RANK()       OVER (PARTITION BY dept ORDER BY salary DESC)       AS rnk,
       DENSE_RANK() OVER (PARTITION BY dept ORDER BY salary DESC)       AS drnk
FROM emp_salary
ORDER BY dept, salary DESC, name
```
Ties: Ravi/Kiran (Engineering) and John/Sunita (Analytics).
</details>

### P2. Top 2 salaries per department, **including everyone tied** for a top-2 salary value.

Return `name`, `dept`, `salary`. Order by `dept`, salary descending, `name`.

**Expected output (order matters):**

| name | dept | salary |
|---|---|---|
| Meera | Analytics | 130000 |
| John | Analytics | 90000 |
| Sunita | Analytics | 90000 |
| Asha | Engineering | 150000 |
| Kiran | Engineering | 120000 |
| Ravi | Engineering | 120000 |
| Priya | Finance | 125000 |
| Vikram | Finance | 70000 |

<details><summary>Solution</summary>

```sql
WITH ranked AS (
    SELECT name, dept, salary,
           DENSE_RANK() OVER (PARTITION BY dept ORDER BY salary DESC) AS drnk
    FROM emp_salary
)
SELECT name, dept, salary
FROM ranked
WHERE drnk <= 2
ORDER BY dept, salary DESC, name
```
`DENSE_RANK` <= 2 keeps everybody in the top two **distinct** salary levels, so Engineering returns 3 people.
</details>

### P3. The second highest distinct salary per department.

Return `dept` and `second_highest`, ordered by `dept`.

**Expected output (order matters):**

| dept | second_highest |
|---|---|
| Analytics | 90000 |
| Engineering | 120000 |
| Finance | 70000 |

<details><summary>Solution</summary>

```sql
WITH ranked AS (
    SELECT dept, salary,
           DENSE_RANK() OVER (PARTITION BY dept ORDER BY salary DESC) AS drnk
    FROM emp_salary
)
SELECT dept, MAX(salary) AS second_highest
FROM ranked
WHERE drnk = 2
GROUP BY dept
ORDER BY dept
```
`MAX` collapses tied rows into one row per department.
</details>

### P4. Running total of revenue per store, ordered by date.

Return `store`, `sale_date`, `revenue`, `running_total`. Order by `store`, `sale_date`.

**Expected output (order matters):**

| store | sale_date | revenue | running_total |
|---|---|---|---|
| A | 2024-03-01 | 100 | 100 |
| A | 2024-03-02 | 150 | 250 |
| A | 2024-03-03 | 120 | 370 |
| A | 2024-03-04 | 200 | 570 |
| A | 2024-03-05 | 180 | 750 |
| B | 2024-03-01 | 80 | 80 |
| B | 2024-03-02 | 60 | 140 |
| B | 2024-03-03 | 90 | 230 |
| B | 2024-03-04 | 110 | 340 |
| B | 2024-03-05 | 130 | 470 |

<details><summary>Solution</summary>

```sql
SELECT store, sale_date, revenue,
       SUM(revenue) OVER (PARTITION BY store ORDER BY sale_date
                          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
FROM daily_sales
ORDER BY store, sale_date
```
</details>

### P5. Day-over-day revenue change per store.

Return `store`, `sale_date`, `revenue`, `prev_revenue`, `change` (revenue minus previous day). The first day of each store has NULL for both. Order by `store`, `sale_date`.

**Expected output (order matters):**

| store | sale_date | revenue | prev_revenue | change |
|---|---|---|---|---|
| A | 2024-03-01 | 100 | NULL | NULL |
| A | 2024-03-02 | 150 | 100 | 50 |
| A | 2024-03-03 | 120 | 150 | -30 |
| A | 2024-03-04 | 200 | 120 | 80 |
| A | 2024-03-05 | 180 | 200 | -20 |
| B | 2024-03-01 | 80 | NULL | NULL |
| B | 2024-03-02 | 60 | 80 | -20 |
| B | 2024-03-03 | 90 | 60 | 30 |
| B | 2024-03-04 | 110 | 90 | 20 |
| B | 2024-03-05 | 130 | 110 | 20 |

<details><summary>Solution</summary>

```sql
SELECT store, sale_date, revenue,
       LAG(revenue) OVER (PARTITION BY store ORDER BY sale_date)            AS prev_revenue,
       revenue - LAG(revenue) OVER (PARTITION BY store ORDER BY sale_date)  AS change
FROM daily_sales
ORDER BY store, sale_date
```
Named windows or a CTE avoid repeating the `OVER` clause.
</details>

### P6. 3-day moving average of revenue per store (use the current day and the 2 days before; rounded to 1 decimal).

Return `store`, `sale_date`, `revenue`, `moving_avg_3d`. Days 1 and 2 use the rows available. Order by `store`, `sale_date`.

**Expected output (order matters):**

| store | sale_date | revenue | moving_avg_3d |
|---|---|---|---|
| A | 2024-03-01 | 100 | 100 |
| A | 2024-03-02 | 150 | 125 |
| A | 2024-03-03 | 120 | 123.3 |
| A | 2024-03-04 | 200 | 156.7 |
| A | 2024-03-05 | 180 | 166.7 |
| B | 2024-03-01 | 80 | 80 |
| B | 2024-03-02 | 60 | 70 |
| B | 2024-03-03 | 90 | 76.7 |
| B | 2024-03-04 | 110 | 86.7 |
| B | 2024-03-05 | 130 | 110 |

<details><summary>Solution</summary>

```sql
SELECT store, sale_date, revenue,
       ROUND(AVG(revenue) OVER (PARTITION BY store ORDER BY sale_date
                                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS moving_avg_3d
FROM daily_sales
ORDER BY store, sale_date
```
</details>

### P7. Each employee's salary as a percentage of their department's total payroll (1 decimal).

Return `name`, `dept`, `salary`, `pct_of_dept`. Order by `dept`, salary descending, `name`.

**Expected output (order matters):**

| name | dept | salary | pct_of_dept |
|---|---|---|---|
| Meera | Analytics | 130000 | 35.1 |
| John | Analytics | 90000 | 24.3 |
| Sunita | Analytics | 90000 | 24.3 |
| Arjun | Analytics | 60000 | 16.2 |
| Asha | Engineering | 150000 | 30.3 |
| Kiran | Engineering | 120000 | 24.2 |
| Ravi | Engineering | 120000 | 24.2 |
| Neha | Engineering | 105000 | 21.2 |
| Priya | Finance | 125000 | 64.1 |
| Vikram | Finance | 70000 | 35.9 |

<details><summary>Solution</summary>

```sql
SELECT name, dept, salary,
       ROUND(100.0 * salary / SUM(salary) OVER (PARTITION BY dept), 1) AS pct_of_dept
FROM emp_salary
ORDER BY dept, salary DESC, name
```
</details>

### P8. Show each employee with the name of the top earner in their department.

Return `name`, `dept`, `salary`, `top_earner`. Break salary ties by name. Order by `dept`, salary descending, `name`.

**Expected output (order matters):**

| name | dept | salary | top_earner |
|---|---|---|---|
| Meera | Analytics | 130000 | Meera |
| John | Analytics | 90000 | Meera |
| Sunita | Analytics | 90000 | Meera |
| Arjun | Analytics | 60000 | Meera |
| Asha | Engineering | 150000 | Asha |
| Kiran | Engineering | 120000 | Asha |
| Ravi | Engineering | 120000 | Asha |
| Neha | Engineering | 105000 | Asha |
| Priya | Finance | 125000 | Priya |
| Vikram | Finance | 70000 | Priya |

<details><summary>Solution</summary>

```sql
SELECT name, dept, salary,
       FIRST_VALUE(name) OVER (PARTITION BY dept ORDER BY salary DESC, name) AS top_earner
FROM emp_salary
ORDER BY dept, salary DESC, name
```
`FIRST_VALUE` works with the default frame because the first row is always inside it. `LAST_VALUE` needs an explicit frame.
</details>

### P9. Split all employees into 4 salary quartiles (1 = highest paid) using `NTILE`.

Return `name`, `salary`, `quartile`. Order by salary descending, then `name`.

**Expected output (order matters):**

| name | salary | quartile |
|---|---|---|
| Asha | 150000 | 1 |
| Meera | 130000 | 1 |
| Priya | 125000 | 1 |
| Kiran | 120000 | 2 |
| Ravi | 120000 | 2 |
| Neha | 105000 | 2 |
| John | 90000 | 3 |
| Sunita | 90000 | 3 |
| Vikram | 70000 | 4 |
| Arjun | 60000 | 4 |

<details><summary>Solution</summary>

```sql
SELECT name, salary,
       NTILE(4) OVER (ORDER BY salary DESC, name) AS quartile
FROM emp_salary
ORDER BY salary DESC, name
```
10 rows in 4 buckets: sizes are 3, 3, 2, 2.
</details>

---

## 7. Common Mistakes

1. Filtering on a window function in `WHERE` (not allowed). Use a CTE or `QUALIFY`.
2. Using `ROW_NUMBER` when ties must be kept (or `RANK` when gaps break logic). Decide tie semantics first.
3. No tiebreaker in `ORDER BY` inside `OVER`, so results change between runs.
4. Relying on the default frame for running totals and `LAST_VALUE`. Write `ROWS ...` explicitly.
5. Forgetting `PARTITION BY`, so the window spans the whole table.
6. Using `ROWS` for a date-based moving average when days are missing (windows count rows, not days).
7. Assuming `LAG` looks across partitions. It stops at the partition boundary and returns NULL.
8. Confusing the outer `ORDER BY` with the window `ORDER BY`. The window one does not sort the final output.
9. Using `COUNT(DISTINCT ...) OVER` in engines that do not support it.
10. Adding window functions on a huge table before filtering, causing needless sorts.

---

## 8. Quick Revision Notes

- `function() OVER (PARTITION BY ... ORDER BY ... frame)`. Rows are kept, not collapsed.
- `ROW_NUMBER` unique. `RANK` has gaps after ties. `DENSE_RANK` has no gaps.
- Top N per group: rank in a CTE, filter in the outer query (or `QUALIFY`).
- Nth highest distinct value: `DENSE_RANK() = N`.
- `LAG`/`LEAD` for previous/next row, default value as 3rd argument.
- Running total: `SUM() OVER (PARTITION BY .. ORDER BY .. ROWS UNBOUNDED PRECEDING)`.
- Moving average: `ROWS BETWEEN n PRECEDING AND CURRENT ROW`.
- Default frame with `ORDER BY` = `RANGE` up to current row (ties are peers). `LAST_VALUE` needs `UNBOUNDED FOLLOWING`.
- Windows run after `WHERE`/`GROUP BY`/`HAVING`, before final `ORDER BY`.
- `NTILE(n)`: earlier buckets get the extra rows.
- Add a tiebreaker column to make results deterministic.

---

**Previous topic:** [04 - Subqueries and CTEs](./04-subqueries-ctes.md)
**Next topic:** [06 - Data Cleaning](./06-data-cleaning.md)
