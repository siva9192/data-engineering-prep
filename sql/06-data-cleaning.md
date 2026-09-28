# 06 - Data Cleaning (NULLs, Dates, Strings, Deduplication)

> Level: Data Engineer, 5 years experience. Every real pipeline cleans data. Interviewers want systematic thinking: profile, standardize, deduplicate, validate, quarantine.

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

Real data is messy. A data engineer's job is to turn raw data into trusted data. The typical toolbox:

### 1. NULL, empty string and sentinel values

`NULL`, `''` (empty string), `'NA'`, `'N/A'`, `'unknown'`, `'0000-00-00'` and `-1` may all mean "missing". They are **different values** to SQL, so standardize them first.

| Tool | Use |
|------|-----|
| `COALESCE(a, b, c)` | First non-NULL value (replace NULL with a default) |
| `NULLIF(a, b)` | Returns NULL if `a = b`, else `a`. Turns `''` into NULL: `NULLIF(TRIM(col), '')` |
| `CASE WHEN ... THEN ... END` | Any custom rule |
| `IS NULL` / `IS NOT NULL` | The only correct NULL tests |

### 2. String cleaning

| Task | Portable function | Notes |
|------|-------------------|-------|
| Trim spaces | `TRIM(col)` | Also `LTRIM`, `RTRIM` |
| Case | `UPPER(col)`, `LOWER(col)` | Standardize before comparing or joining |
| Replace | `REPLACE(col, 'old', 'new')` | Nest for multiple characters |
| Substring | `SUBSTR(col, start, len)` | `SUBSTRING` in Postgres/SQL Server/MySQL |
| Length | `LENGTH(col)` | `LEN` in SQL Server |
| Find position | `INSTR(col, 'x')` | Postgres `POSITION('x' IN col)`, Snowflake `POSITION`/`CHARINDEX`, SQL Server `CHARINDEX('x', col)` |
| Concatenate | `a \|\| b` | `CONCAT(a, b)` in MySQL/SQL Server (CONCAT is NULL-safe in some engines) |
| Proper case | `INITCAP(col)` | Postgres, Snowflake, Oracle, BigQuery. Not in MySQL/SQL Server |
| Regex | `REGEXP_REPLACE`, `REGEXP_LIKE` / `~` | Syntax differs by engine |

### 3. Type casting and safe casting

Landing tables are often all text. Cast to proper types in the next layer, and **never let one bad value fail the whole load**:

| Engine | Safe cast |
|--------|-----------|
| SQL Server, Snowflake | `TRY_CAST(x AS DATE)`, `TRY_TO_DATE(x)` |
| BigQuery | `SAFE_CAST(x AS DATE)` |
| Postgres | no built-in. Validate with a regex/`CASE` first, or a custom function |
| MySQL | invalid dates become NULL/zero with warnings depending on `sql_mode` |

### 4. Dates and times

| Task | Postgres | Snowflake | BigQuery | MySQL | SQL Server |
|------|----------|-----------|----------|-------|------------|
| Truncate to month | `DATE_TRUNC('month', d)` | `DATE_TRUNC('month', d)` | `DATE_TRUNC(d, MONTH)` | `DATE_FORMAT(d, '%Y-%m-01')` | `DATETRUNC(month, d)` (2022+) |
| Add days | `d + INTERVAL '7 days'` | `DATEADD(day, 7, d)` | `DATE_ADD(d, INTERVAL 7 DAY)` | `DATE_ADD(d, INTERVAL 7 DAY)` | `DATEADD(day, 7, d)` |
| Days between | `d2 - d1` | `DATEDIFF(day, d1, d2)` | `DATE_DIFF(d2, d1, DAY)` | `DATEDIFF(d2, d1)` | `DATEDIFF(day, d1, d2)` |
| Extract year | `EXTRACT(YEAR FROM d)` | `EXTRACT(YEAR FROM d)` | `EXTRACT(YEAR FROM d)` | `YEAR(d)` | `YEAR(d)` |
| Time zone convert | `ts AT TIME ZONE 'UTC'` | `CONVERT_TIMEZONE(...)` | `TIMESTAMP(ts, 'zone')` | `CONVERT_TZ(...)` | `AT TIME ZONE` |

