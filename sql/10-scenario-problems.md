# 10 - Classic Scenario Problems (Top N, Gaps and Islands, Sessionization, Retention)

> Level: Data Engineer, 5 years experience. These combine every earlier topic. Interviewers describe a business scenario in plain English and expect you to recognize the pattern.

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

This topic is a pattern library. Real interviews rarely name the pattern; they describe a business scenario and expect you to recognize which one applies. Each pattern below combines tools from Topics 1-9.

### Pattern 1: Nth highest value (per group)
`DENSE_RANK() OVER (PARTITION BY group ORDER BY value DESC) = N`. Decide tie semantics with the interviewer (Topic 5).

### Pattern 2: Top N per group
Same idea with `<= N` instead of `= N`, using `ROW_NUMBER` (exactly N) or `DENSE_RANK`/`RANK` (ties included).

### Pattern 3: Running total / moving average
`SUM()`/`AVG() OVER (ORDER BY ... ROWS BETWEEN ... AND ...)` (Topic 5). Always specify `ROWS`, not the default frame.

### Pattern 4: Gaps and islands (consecutive groups)
Find runs of consecutive rows sharing a property (consecutive days up, consecutive purchases, etc).

**The classic trick:** `row_number - value` (or `row_number - date`) is **constant within a consecutive run** and changes at every break.

```sql
SELECT *, day_num - ROW_NUMBER() OVER (PARTITION BY status ORDER BY day_num) AS grp
FROM server_status;
```
Rows in the same unbroken run of the same status get the same `grp`. Then `GROUP BY status, grp` collapses each run into one row (start day, end day, length).

### Pattern 5: Sessionization
Group events into sessions when the gap between consecutive events (per user) exceeds a threshold.

```sql
WITH gaps AS (
    SELECT *,
           CASE WHEN (time_diff_from_prev_event > threshold) OR prev_event IS NULL
                THEN 1 ELSE 0 END AS is_new_session
    FROM events_with_lag
),
sessions AS (
    SELECT *, SUM(is_new_session) OVER (PARTITION BY user_id ORDER BY event_time) AS session_id
    FROM gaps
)
SELECT user_id, session_id, MIN(event_time), MAX(event_time), COUNT(*)
FROM sessions
GROUP BY user_id, session_id;
```
`LAG` finds the time since the previous event. A running `SUM` of the "new session" flag turns flags into session numbers.

### Pattern 6: Retention / cohort analysis
Assign each user a **cohort** (their first activity period), then measure what fraction of each cohort is still active N periods later.

```sql
WITH first_month AS (
    SELECT user_id, MIN(activity_month) AS cohort_month
    FROM activity
    GROUP BY user_id
)
SELECT f.cohort_month,
       COUNT(DISTINCT CASE WHEN a.activity_month = f.cohort_month              THEN a.user_id END) AS month_0,
       COUNT(DISTINCT CASE WHEN a.activity_month = f.cohort_month + 1 month    THEN a.user_id END) AS month_1
FROM first_month f
JOIN activity a ON a.user_id = f.user_id
GROUP BY f.cohort_month;
```
Conditional `COUNT(DISTINCT ...)` per offset is the standard way to pivot a cohort table.

### Pattern 7: Funnel analysis
Users who completed step 1, then step 2, then step 3, in order. Typically solved with conditional aggregation of the **earliest** timestamp per step per user, then comparing: `step2_time > step1_time` and `step2_time IS NOT NULL`.

### Pattern 8: Median and percentiles
`PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY x)` (Postgres, Snowflake, Oracle, BigQuery via `APPROX_QUANTILES`/`PERCENTILE_CONT`). Without it: rank rows and average the middle one/two (see the worked example).

### Pattern 9: Comparing two periods (period-over-period)
`LAG(value) OVER (PARTITION BY entity ORDER BY period)`, then compute the difference or percent change (Topic 5).

### General approach for scenario questions

1. Restate the question as "one row per ___" (the target grain).
2. Identify which pattern above fits.
3. Sketch it as layered CTEs: raw -> intermediate (flags/ranks/lags) -> final aggregation.
4. Handle edge cases out loud: ties, first/last row with no previous value, empty groups, NULLs.
5. Write the query, then sanity check the numbers against the sample data by hand.

