# 08 - Query Optimization (Indexes, Execution Plans, Partitioning)

> Level: Data Engineer, 5 years experience. Expect "this query is slow, what do you do?" Answer with a method: plan, sargability, indexes/partitions, rewrite, measure.

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

> The data here is tiny, so every query is fast. The **rewrite patterns** are what matter: the same results, but a plan that scales to billions of rows. Check timing and plans on your real engine with `EXPLAIN`.

### The optimization mindset

1. **Measure first.** Read the execution plan (`EXPLAIN`) and look at rows scanned, bytes scanned, join types, spills, and skew. Do not guess.
2. **Reduce data early.** Filter rows and select columns as early as possible, so later steps (joins, sorts, aggregates) handle less.
3. **Help the optimizer use indexes / partitions.** Write predicates it can use (**sargable**).
4. **Avoid work you do not need.** Unneeded `DISTINCT`, `ORDER BY`, `SELECT *`, repeated subqueries.
5. **Know your engine.** Row stores (Postgres, MySQL, SQL Server) optimize with indexes. Columnar warehouses (Snowflake, BigQuery, Redshift) optimize with partition pruning, clustering, and by scanning fewer columns.

### Reading an execution plan

| Engine | How to see the plan |
|--------|---------------------|
| Postgres | `EXPLAIN (ANALYZE, BUFFERS) <query>` |
| MySQL 8 | `EXPLAIN ANALYZE <query>` |
| SQL Server | Actual Execution Plan in SSMS, or `SET STATISTICS IO, TIME ON` |
| Oracle | `EXPLAIN PLAN FOR ...` then `DBMS_XPLAN.DISPLAY` |
| Snowflake | `EXPLAIN <query>` and the **Query Profile** (look for partitions scanned vs total, spilling) |
| BigQuery | Execution details tab (bytes processed, slot time, shuffle) and dry-run estimates |
| SQLite | `EXPLAIN QUERY PLAN <query>` |

What to look for: **full scans** on big tables, **row estimates vs actual rows** (stale statistics), expensive **sorts**, **nested loop** joins over large inputs, **spilling to disk**, and one worker doing most of the work (**skew**).

### Sargability (search-ARGument-able)

A predicate is **sargable** if the engine can use an index or partition pruning for it. Wrapping the column in a function usually destroys that.

| Non-sargable (slow) | Sargable rewrite |
|---------------------|------------------|
| `WHERE YEAR(order_date) = 2024` | `WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'` |
| `WHERE SUBSTR(code, 1, 3) = 'ABC'` | `WHERE code LIKE 'ABC%'` |
| `WHERE amount + 10 > 100` | `WHERE amount > 90` |
| `WHERE LOWER(email) = 'a@x.com'` | Store normalized email, or use a function-based index |
| `WHERE name LIKE '%son'` | Leading wildcard cannot use a B-tree index. Consider full-text/trigram search |
| `WHERE varchar_col = 123` | Compare with the same type (`= '123'`) to avoid implicit casts |

### Indexes (row stores)

- **B-tree index**: speeds up equality, range, `ORDER BY`, and joins. Costs storage and slows writes.
- **Composite index** `(a, b, c)`: usable for filters on `a`, `a,b`, `a,b,c` (the **leftmost prefix**), not for `b` alone. Put equality columns first, then the range column.
- **Covering index**: contains every column the query needs, so the table is never touched (index-only scan). Use `INCLUDE` columns (Postgres 11+, SQL Server).
- **Selectivity matters**: an index on a low-cardinality column (a boolean/status with 3 values) rarely helps. High-cardinality columns are good candidates.
- **Partial/filtered index** covers only some rows (`WHERE status = 'pending'`).

### Warehouse / big data optimizations