Golden rules: store dates as `DATE`/`TIMESTAMP`, not text. Store timestamps in **UTC**. Use half-open ranges (`>= start AND < next_start`). ISO format `YYYY-MM-DD` sorts correctly as text.

### 5. Deduplication patterns

| Pattern | When |
|---------|------|
| `SELECT DISTINCT` | Rows are exact duplicates across all selected columns |
| `GROUP BY` + `MIN/MAX` | Simple keep-one logic |
| `ROW_NUMBER() OVER (PARTITION BY key ORDER BY updated_at DESC)` then `rn = 1` | **Keep the latest row per business key** (the standard answer) |
| `QUALIFY ROW_NUMBER() ... = 1` | Same in Snowflake/BigQuery/Databricks |

### 6. Profile, validate, quarantine

Before cleaning, **profile**: row counts, `COUNT(*)` vs `COUNT(col)` (null rate), `COUNT(DISTINCT key)` vs `COUNT(*)` (duplicates), min/max, value frequencies, pattern checks. After cleaning, **validate** with tests. Send bad rows to a **quarantine/reject table** with a reason instead of silently dropping them.

---

## 2. What Interviewers Look For

- Do you distinguish `NULL`, empty strings and placeholder values, and standardize them consistently?
- Do you know `COALESCE`, `NULLIF`, `TRIM`, `REPLACE`, `SUBSTR`, `CASE` and safe casting?
- Can you **deduplicate keeping the latest record** with `ROW_NUMBER` and explain the tiebreaker?
- Do you clean **before** joining or grouping (case, whitespace) so keys actually match?
- Do you handle dates properly: types, time zones, half-open ranges, invalid values?
- Do you think about **data quality**: profiling, validation rules, quarantine tables, not silently dropping rows?
- Do you know the dialect differences (or say you would check the docs) for date and string functions?

---

## 3. Sample Data

Run [`06-data-cleaning-setup.sql`](./06-data-cleaning-setup.sql) to create these tables.

**stg_customers**

| row_id | full_name | email | phone | signup_date | city | loaded_at |
|---|---|---|---|---|---|---|
| 1 |   asha  rao  | Asha.Rao@Gmail.com  | 98765-43210 | 2024-01-05 | Hyderabad | 2024-01-06 09:00:00 |
| 2 | RAVI KUMAR | ravi@company.com | 9876543211 | 2024-01-10 | hyderabad | 2024-01-11 09:00:00 |
| 3 | meera nair | NULL |  | 2024-02-01 | Chennai  | 2024-02-02 09:00:00 |
| 4 | John Doe | john@gmail.com | (987) 654-3212 |  | Bengaluru | 2024-02-10 09:00:00 |
| 5 | Priya S | priya@yahoo.com | 9876543213 | 2024-13-45 | NA | 2024-02-12 09:00:00 |
| 6 | Asha Rao | asha.rao@gmail.com | 9876543210 | 2024-01-05 | Hyderabad | 2024-03-01 09:00:00 |
| 7 | Kiran | kiran@company.com | 9876543215 | 2024-03-20 | NULL | 2024-03-21 09:00:00 |
| 8 | Ravi Kumar | ravi@company.com | 9876543211 | 2024-01-10 | Hyderabad | 2024-02-15 09:00:00 |

A raw staging table with typical mess: extra spaces, mixed case, blanks, `NA`, invalid dates and duplicate customers loaded at different times.

---

## 4. Examples with Explanations

