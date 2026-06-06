CREATE DATABASE `hr_database`
    CHARACTER SET  utf8mb4
    COLLATE        utf8mb4_unicode_ci;

USE `hr_database`;

-- Confirm you switched to the correct database
SELECT DATABASE();
-- Should return: hr_database

-- After importing the employee_data table
SELECT * FROM employee_data;


-- Data Cleaning on table employees

-- 1. Turn off safe mode
SET SQL_SAFE_UPDATES = 0;

-- 2. Fix the BOM character on EmpID
ALTER TABLE employee_data 
CHANGE `ï»¿EmpID` `EmpID` INT;


-- 3. Fix trailing spaces in DepartmentType
UPDATE employee_data
SET DepartmentType = TRIM(DepartmentType);

SELECT DISTINCT DepartmentType FROM employee_data;
SELECT EmpID FROM employees LIMIT 3;


-- Fix StartDate 'Text to Date'
ALTER TABLE employees ADD COLUMN StartDate_fixed DATE;
UPDATE employees SET StartDate_fixed = STR_TO_DATE(StartDate, '%d-%b-%Y');
ALTER TABLE employees DROP COLUMN StartDate;
ALTER TABLE employees RENAME COLUMN StartDate_fixed TO StartDate;
SELECT StartDate FROM employees LIMIT 5;

-- Fix DOB 'Text to Date'
SELECT DOB FROM employees LIMIT 5;
ALTER TABLE employees ADD COLUMN DOB_fixed DATE;
UPDATE employees
SET DOB_fixed = CASE
    WHEN DOB LIKE '%/%' 
        THEN STR_TO_DATE(DOB, '%d/%m/%Y')
    WHEN DOB LIKE '%-%' 
        THEN STR_TO_DATE(DOB, '%d-%m-%Y')
    ELSE NULL
END;

SELECT 
    COUNT(*)                                                    AS total,
    SUM(CASE WHEN DOB_fixed IS NOT NULL THEN 1 ELSE 0 END)     AS converted,
    SUM(CASE WHEN DOB_fixed IS NULL     THEN 1 ELSE 0 END)     AS failed
FROM employees;

ALTER TABLE employees DROP COLUMN DOB;
ALTER TABLE employees RENAME COLUMN DOB_fixed TO DOB;


-- ExitDate (allow NULL for active employees)
SELECT ExitDate FROM employees LIMIT 25;
ALTER TABLE employees ADD COLUMN ExitDate_fixed DATE;
UPDATE employees SET ExitDate_fixed = STR_TO_DATE(ExitDate, '%d-%b-%Y')
WHERE employees IS NOT NULL AND ExitDate != '';
ALTER TABLE employees DROP COLUMN ExitDate;
ALTER TABLE employees RENAME COLUMN ExitDate_fixed TO ExitDate;

-- Verifying the dattype
SELECT StartDate, DOB, ExitDate FROM employees LIMIT 30;

-- Change column name

ALTER TABLE employees
CHANGE `Current Employee Rating` `CurrentEmployeeRating` INT;

ALTER TABLE employees
CHANGE `Performance Score` `PerformanceScore` TEXT;

SELECT CurrentEmployeeRating FROM employees LIMIT 3;



-- engagement table

SELECT * FROM engagement;

ALTER TABLE engagement
CHANGE `Employee ID`             `EmployeeID`           INT,
CHANGE `Survey Date`             `SurveyDate`           TEXT,
CHANGE `Engagement Score`        `EngagementScore`      INT,
CHANGE `Satisfaction Score`      `SatisfactionScore`    INT,
CHANGE `Work-Life Balance Score` `WorkLifeBalanceScore` INT;



-- training table

SELECT * FROM training;

ALTER TABLE training
CHANGE `Employee ID`             `EmployeeID`           INT,
CHANGE `Training Date`           `TrainingDate`         TEXT,
CHANGE `Training Program Name`   `TrainingProgramName`  VARCHAR(100),
CHANGE `Training Type`           `TrainingType`         VARCHAR(20),
CHANGE `Training Outcome`        `TrainingOutcome`      VARCHAR(20),
CHANGE `Training Duration(Days)` `TrainingDurationDays` INT,
CHANGE `Training Cost`           `TrainingCost`         DECIMAL(10,2);

