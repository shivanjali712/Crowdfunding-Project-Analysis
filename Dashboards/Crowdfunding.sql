SET GLOBAL SQL_SAFE_UPDATES = 0;

Create database crowdfunding;
use Crowdfunding;
show tables;

SELECT * FROM projects LIMIT 10;
select count(projectID) as No_of_Projects from projects;

-- Q.1 Convert the Date fields to Natural Time 
ALTER TABLE projects ADD COLUMN created_at_modified DATETIME;
UPDATE projects
SET created_at_modified = FROM_UNIXTIME(created_at);

ALTER TABLE projects ADD COLUMN deadline_modified DATETIME;
UPDATE projects
SET deadline_modified = FROM_UNIXTIME(deadline);

ALTER TABLE projects ADD COLUMN updated_at_modified DATETIME;
UPDATE projects
SET updated_at_modified = FROM_UNIXTIME(updated_at);

ALTER TABLE projects ADD COLUMN state_changed_at_modified DATETIME;
UPDATE projects
SET state_changed_at_modified = FROM_UNIXTIME(state_changed_at);

ALTER TABLE projects ADD COLUMN successful_at_modified DATETIME;
UPDATE projects
SET successful_at_modified = 
CASE 
WHEN successful_at = 0 THEN null     -- or another default value
ELSE FROM_UNIXTIME(successful_at)
END;

ALTER TABLE projects ADD COLUMN launched_at_modified DATETIME;
UPDATE projects
SET launched_at_modified = FROM_UNIXTIME(launched_at);

-- Q.2  Build a Calendar Table using the Date Column Created Date. (created)
SELECT 
    created_at_modified,
    YEAR(created_at_modified) AS Year,
    MONTH(created_at_modified) AS MonthNo,
    DATE_FORMAT(created_at_modified, '%M') AS MonthFullName,
    CONCAT('Q', QUARTER(created_at_modified)) AS Quarter,
    DATE_FORMAT(created_at_modified, '%Y-%b') AS YearMonth,
    DAYOFWEEK(created_at_modified) AS WeekdayNo,
    DATE_FORMAT(created_at_modified, '%W') AS WeekdayName,
    
    -- Financial Month (April = FM1, May = FM2, ..., March = FM12)
    CASE 
        WHEN MONTH(created_at_modified) = 4 THEN 'FM1'
        WHEN MONTH(created_at_modified) = 5 THEN 'FM2'
        WHEN MONTH(created_at_modified) = 6 THEN 'FM3'
        WHEN MONTH(created_at_modified) = 7 THEN 'FM4'
        WHEN MONTH(created_at_modified) = 8 THEN 'FM5'
        WHEN MONTH(created_at_modified) = 9 THEN 'FM6'
        WHEN MONTH(created_at_modified) = 10 THEN 'FM7'
        WHEN MONTH(created_at_modified) = 11 THEN 'FM8'
        WHEN MONTH(created_at_modified) = 12 THEN 'FM9'
        WHEN MONTH(created_at_modified) = 1 THEN 'FM10'
        WHEN MONTH(created_at_modified) = 2 THEN 'FM11'
        WHEN MONTH(created_at_modified) = 3 THEN 'FM12'
    END AS FinancialMonth,

    -- Financial Quarter (Based on Financial Months)
    CASE 
        WHEN MONTH(created_at_modified) IN (4,5,6) THEN 'FQ-1'
        WHEN MONTH(created_at_modified) IN (7,8,9) THEN 'FQ-2'
        WHEN MONTH(created_at_modified) IN (10,11,12) THEN 'FQ-3'
        WHEN MONTH(created_at_modified) IN (1,2,3) THEN 'FQ-4'
    END AS FinancialQuarter

FROM projects;

-- Q.3  Build the Data Model using the attached Excel Files.(used joins)
SELECT p.p_name, c.c_name, l.country
FROM projects p
JOIN crowdfunding_category c ON p.category_id = c.c_id
JOIN crowdfunding_location l ON p.location_id = l.i_id;

