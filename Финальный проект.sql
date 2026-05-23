SET SQL_SAFE_UPDATES = 0;

UPDATE customers 
SET Gender = NULL 
WHERE Gender = '';
UPDATE customers 
SET Age = NULL 
WHERE Age = '';
alter table customers modify AGE int null;

select * from Transactions;

create table Transactions
(date_new date,
 Id_check int,
 ID_client int,
 Count_products decimal(10,3),
 Sum_payment decimal(10,2));
 
LOAD DATA INFILE "C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\TRANSACTIONS_final.csv"
INTO TABLE Transactions
FIELDS TERMINATED BY ","
LINES TERMINATED BY "\n"
IGNORE 1 ROWS;
 
 show variables like "secure_file_priv";

-- 1. Подготовка данных и фильтрация непрерывных клиентов
WITH MonthlyActivity AS (
    -- Определяем активность каждого клиента по месяцам
    SELECT 
        Id_client,
        DATE_FORMAT(date_new, '%Y-%m-01') AS month_start,
        Sum_payment
    FROM transactions
    WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
),
ContinuousClients AS (
    -- Фильтруем тех, у кого ровно 12 уникальных месяцев активности
    SELECT Id_client
    FROM MonthlyActivity
    GROUP BY Id_client
    HAVING COUNT(DISTINCT month_start) = 12
),
ClientMetrics AS (
    -- Рассчитываем метрики для таких клиентов
    SELECT 
        t.Id_client,
        SUM(t.Sum_payment) AS total_spent,
        COUNT(t.Sum_payment) AS total_ops,
        SUM(t.Sum_payment) / 12 AS avg_monthly_spent,
        SUM(t.Sum_payment) / COUNT(t.Sum_payment) AS avg_check
    FROM transactions t
    JOIN ContinuousClients cc ON t.Id_client = cc.Id_client
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY t.Id_client
)
-- Вывод списка клиентов
SELECT * FROM ClientMetrics;

-- 2. Информация в разрезе месяцев
SELECT 
    DATE_FORMAT(date_new, '%Y-%m') AS month,
    AVG(Sum_payment) AS avg_check_month,
    COUNT(Sum_payment) / COUNT(DISTINCT Id_client) AS avg_ops_per_client,
    COUNT(DISTINCT Id_client) AS active_clients,
    -- Доля операций месяца от годового объема
    COUNT(Sum_payment) * 100.0 / SUM(COUNT(Sum_payment)) OVER() AS pct_ops_month,
    -- Доля суммы месяца от годового объема
    SUM(Sum_payment) * 100.0 / SUM(SUM(Sum_payment)) OVER() AS pct_sum_month
FROM transactions
WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY month;

-- 3. Гендерная аналитика (% M/F/NA и их доли затрат)
SELECT 
    DATE_FORMAT(t.date_new, '%Y-%m') AS month,
    c.Gender,
    COUNT(t.Sum_payment) * 100.0 / SUM(COUNT(t.Sum_payment)) OVER(PARTITION BY DATE_FORMAT(t.date_new, '%Y-%m')) AS pct_ops_gender,
    SUM(t.Sum_payment) * 100.0 / SUM(SUM(t.Sum_payment)) OVER(PARTITION BY DATE_FORMAT(t.date_new, '%Y-%m')) AS pct_spend_gender
FROM transactions t
JOIN customers c ON t.Id_client = c.Id_client
WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY month, c.Gender;

-- 4. Возрастные группы (шаг 10 лет)
WITH AgeGroups AS (
    SELECT 
        t.*,
        CASE 
            WHEN c.AGE IS NULL THEN 'NA'
            WHEN c.AGE < 20 THEN '0-19'
            WHEN c.AGE < 30 THEN '20-29'
            WHEN c.AGE < 40 THEN '30-39'
            WHEN c.AGE < 50 THEN '40-49'
            WHEN c.AGE < 60 THEN '50-59'
            ELSE '60+' 
        END AS age_segment,
        QUARTER(t.date_new) AS qtr
    FROM transactions t
    LEFT JOIN customers c ON t.Id_client = c.Id_client
)
SELECT 
    age_segment,
    SUM(Sum_payment) AS total_sum,
    COUNT(Sum_payment) AS total_ops,
    -- Поквартальные показатели
    AVG(CASE WHEN qtr = 1 THEN Sum_payment END) AS avg_q1,
    AVG(CASE WHEN qtr = 2 THEN Sum_payment END) AS avg_q2,
    AVG(CASE WHEN qtr = 3 THEN Sum_payment END) AS avg_q3,
    AVG(CASE WHEN qtr = 4 THEN Sum_payment END) AS avg_q4
FROM AgeGroups
GROUP BY age_segment;