ALTER TABLE training ADD COLUMN TrainingDate_fixed DATE;
UPDATE training SET TrainingDate_fixed = STR_TO_DATE(TrainingDate, '%d-%b-%y');

ALTER TABLE training DROP COLUMN TrainingDate;
ALTER TABLE training RENAME COLUMN TrainingDate_fixed TO TrainingDate;

SELECT TrainingDate FROM training;



-- recruitment table

UPDATE recruitment
SET `Phone Number` = NULL
WHERE `Phone Number` LIKE '%#%';

SELECT * FROM recruitment LIMIT 25;

ALTER TABLE recruitment
CHANGE `Applicant ID`         `ApplicantID`        INT,
CHANGE `Application Date`     `ApplicationDate`    TEXT,
CHANGE `First Name`           `FirstName`          VARCHAR(60),
CHANGE `Last Name`            `LastName`           VARCHAR(60),
CHANGE `Date of Birth`        `DateOfBirth`        TEXT,
CHANGE `Phone Number`         `PhoneNumber`        VARCHAR(30),
CHANGE `Zip Code`             `ZipCode`            VARCHAR(10),
CHANGE `Education Level`      `EducationLevel`     VARCHAR(40),
CHANGE `Years of Experience`  `YearsOfExperience`  INT,
CHANGE `Desired Salary`       `DesiredSalary`      DECIMAL(10,2),
CHANGE `Job Title`            `JobTitle`           VARCHAR(120);


-- Fixing Application Date column format:
ALTER TABLE recruitment ADD COLUMN ApplicationDate_fixed DATE;
UPDATE recruitment SET ApplicationDate_fixed = STR_TO_DATE(ApplicationDate, '%d-%b-%y');
ALTER TABLE recruitment DROP COLUMN ApplicationDate;
ALTER TABLE recruitment RENAME COLUMN ApplicationDate_fixed TO ApplicationDate;


-- Fixing Date of Birth Date format 
ALTER TABLE recruitment ADD COLUMN DateOfBirth_fixed DATE;
UPDATE recruitment
SET DateOfBirth_fixed = CASE
    WHEN DateOfBirth LIKE '%/%' 
        THEN STR_TO_DATE(DateOfBirth, '%d/%m/%Y')
    WHEN DateOfBirth LIKE '%-%' 
        THEN STR_TO_DATE(DateOfBirth, '%d-%m-%Y')
    ELSE NULL
END;

ALTER TABLE recruitment DROP COLUMN DateOfBirth;
ALTER TABLE recruitment RENAME COLUMN DateOfBirth_fixed TO DateOfBirth;

SELECT ApplicationDate, DateOfBirth 
FROM recruitment 
LIMIT 5;


-- Verify load
SELECT 'employees'   AS table_name, COUNT(*) AS number_rows FROM employees
UNION ALL
SELECT 'engagement'  AS table_name, COUNT(*) FROM engagement
UNION ALL
SELECT 'training'    AS table_name, COUNT(*) FROM training
UNION ALL
SELECT 'recruitment' AS table_name, COUNT(*) FROM recruitment;


-- Fix column types in employees
ALTER TABLE employees
  MODIFY COLUMN DepartmentType  VARCHAR(60),
  MODIFY COLUMN EmployeeStatus  VARCHAR(40),
  MODIFY COLUMN PayZone         VARCHAR(10),
  MODIFY COLUMN PerformanceScore VARCHAR(30);

-- Fix column types in other tables
ALTER TABLE training
  MODIFY COLUMN TrainingOutcome VARCHAR(20);

ALTER TABLE recruitment
  MODIFY COLUMN Status        VARCHAR(30),
  MODIFY COLUMN EducationLevel VARCHAR(40);



