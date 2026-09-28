# 07 - Set Operations, EXISTS vs IN

> Level: Data Engineer, 5 years experience. These questions test NULL traps and reconciliation thinking, which is daily work for data engineers.

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

### Set operators

Set operators combine the **rows** of two queries (vertically), unlike joins which add columns.

| Operator | Result | Duplicates |
|----------|--------|------------|
| `UNION` | Rows in A **or** B | Removed (needs sort/hash, slower) |
| `UNION ALL` | Rows in A **plus** rows in B | Kept (fast) |
| `INTERSECT` | Rows in **both** A and B | Removed |
| `EXCEPT` (Oracle: `MINUS`) | Rows in A **not** in B | Removed |

Rules:
1. Both queries must return the **same number of columns** with **compatible types**, matched by **position** (not name).
2. Column names come from the **first** query.
3. `ORDER BY` goes **once, at the very end**, and applies to the whole result.
4. Set operators compare **entire rows** and treat **NULLs as equal** (unlike `=` in a join, `NULL` matches `NULL` here).
5. Precedence: `INTERSECT` binds tighter than `UNION`/`EXCEPT` in the standard. Use parentheses to be explicit.
6. `EXCEPT` is **not symmetric**: A EXCEPT B differs from B EXCEPT A.

Dialect notes: Oracle uses `MINUS`. BigQuery requires `UNION DISTINCT` / `EXCEPT DISTINCT` (or `ALL` variants). MySQL supports `INTERSECT`/`EXCEPT` from 8.0.31 (older versions must emulate them with joins/`NOT EXISTS`). Snowflake, Postgres and SQL Server support all four. `INTERSECT ALL` / `EXCEPT ALL` (keeping duplicate counts) exist in Postgres and a few others.

### IN vs EXISTS vs JOIN (existence checks)

| Need | Tool | Notes |
|------|------|-------|
| Columns from both tables | `JOIN` | Can multiply rows if the right side has duplicates |
| Rows in A that **have** a match in B | `EXISTS` / `IN` | Never multiplies rows |
| Rows in A with **no** match in B | `NOT EXISTS` | **NULL-safe**. Preferred |
| Same, using a join | `LEFT JOIN ... WHERE b.key IS NULL` | Fine, equivalent to `NOT EXISTS` |
| Same, using `NOT IN` | **Avoid** | Returns **no rows** if the subquery contains any NULL |

Why `NOT IN` fails: `x NOT IN (2, NULL, 7)` means `x<>2 AND x<>NULL AND x<>7`. `x<>NULL` is UNKNOWN, so the whole predicate can never be TRUE.

Performance: in modern optimizers `IN` and `EXISTS` usually become the same semi-join plan. `EXISTS` can stop at the first match. Correctness (NULL handling) is the real differentiator.

---

## 2. What Interviewers Look For

- Do you know `UNION` vs `UNION ALL` (and default to `UNION ALL` unless dedupe is needed)?
- Can you use `EXCEPT`/`INTERSECT` for reconciliation and "in A but not in B" questions?
- Do you know set operators treat NULLs as equal while joins do not?
- Do you avoid the `NOT IN` + NULL trap and prefer `NOT EXISTS`?
- Can you compare two tables in **both** directions (symmetric difference) for data validation?
- Do you know the dialect differences (`MINUS`, `EXCEPT DISTINCT`, older MySQL)?

---

## 3. Sample Data

Run [`07-set-operations-setup.sql`](./07-set-operations-setup.sql) to create these tables.

**users_jan**

| user_id | name |
|---|---|
| 1 | Asha |
| 2 | Ravi |
| 3 | Meera |
| 4 | John |
| 5 | Priya |

**users_feb**

| user_id | name |
|---|---|
| 3 | Meera |
| 4 | John |
| 4 | John |
| 6 | Kiran |
| 7 | Neha |

No primary key: user 4 (John) appears twice on purpose.

**blocked_users**

| user_id |
|---|
| 2 |
| NULL |
| 7 |

Contains a NULL on purpose (the classic `NOT IN` trap).

**src_orders**

| order_id | amount |
|---|---|
| 1 | 100 |
| 2 | 200 |
| 3 | 300 |
| 4 | 400 |
| 5 | 500 |

Source system.

**tgt_orders**

| order_id | amount |
|---|---|
| 1 | 100 |
| 2 | 250 |
| 3 | 300 |
| 5 | 500 |
| 6 | 600 |

Target after a load: order 2 has a different amount, order 4 is missing, order 6 is extra.

---

## 4. Examples with Explanations