| Technique | Idea |
|-----------|------|
| **Partitioning** | Physically split a table by a column (usually date). Queries filtering on it read only the needed partitions (**partition pruning**). |
| **Clustering / sort keys** | Order data within partitions (Snowflake clustering keys, BigQuery clustering, Redshift sort keys) so filters skip blocks. |
| **Columnar storage** | Only the columns you `SELECT` are read, so `SELECT *` is expensive. |
| **Pre-aggregation / materialized views** | Compute heavy aggregates once and reuse. |
| **Join strategy** | Broadcast small tables, avoid shuffling big ones, pick a good distribution key (Redshift `DISTKEY`), watch skew. |
| **Incremental processing** | Process only new/changed partitions, not the whole table. |
| **File layout** (data lakes) | Right-sized Parquet files (128MB to 1GB), avoid millions of tiny files. |

### Common query rewrites

1. Function on a column in `WHERE` -> range predicate on the raw column.
2. Correlated subquery per row -> join with a pre-aggregated derived table, or a window function.
3. `SELECT DISTINCT` after a join to test existence -> `EXISTS`.
4. Filter in `HAVING` that could be in `WHERE` -> move it to `WHERE`.
5. `OR` across different columns -> `UNION ALL` of two selective queries (only when it helps; check the plan).
6. `SELECT *` -> list the needed columns.
7. `OFFSET n` pagination on big tables -> keyset pagination (`WHERE id > last_seen ORDER BY id LIMIT n`).
8. Joining first then aggregating -> aggregate first to the join grain, then join.
9. `COUNT(DISTINCT)` on huge data -> approximate distinct or pre-aggregation.
10. `NOT IN` -> `NOT EXISTS`.

---

## 2. What Interviewers Look For

- Do you start by **reading the execution plan** rather than guessing?
- Do you know **sargability** and can you rewrite a non-sargable predicate?
- Do you understand indexes (composite order, covering, selectivity, write cost)?
- Do you know **partition pruning**, clustering and columnar scan costs in warehouses (Snowflake / BigQuery / Redshift)?
- Can you list several concrete rewrites (correlated subquery, `DISTINCT` misuse, `OR`, `OFFSET` paging)?
- Do you consider **data skew, spills and join strategy** for distributed engines?
- Do you validate that an optimized rewrite returns **identical results**?

---

## 3. Sample Data

Run [`08-query-optimization-setup.sql`](./08-query-optimization-setup.sql) to create these tables.

**customers**

| customer_id | name | city |
|---|---|---|
| 1 | Anil | Hyderabad |
| 2 | Bina | Chennai |
| 3 | Chetan | Hyderabad |
| 4 | Divya | Mumbai |
| 5 | Esha | Chennai |

**orders**

| order_id | customer_id | order_date | status | amount |
|---|---|---|---|---|
| 1 | 1 | 2023-11-15 | completed | 500 |
| 2 | 1 | 2024-01-05 | completed | 300 |
| 3 | 2 | 2024-01-20 | completed | 700 |
| 4 | 2 | 2024-02-11 | cancelled | 150 |
| 5 | 3 | 2024-02-18 | completed | 400 |
| 6 | 1 | 2024-03-02 | completed | 250 |
| 7 | 4 | 2024-03-09 | completed | 900 |
| 8 | 5 | 2024-03-15 | pending | 120 |
| 9 | 3 | 2024-03-28 | completed | 350 |
| 10 | 2 | 2024-04-04 | completed | 600 |
| 11 | 1 | 2024-04-19 | returned | 200 |
| 12 | 4 | 2023-12-24 | completed | 800 |

Two indexes are created by the setup script: `idx_orders_customer` and `idx_orders_date`.

---

## 4. Examples with Explanations

### 4.1 Sargable vs non-sargable date filter (same result)
```sql
-- Non-sargable: the function hides the column from the index / partition pruning
SELECT order_id, order_date
FROM orders
WHERE SUBSTR(order_date, 1, 4) = '2024'
ORDER BY order_id;
```

**Result:**

| order_id | order_date |
|---|---|
| 2 | 2024-01-05 |
| 3 | 2024-01-20 |
| 4 | 2024-02-11 |
| 5 | 2024-02-18 |
| 6 | 2024-03-02 |
| 7 | 2024-03-09 |
| 8 | 2024-03-15 |
| 9 | 2024-03-28 |
| 10 | 2024-04-04 |
| 11 | 2024-04-19 |