-- Indexes
-- employees — most used PARTITION BY / WHERE columns
CREATE INDEX idx_dept         ON employees (DepartmentType(50));
CREATE INDEX idx_status       ON employees (EmployeeStatus(40));
CREATE INDEX idx_payzone      ON employees (PayZone(10));
CREATE INDEX idx_dept_rating  ON employees (DepartmentType(50), CurrentEmployeeRating DESC);
CREATE INDEX idx_perf         ON employees (PerformanceScore(30));

-- engagement / training — JOIN keys
CREATE INDEX idx_eng_emp      ON engagement(EmployeeID);
CREATE INDEX idx_trn_emp      ON training (EmployeeID);
CREATE INDEX idx_trn_outcome  ON training (TrainingOutcome(20));

-- recruitment — standalone queries
CREATE INDEX idx_rec_status   ON recruitment (Status(30));
CREATE INDEX idx_rec_edu      ON recruitment (EducationLevel(40));

-- Turn safe mode back on
SET SQL_SAFE_UPDATES = 1;



-- Analyzing and Extracting Insights

-- 1 — Rank Employees Within Department by Performance Rating

SELECT
    `EmpID`,
    `DepartmentType`,
    `Title`,
    `PayZone`,
    `CurrentEmployeeRating`,
    `PerformanceScore`,

    RANK()       OVER (PARTITION BY `DepartmentType` ORDER BY `CurrentEmployeeRating` DESC) AS `rating_rank`,
    DENSE_RANK() OVER (PARTITION BY `DepartmentType` ORDER BY `CurrentEmployeeRating` DESC) AS `rating_dense_rank`,
    ROW_NUMBER() OVER (PARTITION BY `DepartmentType` ORDER BY `CurrentEmployeeRating` DESC) AS `row_num`

FROM  `employees`
ORDER BY `DepartmentType`, `CurrentEmployeeRating` DESC
LIMIT 10;


-- 2 — Each Employee vs. Department Average Rating
SELECT
    `EmpID`,
    `DepartmentType`,
    `Title`,
    `PayZone`,
    `CurrentEmployeeRating`,
    `PerformanceScore`,

    ROUND(AVG(`CurrentEmployeeRating`) OVER (PARTITION BY `DepartmentType`), 2)
        AS `dept_avg_rating`,

    ROUND(`CurrentEmployeeRating` -
        AVG(`CurrentEmployeeRating`) OVER (PARTITION BY `DepartmentType`), 2)
        AS `diff_from_avg`,

    CASE
        WHEN `CurrentEmployeeRating` - AVG(`CurrentEmployeeRating`) OVER (PARTITION BY `DepartmentType`) >=  1 THEN 'Above Average'
        WHEN `CurrentEmployeeRating` - AVG(`CurrentEmployeeRating`) OVER (PARTITION BY `DepartmentType`) <= -1 THEN 'Below Average'
        ELSE                                                                                                          'At Average'
    END                                                                                                               AS `rating_tier`

FROM  `employees`
ORDER BY `DepartmentType`, `CurrentEmployeeRating` DESC
LIMIT 8;


-- 3. — Top 10% Performers Company-Wide
WITH `ranked` AS (
    SELECT
        `EmpID`, `DepartmentType`, `Title`, `PayZone`,
        `PerformanceScore`, `CurrentEmployeeRating`,
        ROUND(PERCENT_RANK() OVER (ORDER BY `CurrentEmployeeRating`) * 100, 1) AS `percentile`
    FROM `employees`
)
SELECT *
FROM  `ranked`
WHERE `percentile` >= 90.0
ORDER BY `CurrentEmployeeRating` DESC, `DepartmentType`
LIMIT 10;



-- 4 — Attrition Rate by Department and Termination Type
SELECT
    `DepartmentType`,
    COUNT(*)                                                                                      AS `total_employees`,
    SUM(CASE WHEN `EmployeeStatus` = 'Voluntarily Terminated'                 THEN 1 ELSE 0 END) AS `vol_left`,
    SUM(CASE WHEN `EmployeeStatus` = 'Terminated for Cause'                   THEN 1 ELSE 0 END) AS `cause_left`,
    SUM(CASE WHEN `EmployeeStatus` LIKE '%Terminated%'                          THEN 1 ELSE 0 END) AS `total_attrited`,
    ROUND(
        100.0 * SUM(CASE WHEN `EmployeeStatus` LIKE '%Terminated%' THEN 1 ELSE 0 END) / COUNT(*),
        1
    )                                                                                               AS `attrition_rate_pct`