### 4.1 Profile the raw table (null rate, duplicates)
```sql
SELECT COUNT(*)                                   AS total_rows,
       COUNT(email)                                 AS email_not_null,
       COUNT(DISTINCT LOWER(TRIM(email)))           AS distinct_clean_emails,
       SUM(CASE WHEN TRIM(phone) = '' OR phone IS NULL THEN 1 ELSE 0 END) AS phone_missing,
       SUM(CASE WHEN signup_date = '' THEN 1 ELSE 0 END)                   AS signup_blank
FROM stg_customers;
```

**Result:**

| total_rows | email_not_null | distinct_clean_emails | phone_missing | signup_blank |
|---|---|---|---|---|
| 8 | 7 | 5 | 1 | 1 |

8 rows but only 5 distinct cleaned emails among the 7 non-NULL ones, so duplicates exist. Profiling first tells you which cleaning rules are needed.

### 4.2 NULL vs empty string are different
```sql
SELECT row_id,
       phone,
       phone IS NULL           AS is_null,
       phone = ''              AS is_empty,
       NULLIF(TRIM(phone), '') AS phone_or_null
FROM stg_customers
WHERE row_id IN (3, 4);
```

**Result:**

| row_id | phone | is_null | is_empty | phone_or_null |
|---|---|---|---|---|
| 3 |  | 0 | 1 | NULL |
| 4 | (987) 654-3212 | 0 | 0 | (987) 654-3212 |

Row 3 has an empty string (not NULL), so `phone IS NULL` is false. `NULLIF(TRIM(x), '')` maps blanks to real NULLs. (SQLite shows booleans as 0/1.)

### 4.3 COALESCE for defaults and NULLIF for blanks
```sql
SELECT row_id,
       COALESCE(NULLIF(TRIM(city), ''), 'Unknown') AS city_filled
FROM stg_customers
ORDER BY row_id;
```

**Result:**

| row_id | city_filled |
|---|---|
| 1 | Hyderabad |
| 2 | hyderabad |
| 3 | Chennai |
| 4 | Bengaluru |
| 5 | NA |
| 6 | Hyderabad |
| 7 | Unknown |
| 8 | Hyderabad |

Reads inside out: trim, turn blank into NULL, then replace NULL by a default. Note that `'NA'` in row 5 is still not handled, which is problem P3.

### 4.4 Cleaning emails and extracting the domain
```sql
SELECT row_id,
       LOWER(TRIM(email)) AS email_clean,
       SUBSTR(LOWER(TRIM(email)), INSTR(LOWER(TRIM(email)), '@') + 1) AS domain
FROM stg_customers
WHERE email IS NOT NULL
ORDER BY row_id;
```

**Result:**

| row_id | email_clean | domain |
|---|---|---|
| 1 | asha.rao@gmail.com | gmail.com |
| 2 | ravi@company.com | company.com |
| 4 | john@gmail.com | gmail.com |
| 5 | priya@yahoo.com | yahoo.com |
| 6 | asha.rao@gmail.com | gmail.com |
| 7 | kiran@company.com | company.com |
| 8 | ravi@company.com | company.com |

`INSTR` finds the `@`. On Postgres use `POSITION('@' IN email)` or `SPLIT_PART(email, '@', 2)`; on SQL Server `CHARINDEX('@', email)`; on Snowflake `SPLIT_PART` too.

### 4.5 Validate dates stored as text
```sql
SELECT row_id, signup_date,
       CASE
         WHEN signup_date IS NULL OR TRIM(signup_date) = '' THEN 'missing'
         WHEN CAST(SUBSTR(signup_date, 6, 2) AS INTEGER) BETWEEN 1 AND 12
          AND CAST(SUBSTR(signup_date, 9, 2) AS INTEGER) BETWEEN 1 AND 31 THEN 'valid'
         ELSE 'invalid'
       END AS date_status
FROM stg_customers
ORDER BY row_id;
```

**Result:**