---

## 2. What Interviewers Look For

- Can you translate an English business scenario into the right pattern, unprompted?
- Do you know the row_number-minus-date trick for **gaps and islands**?
- Can you build a **sessionization** query with LAG + running SUM from scratch?
- Can you compute **retention/cohorts** with conditional COUNT(DISTINCT)?
- Do you build solutions as **layered CTEs** rather than one giant nested query?
- Do you narrate edge cases (ties, boundaries, NULLs) instead of waiting to be asked?

---

## 3. Sample Data

Run [`10-scenario-problems-setup.sql`](./10-scenario-problems-setup.sql) to create these tables.

**logins**

| user_id | login_date |
|---|---|
| 1 | 2024-01-01 |
| 1 | 2024-01-02 |
| 1 | 2024-02-05 |
| 2 | 2024-01-01 |
| 2 | 2024-02-01 |
| 3 | 2024-01-15 |
| 1 | 2024-03-01 |
| 2 | 2024-03-01 |
| 3 | 2024-03-02 |

User activity across three months, with user 3 skipping February.

**server_status**

| day_num | status |
|---|---|
| 1 | up |
| 2 | up |
| 3 | up |
| 4 | down |
| 5 | down |
| 6 | up |
| 7 | up |
| 8 | down |
| 9 | up |
| 10 | up |
| 11 | up |

A day-by-day up/down log with three separate "up" runs.

**page_views**

| user_id | view_time |
|---|---|
| 1 | 2024-01-01 10:00:00 |
| 1 | 2024-01-01 10:05:00 |
| 1 | 2024-01-01 10:07:00 |
| 1 | 2024-01-01 10:40:00 |
| 1 | 2024-01-01 10:41:00 |
| 2 | 2024-01-01 09:00:00 |
| 2 | 2024-01-01 09:20:00 |
| 2 | 2024-01-01 11:00:00 |

Two users' page view events. User 1 has a 33-minute gap in the middle of the day.

**emp_salary2**

| emp_id | name | dept | salary |
|---|---|---|---|
| 1 | Asha | Engineering | 150000 |
| 2 | Ravi | Engineering | 120000 |
| 3 | Kiran | Engineering | 120000 |
| 4 | Neha | Engineering | 105000 |
| 5 | Meera | Analytics | 130000 |
| 6 | John | Analytics | 90000 |

Same shape as the Topic 5 table, with Ravi and Kiran tied at 120,000 in Engineering.

---

## 4. Examples with Explanations

### 4.1 Nth highest salary per department (N = 2)
```sql
WITH ranked AS (
    SELECT dept, name, salary,
           DENSE_RANK() OVER (PARTITION BY dept ORDER BY salary DESC) AS drnk
    FROM emp_salary2
)
SELECT dept, salary AS second_highest
FROM ranked
WHERE drnk = 2
GROUP BY dept, salary
ORDER BY dept;
```

**Result:**

| dept | second_highest |
|---|---|
| Analytics | 90000 |
| Engineering | 120000 |

Engineering has a tie for 2nd place (Ravi and Kiran both at 120,000), and `DENSE_RANK` correctly gives both of them rank 2, one distinct salary value.

### 4.2 Gaps and islands: find each unbroken run of server status
```sql
WITH grp AS (
    SELECT day_num, status,
           day_num - ROW_NUMBER() OVER (PARTITION BY status ORDER BY day_num) AS island
    FROM server_status
)
SELECT status, MIN(day_num) AS start_day, MAX(day_num) AS end_day, COUNT(*) AS run_length
FROM grp
GROUP BY status, island
ORDER BY start_day;
```

**Result:**

| status | start_day | end_day | run_length |
|---|---|---|---|
| up | 1 | 3 | 3 |
| down | 4 | 5 | 2 |
| up | 6 | 7 | 2 |
| down | 8 | 8 | 1 |
| up | 9 | 11 | 3 |

`island` stays constant while `day_num` and the same-status row number increase together (a run), and jumps whenever the status changes or a day is skipped. Grouping by `(status, island)` collapses each run to one row.

