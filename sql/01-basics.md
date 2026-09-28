# 01 - SQL Basics Refresher

> Level: Data Engineer, 5 years experience. Basics are asked as warm-up, but the *reasoning* (execution order, NULLs, WHERE vs HAVING) is where interviewers separate strong candidates.

## Table of Contents
1. [Concept Summary](#1-concept-summary)
2. [What Interviewers Look For](#2-what-interviewers-look-for)
3. [Sample Data Used in This Doc](#3-sample-data)
4. [Examples with Explanations](#4-examples-with-explanations)
5. [Interview Questions and Answers](#5-interview-questions-and-answers)
6. [Practice Problems](#6-practice-problems)
7. [Common Mistakes](#7-common-mistakes)
8. [Quick Revision Notes](#8-quick-revision-notes)

---

## 1. Concept Summary

SQL is declarative: you describe *what* you want, and the engine decides *how* to get it. A basic query has these clauses:

```sql
SELECT   columns / expressions
FROM     table
WHERE    row-level filter
GROUP BY grouping columns
HAVING   group-level filter
ORDER BY sort columns
LIMIT    n            -- TOP n in SQL Server, FETCH FIRST n ROWS in Oracle
```

### Logical order of execution (MOST asked concept)

The order you *write* a query is not the order the engine *evaluates* it:

| Step | Clause | What happens |
|------|--------|--------------|
| 1 | `FROM` / `JOIN` | Build the working row set |
| 2 | `WHERE` | Filter individual rows |
| 3 | `GROUP BY` | Form groups |
| 4 | `HAVING` | Filter groups |
| 5 | `SELECT` | Compute expressions, window functions, aliases |
| 6 | `DISTINCT` | Remove duplicate rows |
| 7 | `ORDER BY` | Sort the result |
| 8 | `LIMIT` / `OFFSET` | Trim the result |

Consequences of this order:
- You **cannot use a SELECT alias in WHERE** (WHERE runs before SELECT).
- You **can use a SELECT alias in ORDER BY** (ORDER BY runs after SELECT).
- Aggregates are **not allowed in WHERE**, only in HAVING (groups do not exist yet at WHERE time).
- Some engines (BigQuery, Snowflake, MySQL, Postgres for GROUP BY) allow aliases in more places as a convenience, but you should not rely on it in interviews.

---

## 2. What Interviewers Look For

- Can you explain **WHERE vs HAVING** and execution order without hesitation?
- Do you understand **NULL** three-valued logic (TRUE / FALSE / UNKNOWN)?
- Do you know `COUNT(*)` vs `COUNT(col)` vs `COUNT(DISTINCT col)`?
- Do you write clean, readable SQL (formatting, aliases, explicit column lists, no `SELECT *` in production)?
- Do you think about **data volume** even for simple queries (filter early, select only needed columns)?
- Can you spot subtle bugs, such as `NOT IN` with NULLs or `BETWEEN` on timestamps?

---

## 3. Sample Data

**employees**

| emp_id | name   | dept_id | salary | hire_date  | manager_id |
|--------|--------|---------|--------|------------|------------|
| 1      | Asha   | 10      | 90000  | 2019-03-15 | NULL       |
| 2      | Ravi   | 10      | 75000  | 2020-07-01 | 1          |
| 3      | Meera  | 20      | 82000  | 2021-01-10 | 1          |
| 4      | John   | 20      | 82000  | 2022-05-20 | 3          |
| 5      | Priya  | 30      | NULL   | 2023-02-11 | 3          |
| 6      | Kiran  | NULL    | 60000  | 2023-08-30 | 2          |

**departments**

| dept_id | dept_name   |
|---------|-------------|
| 10      | Engineering |
| 20      | Analytics   |
| 30      | Finance     |

---

## 4. Examples with Explanations

### 4.1 Filtering and sorting
```sql
SELECT name, salary
FROM employees
WHERE salary >= 80000
ORDER BY salary DESC, name ASC;
```
Rows with `NULL` salary are excluded, because `NULL >= 80000` is UNKNOWN, not TRUE.

### 4.2 Aggregation with GROUP BY and HAVING
```sql
SELECT dept_id,
       COUNT(*)        AS emp_count,
       AVG(salary)     AS avg_salary
FROM employees
WHERE hire_date >= '2020-01-01'      -- row filter, runs BEFORE grouping
GROUP BY dept_id
HAVING COUNT(*) >= 2                 -- group filter, runs AFTER grouping
ORDER BY avg_salary DESC;
```
`WHERE` reduces rows before the aggregation (cheaper). `HAVING` filters on aggregate results.

### 4.3 COUNT variations
```sql
SELECT COUNT(*)               AS total_rows,      -- 6  (counts all rows)
       COUNT(salary)          AS non_null_salary, -- 5  (ignores NULL)
       COUNT(DISTINCT dept_id) AS unique_depts    -- 3  (ignores NULL, dedupes)
FROM employees;
```

### 4.4 NULL handling
```sql
-- WRONG: never matches anything
SELECT * FROM employees WHERE manager_id = NULL;

-- RIGHT
SELECT * FROM employees WHERE manager_id IS NULL;

-- Replace NULL with a default
SELECT name, COALESCE(salary, 0) AS salary_clean FROM employees;
```

### 4.5 CASE WHEN
```sql
SELECT name,
       salary,
       CASE
         WHEN salary IS NULL   THEN 'Unknown'
         WHEN salary >= 85000  THEN 'High'
         WHEN salary >= 70000  THEN 'Medium'
         ELSE 'Low'
       END AS salary_band
FROM employees;
```

### 4.6 DISTINCT, LIMIT, LIKE, IN, BETWEEN
```sql
SELECT DISTINCT dept_id FROM employees;

SELECT name FROM employees WHERE name LIKE 'A%';           -- starts with A
SELECT name FROM employees WHERE dept_id IN (10, 20);
SELECT name FROM employees
WHERE hire_date BETWEEN '2020-01-01' AND '2021-12-31';     -- inclusive on both ends

SELECT * FROM employees ORDER BY salary DESC LIMIT 3;      -- see dialect notes below
```

### 4.7 Dialect differences (quick reference)

| Task | Postgres / MySQL / Snowflake / BigQuery | SQL Server | Oracle |
|------|------------------------------------------|------------|--------|
| First N rows | `LIMIT n` | `SELECT TOP n` | `FETCH FIRST n ROWS ONLY` |
| String concat | `\|\|` (Postgres, Snowflake), `CONCAT()` | `+` or `CONCAT()` | `\|\|` |
| Current date | `CURRENT_DATE` | `GETDATE()` | `SYSDATE` |
| NULL default | `COALESCE` (all), `IFNULL` (MySQL/BigQuery) | `ISNULL` | `NVL` |

---

## 5. Interview Questions and Answers

### Basic

**Q1. What is the difference between WHERE and HAVING?**
`WHERE` filters individual rows before grouping and cannot contain aggregate functions. `HAVING` filters groups after `GROUP BY` and can use aggregates. Use `WHERE` whenever possible because it reduces the data before aggregation.

**Q2. What is the logical order of execution of a SQL query?**
`FROM/JOIN` -> `WHERE` -> `GROUP BY` -> `HAVING` -> `SELECT` -> `DISTINCT` -> `ORDER BY` -> `LIMIT`. This is why aliases defined in SELECT cannot be used in WHERE.

**Q3. Difference between COUNT(*), COUNT(column) and COUNT(DISTINCT column)?**
`COUNT(*)` counts all rows including NULLs. `COUNT(column)` counts non-NULL values. `COUNT(DISTINCT column)` counts unique non-NULL values.

**Q4. Difference between DELETE, TRUNCATE and DROP?**
- `DELETE`: DML, removes rows (optionally with WHERE), logged row by row, can be rolled back, fires triggers.
- `TRUNCATE`: DDL (in most engines), removes all rows quickly, minimal logging, resets identity, no WHERE.
- `DROP`: removes the table itself (structure and data).

**Q5. What is the difference between UNION and UNION ALL?**
`UNION` removes duplicates (requires a sort or hash, so it is slower). `UNION ALL` keeps everything and is faster. Default to `UNION ALL` unless you need deduplication.

**Q6. How do you find NULL values?**
Use `IS NULL` / `IS NOT NULL`. `= NULL` never returns TRUE because comparing to NULL yields UNKNOWN.

### Intermediate

**Q7. Why does `WHERE col NOT IN (subquery)` return no rows when the subquery contains a NULL?**
`x NOT IN (1, 2, NULL)` expands to `x<>1 AND x<>2 AND x<>NULL`. The last term is UNKNOWN, so the whole expression is never TRUE. Fix by filtering NULLs in the subquery (`WHERE col IS NOT NULL`) or using `NOT EXISTS`.

**Q8. Can you use a column alias in WHERE? In GROUP BY? In ORDER BY?**
Standard SQL: not in `WHERE` or `HAVING` (they run before SELECT), yes in `ORDER BY`. `GROUP BY` alias support is engine-specific (allowed in Postgres, MySQL, BigQuery, Snowflake; not in SQL Server or Oracle).

**Q9. What happens if you SELECT a non-aggregated column that is not in GROUP BY?**
Standard SQL raises an error, because the value is ambiguous for the group. MySQL (with `ONLY_FULL_GROUP_BY` off) may return an arbitrary value, which is a bug source.

**Q10. What is the difference between `BETWEEN` and `>= AND <=` for timestamps?**
`BETWEEN` is inclusive on both ends. With timestamps, `BETWEEN '2024-01-01' AND '2024-01-31'` misses everything after `2024-01-31 00:00:00`. Prefer a half-open range: `>= '2024-01-01' AND < '2024-02-01'`.

**Q11. How do NULLs behave in aggregates, GROUP BY, DISTINCT and ORDER BY?**
- Aggregates (except `COUNT(*)`) ignore NULLs. `AVG` divides by the non-NULL count.
- `GROUP BY` and `DISTINCT` treat all NULLs as one group / one value.
- `ORDER BY` placement varies: Postgres/Oracle put NULLs last for ASC, MySQL/SQL Server put them first. Use `NULLS FIRST/LAST` where supported.

**Q12. What is the difference between `CHAR`, `VARCHAR` and `TEXT`?**
`CHAR(n)` is fixed length (padded), `VARCHAR(n)` is variable length with a limit, `TEXT` is variable length with no practical limit (engine-specific). In modern warehouses (Snowflake, BigQuery) the distinction has little storage impact.

### Advanced

**Q13. How would you get the 2nd highest salary without window functions? What are the tie-handling pitfalls?**
```sql
SELECT MAX(salary) AS second_highest
FROM employees
WHERE salary < (SELECT MAX(salary) FROM employees);
```
This returns the second highest **distinct** value and returns NULL if none exists. With window functions, `DENSE_RANK()` gives the same semantics; `ROW_NUMBER()` would treat ties as different ranks and give a wrong answer for "2nd highest salary". Clarify the tie semantics with the interviewer first.

**Q14. Why is `SELECT *` discouraged in production pipelines?**
It reads unnecessary columns (a big cost in columnar stores like Snowflake, BigQuery, Parquet), breaks downstream code when the schema changes, and hides lineage. Select explicit columns.

**Q15. Does putting a filter in `WHERE` versus `HAVING` change performance?**
Yes. A filter on a non-aggregated column belongs in `WHERE` so rows are eliminated before grouping (and can use indexes/partition pruning). Modern optimizers often push such HAVING predicates down, but you should not depend on it.

**Q16. What is a deterministic query and why does it matter in pipelines?**
Same input always yields same output. `LIMIT` without `ORDER BY`, or `ROW_NUMBER()` over ties without a tiebreaker, is non-deterministic, which causes flaky reruns and unstable backfills. Always add a unique tiebreaker column.

---

## 6. Practice Problems

Use the sample tables from section 3.

**P1.** List employees hired after 2020-12-31, sorted by hire date (newest first).

<details><summary>Solution</summary>

```sql
SELECT emp_id, name, hire_date
FROM employees
WHERE hire_date > '2020-12-31'
ORDER BY hire_date DESC;
```
</details>

**P2.** Show the number of employees and the average salary per department, only for departments with more than 1 employee.

<details><summary>Solution</summary>

```sql
SELECT dept_id, COUNT(*) AS emp_count, AVG(salary) AS avg_salary
FROM employees
GROUP BY dept_id
HAVING COUNT(*) > 1;
```
Note: `Kiran` has NULL `dept_id` and forms its own group of 1, so it is excluded by the HAVING.
</details>

**P3.** Find employees whose salary is NULL or below 70000.

<details><summary>Solution</summary>

```sql
SELECT name, salary
FROM employees
WHERE salary IS NULL OR salary < 70000;
```
</details>

**P4.** Find the second highest distinct salary.

<details><summary>Solution</summary>

```sql
SELECT MAX(salary) AS second_highest
FROM employees
WHERE salary < (SELECT MAX(salary) FROM employees);
-- Expected: 82000
```
</details>

**P5.** Add a column `tenure_flag` = 'Senior' if hired before 2021-01-01, otherwise 'Junior'.

<details><summary>Solution</summary>

```sql
SELECT name, hire_date,
       CASE WHEN hire_date < '2021-01-01' THEN 'Senior' ELSE 'Junior' END AS tenure_flag
FROM employees;
```
</details>

**P6.** Find all employees who do **not** belong to any department listed in the `departments` table (safely handling NULLs).

<details><summary>Solution</summary>

```sql
SELECT e.name
FROM employees e
WHERE NOT EXISTS (
    SELECT 1 FROM departments d WHERE d.dept_id = e.dept_id
);
-- Returns Kiran (dept_id NULL)
```
`NOT EXISTS` is NULL-safe, unlike `NOT IN`.
</details>

**P7.** Return the top 3 highest paid employees. If there is a tie for 3rd place, explain how you would handle it.

<details><summary>Solution</summary>

```sql
SELECT name, salary
FROM employees
WHERE salary IS NOT NULL
ORDER BY salary DESC, emp_id
LIMIT 3;
```
This gives exactly 3 rows (with a deterministic tiebreaker). If the business wants *all* people tied at the 3rd salary, use `DENSE_RANK() <= 3` in a subquery (covered in the Window Functions topic).
</details>

---

## 7. Common Mistakes

1. Writing `= NULL` instead of `IS NULL`.
2. Using `NOT IN` against a column that can contain NULLs.
3. Putting non-aggregate filters in `HAVING` instead of `WHERE`.
4. Using `BETWEEN` with timestamps and missing the end of the last day.
5. Using `LIMIT` / `TOP` without `ORDER BY` (non-deterministic result).
6. Using `SELECT *` in production queries and views.
7. Assuming `AVG(col)` treats NULL as 0 (it ignores them).
8. Using `UNION` when `UNION ALL` is enough (needless sort/dedupe cost).
9. Trying to use a SELECT alias in `WHERE`.
10. Forgetting integer division (`5/2 = 2` in many engines); cast to decimal first.

---

## 8. Quick Revision Notes

- **Execution order:** FROM -> WHERE -> GROUP BY -> HAVING -> SELECT -> DISTINCT -> ORDER BY -> LIMIT
- **WHERE** = rows, **HAVING** = groups.
- **NULL** is not equal to anything, not even NULL. Use `IS NULL`, `COALESCE`.
- `COUNT(*)` counts all rows, `COUNT(col)` skips NULLs.
- `NOT EXISTS` is safer than `NOT IN`.
- `UNION ALL` is faster than `UNION`.
- Use half-open ranges for timestamps.
- Always add `ORDER BY` with a tiebreaker when using `LIMIT`.
- Dialect gotchas: `LIMIT` / `TOP` / `FETCH FIRST`, string concat, NULL functions.

---

**Next topic:** [02 - Joins](./02-joins.md)