| row_id | signup_date | date_status |
|---|---|---|
| 1 | 2024-01-05 | valid |
| 2 | 2024-01-10 | valid |
| 3 | 2024-02-01 | valid |
| 4 |  | missing |
| 5 | 2024-13-45 | invalid |
| 6 | 2024-01-05 | valid |
| 7 | 2024-03-20 | valid |
| 8 | 2024-01-10 | valid |

This is a simple sanity check. In production use `TRY_CAST` / `SAFE_CAST` / `TRY_TO_DATE`, which reject impossible dates such as Feb 30 as well.

### 4.6 Find duplicates before deleting anything
```sql
SELECT LOWER(TRIM(email)) AS email_clean, COUNT(*) AS copies
FROM stg_customers
WHERE email IS NOT NULL
GROUP BY LOWER(TRIM(email))
HAVING COUNT(*) > 1
ORDER BY email_clean;
```

**Result:**

| email_clean | copies |
|---|---|
| asha.rao@gmail.com | 2 |
| ravi@company.com | 2 |

Note that the two `asha.rao` rows only match **after** `LOWER(TRIM(...))`. Raw `GROUP BY email` would miss them.

### 4.7 Deduplicate: keep the latest row per cleaned email
```sql
WITH ranked AS (
    SELECT s.*,
           ROW_NUMBER() OVER (
               PARTITION BY LOWER(TRIM(email))
               ORDER BY loaded_at DESC, row_id DESC   -- latest wins, row_id is the tiebreaker
           ) AS rn
    FROM stg_customers s
)
SELECT row_id, LOWER(TRIM(email)) AS email_clean, loaded_at
FROM ranked
WHERE rn = 1
ORDER BY row_id;
```

**Result:**

| row_id | email_clean | loaded_at |
|---|---|---|
| 3 | NULL | 2024-02-02 09:00:00 |
| 4 | john@gmail.com | 2024-02-10 09:00:00 |
| 5 | priya@yahoo.com | 2024-02-12 09:00:00 |
| 6 | asha.rao@gmail.com | 2024-03-01 09:00:00 |
| 7 | kiran@company.com | 2024-03-21 09:00:00 |
| 8 | ravi@company.com | 2024-02-15 09:00:00 |

Rows 1 and 2 are dropped because rows 6 and 8 are newer versions of the same customers. Row 3 has a NULL email, so it forms its own NULL partition and is kept. Decide explicitly how to treat rows with a missing key.

---

## 5. Interview Questions and Answers

### Basic

**Q1. Difference between NULL, empty string and 0?**
`NULL` means unknown/missing, `''` is a known string of length zero, and `0` is a number. They compare differently: `NULL = NULL` is UNKNOWN, `'' = ''` is TRUE. Oracle is a special case: it treats `''` as NULL.

**Q2. What do `COALESCE` and `NULLIF` do? Give a use case for each.**
`COALESCE(a, b, ...)` returns the first non-NULL argument (defaults). `NULLIF(a, b)` returns NULL when `a = b` (turn blanks into NULL, or avoid divide-by-zero with `x / NULLIF(y, 0)`).

**Q3. How do you remove leading and trailing spaces? Why does it matter?**
`TRIM`, `LTRIM`, `RTRIM`. `'Asha'` and `'Asha '` are different keys, so joins, group-bys and dedupes silently fail without trimming. Also standardize case (`LOWER/UPPER`).

**Q4. How do you find duplicate rows?**
`GROUP BY` the key columns with `HAVING COUNT(*) > 1`, or `COUNT(*) OVER (PARTITION BY key)` to see the duplicates as rows.

**Q5. `ISNULL` vs `IFNULL` vs `NVL` vs `COALESCE`?**
All replace NULL. `COALESCE` is ANSI standard, takes many arguments and works everywhere. `ISNULL` (SQL Server), `IFNULL` (MySQL, BigQuery, SQLite), `NVL` (Oracle, Snowflake) take two arguments. Prefer `COALESCE` for portability.

### Intermediate

