# 03 - Aggregations and Conditional Logic

> Level: Data Engineer, 5 years experience. Aggregation questions test NULL handling, grain awareness and conditional aggregation (pivoting).

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

**Aggregation** collapses many rows into one value per group. `GROUP BY` defines the groups. Without `GROUP BY`, the whole table is one group.

### Core aggregate functions

| Function | Meaning | NULL behavior |
|----------|---------|---------------|
| `COUNT(*)` | Number of rows | Counts every row |
| `COUNT(col)` | Number of non-NULL values | Skips NULLs |
| `COUNT(DISTINCT col)` | Number of unique non-NULL values | Skips NULLs |
| `SUM(col)` | Total | Skips NULLs. Returns **NULL** (not 0) if there are no non-NULL rows |
| `AVG(col)` | Average | Skips NULLs, so the divisor is the non-NULL count |
| `MIN(col)` / `MAX(col)` | Smallest / largest | Skips NULLs |

### Rules for GROUP BY

1. Every column in `SELECT` must be either **in `GROUP BY`** or **inside an aggregate function**.
2. `WHERE` filters rows **before** grouping. `HAVING` filters groups **after** aggregation.
3. `GROUP BY` treats all NULLs as **one** group.
4. Aggregating an empty set: `COUNT` returns 0, `SUM/AVG/MIN/MAX` return NULL.

### Conditional logic: CASE WHEN

`CASE` is SQL's if/else. It returns one value per row and can be used in `SELECT`, `WHERE`, `ORDER BY`, `GROUP BY` and **inside aggregates**.

```sql
CASE WHEN condition1 THEN result1
     WHEN condition2 THEN result2
     ELSE default_result      -- if omitted, unmatched rows return NULL
END
```

### Conditional aggregation (the most useful pattern in analytics SQL)

Put a `CASE` **inside** `SUM` / `COUNT` / `AVG` to compute several filtered metrics in a single pass. This is also how you **pivot** rows into columns.

```sql
SUM(CASE WHEN status = 'returned' THEN amount ELSE 0 END)
COUNT(CASE WHEN status = 'returned' THEN 1 END)     -- COUNT ignores the NULL from the missing ELSE
```

### Dialect differences

| Task | Postgres | Snowflake | BigQuery | MySQL | SQL Server |
|------|----------|-----------|----------|-------|------------|
| Concatenate values in a group | `STRING_AGG(col, ',')` | `LISTAGG(col, ',')` | `STRING_AGG(col, ',')` | `GROUP_CONCAT(col)` | `STRING_AGG(col, ',')` |
| Filtered aggregate shortcut | `COUNT(*) FILTER (WHERE ...)` | `COUNT_IF(...)` | `COUNTIF(...)` | use CASE | use CASE |
| Subtotals | `ROLLUP`, `CUBE`, `GROUPING SETS` | same | same | `WITH ROLLUP` | `ROLLUP`, `CUBE`, `GROUPING SETS` |

---

## 2. What Interviewers Look For

- Do you know the exact NULL behavior of `COUNT(*)`, `COUNT(col)`, `SUM` and `AVG`?
- Can you explain `WHERE` vs `HAVING` and choose correctly for performance?
- Do you use **conditional aggregation** instead of running multiple queries and joining them?
- Do you notice the grain of the result (one row per what?) and avoid double counting?
- Can you handle percentages, ratios and divide-by-zero safely (`NULLIF`)?
- Do you know subtotal features (`ROLLUP`, `GROUPING SETS`) and string aggregation?

---

## 3. Sample Data

Run [`03-aggregations-setup.sql`](./03-aggregations-setup.sql) to create these tables.

**sales**