FROM   `employees`
GROUP BY `DepartmentType`
ORDER BY `attrition_rate_pct` DESC;


-- 5 — Employee Tenure Analysis with TIMESTAMPDIFF
-- Identify long-tenured employees and classify retention risk by combining tenure with performance tier.
SELECT
    `EmpID`,
    `DepartmentType`,
    `Title`,
    `PayZone`,
    `PerformanceScore`,
    `CurrentEmployeeRating`,
    `EmployeeStatus`,
    `StartDate`,

    TIMESTAMPDIFF(YEAR, `StartDate`, CURDATE())       AS `tenure_years`,

    RANK() OVER (PARTITION BY `DepartmentType`
                 ORDER BY TIMESTAMPDIFF(YEAR, `StartDate`, CURDATE()) DESC)
                                                             AS `tenure_rank_in_dept`,

    CASE
        WHEN TIMESTAMPDIFF(YEAR, `StartDate`, CURDATE()) >= 8
         AND `PerformanceScore` = 'Exceeds'              THEN 'Critical — Veteran High Performer'
        WHEN TIMESTAMPDIFF(YEAR, `StartDate`, CURDATE()) >= 6
         AND `PayZone` = 'Zone A'                       THEN 'At Risk — Long Tenure, Low Pay Zone'
        WHEN TIMESTAMPDIFF(YEAR, `StartDate`, CURDATE()) >= 5                THEN 'Monitor — Senior Employee'
        ELSE                                                                     'Standard'
    END                                                        AS `retention_risk`

FROM  `employees`
WHERE `EmployeeStatus` = 'Active'
  AND TIMESTAMPDIFF(YEAR, `StartDate`, CURDATE()) >= 5
ORDER BY
    `retention_risk`,
    `tenure_years` DESC;


-- 6 — Performance Rating vs. Attrition (PIP Employees)
-- Do low performers leave more? 
SELECT
    `PerformanceScore`,
    CASE `PerformanceScore`
        WHEN 'Exceeds'           THEN 1
        WHEN 'Fully Meets'       THEN 2
        WHEN 'Needs Improvement' THEN 3
        WHEN 'PIP'               THEN 4
    END                                                                          AS `perf_order`,
    COUNT(*)                                                                   AS `total`,
    SUM(CASE WHEN `EmployeeStatus` LIKE '%Terminated%' THEN 1 ELSE 0 END)    AS `attrited`,
    ROUND(
        100.0 * SUM(CASE WHEN `EmployeeStatus` LIKE '%Terminated%' THEN 1 ELSE 0 END) / COUNT(*),
        1
    )                                                                            AS `attrition_pct`,
    ROUND(AVG(`CurrentEmployeeRating`), 2)                                     AS `avg_numeric_rating`
FROM   `employees`
GROUP BY `PerformanceScore`
ORDER BY `perf_order`;


-- 7 — PayZone Distribution Within Department + Attrition per Zone
SELECT
    `DepartmentType`,
    `PayZone`,
    COUNT(*)                                                                   AS `employees_in_zone`,

    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (PARTITION BY `DepartmentType`),
        1
    )                                                                            AS `pct_of_dept`,

    SUM(CASE WHEN `EmployeeStatus` LIKE '%Terminated%' THEN 1 ELSE 0 END)    AS `attrited`,

    ROUND(
        100.0 * SUM(CASE WHEN `EmployeeStatus` LIKE '%Terminated%' THEN 1 ELSE 0 END) / COUNT(*),
        1
    )                                                                            AS `attrition_pct`

FROM   `employees`
GROUP BY `DepartmentType`, `PayZone`
ORDER BY `DepartmentType`,
    CASE `PayZone` WHEN 'Zone A' THEN 1
                   WHEN 'Zone B' THEN 2
                   WHEN 'Zone C' THEN 3 END;
                   
                   