### 4.1 UNION vs UNION ALL
```sql
SELECT user_id, name FROM users_jan
UNION
SELECT user_id, name FROM users_feb
ORDER BY user_id;
```

**Result:**

| user_id | name |
|---|---|
| 1 | Asha |
| 2 | Ravi |
| 3 | Meera |
| 4 | John |
| 5 | Priya |
| 6 | Kiran |
| 7 | Neha |

7 distinct users. Change `UNION` to `UNION ALL` and you get 10 rows (5 + 5), including the duplicated John.

### 4.2 INTERSECT: users present in both months
```sql
SELECT user_id, name FROM users_jan
INTERSECT
SELECT user_id, name FROM users_feb
ORDER BY user_id;
```

**Result:**

| user_id | name |
|---|---|
| 3 | Meera |
| 4 | John |

John appears once even though users_feb has him twice, because `INTERSECT` removes duplicates.

### 4.3 EXCEPT: in January but not in February (churned users)
```sql
SELECT user_id, name FROM users_jan
EXCEPT
SELECT user_id, name FROM users_feb
ORDER BY user_id;
```

**Result:**

| user_id | name |
|---|---|
| 1 | Asha |
| 2 | Ravi |
| 5 | Priya |

Swap the two queries to get new users instead. `EXCEPT` is not symmetric.

### 4.4 The same result using NOT EXISTS (works in every engine, including old MySQL)
```sql
SELECT j.user_id, j.name
FROM users_jan j
WHERE NOT EXISTS (SELECT 1 FROM users_feb f WHERE f.user_id = j.user_id)
ORDER BY j.user_id;
```

**Result:**

| user_id | name |
|---|---|
| 1 | Asha |
| 2 | Ravi |
| 5 | Priya |

Difference from `EXCEPT`: this compares only `user_id`, while `EXCEPT` compares every selected column and de-duplicates the result.

### 4.5 The NOT IN trap: a single NULL wipes out the result
```sql
SELECT user_id, name
FROM users_jan
WHERE user_id NOT IN (SELECT user_id FROM blocked_users);
```

**Result:**

| user_id | name |
|---|---|

*(0 rows returned)*

`blocked_users` contains a NULL, so the result is **empty**, even though users 1, 3, 4 and 5 are not blocked. A missing row and no error message: one of the nastiest silent bugs in SQL.

### 4.6 The fixes: NOT EXISTS or filter the NULL
```sql
SELECT j.user_id, j.name
FROM users_jan j
WHERE NOT EXISTS (SELECT 1 FROM blocked_users b WHERE b.user_id = j.user_id)
ORDER BY j.user_id;
```

**Result:**

| user_id | name |
|---|---|
| 1 | Asha |
| 3 | Meera |
| 4 | John |
| 5 | Priya |

`NOT EXISTS` never sees the NULL as a match. The alternative is `NOT IN (SELECT user_id FROM blocked_users WHERE user_id IS NOT NULL)`.

### 4.7 NULLs are equal in set operators (but not in joins)
```sql
SELECT NULL AS x
INTERSECT
SELECT NULL AS x;
```

**Result:**

| x |
|---|
| NULL |

Returns one row with NULL. An equality join on two NULLs would return no match.

### 4.8 Row count sanity check: UNION vs UNION ALL
```sql
SELECT
  (SELECT COUNT(*) FROM (SELECT user_id FROM users_jan UNION     SELECT user_id FROM users_feb) u)  AS union_rows,
  (SELECT COUNT(*) FROM (SELECT user_id FROM users_jan UNION ALL SELECT user_id FROM users_feb) ua) AS union_all_rows;
```

**Result:**

| union_rows | union_all_rows |
|---|---|
| 7 | 10 |

A quick way to detect overlaps or duplicates between two sources.

### 4.9 Symmetric difference: rows in exactly one of the two tables
```sql
SELECT * FROM (SELECT user_id, name FROM users_jan EXCEPT SELECT user_id, name FROM users_feb) a
UNION ALL
SELECT * FROM (SELECT user_id, name FROM users_feb EXCEPT SELECT user_id, name FROM users_jan) b
ORDER BY user_id;
```

**Result:**

| user_id | name |
|---|---|
| 1 | Asha |
| 2 | Ravi |
| 5 | Priya |
| 6 | Kiran |
| 7 | Neha |

Standard reconciliation pattern. Zero rows means the two tables are identical (as sets).

---

## 5. Interview Questions and Answers

### Basic

**Q1. Difference between UNION and UNION ALL?**
`UNION` removes duplicate rows (extra sort or hash step, slower). `UNION ALL` keeps all rows and is faster. Use `UNION ALL` unless you truly need de-duplication, especially when the inputs are known to be disjoint.