| sale_id | sale_date | region | product | category | quantity | unit_price | status |
|---|---|---|---|---|---|---|---|
| 1 | 2024-01-05 | North | Laptop | Electronics | 2 | 800 | completed |
| 2 | 2024-01-12 | North | Mouse | Accessories | 10 | 20 | completed |
| 3 | 2024-01-20 | South | Laptop | Electronics | 1 | 800 | completed |
| 4 | 2024-02-03 | South | Keyboard | Accessories | 5 | 45 | completed |
| 5 | 2024-02-14 | East | Phone | Electronics | 3 | 600 | completed |
| 6 | 2024-02-20 | East | Mouse | Accessories | 8 | 20 | returned |
| 7 | 2024-02-25 | North | Phone | Electronics | 1 | 600 | completed |
| 8 | 2024-03-02 | West | Laptop | Electronics | 2 | 800 | completed |
| 9 | 2024-03-09 | West | Keyboard | Accessories | NULL | 45 | cancelled |
| 10 | 2024-03-15 | South | Phone | Electronics | 2 | 600 | completed |
| 11 | 2024-03-22 | North | Keyboard | Accessories | 4 | 45 | completed |
| 12 | 2024-03-28 | East | Laptop | Electronics | 1 | 800 | returned |
| 13 | 2024-04-04 | West | Mouse | Accessories | 6 | 20 | completed |
| 14 | 2024-04-11 | South | Mouse | Accessories | 12 | 20 | completed |
| 15 | 2024-04-18 | North | Laptop | Electronics | 3 | 800 | completed |
| 16 | 2024-04-25 | East | Keyboard | Accessories | 2 | 45 | completed |

Sale 9 has a NULL `quantity`. Revenue = `quantity * unit_price`. Statuses: completed, returned, cancelled.

---

## 4. Examples with Explanations

### 4.1 COUNT variations and NULLs
```sql
SELECT COUNT(*)                AS total_rows,
       COUNT(quantity)          AS qty_not_null,
       COUNT(DISTINCT region)   AS distinct_regions,
       SUM(quantity)            AS total_qty,
       AVG(quantity)            AS avg_qty
FROM sales;
```

**Result:**

| total_rows | qty_not_null | distinct_regions | total_qty | avg_qty |
|---|---|---|---|---|
| 16 | 15 | 4 | 62 | 4.13 |

`COUNT(*)` is 16 but `COUNT(quantity)` is 15 because sale 9 has a NULL quantity. `AVG` divides by 15, not 16.

### 4.2 Revenue per region and category (multiple grouping columns)
```sql
SELECT region, category, SUM(quantity * unit_price) AS revenue
FROM sales
WHERE status = 'completed'
GROUP BY region, category
ORDER BY region, category;
```

**Result:**

| region | category | revenue |
|---|---|---|
| East | Accessories | 90 |
| East | Electronics | 1800 |
| North | Accessories | 380 |
| North | Electronics | 4600 |
| South | Accessories | 465 |
| South | Electronics | 2000 |
| West | Accessories | 120 |
| West | Electronics | 1600 |

The row filter goes in `WHERE`. Every non-aggregated column in `SELECT` appears in `GROUP BY`.

### 4.3 HAVING: filtering groups
```sql
SELECT product, SUM(quantity) AS total_qty
FROM sales
WHERE status = 'completed'
GROUP BY product
HAVING SUM(quantity) >= 20
ORDER BY total_qty DESC;
```

**Result:**

| product | total_qty |
|---|---|
| Mouse | 28 |

`HAVING` can use aggregates, `WHERE` cannot.

### 4.4 Conditional aggregation: pivot status into columns
```sql
SELECT region,
       SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed_orders,
       SUM(CASE WHEN status = 'returned'  THEN 1 ELSE 0 END) AS returned_orders,
       SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_orders
FROM sales
GROUP BY region
ORDER BY region;
```

**Result:**

| region | completed_orders | returned_orders | cancelled_orders |
|---|---|---|---|
| East | 2 | 2 | 0 |
| North | 5 | 0 | 0 |
| South | 4 | 0 | 0 |
| West | 2 | 0 | 1 |

One scan of the table produces three metrics. This beats three separate queries joined together.

### 4.5 Percentage with safe division
```sql
SELECT category,
       ROUND(100.0 * SUM(CASE WHEN status = 'returned' THEN quantity * unit_price ELSE 0 END)
             / NULLIF(SUM(quantity * unit_price), 0), 1) AS return_value_pct
FROM sales
GROUP BY category
ORDER BY category;
```