Correct, but the engine must compute `SUBSTR` for every row. See the next example for the fast version.

### 4.2 The sargable rewrite
```sql
SELECT order_id, order_date
FROM orders
WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'
ORDER BY order_id;
```

**Result:**

| order_id | order_date |
|---|---|
| 2 | 2024-01-05 |
| 3 | 2024-01-20 |
| 4 | 2024-02-11 |
| 5 | 2024-02-18 |
| 6 | 2024-03-02 |
| 7 | 2024-03-09 |
| 8 | 2024-03-15 |
| 9 | 2024-03-28 |
| 10 | 2024-04-04 |
| 11 | 2024-04-19 |

Identical output, but the engine can seek directly into the index on `order_date`, or prune partitions in a warehouse. A half-open range also works correctly for timestamps.

### 4.3 Look at a plan (SQLite syntax, other engines use EXPLAIN)
```sql
EXPLAIN QUERY PLAN
SELECT order_id, amount
FROM orders
WHERE customer_id = 1;
```

**Result:**

| id | parent | notused | detail |
|---|---|---|---|
| 3 | 0 | 0 | SEARCH orders USING INDEX idx_orders_customer (customer_id=?) |

The plan shows a `SEARCH ... USING INDEX idx_orders_customer` rather than a full `SCAN`. The setup script created that index. Drop the index and re-run to see the difference. Also try the `SUBSTR(order_date, 1, 4) = '2024'` query and notice it cannot use `idx_orders_date`.

### 4.4 Correlated subquery in SELECT vs join to a pre-aggregated table
```sql
-- Slow pattern: logically one subquery execution per customer
SELECT c.name,
       (SELECT SUM(o.amount) FROM orders o
        WHERE o.customer_id = c.customer_id AND o.status = 'completed') AS total_completed
FROM customers c
ORDER BY c.name;
```

**Result:**

| name | total_completed |
|---|---|
| Anil | 1050 |
| Bina | 1300 |
| Chetan | 750 |
| Divya | 1700 |
| Esha | NULL |

Works, and modern optimizers may decorrelate it, but you cannot count on it. The join version in problem P2 is explicit and predictable.

### 4.5 Composite index: column order matters (concept, not run)
```sql
-- Query
SELECT order_id FROM orders WHERE customer_id = 1 AND order_date >= '2024-01-01';

-- Good: equality column first, then the range column
CREATE INDEX idx_cust_date ON orders (customer_id, order_date);

-- The same index helps `WHERE customer_id = 1` alone (leftmost prefix)
-- but NOT `WHERE order_date >= '2024-01-01'` alone.
```

Rule of thumb: equality predicates first, range predicate last, and consider `INCLUDE (amount)` to make it covering.

### 4.6 Keyset pagination instead of OFFSET (concept, not run)
```sql
-- Slow for deep pages: the engine reads and discards 100000 rows
SELECT * FROM orders ORDER BY order_id LIMIT 50 OFFSET 100000;

-- Fast: remember the last id from the previous page
SELECT * FROM orders WHERE order_id > :last_seen_id ORDER BY order_id LIMIT 50;
```

Keyset pagination needs a unique, indexed sort key. Its cost stays flat regardless of page depth.

### 4.7 Partition pruning in a warehouse (concept, not run)
```sql
-- BigQuery: table partitioned by DATE(order_ts), clustered by customer_id
SELECT customer_id, SUM(amount)
FROM sales.orders
WHERE order_ts >= TIMESTAMP('2024-03-01') AND order_ts < TIMESTAMP('2024-04-01')   -- prunes to 1 month
GROUP BY customer_id;
-- Wrapping order_ts in a function (e.g. FORMAT_TIMESTAMP(...)) in the WHERE clause can defeat pruning.
```

In BigQuery you pay for **bytes scanned**, in Snowflake for **warehouse time**. In both, pruning and selecting fewer columns are the cheapest wins.

---