**Q2. What are the rules for using set operators?**
Same number of columns, compatible data types by position, column names from the first query, one final `ORDER BY`. NULLs are treated as equal for de-duplication and matching.

**Q3. What do INTERSECT and EXCEPT do?**
`INTERSECT` returns rows that appear in both queries. `EXCEPT` (`MINUS` in Oracle) returns rows in the first query that do not appear in the second. Both return distinct rows.

**Q4. Is `A EXCEPT B` the same as `B EXCEPT A`?**
No. Order matters. The union of both directions is the symmetric difference.

**Q5. What is the difference between JOIN and UNION?**
JOIN combines tables horizontally using a key (more columns). UNION stacks results vertically (more rows) and requires matching column structure.

### Intermediate

**Q6. IN vs EXISTS: what is the difference?**
`IN` compares a value against a list produced by a subquery. `EXISTS` checks whether the correlated subquery returns any row. Modern optimizers often produce the same semi-join plan. The critical differences are NULL handling (especially `NOT IN` vs `NOT EXISTS`) and readability for multi-column conditions (`EXISTS` handles composite keys naturally).

**Q7. Why does `NOT IN` return no rows when the subquery has a NULL?**
`x NOT IN (a, b, NULL)` expands to `x<>a AND x<>b AND x<>NULL`. The last comparison is UNKNOWN, so the predicate is never TRUE. Use `NOT EXISTS`, or add `WHERE col IS NOT NULL` in the subquery.

**Q8. Can `EXCEPT` be rewritten without `EXCEPT`? What are the differences?**
Yes: `NOT EXISTS` or `LEFT JOIN ... IS NULL` on the key columns. Differences: `EXCEPT` compares **all selected columns**, removes duplicates and treats NULLs as equal. `NOT EXISTS` compares only the columns you put in the predicate, keeps duplicates from the left table, and needs explicit NULL-safe comparison (`IS NOT DISTINCT FROM`) if NULL keys should match.

**Q9. How do you compare two tables to check that a migration is correct?**
Row counts, aggregates per column (sums, null counts, min/max), then `EXCEPT` in both directions on the full row (or on a hash of the row for wide tables). If both are empty the tables match. To locate the differences by key, do a full outer join on the primary key and classify: missing in target, extra in target, value mismatch.

**Q10. What is the precedence when mixing UNION, INTERSECT and EXCEPT?**
`INTERSECT` is evaluated before `UNION` and `EXCEPT` (in the SQL standard and Postgres, SQL Server, Oracle); the others are left to right. Do not rely on it: use parentheses.

**Q11. How do you order the result of a UNION?**
Put a single `ORDER BY` after the last query, referring to output column names (from the first query) or positions.

**Q12. How can `UNION ALL` be used to unpivot or to combine partitioned tables?**
Stack the same columns from monthly/sharded tables (`sales_2023 UNION ALL sales_2024`), adding a literal column like `'2023' AS source` to preserve the origin. Also useful to "unpivot": `SELECT id, 'q1' AS quarter, q1 AS amount FROM t UNION ALL SELECT id, 'q2', q2 FROM t ...` (or the native `UNPIVOT`).

### Advanced

**Q13. Performance of UNION (distinct) on huge tables?**
It must hash or sort the full combined output to remove duplicates, spilling to disk when large. Avoid it if inputs are already distinct or disjoint. If you need dedupe, dedupe on a narrow key or use `ROW_NUMBER` to keep the right record, rather than deduping whole wide rows.

**Q14. What happens when the column types differ between the two queries?**
The engine applies implicit type coercion by precedence (for example `INT` and `DECIMAL` become `DECIMAL`), or raises an error for incompatible types (date vs int). Cast explicitly to avoid surprises (for example `'001'` and `1` merging incorrectly).

**Q15. How would you implement a symmetric difference in MySQL 5.7 (no EXCEPT/INTERSECT/FULL JOIN)?**
`(SELECT ... FROM a WHERE NOT EXISTS (...b...)) UNION ALL (SELECT ... FROM b WHERE NOT EXISTS (...a...))`, using only the supported constructs.

**Q16. How do you write a NULL-safe "not in" on composite keys?**
`NOT EXISTS (SELECT 1 FROM b WHERE b.k1 = a.k1 AND b.k2 = a.k2)`. If NULL keys should match each other, use `IS NOT DISTINCT FROM` (Postgres, Snowflake) or `<=>` (MySQL).

