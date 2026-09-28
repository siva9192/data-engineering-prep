# Data Engineering Interview Preparation

A structured, topic-by-topic guide for preparing for **Data Engineer interviews (around 5 years of experience)**. Each topic has concept summaries, worked examples, interview questions with answers, practice problems with solutions, common mistakes and quick revision notes.

## How to Use This Repo

1. Go through the topics **in order**. Later topics build on earlier ones.
2. Read the concept summary, then try each practice problem **before** opening the solution.
3. Answer the interview questions out loud, as you would in a real interview.
4. Tick off each topic in the checklist below when you finish it.
5. Use the "Quick Revision Notes" at the end of each file for last-minute revision.

## Progress Checklist

### Phase 1: SQL

- [x] [01 - SQL Basics](./sql/01-basics.md)
- [x] [02 - Joins](./sql/02-joins.md)
- [ ] 03 - Aggregations and Conditional Logic
- [ ] 04 - Subqueries and CTEs (including recursive)
- [ ] 05 - Window Functions
- [ ] 06 - Data Cleaning (NULLs, dates, strings, deduplication)
- [ ] 07 - Set Operations, EXISTS vs IN
- [ ] 08 - Query Optimization (indexes, execution plans, partitioning)
- [ ] 09 - Data Modeling (star/snowflake, SCD types, normalization)
- [ ] 10 - Classic Scenario Problems (top N per group, gaps and islands, sessionization, retention)

### Phase 2: Python for Data Engineering

- [ ] Python fundamentals and data structures
- [ ] Pandas and data manipulation
- [ ] File formats, APIs and error handling
- [ ] Coding interview problems

### Phase 3: Data Warehousing and Modeling

- [ ] Dimensional modeling
- [ ] ETL vs ELT
- [ ] Slowly Changing Dimensions
- [ ] Partitioning, clustering and performance

### Phase 4: Big Data and Spark

- [ ] Spark architecture
- [ ] DataFrames and Spark SQL
- [ ] Optimization (shuffles, skew, caching)
- [ ] Spark interview questions

### Phase 5: Orchestration and Pipelines

- [ ] Airflow concepts (DAGs, operators, scheduling)
- [ ] Idempotency, retries and backfills
- [ ] Data quality and monitoring

### Phase 6: Cloud

- [ ] Core services (storage, compute, warehouse)
- [ ] Streaming basics (Kafka, Kinesis, Pub/Sub)
- [ ] Security and cost optimization

### Phase 7: System Design and Behavioral

- [ ] Data pipeline system design
- [ ] Batch vs streaming architecture
- [ ] Behavioral questions (STAR method) and project stories
- [ ] Final revision checklist

## Repository Structure

```
data-engineering-prep/
├── README.md
├── sql/
│   ├── 01-basics.md
│   ├── 02-joins.md
│   └── ...
├── python/
├── data-warehousing/
├── spark/
├── airflow/
├── cloud/
└── system-design/
```

## Topic File Format

Every topic file follows the same layout:

1. Concept summary
2. What interviewers look for
3. Examples with explanations
4. Interview questions and answers (basic, intermediate, advanced)
5. Practice problems with solutions
6. Common mistakes
7. Quick revision notes

## Study Tips

- Consistency beats cramming. One topic per day or two is a good pace.
- Practice writing SQL and code by hand or in a plain editor, without autocomplete.
- Explain your approach before writing the answer. Interviewers care about reasoning.
- Prepare 3 to 4 stories from your real projects (impact, challenges, decisions).
- Note the topics you find hard and revisit them at the end of each week.

## Contributing / Notes

This is a personal study guide. Feel free to add your own notes, questions asked in real interviews and corrections.

---

*Last updated: September 2026*