**Q6. How do you delete duplicates and keep the latest record?**
Rank with `ROW_NUMBER() OVER (PARTITION BY business_key ORDER BY updated_at DESC, id DESC)`, keep `rn = 1`. To physically delete: delete where `rn > 1` (via CTE/subquery or `DELETE ... USING`). In pipelines, prefer writing the deduplicated result to a new table over deleting in place.

**Q7. `DISTINCT` vs `GROUP BY` vs `ROW_NUMBER` for deduplication?**
`DISTINCT` removes fully identical rows only. `GROUP BY` with aggregates can pick min/max but mixes values from different rows. `ROW_NUMBER` keeps one complete, chosen row per key, which is the right tool when duplicates differ in some columns.

**Q8. How do you safely convert text to dates or numbers when some values are invalid?**
Use safe cast functions (`TRY_CAST`, `SAFE_CAST`, `TRY_TO_DATE`) that return NULL on failure, then route rows with NULL results to a reject/quarantine table with a reason. In Postgres validate with a regex or write a helper function.

**Q9. How do you extract the year/month from a date and group by month?**
`EXTRACT(YEAR FROM d)`, `DATE_TRUNC('month', d)` (or engine equivalent). Group by the truncated month (a real date) rather than concatenated strings, so it sorts and joins correctly.

**Q10. How do you handle time zones?**
Store timestamps in UTC (or with time zone type), convert to local time only at the reporting edge, and be explicit about the type (`TIMESTAMP_NTZ` vs `TIMESTAMP_TZ` in Snowflake, `timestamp` vs `timestamptz` in Postgres). Daily reports must define "day" in a specific time zone.

**Q11. What are the risks of `BETWEEN` on dates/timestamps?**
Inclusive at both ends, so `BETWEEN '2024-01-01' AND '2024-01-31'` misses `2024-01-31 10:00`. Use `>= start AND < next_start`.

**Q12. How would you standardize inconsistent categorical values (`'hyd'`, `'Hyderabad '`, `'HYDERABAD'`)?**
Trim + case normalization, then a mapping table (`raw_value -> standard_value`) joined in, with unmapped values flagged for review. A mapping table is auditable and editable by non-engineers, unlike a huge `CASE`.

### Advanced

**Q13. How do you design data quality checks in a pipeline?**
Layered tests: schema (types, required columns), completeness (null rate thresholds), uniqueness (primary key), referential integrity (foreign keys exist), validity (ranges, formats, allowed values), freshness and volume anomalies (row count vs yesterday). Implement with dbt tests, Great Expectations, Soda, or SQL assertions, fail or alert by severity, and quarantine bad rows.

**Q14. Should a pipeline drop invalid records or fix them?**
Neither silently. Fix deterministic issues (trim, case, known mappings), quarantine the rest with a reason code and source pointer, alert on volume, and keep raw data immutable so you can reprocess after rules change. Silent drops make totals disagree with the source.

**Q15. How do you deduplicate at scale (billions of rows)?**
Partition/cluster by the dedupe key, `ROW_NUMBER` over that partition (or `QUALIFY`), filter early to only new/changed partitions (incremental logic), and use `MERGE`/upsert into the target on a primary key. Avoid global `DISTINCT` on wide rows; hash the key columns and dedupe on the hash.

**Q16. How do you handle late-arriving or out-of-order records when deduplicating "latest"?**
Order by a business timestamp (event/updated time from the source) with the load time as a tiebreaker, not just load time. Reprocess a lookback window on each run, and make the merge idempotent so reruns produce the same result.

**Q17. How do you compare two tables for differences (reconciliation) after a migration?**
Row counts, per-column aggregates (sums, min/max, null counts), a hash or checksum per row, and set difference in both directions (`EXCEPT`). Investigate the mismatches by key. (See Topic 7.)