### 4.3 Sessionize page views with a 15-minute timeout
```sql
WITH lagged AS (
    SELECT user_id, view_time,
           LAG(view_time) OVER (PARTITION BY user_id ORDER BY view_time) AS prev_time
    FROM page_views
),
flagged AS (
    SELECT *,
           CASE WHEN prev_time IS NULL
                     OR (JULIANDAY(view_time) - JULIANDAY(prev_time)) * 24 * 60 > 15
                THEN 1 ELSE 0 END AS is_new_session
    FROM lagged
),
sessions AS (
    SELECT *, SUM(is_new_session) OVER (PARTITION BY user_id ORDER BY view_time) AS session_num
    FROM flagged
)
SELECT user_id, session_num, MIN(view_time) AS session_start, MAX(view_time) AS session_end, COUNT(*) AS events
FROM sessions
GROUP BY user_id, session_num
ORDER BY user_id, session_num;
```

**Result:**

| user_id | session_num | session_start | session_end | events |
|---|---|---|---|---|
| 1 | 1 | 2024-01-01 10:00:00 | 2024-01-01 10:07:00 | 3 |
| 1 | 2 | 2024-01-01 10:40:00 | 2024-01-01 10:41:00 | 2 |
| 2 | 1 | 2024-01-01 09:00:00 | 2024-01-01 09:00:00 | 1 |
| 2 | 2 | 2024-01-01 09:20:00 | 2024-01-01 09:20:00 | 1 |
| 2 | 3 | 2024-01-01 11:00:00 | 2024-01-01 11:00:00 | 1 |

User 1 has a 33-minute gap between 10:07 and 10:40, so that starts a new session. User 2 has a 1h40m gap, also a new session. `JULIANDAY` is SQLite-specific for computing minutes between two timestamps; use `EXTRACT(EPOCH FROM ...)` (Postgres), `TIMESTAMPDIFF` (MySQL), `DATEDIFF(minute, ...)` (SQL Server), or `TIMESTAMP_DIFF` (BigQuery).

### 4.4 Simple median without PERCENTILE_CONT (portable pattern)
```sql
WITH ordered AS (
    SELECT salary,
           ROW_NUMBER() OVER (ORDER BY salary) AS rn,
           COUNT(*) OVER () AS n
    FROM emp_salary2
)
SELECT AVG(salary) AS median_salary
FROM ordered
WHERE rn IN ((n + 1) / 2, (n + 2) / 2);
```

**Result:**

| median_salary |
|---|
| 120000 |

With an even count this averages the two middle values; with an odd count both expressions point to the same middle row, so the average is just that value. `(n+1)/2` and `(n+2)/2` use integer division on purpose.

---

## 5. Interview Questions and Answers

### Basic

**Q1. How do you find the Nth highest value overall or per group?**
`DENSE_RANK() OVER (PARTITION BY group ORDER BY value DESC)`, filter `= N`. Clarify whether ties should count as one rank (use `DENSE_RANK`) or consume multiple ranks (use `RANK`).

**Q2. How do you get the top 3 products by sales in each region?**
`ROW_NUMBER()`/`RANK()`/`DENSE_RANK() OVER (PARTITION BY region ORDER BY sales DESC)` in a CTE, filter `<= 3` in the outer query.

**Q3. What is "gaps and islands"?**
A class of problems where you must find consecutive runs of rows sharing some property (consecutive dates, consecutive statuses, consecutive IDs) and treat each run as a group.

**Q4. What is sessionization?**
Grouping a user's events into sessions by inserting a session boundary whenever the time since the previous event exceeds a threshold.

### Intermediate

**Q5. Explain the row-number-minus-date trick for gaps and islands.**
For rows ordered within a partition, if you subtract a sequential row number from a sequential value (like a date or an id), the result is constant for consecutive values and changes whenever there's a break. That constant becomes a synthetic group id for `GROUP BY`.

**Q6. How would you find users who logged in on 3 or more consecutive days?**
Assign `date - ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY date)` as the island id per user, group by `(user_id, island)`, count days per group, and keep groups with `COUNT(*) >= 3`.

**Q7. How do you build a session id from raw event timestamps?**
`LAG(event_time) OVER (PARTITION BY user_id ORDER BY event_time)` to get the previous event time, flag `1` when the gap exceeds the timeout (or there is no previous event), then `SUM(flag) OVER (PARTITION BY user_id ORDER BY event_time)` turns the flags into an increasing session number.