**Result:**

| category | return_value_pct |
|---|---|
| Accessories | 13.2 |
| Electronics | 7.4 |

`NULLIF(x, 0)` turns a zero denominator into NULL, so the result is NULL instead of a divide-by-zero error. Multiplying by `100.0` (not `100`) avoids integer division.

### 4.6 Aggregating an empty set
```sql
SELECT COUNT(*) AS cnt, SUM(quantity) AS total_qty, MAX(quantity) AS max_qty
FROM sales
WHERE status = 'no-such-status';
```

**Result:**

| cnt | total_qty | max_qty |
|---|---|---|
| 0 | NULL | NULL |

`COUNT` gives 0, but `SUM` and `MAX` give NULL. Use `COALESCE(SUM(...), 0)` when you need a zero.

### 4.7 CASE for bucketing (used in SELECT and GROUP BY)
```sql
SELECT CASE WHEN quantity IS NULL THEN 'unknown'
            WHEN quantity >= 10    THEN 'bulk'
            WHEN quantity >= 3     THEN 'medium'
            ELSE 'small' END AS order_size,
       COUNT(*) AS orders
FROM sales
GROUP BY CASE WHEN quantity IS NULL THEN 'unknown'
              WHEN quantity >= 10    THEN 'bulk'
              WHEN quantity >= 3     THEN 'medium'
              ELSE 'small' END
ORDER BY orders DESC, order_size;
```

**Result:**

| order_size | orders |
|---|---|
| small | 7 |
| medium | 6 |
| bulk | 2 |
| unknown | 1 |

Repeating the CASE in `GROUP BY` is portable. Some engines (Postgres, Snowflake, BigQuery, MySQL) allow `GROUP BY 1` or the alias. Better still: compute the bucket in a CTE, then group.

### 4.8 Subtotals with ROLLUP (dialect-specific, not run here)
```sql
-- Postgres / Snowflake / BigQuery / SQL Server
SELECT region, category, SUM(quantity * unit_price) AS revenue
FROM sales
GROUP BY ROLLUP (region, category);
-- Returns detail rows, a subtotal per region (category = NULL), and a grand total (both NULL).

-- GROUPING SETS gives full control:
GROUP BY GROUPING SETS ((region, category), (region), ())
```

Use `GROUPING(col)` to tell a real NULL from a subtotal NULL. MySQL syntax: `GROUP BY region, category WITH ROLLUP`.

### 4.9 String aggregation (dialect-specific, not run here)
```sql
-- Postgres / BigQuery / SQL Server
SELECT region, STRING_AGG(DISTINCT product, ', ') AS products FROM sales GROUP BY region;
-- Snowflake
SELECT region, LISTAGG(DISTINCT product, ', ') WITHIN GROUP (ORDER BY product) FROM sales GROUP BY region;
-- MySQL
SELECT region, GROUP_CONCAT(DISTINCT product) FROM sales GROUP BY region;
```

---

## 5. Interview Questions and Answers

### Basic

**Q1. Difference between `COUNT(*)`, `COUNT(col)` and `COUNT(DISTINCT col)`?**
`COUNT(*)` counts rows, `COUNT(col)` counts non-NULL values, `COUNT(DISTINCT col)` counts unique non-NULL values.

**Q2. Difference between WHERE and HAVING?**
`WHERE` filters rows before grouping and cannot use aggregates. `HAVING` filters groups after aggregation. Put non-aggregate conditions in `WHERE` so less data is grouped.

**Q3. What happens if a SELECT column is neither in GROUP BY nor aggregated?**
Standard SQL raises an error, because the column has many values per group. MySQL with `ONLY_FULL_GROUP_BY` disabled returns an arbitrary value, which is a silent bug. Engines like BigQuery/Snowflake raise an error.

**Q4. How do aggregates treat NULLs?**
All aggregates except `COUNT(*)` ignore NULLs. `AVG(x)` = `SUM(x) / COUNT(x)`, so NULLs are excluded from both. If you want NULL treated as 0, use `AVG(COALESCE(x, 0))`, but that changes the meaning.