**Q17. Why might `INTERSECT` be preferable to an `INNER JOIN` for finding common rows?**
It compares all columns, ignores column-name mismatches, treats NULLs as equal and returns distinct rows without you writing every join predicate. A join is better when you need extra columns or when duplicates and counts matter.

**Q18. What are `MERGE` and how does it relate?**
`MERGE` (upsert) combines an insert, update and delete in one statement by matching a source to a target on a key. It is the write-side counterpart of the "in source not in target / in both / in target not in source" classification you do with set operations, and it is the core of incremental loads and SCD handling.

---

## 6. Practice Problems

### How to practice (write, run, test, then look at the solution)

1. **Set up the data.** Run [`07-set-operations-setup.sql`](./07-set-operations-setup.sql) in any database (Postgres, Snowflake, MySQL, SQLite, or an online tool such as DB Fiddle).
2. **Write your own query** for the problem.
3. **Compare with the Expected Output** under each problem.
4. **Run the self-check query** (template below). **0 rows returned = correct.**
5. Only then open the **Solution**.

### Self-check template

```sql
WITH my_answer AS (
    -- paste YOUR query here (example below is the solution to P1)
    SELECT user_id, name FROM users_jan
    INTERSECT
    SELECT user_id, name FROM users_feb
),
expected (user_id, name) AS (
    VALUES (3, 'Meera'),
           (4, 'John')
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

### P1. Users who were active in **both** January and February.

Return `user_id` and `name`, ordered by `user_id`. Use `INTERSECT`.

**Expected output (order matters):**

| user_id | name |
|---|---|
| 3 | Meera |
| 4 | John |

<details><summary>Solution</summary>

```sql
SELECT user_id, name FROM users_jan
INTERSECT
SELECT user_id, name FROM users_feb
ORDER BY user_id
```
</details>

### P2. Users who churned: active in January but **not** in February.

Return `user_id` and `name`, ordered by `user_id`. Use `EXCEPT`.

**Expected output (order matters):**

| user_id | name |
|---|---|
| 1 | Asha |
| 2 | Ravi |
| 5 | Priya |

<details><summary>Solution</summary>

```sql
SELECT user_id, name FROM users_jan
EXCEPT
SELECT user_id, name FROM users_feb
ORDER BY user_id
```
Oracle: `MINUS`. Old MySQL: `NOT EXISTS`.
</details>

### P3. New users: active in February but **not** in January.

Return `user_id` and `name`, ordered by `user_id`.

**Expected output (order matters):**

| user_id | name |
|---|---|
| 6 | Kiran |
| 7 | Neha |

<details><summary>Solution</summary>

```sql
SELECT user_id, name FROM users_feb
EXCEPT
SELECT user_id, name FROM users_jan
ORDER BY user_id
```
Note `EXCEPT` also de-duplicates, so a new user loaded twice would appear once.
</details>

### P4. One list of every user seen in either month, with each user appearing once.

Return `user_id` and `name`, ordered by `user_id`.

**Expected output (order matters):**

| user_id | name |
|---|---|
| 1 | Asha |
| 2 | Ravi |
| 3 | Meera |
| 4 | John |
| 5 | Priya |
| 6 | Kiran |
| 7 | Neha |

<details><summary>Solution</summary>

```sql
SELECT user_id, name FROM users_jan
UNION
SELECT user_id, name FROM users_feb
ORDER BY user_id
```
</details>

### P5. Show how many rows `UNION` and `UNION ALL` return when combining the `user_id` columns of both tables.

Return one row with columns `union_rows` and `union_all_rows`.

**Expected output:**

| union_rows | union_all_rows |
|---|---|
| 7 | 10 |

<details><summary>Solution</summary>

```sql
SELECT
  (SELECT COUNT(*) FROM (SELECT user_id FROM users_jan UNION     SELECT user_id FROM users_feb) u)  AS union_rows,
  (SELECT COUNT(*) FROM (SELECT user_id FROM users_jan UNION ALL SELECT user_id FROM users_feb) ua) AS union_all_rows