**Q8. How do you compute month-1 retention for a signup cohort?**
Find each user's first activity month (their cohort). Join activity back to the cohort. Count distinct users active in cohort month + 1 versus the cohort size, per cohort month. Typically expressed as conditional `COUNT(DISTINCT CASE WHEN ... END)`.

**Q9. How do you calculate a running total that resets every month?**
`SUM(x) OVER (PARTITION BY month ORDER BY date ROWS UNBOUNDED PRECEDING)`. The partition boundary causes the reset.

**Q10. How would you compute median salary per department without a built-in percentile function?**
Rank rows by salary within each department, get the count per department, and average the value(s) at the middle rank(s), handling even/odd counts (see the worked example, adding `PARTITION BY dept`).

### Advanced

**Q11. How do you detect a funnel drop-off (visited -> added to cart -> purchased) per user?**
Compute the earliest timestamp per user per step with conditional `MIN`, then compare: a later step only counts if its timestamp exists and is after the earlier step's timestamp. Aggregate counts at each step to see the drop-off, and consider whether steps must happen within a time window.

**Q12. How would you find the longest streak of consecutive days a user was active?**
Island-group their login dates (Pattern 4), compute the length of each island (`MAX(date) - MIN(date) + 1` or `COUNT(*)` if every day is guaranteed present), then take the max per user.

**Q13. How do you handle sessionization when events for the same user can arrive out of order or late?**
Sort explicitly by event time (not arrival/load time) before computing `LAG`, and rerun/recompute affected sessions on a lookback window when late data arrives rather than only appending. Make the job idempotent (recompute a full day/user rather than incrementally patch).

**Q14. How do you compute week-over-week percent change per product?**
`LAG(revenue) OVER (PARTITION BY product ORDER BY week)`, then `(revenue - prev) / NULLIF(prev, 0) * 100.0`. Decide how to handle a product with no prior week (NULL result is usually correct, meaning "no comparison available").

**Q15. How would you identify duplicate "bot-like" activity, for example a user with more than 100 events in under 60 seconds?**
Compute inter-event gaps with `LAG`, aggregate counts and total elapsed time per user over a rolling window (or per session from Pattern 5), and flag users whose event count in that window exceeds the threshold while elapsed time is below it. This is sessionization plus a threshold rule.

**Q16. What is the general strategy you use for an unfamiliar scenario question?**
State the target grain out loud, decide which pattern(s) apply (ranking, running/moving calc, gaps and islands, sessionization, cohort), sketch layered CTEs (raw -> flags/lags -> grouped result), then write the SQL, narrating tie-breaking and edge cases as you go, and sanity-check against a couple of rows by hand.

---

## 6. Practice Problems

### How to practice (write, run, test, then look at the solution)

1. **Set up the data.** Run [`10-scenario-problems-setup.sql`](./10-scenario-problems-setup.sql) in any database (Postgres, Snowflake, MySQL, SQLite, or an online tool such as DB Fiddle).
2. **Write your own query** for the problem.
3. **Compare with the Expected Output** under each problem.
4. **Run the self-check query** (template below). **0 rows returned = correct.**
5. Only then open the **Solution**.

### Self-check template