-- 8 — Cumulative Rating Distribution (CUME_DIST)
SELECT
    `EmpID`,
    `DepartmentType`,
    `Title`,
    `CurrentEmployeeRating`,
    `PerformanceScore`,
    `PayZone`,

    ROUND(
        CUME_DIST() OVER (PARTITION BY `DepartmentType` ORDER BY `CurrentEmployeeRating`) * 100,
        1
    ) AS `dept_percentile`,

    ROUND(
        CUME_DIST() OVER (ORDER BY `CurrentEmployeeRating`) * 100,
        1
    ) AS `company_percentile`,

    CASE
        WHEN CUME_DIST() OVER (ORDER BY `CurrentEmployeeRating`) >= 0.75 THEN 'Top 25%'
        WHEN CUME_DIST() OVER (ORDER BY `CurrentEmployeeRating`) >= 0.50 THEN 'Upper Mid'
        WHEN CUME_DIST() OVER (ORDER BY `CurrentEmployeeRating`) >= 0.25 THEN 'Lower Mid'
        ELSE                                                                      'Bottom 25%'
    END                                                                          AS `company_rating_band`

FROM  `employees`
ORDER BY `DepartmentType`, `CurrentEmployeeRating` DESC
LIMIT 10;


-- 9 — Z-Score: Rating Outliers Within Department
WITH `dept_stats` AS (
    SELECT
        `DepartmentType`,
        ROUND(AVG(`CurrentEmployeeRating`),        4) AS `dept_mean`,
        ROUND(STDDEV_POP(`CurrentEmployeeRating`), 4) AS `dept_stddev`
    FROM  `employees`
    GROUP BY `DepartmentType`
),
`z_scored` AS (
    SELECT
        e.`EmpID`,
        e.`DepartmentType`,
        e.`Title`,
        e.`PayZone`,
        e.`PerformanceScore`,
        e.`CurrentEmployeeRating`,
        e.`EmployeeStatus`,
        s.`dept_mean`,
        s.`dept_stddev`,
        ROUND(
            (e.`CurrentEmployeeRating` - s.`dept_mean`)
            / NULLIF(s.`dept_stddev`, 0),        -- NULLIF prevents divide-by-zero
            2
        ) AS `z_score`
    FROM  `employees` e
    JOIN  `dept_stats` s ON e.`DepartmentType` = s.`DepartmentType`
)
SELECT
    `EmpID`, `DepartmentType`, `Title`, `PayZone`,
    `PerformanceScore`, `CurrentEmployeeRating`,
    `dept_mean`, `dept_stddev`, `z_score`, `EmployeeStatus`,
    CASE
        WHEN `z_score` >  2 THEN 'Exceptional Outlier — Promote / Retain'
        WHEN `z_score` < -2 THEN 'Low Outlier — Intervention Needed'
    END        AS `outlier_action`
FROM  `z_scored`
WHERE ABS(`z_score`) > 2
ORDER BY `z_score` DESC;


-- 10 — Engagement Score vs. Performance
-- Do high performers report higher engagement, satisfaction, and work-life balance scores?
SELECT
    e.`PerformanceScore`,
    CASE e.`PerformanceScore`
        WHEN 'Exceeds'           THEN 1
        WHEN 'Fully Meets'       THEN 2
        WHEN 'Needs Improvement' THEN 3
        WHEN 'PIP'               THEN 4
    END                                      AS `perf_order`,
    COUNT(DISTINCT e.`EmpID`)               AS `employee_count`,
    ROUND(AVG(s.`EngagementScore`),      2) AS `avg_engagement`,
    ROUND(AVG(s.`SatisfactionScore`),    2) AS `avg_satisfaction`,
    ROUND(AVG(s.`WorkLifeBalanceScore`), 2) AS `avg_wlb`,
    MIN(s.`EngagementScore`)                AS `min_engagement`,
    MAX(s.`EngagementScore`)                AS `max_engagement`