## 5. Interview Questions and Answers

### Basic

**Q1. How do you find out why a query is slow?**
Look at the execution plan (`EXPLAIN`, Query Profile, actual plan in SSMS). Check rows scanned vs returned, full table scans, join types and order, sorts, spills to disk, and estimate vs actual row counts. Then confirm with timing/IO statistics before and after any change.

**Q2. What is an index and what are its trade-offs?**
A sorted data structure (usually B-tree) that lets the engine find rows without scanning the table. It speeds up reads (filters, joins, sorts) but uses storage and slows `INSERT/UPDATE/DELETE`, because every index must be maintained.

**Q3. What does "sargable" mean?**
A predicate that lets the engine use an index or partition pruning. Applying functions or arithmetic to the indexed column (`YEAR(col) = 2024`) usually makes it non-sargable. Rewrite as a range on the raw column.

**Q4. Why is `SELECT *` discouraged?**
It reads unneeded columns (a large cost in columnar storage), prevents covering-index use, sends more data over the network, and breaks when the schema changes.

**Q5. What is the difference between a clustered and non-clustered index?**
A clustered index defines the physical order of the table rows (one per table, often the primary key in SQL Server/InnoDB). A non-clustered index is a separate structure with pointers back to the rows (many allowed).

### Intermediate

**Q6. Explain composite index column ordering.**
The index can be used for the leftmost prefix of its columns. For `(a, b, c)` filters on `a`, `a,b`, and `a,b,c` benefit; a filter on `b` alone does not. Put equality columns first, the range column after, and high-selectivity columns early. Include extra columns to make it covering.

**Q7. When would an index NOT be used?**
Non-sargable predicates, a leading wildcard (`LIKE '%x'`), implicit type conversion, a filter matching a large fraction of the table (a scan is cheaper), tiny tables, stale statistics, or a function on the column without a matching function-based index.

**Q8. What is a covering index?**
An index containing all columns a query needs (filter, join, and select columns), so the engine answers from the index alone (index-only scan) without touching the table.

**Q9. Nested loop vs hash join vs merge join, and when does each win?**
Nested loop: small outer input with an indexed inner lookup. Hash join: large unsorted inputs with an equality join, needs memory. Merge join: both inputs already sorted (or cheap to sort), also good for range-ish joins. The optimizer chooses from statistics, so stale stats lead to bad plans (`ANALYZE`/`UPDATE STATISTICS`).

**Q10. How does `EXISTS` compare with `IN` and `JOIN + DISTINCT` for performance?**
`EXISTS` and `IN` typically become the same semi-join and can stop at the first match. `JOIN + DISTINCT` builds the whole join and then sorts/hashes to de-duplicate, so it is usually worse. Use `EXISTS` for existence checks.

**Q11. Why can `OR` conditions be slow and what can you do?**
`OR` across different columns can prevent a single index from covering both branches, causing a scan. Options: rewrite as `UNION ALL` of two indexed queries (ensuring no overlap), use index-merge if the engine supports it, or restructure the data. Always confirm with the plan; do not rewrite blindly.

**Q12. Why is `OFFSET` pagination slow, and what is the alternative?**
The engine must generate and discard all skipped rows, so cost grows with the offset. Use keyset (seek) pagination based on the last seen unique sorted key.

**Q13. What does `ORDER BY` cost and how do you avoid it?**
A sort is O(n log n), memory heavy and may spill. Avoid ordering in subqueries and intermediate CTEs that do not need it, use an index that already provides the order, or `LIMIT` with top-N heapsort. Do not `ORDER BY` unless the consumer needs ordering.

### Advanced

**Q14. How do you optimize a query in Snowflake or BigQuery (columnar warehouse)?**
Select only needed columns, filter on partition/cluster columns to enable pruning, avoid functions on those columns, avoid `SELECT *` and cross joins, pre-aggregate large joins, use `QUALIFY`/window instead of self-joins, cache/materialize repeated heavy logic, right-size the warehouse (Snowflake) or watch slot usage and bytes billed (BigQuery). Check the Query Profile for spilling and partitions scanned vs total.