```
10 - 7 = 3 rows are duplicates: users 3 and 4 appear in both months (2 rows lost), and user 4 is also duplicated inside `users_feb` (1 more).
</details>

### P6. January users that are **not blocked**, written so that the NULL in `blocked_users` does not break the result.

Return `name`, ordered by `name`. Use `NOT EXISTS`.

**Expected output (order matters):**

| name |
|---|
| Asha |
| John |
| Meera |
| Priya |

<details><summary>Solution</summary>

```sql
SELECT j.name
FROM users_jan j
WHERE NOT EXISTS (SELECT 1 FROM blocked_users b WHERE b.user_id = j.user_id)
ORDER BY j.name
```
The `NOT IN` version returns **zero rows** because the subquery contains a NULL. This is the most common interview trap of this topic.
</details>

### P7. Reconcile `src_orders` (source) with `tgt_orders` (target). Report every problem order with a reason: `MISSING_IN_TARGET`, `EXTRA_IN_TARGET` or `AMOUNT_MISMATCH`.

Return `order_id` and `issue`, ordered by `order_id`.

**Expected output (order matters):**

| order_id | issue |
|---|---|
| 2 | AMOUNT_MISMATCH |
| 4 | MISSING_IN_TARGET |
| 6 | EXTRA_IN_TARGET |

<details><summary>Solution</summary>

```sql
SELECT s.order_id AS order_id,
       CASE WHEN t.order_id IS NULL THEN 'MISSING_IN_TARGET' ELSE 'AMOUNT_MISMATCH' END AS issue
FROM src_orders s
LEFT JOIN tgt_orders t ON t.order_id = s.order_id
WHERE t.order_id IS NULL OR s.amount <> t.amount
UNION ALL
SELECT t.order_id, 'EXTRA_IN_TARGET'
FROM tgt_orders t
LEFT JOIN src_orders s ON s.order_id = t.order_id
WHERE s.order_id IS NULL
ORDER BY order_id
```
With `FULL OUTER JOIN` on `order_id` the same report needs one query. This version also works in engines without full outer joins (MySQL). If `amount` can be NULL, use a NULL-safe comparison (`IS DISTINCT FROM`).
</details>

### P8. Find users who have more than one record in `users_feb` (duplicates in a table without a primary key).

Return `user_id` and `records`.

**Expected output:**

| user_id | records |
|---|---|
| 4 | 2 |

<details><summary>Solution</summary>

```sql
SELECT user_id, COUNT(*) AS records
FROM users_feb
GROUP BY user_id
HAVING COUNT(*) > 1
```
</details>

### P9. Users active in **exactly one** of the two months (symmetric difference).

Return `user_id` and `name`, ordered by `user_id`.

**Expected output (order matters):**

| user_id | name |
|---|---|
| 1 | Asha |
| 2 | Ravi |
| 5 | Priya |
| 6 | Kiran |
| 7 | Neha |

<details><summary>Solution</summary>

```sql
SELECT user_id, name FROM (SELECT user_id, name FROM users_jan EXCEPT SELECT user_id, name FROM users_feb) a
UNION
SELECT user_id, name FROM (SELECT user_id, name FROM users_feb EXCEPT SELECT user_id, name FROM users_jan) b
ORDER BY user_id
```
</details>

---

## 7. Common Mistakes

1. Using `UNION` when `UNION ALL` is enough (slow, needless de-duplication).
2. Using `UNION ALL` when duplicates are not wanted (inflated counts).
3. Mismatched column order or types between the two queries (matching is by position).
4. Using `NOT IN` against a nullable column.
5. Assuming `EXCEPT` is symmetric.
6. Putting `ORDER BY` inside individual queries of a `UNION` (only allowed once at the end).
7. Forgetting that set operators treat NULLs as equal while joins do not.
8. Using `EXCEPT` on wide tables with float/timestamp columns, so tiny differences create false mismatches.
9. Expecting `EXCEPT`/`INTERSECT` to preserve duplicates (they do not).
10. Assuming every database supports `EXCEPT`/`INTERSECT`/`FULL JOIN` (old MySQL does not).

---

## 8. Quick Revision Notes

- `UNION` = distinct, `UNION ALL` = keep everything (faster).
- `INTERSECT` = in both. `EXCEPT`/`MINUS` = in first, not in second. Not symmetric.
- Same column count, compatible types, matched by position, names from the first query, one final `ORDER BY`.
- Set operators treat NULLs as equal. Joins and `=` do not.
- Existence: `EXISTS` / `IN`. Non-existence: `NOT EXISTS` (never `NOT IN` on nullable columns).
- Reconciliation: count rows, compare aggregates, `EXCEPT` in both directions, classify differences by key.
- Dialects: Oracle `MINUS`, BigQuery `EXCEPT DISTINCT`, MySQL < 8.0.31 has no `INTERSECT`/`EXCEPT`.
- `MERGE` is the write-side twin: match source and target by key to insert, update, delete.

---

**Previous topic:** [06 - Data Cleaning](./06-data-cleaning.md)
**Next topic:** [08 - Query Optimization](./08-query-optimization.md)