FROM      `employees` e
JOIN      `engagement` s ON e.`EmpID` = s.`EmployeeID`
GROUP BY  e.`PerformanceScore`
ORDER BY  `perf_order`;


-- 11 — Training ROI: Success Rate and Cost by Department
-- JOIN employees + training to calculate training success rates and total spend per department.
SELECT
    e.`DepartmentType`,
    COUNT(*)                                                                               AS `total_trainings`,
    SUM(CASE WHEN t.`TrainingOutcome` IN ('Passed', 'Completed') THEN 1 ELSE 0 END)      AS `successful`,
    SUM(CASE WHEN t.`TrainingOutcome` IN ('Failed', 'Incomplete') THEN 1 ELSE 0 END)    AS `unsuccessful`,
    ROUND(
        100.0 * SUM(CASE WHEN t.`TrainingOutcome` IN ('Passed', 'Completed') THEN 1 ELSE 0 END)
        / COUNT(*),
        1
    )                                                                                       AS `success_rate_pct`,
    ROUND(SUM(t.`TrainingCost`), 0)                                                        AS `total_cost`,
    ROUND(AVG(t.`TrainingCost`), 0)                                                        AS `avg_cost_per_session`,
    ROUND(
        SUM(t.`TrainingCost`) /
        NULLIF(SUM(CASE WHEN t.`TrainingOutcome` IN ('Passed', 'Completed') THEN 1 ELSE 0 END), 0),
        0
    )                                                                                       AS `cost_per_success`
FROM       `employees` e
JOIN       `training`  t ON e.`EmpID` = t.`EmployeeID`
GROUP BY   e.`DepartmentType`
ORDER BY   `success_rate_pct` DESC;


-- 12 — High Performers in Zone A (Flight Risk)
-- Identify employees who rate high on performance but sit in the lowest pay zone AND report low engagement — the exact profile of someone about to resign.
WITH `dept_ranked` AS (
    SELECT
        e.`EmpID`,
        e.`DepartmentType`,
        e.`Title`,
        e.`PayZone`,
        e.`PerformanceScore`,
        e.`CurrentEmployeeRating`,
        e.`EmployeeStatus`,
        TIMESTAMPDIFF(YEAR, e.`StartDate`, CURDATE())               AS `tenure_years`,
        s.`EngagementScore`,
        s.`SatisfactionScore`,
        RANK() OVER (PARTITION BY e.`DepartmentType`
                     ORDER BY e.`CurrentEmployeeRating` DESC)        AS `dept_rank`
    FROM  `employees` e
    JOIN  `engagement` s ON e.`EmpID` = s.`EmployeeID`
    WHERE e.`EmployeeStatus` = 'Active'
)
SELECT
    `EmpID`,
    `DepartmentType`,
    `Title`,
    `PayZone`,
    `PerformanceScore`,
    `CurrentEmployeeRating`,
    `dept_rank`,
    `tenure_years`,
    `EngagementScore`,
    `SatisfactionScore`,
    CASE
        WHEN `EngagementScore` <= 2 AND `SatisfactionScore` <= 2 THEN 'CRITICAL — Actively Disengaged'
        WHEN `EngagementScore` <= 3                              THEN 'HIGH RISK — Low Engagement'
        ELSE                                                          'MONITOR'
    END                                                               AS `flight_risk`
FROM  `dept_ranked`
WHERE `PayZone`              =  'Zone A'
  AND `CurrentEmployeeRating` >= 4
  AND `PerformanceScore`      IN ('Exceeds', 'Fully Meets')
ORDER BY
    `flight_risk`,
    `CurrentEmployeeRating` DESC,
    `EngagementScore`;


-- 13 — Recruitment Pipeline: Hiring Funnel + Desired Salary by Education
-- Analyze the hiring funnel and desired salary expectations by education level — using NTILE(4) to tier applicants by salary expectation.