-- Q.4  Convert the Goal amount into USD using the Static USD Rate.
ALTER TABLE projects ADD COLUMN Goal_Amount int;
UPDATE projects SET Goal_Amount = Goal*static_usd_rate;

-- Q.5.1 Projects Overview KPI :   Total Number of Projects based on outcome    
select state as Outcome ,count(projectID) as No_of_Projects from projects group by state;

-- Q.5.2  Total Number of Projects based on Locations
select country as Location,count(projectid) from projects group by country;

-- Q.5.3 Total Number of Projects based on  Category
SELECT c.c_name AS Category,
COUNT(p.projectID) AS No_of_projects
FROM crowdfunding_category c
LEFT JOIN projects p ON c.c_id = p.category_id
GROUP BY c.c_name
ORDER BY No_of_projects DESC;

-- Q.5.4  Total Number of Projects created by Year , Quarter , Month
select Year,Quarter,Month_name,No_of_Projects
from (SELECT YEAR(created_at_modified) AS Year, 
             MONTH(created_at_modified) AS Month,
             QUARTER(created_at_modified) AS quarter,
             MONTHname(created_at_modified) AS Month_Name, 
             COUNT(*) AS No_of_projects
FROM projects
GROUP BY year,month,Quarter,month_name
order by year, quarter,month) as P;


-- Q.6.1 Successful Projects based on Amount Raised
select state,concat(round(sum(goal_amount)/1000000),'M') as Amount_Raised 
from projects where state="successful";

-- Q.6.2 Successful Projects based on No of Backers
select state,concat(round(sum(backers_count)/1000000),'M') as No_of_Backers 
from projects where state="successful";

-- Q.6.3 Average no of days for Successful Projects 
SELECT 
round(AVG(DATEDIFF(successful_at_modified,created_at_modified)),2) AS Average_Days
FROM projects
WHERE state = 'successful';

-- Q.7.1  Top Successful Projects :Based on Number of Backers
select p_name,concat(round(Backers_count/1000),'K') as No_of_Backers 
from projects where state="successful" order by Backers_count desc limit 10;

-- Q.7.2  Top Successful Projects :Based on Amount Raised
select p_name,concat(round(goal_amount/1000000),'M') as Amount_Raised
 from projects where state="successful" order by goal_amount desc limit 10 ;
 
 -- Q.8.1  Percentage of Successful Projects overall
SELECT 
    concat(round(COUNT(CASE WHEN state = 'successful' THEN 1 END) * 100.0 / COUNT(*),2),"%") AS percentage_successful_projects
FROM 
    projects;
    
-- Q.8.2 Percentage of Successful Projects  by Category
SELECT 
  c.c_name AS Category,
  CONCAT(ROUND(COUNT(CASE WHEN p.state = 'successful' THEN 1 END) * 100.0 / COUNT(*), 2), '%') AS percentage_successful_projects
FROM crowdfunding_category c
LEFT JOIN projects p ON c.c_id = p.category_id
GROUP BY c.c_name
ORDER BY c.c_name;

-- Q.8.3 Percentage of Successful Projects by Year , Month
SELECT 
    YEAR(p.created_at_modified) AS project_year,
    MONTH(p.created_at_modified) AS project_month,
    COUNT(CASE WHEN p.state = 'Successful' THEN 1 END) * 100.0 / COUNT(*) AS success_percentage
FROM projects p
GROUP BY project_year, project_month
ORDER BY project_year DESC, project_month ASC;

-- Q.8.3 Percentage of Successful Projects by Goal Range
SELECT 
    CASE 
        WHEN Goal_Amount < 10000 THEN 'Small (<10K)'
        WHEN Goal_Amount BETWEEN 10000 AND 50000 THEN 'Medium (10K-50K)'
        WHEN Goal_Amount BETWEEN 50000 AND 100000 THEN 'Large (50K-100K)'
        ELSE 'Extra Large (>100K)'
    END AS goal_range,
    COUNT(CASE WHEN state = 'Successful' THEN 1 END) * 100.0 / COUNT(*) AS success_percentage
FROM projects
GROUP BY goal_range
ORDER BY success_percentage DESC;