**Q15. What is partitioning vs clustering vs indexing?**
Partitioning splits data into separate physical units by a key (coarse pruning, easy data lifecycle management). Clustering/sort keys order data within partitions to skip blocks (fine-grained pruning). Indexes are separate lookup structures for row stores. Warehouses generally rely on partitioning and clustering, not B-tree indexes.

**Q16. What is data skew and how does it hurt a join or aggregation?**
When a few key values contain most rows (for example `NULL` or a default id), one worker processes far more data than the others and the job waits on it. Mitigate by filtering or isolating hot keys, salting keys, broadcasting the small side, or using engines with adaptive skew handling.

**Q17. Explain statistics and why an outdated plan may be chosen.**
The optimizer estimates row counts and selectivity from statistics (histograms, distinct counts). If statistics are stale (after a big load), it may choose a nested loop for millions of rows or the wrong join order. Refresh statistics (`ANALYZE`, `UPDATE STATISTICS`) and check estimated vs actual rows.

**Q18. How would you speed up a dashboard query that aggregates 5 billion rows every time?**
Pre-aggregate incrementally into a summary/rollup table or materialized view at the grain the dashboard needs, partition by date, process only new partitions, cache results, and possibly approximate metrics (`APPROX_COUNT_DISTINCT`). Move heavy joins upstream into the modeled layer (data warehouse), not in the BI query.

**Q19. What are the risks of over-indexing?**
Slower writes and bulk loads, extra storage, more maintenance, and index bloat. Warehouses avoid it by design. Use indexes for proven access patterns and drop unused ones (check usage statistics).

**Q20. Denormalization for performance. When is it justified?**
When read-heavy analytics repeatedly join the same large tables, pre-joining into wide tables (or star-schema fact tables) trades storage and update complexity for far fewer joins at query time. Keep the normalized source of truth and rebuild the denormalized layer by pipeline.

---

## 6. Practice Problems

### How to practice (write, run, test, then look at the solution)

1. **Set up the data.** Run [`08-query-optimization-setup.sql`](./08-query-optimization-setup.sql) in any database (Postgres, Snowflake, MySQL, SQLite, or an online tool such as DB Fiddle).
2. **Write your own query** for the problem.
3. **Compare with the Expected Output** under each problem.
4. **Run the self-check query** (template below). **0 rows returned = correct.**
5. Only then open the **Solution**.

### Self-check template

```sql
WITH my_answer AS (
    -- paste YOUR query here (example below is the solution to P1)
    SELECT order_id, order_date
    FROM orders
    WHERE order_date >= '2024-01-01'
      AND order_date <  '2025-01-01'
),
expected (order_id, order_date) AS (
    VALUES (2, '2024-01-05'),
           (3, '2024-01-20'),
           (4, '2024-02-11'),
           (5, '2024-02-18'),
           (6, '2024-03-02'),
           (7, '2024-03-09'),
           (8, '2024-03-15'),
           (9, '2024-03-28'),
           (10, '2024-04-04'),
           (11, '2024-04-19')
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

### P1. **Rewrite for speed:** list the orders placed in 2024. The slow version is `WHERE SUBSTR(order_date, 1, 4) = '2024'`.

Return `order_id` and `order_date`, ordered by `order_id`. Your version must use a **sargable** predicate on `order_date` and return exactly the same rows.

**Expected output (order matters):**

| order_id | order_date |
|---|---|
| 2 | 2024-01-05 |
| 3 | 2024-01-20 |
| 4 | 2024-02-11 |
| 5 | 2024-02-18 |
| 6 | 2024-03-02 |
| 7 | 2024-03-09 |
| 8 | 2024-03-15 |
| 9 | 2024-03-28 |
| 10 | 2024-04-04 |
| 11 | 2024-04-19 |

<details><summary>Solution</summary>

```sql
SELECT order_id, order_date
FROM orders
WHERE order_date >= '2024-01-01'
  AND order_date <  '2025-01-01'