```sql
WITH my_answer AS (
    -- paste YOUR query here (example below is the solution to P1)
    WITH ranked AS (
        SELECT dept, salary,
               DENSE_RANK() OVER (PARTITION BY dept ORDER BY salary DESC) AS drnk
        FROM emp_salary2
    )
    SELECT dept, salary AS second_highest
    FROM ranked
    WHERE drnk = 2
    GROUP BY dept, salary
),
expected (dept, second_highest) AS (
    VALUES ('Analytics', 90000),
           ('Engineering', 120000)
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

### P1. The 2nd highest distinct salary in each department (same as the worked example, but write it yourself).

Return `dept` and `second_highest`, ordered by `dept`.

**Expected output (order matters):**

| dept | second_highest |
|---|---|
| Analytics | 90000 |
| Engineering | 120000 |

<details><summary>Solution</summary>

```sql
WITH ranked AS (
    SELECT dept, salary,
           DENSE_RANK() OVER (PARTITION BY dept ORDER BY salary DESC) AS drnk
    FROM emp_salary2
)
SELECT dept, salary AS second_highest
FROM ranked
WHERE drnk = 2
GROUP BY dept, salary
ORDER BY dept
```
</details>

### P2. Find every unbroken run of `'up'` days in `server_status`, with its start day, end day and length.

Return `start_day`, `end_day`, `run_length`, ordered by `start_day`. Only `'up'` runs, not `'down'`.

**Expected output (order matters):**

| start_day | end_day | run_length |
|---|---|---|
| 1 | 3 | 3 |
| 6 | 7 | 2 |
| 9 | 11 | 3 |

<details><summary>Solution</summary>

```sql
WITH grp AS (
    SELECT day_num, status,
           day_num - ROW_NUMBER() OVER (PARTITION BY status ORDER BY day_num) AS island
    FROM server_status
)
SELECT MIN(day_num) AS start_day, MAX(day_num) AS end_day, COUNT(*) AS run_length
FROM grp
WHERE status = 'up'
GROUP BY island
ORDER BY start_day
```
Three separate up-runs: days 1-3, days 6-7, days 9-11.
</details>

### P3. Which server status run was the longest overall (any status)? Return just that one row.

Return `status`, `start_day`, `end_day`, `run_length`.

**Expected output:**

| status | start_day | end_day | run_length |
|---|---|---|---|
| up | 1 | 3 | 3 |

<details><summary>Solution</summary>

```sql
WITH grp AS (
    SELECT day_num, status,
           day_num - ROW_NUMBER() OVER (PARTITION BY status ORDER BY day_num) AS island
    FROM server_status
),
runs AS (
    SELECT status, MIN(day_num) AS start_day, MAX(day_num) AS end_day, COUNT(*) AS run_length
    FROM grp
    GROUP BY status, island
)
SELECT status, start_day, end_day, run_length
FROM runs
ORDER BY run_length DESC, start_day
LIMIT 1
```
Days 9-11 ('up', length 3) ties with days 1-3 ('up', length 3); the tiebreaker `start_day` picks the earlier one. State this assumption out loud in an interview.
</details>

### P4. Sessionize user 1's page views using a 15-minute timeout. Show each session's start time, end time and event count.

Return `session_num`, `session_start`, `session_end`, `events` for `user_id = 1`, ordered by `session_num`.

**Expected output (order matters):**

| session_num | session_start | session_end | events |
|---|---|---|---|
| 1 | 2024-01-01 10:00:00 | 2024-01-01 10:07:00 | 3 |
| 2 | 2024-01-01 10:40:00 | 2024-01-01 10:41:00 | 2 |

<details><summary>Solution</summary>

```sql
WITH lagged AS (
    SELECT user_id, view_time,
           LAG(view_time) OVER (PARTITION BY user_id ORDER BY view_time) AS prev_time
    FROM page_views
    WHERE user_id = 1
),
flagged AS (
    SELECT *,
           CASE WHEN prev_time IS NULL
                     OR (JULIANDAY(view_time) - JULIANDAY(prev_time)) * 24 * 60 > 15
                THEN 1 ELSE 0 END AS is_new_session
    FROM lagged
),
sessions AS (
    SELECT *, SUM(is_new_session) OVER (ORDER BY view_time) AS session_num
    FROM flagged
)
SELECT session_num, MIN(view_time) AS session_start, MAX(view_time) AS session_end, COUNT(*) AS events
FROM sessions
GROUP BY session_num
ORDER BY session_num
```
`JULIANDAY` is SQLite-only; translate the minute-gap calculation for your real engine (see the worked example note).
</details>

### P5. How many distinct users logged in during each calendar month, and what fraction of January's users (the cohort) returned in February and in March?

Return one row: `jan_users`, `feb_returning`, `mar_returning` (counts of January's users seen again in Feb / Mar).

**Expected output:**

| jan_users | feb_returning | mar_returning |
|---|---|---|
| 3 | 2 | 3 |

<details><summary>Solution</summary>

```sql
WITH jan_users AS (
    SELECT DISTINCT user_id FROM logins WHERE SUBSTR(login_date, 1, 7) = '2024-01'
)
SELECT
  (SELECT COUNT(*) FROM jan_users) AS jan_users,
  (SELECT COUNT(DISTINCT l.user_id) FROM logins l JOIN jan_users j ON j.user_id = l.user_id
     WHERE SUBSTR(l.login_date, 1, 7) = '2024-02') AS feb_returning,
  (SELECT COUNT(DISTINCT l.user_id) FROM logins l JOIN jan_users j ON j.user_id = l.user_id
     WHERE SUBSTR(l.login_date, 1, 7) = '2024-03') AS mar_returning