-- Part A: Hiring funnel by education level
-- How does education level affect hiring success?
SELECT
    `EducationLevel`,
    COUNT(*)                                                                   AS `total_applicants`,
    SUM(CASE WHEN `Status` = 'Offered'     THEN 1 ELSE 0 END)              AS `offers_made`,
    SUM(CASE WHEN `Status` = 'Rejected'    THEN 1 ELSE 0 END)              AS `rejected`,
    SUM(CASE WHEN `Status` = 'Interviewing'THEN 1 ELSE 0 END)              AS `interviewing`,
    ROUND(
        100.0 * SUM(CASE WHEN `Status` = 'Offered' THEN 1 ELSE 0 END) / COUNT(*),
        1
    )                                                                            AS `offer_rate_pct`,
    ROUND(AVG(`DesiredSalary`),  0)                                            AS `avg_desired_salary`,
    ROUND(MIN(`DesiredSalary`),  0)                                            AS `min_desired_salary`,
    ROUND(MAX(`DesiredSalary`),  0)                                            AS `max_desired_salary`
FROM   `recruitment`
GROUP BY `EducationLevel`
ORDER BY `avg_desired_salary` DESC;

-- Part B: Salary quartile banding on applicants using NTILE(4) + PERCENT_RANK
-- How does desired salary expectation affect hiring?
WITH `salary_ranked` AS (
    SELECT
        `ApplicantID`,
        `JobTitle`,
        `EducationLevel`,
        `YearsOfExperience`,
        `DesiredSalary`,
        `Status`,
        NTILE(4) OVER (ORDER BY `DesiredSalary`)                          AS `salary_quartile`,
        ROUND(PERCENT_RANK() OVER (ORDER BY `DesiredSalary`) * 100, 1)  AS `salary_percentile`
    FROM `recruitment`
)
SELECT
    `salary_quartile`,
    CASE `salary_quartile`
        WHEN 1 THEN 'Q1 — $30K–$47K'
        WHEN 2 THEN 'Q2 — $47K–$65K'
        WHEN 3 THEN 'Q3 — $65K–$82K'
        WHEN 4 THEN 'Q4 — $82K–$100K'
    END                                                        AS `salary_band`,
    COUNT(*)                                                  AS `applicants`,
    ROUND(AVG(`YearsOfExperience`), 1)                        AS `avg_years_exp`,
    SUM(CASE WHEN `Status` = 'Offered'  THEN 1 ELSE 0 END)  AS `offers`,
    ROUND(AVG(`DesiredSalary`), 0)                            AS `avg_salary_in_band`
FROM   `salary_ranked`
GROUP BY `salary_quartile`
ORDER BY `salary_quartile`;


-- 14 — Full Executive Dashboard
-- The complete C-suite summary: headcount, avg performance, avg engagement, training success, and attrition.
WITH
dept_base AS (
    -- Main department aggregates
    SELECT
        e.`DepartmentType`,
        COUNT(DISTINCT e.`EmpID`)                                                          AS `headcount`,
        ROUND(AVG(e.`CurrentEmployeeRating`),  2)                                          AS `avg_rating`,
        ROUND(AVG(s.`EngagementScore`),         2)                                          AS `avg_engagement`,
        ROUND(AVG(s.`SatisfactionScore`),       2)                                          AS `avg_satisfaction`,
        ROUND(
            100.0 * SUM(CASE WHEN t.`TrainingOutcome` IN ('Passed','Completed') THEN 1 ELSE 0 END)
            / NULLIF(COUNT(t.`TrainingOutcome`), 0),
            1
        )                                                                                    AS `training_success_pct`,
        ROUND(SUM(t.`TrainingCost`), 0)                                                    AS `total_training_cost`,
        ROUND(
            100.0 * SUM(CASE WHEN e.`EmployeeStatus` LIKE '%Terminated%' THEN 1 ELSE 0 END)
            / COUNT(DISTINCT e.`EmpID`),
            1
        )                                                                                    AS `attrition_pct`
    FROM      `employees`  e
    LEFT JOIN `engagement` s ON e.`EmpID` = s.`EmployeeID`
    LEFT JOIN `training`   t ON e.`EmpID` = t.`EmployeeID`
    GROUP BY  e.`DepartmentType`
),
median_calc AS (
    -- MySQL 8.0 median via ROW_NUMBER (no PERCENTILE_CONT available)
    SELECT
        `DepartmentType`,
        AVG(`CurrentEmployeeRating`) AS `median_rating`
    FROM (
        SELECT
            `DepartmentType`,
            `CurrentEmployeeRating`,
            ROW_NUMBER() OVER (PARTITION BY `DepartmentType` ORDER BY `CurrentEmployeeRating`) AS `rn`,
            COUNT(*)    OVER (PARTITION BY `DepartmentType`)                                    AS `cnt`
        FROM `employees`
    ) `numbered`
    WHERE `rn` IN (
        FLOOR((`cnt` + 1) / 2),   -- lower-middle row
        CEIL ((`cnt` + 1) / 2)    -- upper-middle row (same as lower for odd counts)
    )
    GROUP BY `DepartmentType`
)
SELECT
    b.`DepartmentType`,
    b.`headcount`,
    b.`avg_rating`,
    ROUND(m.`median_rating`, 1) AS `median_rating`,
    b.`avg_engagement`,
    b.`avg_satisfaction`,
    b.`training_success_pct`,
    b.`total_training_cost`,
    b.`attrition_pct`