**Q5. What does `SUM` return on zero rows, or if all values are NULL?**
NULL, not 0. Wrap it: `COALESCE(SUM(x), 0)`. `COUNT` returns 0.

**Q6. What is CASE WHEN? Can it be used in ORDER BY or GROUP BY?**
It is conditional expression logic. Yes, it works anywhere an expression is allowed: `SELECT`, `WHERE`, `ORDER BY` (custom sort order), `GROUP BY` (bucketing) and inside aggregates.

### Intermediate

**Q7. What is conditional aggregation? Give an example.**
Putting `CASE` inside an aggregate to compute filtered metrics per group in one scan, for example `SUM(CASE WHEN status = 'returned' THEN amount END)`. It is also the standard way to pivot rows to columns in engines without a `PIVOT` keyword.

**Q8. How do you calculate a percentage of total per group?**
Two common ways: (1) conditional aggregation / ratio of two aggregates, `100.0 * SUM(CASE ... END) / NULLIF(SUM(x), 0)`; (2) a window function, `SUM(x) / SUM(SUM(x)) OVER ()` (covered in Topic 5). Always guard the denominator with `NULLIF` and multiply by `100.0` to avoid integer division.

**Q9. Why does `AVG` of an integer column sometimes return an integer?**
In some engines (SQL Server) `AVG` on `INT` returns `INT`, truncating decimals. Cast first: `AVG(CAST(x AS DECIMAL(18,2)))` or `AVG(x * 1.0)`.

**Q10. Can you use an alias from SELECT in HAVING?**
Standard SQL: no, because `HAVING` runs before `SELECT`. Repeat the expression. Some engines (MySQL, Snowflake, BigQuery, Postgres for GROUP BY) allow it, but it is not portable.

**Q11. What is the difference between `COUNT(CASE WHEN cond THEN 1 END)` and `SUM(CASE WHEN cond THEN 1 ELSE 0 END)`?**
Same result. `COUNT` ignores the NULL produced by the missing `ELSE`. `SUM(... ELSE 0)` always returns a number for non-empty groups, while `COUNT` also gives 0. On an empty group `SUM` returns NULL and `COUNT` returns 0.

**Q12. How do you find groups with duplicates?**
`SELECT key, COUNT(*) FROM t GROUP BY key HAVING COUNT(*) > 1`.

**Q13. What are ROLLUP, CUBE and GROUPING SETS?**
Extensions to `GROUP BY` that compute multiple grouping levels in one query. `ROLLUP(a, b)` gives (a,b), (a), () - a hierarchy of subtotals. `CUBE(a, b)` gives all combinations. `GROUPING SETS` lists exactly the groupings you want. Use `GROUPING()` to distinguish subtotal NULLs from real NULLs.

### Advanced

**Q14. Why does joining before aggregating give wrong totals, and how do you fix it?**
A one-to-many join multiplies the "one" side's rows (fan-out), so `SUM` over its columns double counts. Aggregate each table to the target grain first (in CTEs/subqueries), then join. See Topic 2.

**Q15. `COUNT(DISTINCT)` is slow on huge data. What are the options?**
Approximate functions (`APPROX_COUNT_DISTINCT`, HyperLogLog sketches in BigQuery/Snowflake/Spark), pre-aggregation (distinct at a lower grain then sum), or maintaining incremental aggregate tables. Also know that `COUNT(DISTINCT)` cannot be summed across groups (distinct users per day cannot be added up to distinct users per month).

**Q16. Which aggregates are additive, semi-additive and non-additive?**
Additive (summable across any dimension): revenue, quantity. Semi-additive (not across time): account balance, inventory. Non-additive: ratios, averages, distinct counts. For ratios, store numerator and denominator separately and divide at the end.

**Q17. Why might `SUM(price * qty)` differ from `SUM(price) * SUM(qty)`?**
Sum of products is not the product of sums. Row-level math must happen **before** aggregation, so put it inside the aggregate.