**Q18. What is the difference between `TRIM` on characters like non-breaking spaces or tabs?**
Standard `TRIM` removes ordinary spaces only. Invisible characters (`\u00A0` non-breaking space, tabs, carriage returns from Windows files) need `REGEXP_REPLACE(col, '[\s\u00A0]+', ' ')` or `TRIM(BOTH ... FROM ...)` with an explicit character set. A classic reason for "identical" values that will not join.

---

## 6. Practice Problems

### How to practice (write, run, test, then look at the solution)

1. **Set up the data.** Run [`06-data-cleaning-setup.sql`](./06-data-cleaning-setup.sql) in any database (Postgres, Snowflake, MySQL, SQLite, or an online tool such as DB Fiddle).
2. **Write your own query** for the problem.
3. **Compare with the Expected Output** under each problem.
4. **Run the self-check query** (template below). **0 rows returned = correct.**
5. Only then open the **Solution**.

### Self-check template

```sql
WITH my_answer AS (
    -- paste YOUR query here (example below is the solution to P1)
    SELECT row_id, LOWER(TRIM(email)) AS email_clean
    FROM stg_customers
),
expected (row_id, email_clean) AS (
    VALUES (1, 'asha.rao@gmail.com'),
           (2, 'ravi@company.com'),
           (3, NULL),
           (4, 'john@gmail.com'),
           (5, 'priya@yahoo.com'),
           (6, 'asha.rao@gmail.com'),
           (7, 'kiran@company.com'),
           (8, 'ravi@company.com')
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

### P1. Standardize the email: trim spaces and convert to lower case. NULL emails stay NULL.

Return `row_id` and `email_clean`, ordered by `row_id`.

**Expected output (order matters):**

| row_id | email_clean |
|---|---|
| 1 | asha.rao@gmail.com |
| 2 | ravi@company.com |
| 3 | NULL |
| 4 | john@gmail.com |
| 5 | priya@yahoo.com |
| 6 | asha.rao@gmail.com |
| 7 | kiran@company.com |
| 8 | ravi@company.com |

<details><summary>Solution</summary>

```sql
SELECT row_id, LOWER(TRIM(email)) AS email_clean
FROM stg_customers
ORDER BY row_id
```
</details>

### P2. Clean the phone number so it contains digits only (remove `-`, spaces, `(` and `)`). Blank phones must become NULL.

Return `row_id` and `phone_clean`, ordered by `row_id`.

**Expected output (order matters):**

| row_id | phone_clean |
|---|---|
| 1 | 9876543210 |
| 2 | 9876543211 |
| 3 | NULL |
| 4 | 9876543212 |
| 5 | 9876543213 |
| 6 | 9876543210 |
| 7 | 9876543215 |
| 8 | 9876543211 |

<details><summary>Solution</summary>

```sql
SELECT row_id,
       NULLIF(REPLACE(REPLACE(REPLACE(REPLACE(phone, '-', ''), ' ', ''), '(', ''), ')', ''), '') AS phone_clean
FROM stg_customers
ORDER BY row_id
```
Nested `REPLACE` is portable. Use `REGEXP_REPLACE(phone, '[^0-9]', '')` where regex is available, which is shorter and handles every character.
</details>

### P3. Standardize the city: trim, proper case (first letter upper, rest lower), and use `'Unknown'` for NULL, blank or `'NA'`.

Return `row_id` and `city_clean`, ordered by `row_id`.

**Expected output (order matters):**

| row_id | city_clean |
|---|---|
| 1 | Hyderabad |
| 2 | Hyderabad |
| 3 | Chennai |
| 4 | Bengaluru |
| 5 | Unknown |
| 6 | Hyderabad |
| 7 | Unknown |
| 8 | Hyderabad |

<details><summary>Solution</summary>

```sql
SELECT row_id,
       CASE
         WHEN city IS NULL OR TRIM(city) = '' OR UPPER(TRIM(city)) = 'NA' THEN 'Unknown'
         ELSE UPPER(SUBSTR(TRIM(city), 1, 1)) || LOWER(SUBSTR(TRIM(city), 2))
       END AS city_clean