FROM  `dept_base`    b
JOIN  `median_calc`  m ON b.`DepartmentType` = m.`DepartmentType`
ORDER BY b.`headcount` DESC;



-- Stretch Goal — NTILE(4) Rating Bands + Attrition
-- Divide each department into four equal-size performance quartiles using NTILE(4) on CurrentEmployeeRating, then measure attrition per band.
-- The business question: do lower-rated employees leave more?

-- 1. Rating Band Labels per Department
WITH `banded` AS (
    SELECT
        `EmpID`,
        `DepartmentType`,
        `Title`,
        `PayZone`,
        `CurrentEmployeeRating`,
        `PerformanceScore`,
        `EmployeeStatus`,
        `GenderCode`,
        NTILE(4) OVER (PARTITION BY `DepartmentType` ORDER BY `CurrentEmployeeRating` DESC) AS `rating_quartile`
    FROM `employees`
)
SELECT
    `EmpID`,
    `DepartmentType`,
    `Title`,
    `PayZone`,
    `CurrentEmployeeRating`,
    `PerformanceScore`,
    `EmployeeStatus`,
    `GenderCode`,
    `rating_quartile`,
    CASE `rating_quartile`
        WHEN 1 THEN 'Top 25% Performers'
        WHEN 2 THEN 'Upper Mid Performers'
        WHEN 3 THEN 'Lower Mid Performers'
        WHEN 4 THEN 'Bottom 25% Performers'
    END                       AS `rating_band`
FROM  `banded`
ORDER BY `DepartmentType`, `rating_quartile`, `CurrentEmployeeRating` DESC;


-- Attrition Rate per Rating Band — The Key Business Insight
WITH `banded` AS (
    SELECT
        `DepartmentType`,
        `EmployeeStatus`,
        NTILE(4) OVER (PARTITION BY `DepartmentType` ORDER BY `CurrentEmployeeRating` DESC) AS `quartile`
    FROM `employees`
)
SELECT
    `DepartmentType`,
    CASE `quartile`
        WHEN 1 THEN 'Top 25%'
        WHEN 2 THEN 'Upper Mid'
        WHEN 3 THEN 'Lower Mid'
        WHEN 4 THEN 'Bottom 25%'
    END                                                                          AS `rating_band`,
    `quartile`,
    COUNT(*)                                                                   AS `total`,
    SUM(CASE WHEN `EmployeeStatus` LIKE '%Terminated%' THEN 1 ELSE 0 END)    AS `attrited`,
    ROUND(
        100.0 * SUM(CASE WHEN `EmployeeStatus` LIKE '%Terminated%' THEN 1 ELSE 0 END) / COUNT(*),
        1
    )                                                                            AS `attrition_pct`
FROM  `banded`
GROUP BY `DepartmentType`, `quartile`
ORDER BY `DepartmentType`, `quartile`;