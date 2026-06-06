# 🏢 Employee Performance & Workforce Analytics — SQL + Power BI

_SQL-driven HR analysis across 3,000 employees — attrition patterns, flight risk detection, training ROI, and recruitment funnel analysis — built in MySQL with a 3-tab Power BI dashboard._

---

## 📌 Table of Contents
- <a href="#overview">Overview</a>
- <a href="#business-problem">Business Problem</a>
- <a href="#dataset">Dataset</a>
- <a href="#tools--technologies">Tools & Technologies</a>
- <a href="#project-structure">Project Structure</a>
- <a href="#data-cleaning--preparation">Data Cleaning & Preparation</a>
- <a href="#exploratory-data-analysis-eda">Exploratory Data Analysis (EDA)</a>
- <a href="#research-questions--key-findings">Research Questions & Key Findings</a>
- <a href="#dashboard">Dashboard</a>
- <a href="#how-to-run-this-project">How to Run This Project</a>
- <a href="#final-recommendations">Final Recommendations</a>

---

<h2><a class="anchor" id="overview"></a>Overview</h2>

This project analyses workforce data across 3,000 employees to answer four HR business questions: who is leaving, who is a flight risk before they leave, whether training spend is returning value, and what the recruitment funnel looks like by salary expectation. The full pipeline runs in MySQL — raw CSV ingestion through data cleaning, indexing, segmentation, Z-score outlier detection, risk scoring, and CLV-style ranking — with outputs to a 3-tab Power BI dashboard. Overall attrition rate: **12.90%** (387 terminated out of 3,000).

---

<h2><a class="anchor" id="business-problem"></a>Business Problem</h2>

HR teams sit on rich employee data but struggle to act on it. This project answers four concrete business questions:

- **Who is leaving — and why?** Attrition patterns by department, pay zone, and performance tier
- **Who is a flight risk?** High performers in low pay zones with declining engagement — before they resign
- **Is training worth the spend?** Success rates and cost-per-outcome by department across $1.67M in spend
- **Who should we hire?** Recruitment funnel conversion and salary expectation benchmarks by education level

---

<h2><a class="anchor" id="dataset"></a>Dataset</h2>

| Table | Rows | Description |
|---|---|---|
| `employees` | 3,000 | Core HR record — department, pay zone, performance score, status, tenure |
| `engagement` | 3,000 | Survey scores — engagement, satisfaction, work-life balance |
| `training` | 3,000 | Training program, outcome, cost, duration |
| `recruitment` | 3,000 | Applicant pipeline — education, salary expectation, hire status |

**Source:** Synthetic HR dataset (Kaggle) — structured to mirror real enterprise HR data models.

---

<h2><a class="anchor" id="tools--technologies"></a>Tools & Technologies</h2>

- SQL (MySQL 8.0 — DDL/DML, CTEs, Window Functions, Subqueries, Indexes)
- MySQL Workbench
- Power BI Desktop
- GitHub

---

<h2><a class="anchor" id="project-structure"></a>Project Structure</h2>

```
employee-performance-analytics/
│
├── README.md
├── Employee_Performance.sql          # Full SQL: cleaning + indexes + 14 analysis queries
│
├── data/
│   ├── employees.csv
│   ├── engagement.csv
│   ├── training.csv
│   └── recruitment.csv
│
├── dashboard/
│   └── employee_performance_dashboard.pbix
│
└── screenshots/
    ├── 01_Workforce_Overview.png
    ├── 02_Attrition_Performance.png
    └── 03_Training_Recruitment.png
```

---

<h2><a class="anchor" id="data-cleaning--preparation"></a>Data Cleaning & Preparation</h2>

- Parsed mixed-format date columns using `STR_TO_DATE()` — raw CSV had inconsistent date formats across source tables
- Removed BOM (Byte Order Mark) characters from column headers introduced during CSV export
- Applied `TRIM()` across all VARCHAR columns to strip leading/trailing whitespace
- Validated `churn`-equivalent `EmployeeStatus` column — confirmed all values fall within expected categories (Active, Terminated, Leave of Absence, Future Start, Voluntarily Terminated)
- Handled NULLs in engagement and training tables with `LEFT JOIN` rather than `INNER JOIN` to retain all employee records
- Added composite indexes on `(DepartmentType, EmployeeStatus)` and prefix indexes on VARCHAR columns for query performance
- Verified referential integrity across 4 tables: all 3,000 `EmpID` values in `employees` have matching records in `engagement`, `training`, and `recruitment`

---

<h2><a class="anchor" id="exploratory-data-analysis-eda"></a>Exploratory Data Analysis (EDA)</h2>