```
This is a simplified single-cohort version of Pattern 6. All 3 January users (1, 2, 3) came back eventually, but check the month-by-month detail: user 3 skipped February entirely.
</details>

### P6. Find the median salary across all employees (ignore department) without using a built-in percentile function.

Return one row with `median_salary`.

**Expected output:**

| median_salary |
|---|
| 120000 |

<details><summary>Solution</summary>

```sql
WITH ordered AS (
    SELECT salary,
           ROW_NUMBER() OVER (ORDER BY salary) AS rn,
           COUNT(*) OVER () AS n
    FROM emp_salary2
)
SELECT AVG(salary) AS median_salary
FROM ordered
WHERE rn IN ((n + 1) / 2, (n + 2) / 2)
```
6 employees (even count), so the median is the average of the 3rd and 4th ordered salaries.
</details>

### P7. For each user, find their longest streak of consecutive login days.

Return `user_id` and `longest_streak_days`, ordered by `user_id`. A single isolated login day counts as a streak of length 1.

**Expected output (order matters):**

| user_id | longest_streak_days |
|---|---|
| 1 | 2 |
| 2 | 1 |
| 3 | 1 |

<details><summary>Solution</summary>

```sql
WITH grp AS (
    SELECT user_id, login_date,
           JULIANDAY(login_date) - ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date) AS island
    FROM logins
),
streaks AS (
    SELECT user_id, island, COUNT(*) AS streak_days
    FROM grp
    GROUP BY user_id, island
)
SELECT user_id, MAX(streak_days) AS longest_streak_days
FROM streaks
GROUP BY user_id
ORDER BY user_id
```
User 1's longest streak is 2 days (Jan 1-2). `JULIANDAY` converts the date to a number so subtraction works the same as with integer days; on other engines subtract the dates directly or cast to an integer day number.
</details>

---

## 7. Common Mistakes

1. Trying to solve gaps/islands or sessionization with a single flat query instead of layered CTEs.
2. Forgetting the row-number-minus-date trick requires the same `ORDER BY` and `PARTITION BY` as the grouping logic.
3. Sessionizing without ordering by the true event time (using arrival/load order instead).
4. Not handling the first row's NULL `LAG` (must count as a new session/streak start).
5. Choosing `RANK` vs `DENSE_RANK` vs `ROW_NUMBER` without checking how ties should behave for that specific question.
6. Computing retention using total counts instead of `COUNT(DISTINCT user_id)`.
7. Mixing up cohort membership date with activity date when building a retention matrix.
8. Assuming every day/period exists in the data (missing dates silently break streak/gap logic based on `COUNT(*)`).
9. Median: forgetting the even/odd count split, or forgetting `PARTITION BY` when the median is needed per group.
10. Not stating tie-breaking assumptions out loud in an interview before coding.

---

## 8. Quick Revision Notes

- Nth value: `DENSE_RANK() = N`. Top N per group: rank in a CTE, filter outside.
- Gaps and islands: `value - ROW_NUMBER() OVER (PARTITION BY key ORDER BY value)` is constant within a run.
- Sessionization: `LAG` for the gap, a flag when the gap exceeds the timeout, running `SUM(flag)` for the session id.
- Retention/cohort: `MIN(activity_period)` = cohort, then conditional `COUNT(DISTINCT user_id)` per offset.
- Median without a built-in: rank rows, average the middle 1 or 2 by integer-division index.
- Funnel: conditional `MIN(timestamp)` per step per user, compare consecutive steps.
- Always build scenario answers as layered CTEs: raw -> flags/lags/ranks -> grouped result.
- State the target grain and tie-breaking rules out loud before writing the query.

---

**Previous topic:** [09 - Data Modeling](./09-data-modeling.md)
**You have finished the SQL phase. Next: Python for Data Engineering.**