ORDER BY order_id
```
The half-open range `>= start AND < next_start` is index/partition friendly and safe for timestamps.
</details>

### P2. **Rewrite for speed:** total completed order amount per customer. The slow version uses a correlated subquery in `SELECT`.

```sql
-- slow
SELECT c.name,
       (SELECT SUM(o.amount) FROM orders o
        WHERE o.customer_id = c.customer_id AND o.status = 'completed') AS total_completed
FROM customers c;
```

Return `name` and `total_completed` (NULL for customers with no completed orders), ordered by `name`. Use a join and `GROUP BY`.

**Expected output (order matters):**

| name | total_completed |
|---|---|
| Anil | 1050 |
| Bina | 1300 |
| Chetan | 750 |
| Divya | 1700 |
| Esha | NULL |

<details><summary>Solution</summary>

```sql
SELECT c.name, SUM(o.amount) AS total_completed
FROM customers c
LEFT JOIN orders o
       ON o.customer_id = c.customer_id
      AND o.status = 'completed'      -- filter in ON keeps customers with no completed orders
GROUP BY c.name
ORDER BY c.name
```
Esha only has a pending order, so her total is NULL (matching the original). If you moved the status filter to `WHERE`, Esha would disappear (see Topic 2).
</details>

### P3. **Rewrite for speed:** customers who have at least one cancelled or returned order. The slow version is `SELECT DISTINCT c.name FROM customers c JOIN orders o ON ... WHERE o.status IN ('cancelled','returned')`.

Return `name`, ordered by `name`. Use `EXISTS` instead of join plus `DISTINCT`.

**Expected output (order matters):**

| name |
|---|
| Anil |
| Bina |

<details><summary>Solution</summary>

```sql
SELECT c.name
FROM customers c
WHERE EXISTS (SELECT 1
              FROM orders o
              WHERE o.customer_id = c.customer_id
                AND o.status IN ('cancelled', 'returned'))
ORDER BY c.name
```
`EXISTS` stops at the first matching order and never builds duplicates that `DISTINCT` must then remove.
</details>

### P4. **Rewrite for speed:** total order amount for customers 1 and 2, only if the total exceeds 1000. The slow version filters `customer_id` in `HAVING`.

```sql
-- slow
SELECT customer_id, SUM(amount) AS total
FROM orders
GROUP BY customer_id
HAVING customer_id IN (1, 2) AND SUM(amount) > 1000;
```

Return `customer_id` and `total`, ordered by `customer_id`. Move the row-level filter to `WHERE`.

**Expected output (order matters):**

| customer_id | total |
|---|---|
| 1 | 1250 |
| 2 | 1450 |

<details><summary>Solution</summary>

```sql
SELECT customer_id, SUM(amount) AS total
FROM orders
WHERE customer_id IN (1, 2)
GROUP BY customer_id
HAVING SUM(amount) > 1000
ORDER BY customer_id
```
Filter rows **before** grouping. Many optimizers push this down automatically, but do not rely on it.
</details>

### P5. **Rewrite for speed:** orders that belong to customer 4 **or** have status `pending`. The slow version is a single `WHERE customer_id = 4 OR status = 'pending'`.

Return `order_id`, `customer_id`, `status`, ordered by `order_id`. Use `UNION ALL` of two selective queries without creating duplicates.

**Expected output (order matters):**

| order_id | customer_id | status |
|---|---|---|
| 7 | 4 | completed |
| 8 | 5 | pending |
| 12 | 4 | completed |

<details><summary>Solution</summary>

```sql
SELECT order_id, customer_id, status
FROM orders
WHERE customer_id = 4
UNION ALL
SELECT order_id, customer_id, status
FROM orders
WHERE status = 'pending'
  AND customer_id <> 4