FROM stg_customers
ORDER BY row_id
```
This proper-case works for single-word city names. For multi-word names use `INITCAP` (Postgres, Snowflake, Oracle, BigQuery). MySQL/SQL Server: replace `||` with `CONCAT` / `+`.
</details>

### P4. Flag each row's `signup_date` as `'missing'` (NULL or blank), `'invalid'` (month not 1-12 or day not 1-31) or `'valid'`.

Return `row_id`, `signup_date`, `date_status`, ordered by `row_id`.

**Expected output (order matters):**

| row_id | signup_date | date_status |
|---|---|---|
| 1 | 2024-01-05 | valid |
| 2 | 2024-01-10 | valid |
| 3 | 2024-02-01 | valid |
| 4 |  | missing |
| 5 | 2024-13-45 | invalid |
| 6 | 2024-01-05 | valid |
| 7 | 2024-03-20 | valid |
| 8 | 2024-01-10 | valid |

<details><summary>Solution</summary>

```sql
SELECT row_id, signup_date,
       CASE
         WHEN signup_date IS NULL OR TRIM(signup_date) = '' THEN 'missing'
         WHEN CAST(SUBSTR(signup_date, 6, 2) AS INTEGER) BETWEEN 1 AND 12
          AND CAST(SUBSTR(signup_date, 9, 2) AS INTEGER) BETWEEN 1 AND 31 THEN 'valid'
         ELSE 'invalid'
       END AS date_status
FROM stg_customers
ORDER BY row_id
```
Order of the `WHEN` clauses matters: check missing first, otherwise `CAST` on a blank would produce a misleading result.
</details>

### P5. Find duplicated customers by cleaned email (trim + lower). Show the email and how many rows share it. Ignore NULL emails.

Return `email_clean` and `copies`, ordered by `email_clean`.

**Expected output (order matters):**

| email_clean | copies |
|---|---|
| asha.rao@gmail.com | 2 |
| ravi@company.com | 2 |

<details><summary>Solution</summary>

```sql
SELECT LOWER(TRIM(email)) AS email_clean, COUNT(*) AS copies
FROM stg_customers
WHERE email IS NOT NULL
GROUP BY LOWER(TRIM(email))
HAVING COUNT(*) > 1
ORDER BY email_clean
```
</details>

### P6. Deduplicate: keep only the most recently loaded row (`loaded_at`) for each cleaned email. Rows with a NULL email are all kept.

Return the `row_id` values of the kept rows, ordered by `row_id`.

**Expected output (order matters):**

| row_id |
|---|
| 3 |
| 4 |
| 5 |
| 6 |
| 7 |
| 8 |

<details><summary>Solution</summary>

```sql
WITH ranked AS (
    SELECT row_id,
           ROW_NUMBER() OVER (
               PARTITION BY LOWER(TRIM(email))
               ORDER BY loaded_at DESC, row_id DESC
           ) AS rn
    FROM stg_customers
)
SELECT row_id
FROM ranked
WHERE rn = 1
ORDER BY row_id
```
Only one row has a NULL email here, so it forms a single partition of size 1. If several rows had NULL emails, all NULL rows would share one partition and only one would survive. To keep all of them, partition by `COALESCE(LOWER(TRIM(email)), 'no-email-' || row_id)`.
</details>

### P7. How many customers use each email domain? Count all non-NULL email rows (no deduplication).

Return `domain` and `customers`. Highest count first, ties by domain.

**Expected output (order matters):**

| domain | customers |
|---|---|
| company.com | 3 |
| gmail.com | 3 |
| yahoo.com | 1 |

<details><summary>Solution</summary>

```sql
SELECT SUBSTR(LOWER(TRIM(email)), INSTR(LOWER(TRIM(email)), '@') + 1) AS domain,
       COUNT(*) AS customers