**Q18. How would you find the mode (most frequent value) per group?**
Count per value, then rank: `COUNT(*)` grouped by (group, value), then `ROW_NUMBER() OVER (PARTITION BY group ORDER BY cnt DESC)` and keep rank 1 (decide on tie handling first).

---

## 6. Practice Problems

### How to practice (write, run, test, then look at the solution)

1. **Set up the data.** Run [`03-aggregations-setup.sql`](./03-aggregations-setup.sql) in any database (Postgres, Snowflake, MySQL, SQLite, or an online tool such as DB Fiddle).
2. **Write your own query** for the problem.
3. **Compare with the Expected Output** under each problem.
4. **Run the self-check query** (template below). **0 rows returned = correct.**
5. Only then open the **Solution**.

### Self-check template

```sql
WITH my_answer AS (
    -- paste YOUR query here (example below is the solution to P1)
    SELECT SUM(quantity * unit_price) AS total_revenue
    FROM sales
    WHERE status = 'completed'
),
expected (total_revenue) AS (
    VALUES (11055)
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

### P1. Total revenue of all completed sales (revenue = quantity x unit_price).

**Expected output:**

| total_revenue |
|---|
| 11055 |

<details><summary>Solution</summary>

```sql
SELECT SUM(quantity * unit_price) AS total_revenue
FROM sales
WHERE status = 'completed'
```
</details>

### P2. Revenue per region for completed sales, highest first (break ties by region name).

**Expected output (order matters):**

| region | revenue |
|---|---|
| North | 4980 |
| South | 2465 |
| East | 1890 |
| West | 1720 |

<details><summary>Solution</summary>

```sql
SELECT region, SUM(quantity * unit_price) AS revenue
FROM sales
WHERE status = 'completed'
GROUP BY region
ORDER BY revenue DESC, region
```
</details>

### P3. Products whose total completed quantity is at least 15.

**Expected output (order matters):**

| product | total_qty |
|---|---|
| Mouse | 28 |

<details><summary>Solution</summary>

```sql
SELECT product, SUM(quantity) AS total_qty
FROM sales
WHERE status = 'completed'
GROUP BY product
HAVING SUM(quantity) >= 15
ORDER BY product
```
`WHERE` restricts to completed sales first, then `HAVING` filters the grouped totals.
</details>

### P4. In one row show: total rows, number of non-NULL quantities, and number of distinct regions.

Name the columns `total_rows`, `qty_not_null`, `distinct_regions`.

**Expected output:**

| total_rows | qty_not_null | distinct_regions |
|---|---|---|
| 16 | 15 | 4 |

<details><summary>Solution</summary>

```sql
SELECT COUNT(*)              AS total_rows,
       COUNT(quantity)        AS qty_not_null,
       COUNT(DISTINCT region) AS distinct_regions
FROM sales
```
</details>

### P5. Per region, show completed revenue and returned revenue as two separate columns (pivot).

Name the columns `completed_revenue` and `returned_revenue`. Regions with no returns must show 0.

**Expected output (order matters):**

| region | completed_revenue | returned_revenue |
|---|---|---|
| East | 1890 | 960 |
| North | 4980 | 0 |
| South | 2465 | 0 |
| West | 1720 | 0 |

<details><summary>Solution</summary>

```sql
SELECT region,
       SUM(CASE WHEN status = 'completed' THEN quantity * unit_price ELSE 0 END) AS completed_revenue,
       SUM(CASE WHEN status = 'returned'  THEN quantity * unit_price ELSE 0 END) AS returned_revenue
FROM sales
GROUP BY region
ORDER BY region
```
Cancelled sale 9 has a NULL quantity, but it is excluded by the CASE conditions, so the sums stay clean.
</details>

### P6. Monthly completed revenue.

Return `sale_month` (format `YYYY-MM`) and `revenue`, oldest month first.

**Expected output (order matters):**

| sale_month | revenue |
|---|---|
| 2024-01 | 2600 |
| 2024-02 | 2625 |
| 2024-03 | 2980 |
| 2024-04 | 2850 |

<details><summary>Solution</summary>

```sql
SELECT SUBSTR(sale_date, 1, 7) AS sale_month,
       SUM(quantity * unit_price) AS revenue