ORDER BY order_id
```
The `customer_id <> 4` condition prevents an order matching both branches from appearing twice. If `customer_id` can be NULL use `(customer_id <> 4 OR customer_id IS NULL)`. Only apply this rewrite if the plan shows the `OR` causing a scan.
</details>

### P6. **Rewrite for speed:** the latest order of each customer. The slow version is `WHERE order_date = (SELECT MAX(order_date) FROM orders o2 WHERE o2.customer_id = o.customer_id)`.

Return `customer_id`, `order_id`, `order_date`, ordered by `customer_id`. Use a window function, with `order_id DESC` as tiebreaker.

**Expected output (order matters):**

| customer_id | order_id | order_date |
|---|---|---|
| 1 | 11 | 2024-04-19 |
| 2 | 10 | 2024-04-04 |
| 3 | 9 | 2024-03-28 |
| 4 | 7 | 2024-03-09 |
| 5 | 8 | 2024-03-15 |

<details><summary>Solution</summary>

```sql
WITH ranked AS (
    SELECT customer_id, order_id, order_date,
           ROW_NUMBER() OVER (PARTITION BY customer_id
                              ORDER BY order_date DESC, order_id DESC) AS rn
    FROM orders
)
SELECT customer_id, order_id, order_date
FROM ranked
WHERE rn = 1
ORDER BY customer_id
```
One pass over the table instead of a per-row lookup, and it returns exactly one row per customer even if two orders share the latest date.
</details>

### P7. **Rewrite for speed:** total order amount per city. The slow version joins all order rows to customers first and then aggregates.

Return `city` and `total_amount` (all statuses), ordered by `city`. Aggregate `orders` to one row per customer **before** joining.

**Expected output (order matters):**

| city | total_amount |
|---|---|
| Chennai | 1570 |
| Hyderabad | 2000 |
| Mumbai | 1700 |

<details><summary>Solution</summary>

```sql
WITH cust_totals AS (
    SELECT customer_id, SUM(amount) AS total_amount
    FROM orders
    GROUP BY customer_id
)
SELECT c.city, SUM(t.total_amount) AS total_amount
FROM customers c
JOIN cust_totals t ON t.customer_id = c.customer_id
GROUP BY c.city
ORDER BY c.city
```
The join now has 5 x 5 rows instead of 12 x 5. On real data this shrinks the join input from billions of order rows to millions of customers.
</details>

---

## 7. Common Mistakes

1. Optimizing without reading the plan or measuring.
2. Wrapping indexed / partition columns in functions (`YEAR(date_col) = 2024`).
3. Using `SELECT *` on columnar warehouses (paying for every column).
4. Indexing everything (slow writes) or indexing low-selectivity columns.
5. Wrong composite index order, or expecting `(a, b)` to help a filter on `b` alone.
6. Leading wildcard `LIKE '%text'` on big tables.
7. Implicit type conversion in joins and filters (varchar vs int).
8. `SELECT DISTINCT` to hide duplicate rows created by a bad join.
9. `ORDER BY` in subqueries and CTEs that do not need it.
10. `OFFSET` pagination for deep pages.
11. Ignoring skew: one hot key making a distributed job crawl.
12. Rewriting a query and not checking it still returns identical results.

---

## 8. Quick Revision Notes

- Plan first: `EXPLAIN`, look for scans, sorts, spills, row estimate errors, skew.
- Sargable = no functions on the column. Use ranges, `>= start AND < next_start`.
- Composite index: equality columns first, range last, leftmost-prefix rule, add `INCLUDE` to cover.
- Reduce early: filter rows, select only needed columns, aggregate before joining.
- `EXISTS` beats `JOIN + DISTINCT` for existence. `NOT EXISTS` beats `NOT IN`.
- Correlated subquery -> join to pre-aggregate or window function.
- Keyset pagination instead of `OFFSET`.
- Warehouses: partition pruning, clustering, columnar (fewer columns), pre-aggregation, incremental loads.
- Joins: nested loop (small + indexed), hash (large, memory), merge (sorted). Broadcast small tables. Watch skew.
- Keep statistics fresh. Validate rewrites return identical results.

---

**Previous topic:** [07 - Set Operations, EXISTS vs IN](./07-set-operations.md)
**Next topic:** [09 - Data Modeling](./09-data-modeling.md)