FROM stg_customers
WHERE email IS NOT NULL
GROUP BY SUBSTR(LOWER(TRIM(email)), INSTR(LOWER(TRIM(email)), '@') + 1)
ORDER BY customers DESC, domain
```
Better: compute `domain` once in a CTE, then group by it. Other engines: `SPLIT_PART(email, '@', 2)` (Postgres, Snowflake), `POSITION('@' IN email)`, `CHARINDEX('@', email)` (SQL Server).
</details>

### P8. Number of signups per month, counting only rows with a valid month (1-12). Month format `YYYY-MM`.

Return `signup_month` and `signups`, oldest month first.

**Expected output (order matters):**

| signup_month | signups |
|---|---|
| 2024-01 | 4 |
| 2024-02 | 1 |
| 2024-03 | 1 |

<details><summary>Solution</summary>

```sql
SELECT SUBSTR(signup_date, 1, 7) AS signup_month, COUNT(*) AS signups
FROM stg_customers
WHERE CAST(SUBSTR(signup_date, 6, 2) AS INTEGER) BETWEEN 1 AND 12
GROUP BY SUBSTR(signup_date, 1, 7)
ORDER BY signup_month
```
The blank date (row 4) and the impossible month 13 (row 5) are excluded by the filter. This includes duplicates; deduplicate first if you need customer counts.
</details>

### P9. Find rows whose `full_name` has extra whitespace at the start or end, and count how many extra characters there are.

Return `row_id` and `extra_chars` (length before trimming minus length after).

**Expected output (order matters):**

| row_id | extra_chars |
|---|---|
| 1 | 3 |

<details><summary>Solution</summary>

```sql
SELECT row_id,
       LENGTH(full_name) - LENGTH(TRIM(full_name)) AS extra_chars
FROM stg_customers
WHERE full_name <> TRIM(full_name)
ORDER BY row_id
```
`LEN` in SQL Server (and note it ignores trailing spaces, so use `DATALENGTH` there). The double space inside `'  asha  rao '` is not counted because `TRIM` only touches the ends.
</details>

---

## 7. Common Mistakes

1. Comparing or grouping on untrimmed, mixed-case text (`'Asha '` vs `'asha'`).
2. Treating `''`, `'NA'` and `NULL` as the same without converting them explicitly.
3. Using `= NULL` instead of `IS NULL`.
4. Deduplicating with `DISTINCT` when the duplicate rows differ in some columns.
5. No tiebreaker in the dedupe `ORDER BY`, so reruns keep different rows.
6. Ordering by load time instead of the business/updated timestamp.
7. Letting one bad value crash a whole load instead of using safe casts plus a reject table.
8. Storing dates as text and formatting them differently across sources.
9. Using `BETWEEN` for timestamp ranges.
10. Silently dropping invalid rows, so totals no longer reconcile with the source.
11. Forgetting NULL rows all fall into one `PARTITION BY` group in window dedupe.

---

## 8. Quick Revision Notes

- Standardize missing values first: `NULLIF(TRIM(col), '')`, `COALESCE(x, default)`.
- Trim + case-fold text before joining, grouping or deduplicating.
- Dedupe latest per key: `ROW_NUMBER() OVER (PARTITION BY key ORDER BY updated_at DESC, id DESC)`, keep `rn = 1`.
- Profile first: null rates, distinct vs total counts, min/max, value frequencies.
- Safe casts: `TRY_CAST` / `SAFE_CAST` / `TRY_TO_DATE`, and quarantine failures with a reason.
- Dates: proper types, UTC, half-open ranges, no `BETWEEN` on timestamps.
- Use a mapping table for category standardization instead of giant `CASE`s.
- Never silently drop rows. Reconcile counts and totals against the source.
- String/date function names differ by engine. Know the concept, look up the syntax.

---

**Previous topic:** [05 - Window Functions](./05-window-functions.md)
**Next topic:** [07 - Set Operations, EXISTS vs IN](./07-set-operations.md)