**Workforce Snapshot:**
- Total employees: 3,000 | Active: 2,458 | Terminated: 387 | Attrition rate: **12.90%**
- Avg engagement score: **2.94 / 5** | Avg satisfaction score: **3.02 / 5**

**Department Breakdown:**
- Production is the largest department at 2,020 employees (67.3% of workforce)
- Software Engineering has only 115 employees but the highest attrition rate at **17.4%**

**Employment Type:**
- Full-Time: 1,038 | Contract: 1,008 | Part-Time: 954 — near-even three-way split

**Performance Distribution:**
- Fully Meets: 2,361 (78.7%) | Exceeds: 369 (12.3%) | Needs Improvement: 177 (5.9%) | PIP: 93 (3.1%)

**Pay Zone:**
- Zone A: 1,062 (35.4%) | Zone B: 985 (32.8%) | Zone C: 953 (31.8%) — roughly balanced

**Training:**
- Total spend: **$1,675,886** | Success rate: **50.3%** | Production absorbs $1.13M of total training cost
- Internal vs External training: 50/50 split (1,491 internal, 1,509 external)

**Recruitment:**
- Offer rate: **20.33%** | Pipeline near-uniform across stages: Applied (611) through Interviewed (590)
- Avg desired salary varies little by education — Master's ($65,482) vs High School ($64,549)

**Counterintuitive finding:**
- "Exceeds" performers attriting at **10.8%** — nearly as high as "Needs Improvement" (11.3%). High performers are leaving at almost the same rate as underperformers. The flight risk query was built specifically because of this pattern.

---

<h2><a class="anchor" id="research-questions--key-findings"></a>Research Questions & Key Findings</h2>

### 1. Flight Risk Detection — High Performers Underpaid & Disengaged

```sql
WITH dept_ranked AS (
    SELECT
        e.EmpID, e.DepartmentType, e.Title, e.PayZone,
        e.PerformanceScore, e.CurrentEmployeeRating,
        e.EmployeeStatus,
        TIMESTAMPDIFF(YEAR, e.StartDate, CURDATE())               AS tenure_years,
        s.EngagementScore, s.SatisfactionScore,
        RANK() OVER (PARTITION BY e.DepartmentType
                     ORDER BY e.CurrentEmployeeRating DESC)        AS dept_rank
    FROM  employees e
    JOIN  engagement s ON e.EmpID = s.EmployeeID
    WHERE e.EmployeeStatus = 'Active'
)
SELECT
    EmpID, DepartmentType, Title, PayZone,
    PerformanceScore, CurrentEmployeeRating, dept_rank,
    tenure_years, EngagementScore, SatisfactionScore,
    CASE
        WHEN EngagementScore <= 2 AND SatisfactionScore <= 2 THEN 'CRITICAL — Actively Disengaged'
        WHEN EngagementScore <= 3                            THEN 'HIGH RISK — Low Engagement'
        ELSE                                                      'MONITOR'
    END AS flight_risk
FROM  dept_ranked
WHERE PayZone              =  'Zone A'
  AND CurrentEmployeeRating >= 4
  AND PerformanceScore      IN ('Exceeds', 'Fully Meets')
ORDER BY flight_risk, CurrentEmployeeRating DESC, EngagementScore;
```

**Answers:** Who are we about to lose without knowing it?
→ Flags Zone A employees rated 4+ with strong performance scores but low engagement — the highest-value flight risk group.

---

### 2. Z-Score Outlier Detection — Who Stands Out Statistically?

```sql
WITH dept_stats AS (
    SELECT
        DepartmentType,
        ROUND(AVG(CurrentEmployeeRating),        4) AS dept_mean,
        ROUND(STDDEV_POP(CurrentEmployeeRating), 4) AS dept_stddev
    FROM  employees
    GROUP BY DepartmentType
),
z_scored AS (
    SELECT
        e.EmpID, e.DepartmentType, e.Title,
        e.CurrentEmployeeRating, e.PerformanceScore,
        s.dept_mean, s.dept_stddev,
        ROUND(
            (e.CurrentEmployeeRating - s.dept_mean)
            / NULLIF(s.dept_stddev, 0),
        2) AS z_score
    FROM  employees e
    JOIN  dept_stats s ON e.DepartmentType = s.DepartmentType
)
SELECT *,
    CASE
        WHEN z_score >  2 THEN 'Exceptional Outlier — Promote / Retain'
        WHEN z_score < -2 THEN 'Low Outlier — Intervention Needed'
    END AS outlier_action
FROM  z_scored
WHERE ABS(z_score) > 2
ORDER BY z_score DESC;
```