FROM sales
WHERE status = 'completed'
GROUP BY SUBSTR(sale_date, 1, 7)
ORDER BY sale_month
```
`SUBSTR` is portable for ISO date text. On real DATE columns use `DATE_TRUNC('month', d)` (Postgres/Snowflake), `DATE_FORMAT(d, '%Y-%m')` (MySQL), or `FORMAT_DATE('%Y-%m', d)` (BigQuery).
</details>

### P7. Return percentage per region: share of sales rows (all statuses) that were returned, rounded to 1 decimal.

Name the columns `region` and `return_pct`.

**Expected output (order matters):**

| region | return_pct |
|---|---|
| East | 50 |
| North | 0 |
| South | 0 |
| West | 0 |

<details><summary>Solution</summary>

```sql
SELECT region,
       ROUND(100.0 * SUM(CASE WHEN status = 'returned' THEN 1 ELSE 0 END) / COUNT(*), 1) AS return_pct
FROM sales
GROUP BY region
ORDER BY region
```
</details>

### P8. Average quantity per product in two versions: ignoring NULLs, and treating NULL as 0. Round to 2 decimals.

Name the columns `product`, `avg_qty`, `avg_qty_null_as_zero`.

**Expected output (order matters):**

| product | avg_qty | avg_qty_null_as_zero |
|---|---|---|
| Keyboard | 3.67 | 2.75 |
| Laptop | 1.8 | 1.8 |
| Mouse | 9 | 9 |
| Phone | 2 | 2 |

<details><summary>Solution</summary>

```sql
SELECT product,
       ROUND(AVG(quantity), 2)               AS avg_qty,
       ROUND(AVG(COALESCE(quantity, 0)), 2)  AS avg_qty_null_as_zero
FROM sales
GROUP BY product
ORDER BY product
```
Only `Keyboard` differs, because sale 9 (Keyboard) has a NULL quantity. This is exactly why you must state how NULLs should be treated.
</details>

---

## 7. Common Mistakes

1. Putting an aggregate condition in `WHERE` (error) or a plain row filter in `HAVING` (slow).
2. Selecting a column that is not in `GROUP BY` and not aggregated.
3. Assuming `AVG` counts NULL as 0.
4. Forgetting `SUM` returns NULL (not 0) on empty input. Use `COALESCE`.
5. Integer division: `SUM(a) / SUM(b)` truncates in some engines. Multiply by `1.0` or cast.
6. Dividing without `NULLIF(denominator, 0)`.
7. Using `COUNT(*)` after a LEFT JOIN when you meant `COUNT(right_key)`.
8. Summing after a fan-out join (double counting).
9. Adding up distinct counts or averages across groups (they are not additive).
10. Using `GROUP BY 1, 2` in production code where column order can change, making it hard to read.

---

## 8. Quick Revision Notes

- `COUNT(*)` counts rows, `COUNT(col)` skips NULLs, `COUNT(DISTINCT col)` counts unique values.
- `SUM/AVG/MIN/MAX` ignore NULLs. `SUM` of nothing is NULL.
- `WHERE` = rows before grouping, `HAVING` = groups after grouping.
- Every SELECT column: in `GROUP BY` or inside an aggregate.
- Conditional aggregation: `SUM(CASE WHEN ... THEN x ELSE 0 END)` = filtered metric and pivot.
- Safe ratio: `100.0 * a / NULLIF(b, 0)`.
- Aggregate to the right grain before joining.
- Subtotals: `ROLLUP`, `CUBE`, `GROUPING SETS`. String aggregation: `STRING_AGG` / `LISTAGG` / `GROUP_CONCAT`.
- Additive vs semi-additive vs non-additive measures.

---

**Previous topic:** [02 - Joins](./02-joins.md)
**Next topic:** [04 - Subqueries and CTEs](./04-subqueries-ctes.md)