**Answers:** Which employees are statistically exceptional or critically underperforming relative to their department?
→ Uses `STDDEV_POP()` per department; `NULLIF` guards against divide-by-zero in single-employee departments. Flags anyone beyond ±2 standard deviations for action.

---

### 3. Training ROI — Cost Per Successful Outcome

```sql
SELECT
    e.DepartmentType,
    COUNT(*)                                                                                AS total_trainings,
    SUM(CASE WHEN t.TrainingOutcome IN ('Passed','Completed') THEN 1 ELSE 0 END)          AS successful,
    ROUND(
        100.0 * SUM(CASE WHEN t.TrainingOutcome IN ('Passed','Completed') THEN 1 ELSE 0 END)
        / COUNT(*), 1
    )                                                                                        AS success_rate_pct,
    ROUND(SUM(t.TrainingCost), 0)                                                           AS total_cost,
    ROUND(
        SUM(t.TrainingCost) /
        NULLIF(SUM(CASE WHEN t.TrainingOutcome IN ('Passed','Completed') THEN 1 ELSE 0 END), 0),
    0)                                                                                       AS cost_per_success
FROM       employees e
JOIN       training  t ON e.EmpID = t.EmployeeID
GROUP BY   e.DepartmentType
ORDER BY   success_rate_pct DESC;
```

**Answers:** Which departments get the best return on training spend?
→ Admin Offices leads at 53% success rate; Production spends the most ($1.13M) but sits mid-table on success rate. Cost per success is the real efficiency metric — not total spend.

---

### 4. Recruitment Funnel + NTILE Salary Banding

```sql
-- Salary quartile banding — does salary expectation affect offer rate?
WITH salary_ranked AS (
    SELECT
        ApplicantID, JobTitle, EducationLevel,
        YearsOfExperience, DesiredSalary, Status,
        NTILE(4) OVER (ORDER BY DesiredSalary)                         AS salary_quartile,
        ROUND(PERCENT_RANK() OVER (ORDER BY DesiredSalary) * 100, 1)  AS salary_percentile
    FROM recruitment
)
SELECT
    salary_quartile,
    CASE salary_quartile
        WHEN 1 THEN 'Q1 — $30K–$47K'
        WHEN 2 THEN 'Q2 — $47K–$65K'
        WHEN 3 THEN 'Q3 — $65K–$82K'
        WHEN 4 THEN 'Q4 — $82K–$100K'
    END                                            AS salary_band,
    COUNT(*)                                       AS applicants,
    ROUND(AVG(YearsOfExperience), 1)               AS avg_years_exp,
    SUM(CASE WHEN Status = 'Offered' THEN 1 ELSE 0 END) AS offers
FROM   salary_ranked
GROUP BY salary_quartile
ORDER BY salary_quartile;
```

**Answers:** Does salary expectation affect hiring outcomes?
→ Overall offer rate: **20.33%**. Pipeline is near-uniform across all stages (Applied through Interviewed hover around 590–611). Avg desired salary barely varies by education level — Master's ($65,482) vs High School ($64,549) — a $933 spread across four education tiers.

---

### 5. Executive Summary Dashboard Query — All KPIs Per Department

```sql
WITH
dept_base AS (
    SELECT
        e.DepartmentType,
        COUNT(DISTINCT e.EmpID)                                                   AS headcount,
        ROUND(AVG(e.CurrentEmployeeRating), 2)                                    AS avg_rating,
        ROUND(AVG(s.EngagementScore),       2)                                    AS avg_engagement,
        ROUND(
            100.0 * SUM(CASE WHEN t.TrainingOutcome IN ('Passed','Completed') THEN 1 ELSE 0 END)
            / NULLIF(COUNT(t.TrainingOutcome), 0), 1
        )                                                                           AS training_success_pct,
        ROUND(
            100.0 * SUM(CASE WHEN e.EmployeeStatus LIKE '%Terminated%' THEN 1 ELSE 0 END)
            / COUNT(DISTINCT e.EmpID), 1
        )                                                                           AS attrition_pct
    FROM      employees  e
    LEFT JOIN engagement s ON e.EmpID = s.EmployeeID
    LEFT JOIN training   t ON e.EmpID = t.EmployeeID
    GROUP BY  e.DepartmentType
),
median_calc AS (
    SELECT DepartmentType, AVG(CurrentEmployeeRating) AS median_rating
    FROM (
        SELECT DepartmentType, CurrentEmployeeRating,
               ROW_NUMBER() OVER (PARTITION BY DepartmentType ORDER BY CurrentEmployeeRating) AS rn,
               COUNT(*)     OVER (PARTITION BY DepartmentType)                                AS cnt
        FROM employees
    ) numbered
    WHERE rn IN (FLOOR((cnt+1)/2), CEIL((cnt+1)/2))
    GROUP BY DepartmentType
)
SELECT b.*, ROUND(m.median_rating, 1) AS median_rating
FROM  dept_base   b
JOIN  median_calc m ON b.DepartmentType = m.DepartmentType
ORDER BY b.headcount DESC;
```

**Answers:** One query for C-suite: headcount, attrition, training success, and avg engagement per department.
→ `ROW_NUMBER()` workaround used for median — MySQL 8.0 lacks `PERCENTILE_CONT`. Chained CTEs keep `dept_base` and `median_calc` logic separate and readable.

---

<h2><a class="anchor" id="dashboard"></a>Dashboard</h2>

3-tab Power BI dashboard connected to MySQL via the `hr_database` tables (`employees`, `engagement`, `recruitment`, `training`). All tabs include a **Filter by Department** slicer.

---

**Tab 1 — Workforce Overview**
KPI cards (3,000 employees, 2,458 active, 12.90% attrition, 2.94 avg engagement), employees by department bar chart, employment type breakdown, gender distribution, pay zone split, performance score distribution.

![Workforce Overview](screenshots/01_Workforce_Overview.png)

---

**Tab 2 — Attrition & Performance**
KPI cards (387 terminated, 12.90% attrition, 3.02 avg satisfaction), attrition by department, attrition by performance score, engagement score by performance tier, employee status breakdown donut, attrition by gender, attrition by pay zone.

![Attrition & Performance](screenshots/02_Attrition_Performance.png)

---

**Tab 3 — Training & Recruitment**
KPI cards ($1,675,886 total training cost, 50.30% success rate, 20.33% offer rate), training success rate by department, training cost by department, training outcome distribution, internal vs external split, most common programs, recruitment pipeline by status, avg desired salary by education level.

![Training & Recruitment](screenshots/03_Training_Recruitment.png)

---

<h2><a class="anchor" id="how-to-run-this-project"></a>How to Run This Project</h2>

1. Clone the repository:
```bash
git clone https://github.com/yourusername/employee-performance-analytics.git
```

2. Set up the database in MySQL Workbench:
```sql
-- Create schema and load all 4 tables from /data/ CSVs
-- Full setup included at the top of Employee_Performance.sql
SOURCE Employee_Performance.sql;
```

3. Open Power BI Desktop and connect to MySQL:
   - Data Source: MySQL database → `hr_database`
   - Load tables: `employees`, `engagement`, `training`, `recruitment`
   - Open `dashboard/employee_performance_dashboard.pbix`

---

<h2><a class="anchor" id="final-recommendations"></a>Final Recommendations</h2>

**Summary of key findings:**

| Metric | Value | Implication |
|---|---|---|
| Overall attrition rate | 12.90% | 387 employees lost across 3,000 |
| Highest attrition dept | Software Engineering — 17.4% | Small team (115) losing at high rate |
| PIP attrition | 19.4% | Expected — but not significantly above "Exceeds" (10.8%) |
| "Exceeds" attrition | 10.8% | Nearly as high as "Needs Improvement" (11.3%) — alarming |
| Total training spend | $1,675,886 | 50.3% success rate — half the spend delivers no outcome |
| Recruitment offer rate | 20.33% | Pipeline near-uniform — no major bottleneck stage |
| Avg engagement score | 2.94 / 5 | Below midpoint across all performance tiers |

**Immediate actions:**
- Run the flight risk query to identify Zone A high performers with engagement scores under 3 — these are the employees most likely to leave before any warning signal appears in HR systems
- Software Engineering at 17.4% attrition warrants a focused exit interview analysis — a department of 115 losing at that rate has disproportionate impact on delivery capacity
- The 50% training failure rate ($837K in spend on incomplete/failed outcomes) requires a department-level cost-per-success review before the next training budget cycle

**For the next iteration:**
- Normalize the schema — `PerformanceScore` stored as TEXT; a lookup table with integer FK would be cleaner and faster to sort
- Build stored procedures for the flight risk and executive dashboard queries — parameterize by department instead of hardcoding `'Zone A'`
- Create a materialized summary table for the `dept_base` CTE — recomputing on every dashboard refresh is unnecessary overhead
- Use `PERCENTILE_CONT` for median calculation — the `ROW_NUMBER()` workaround works but a PostgreSQL port would be cleaner
- Add salary-to-performance ratio as an attrition driver — Zone A pays less than Zone C by definition, but the gap relative to individual performance rating is the real signal
