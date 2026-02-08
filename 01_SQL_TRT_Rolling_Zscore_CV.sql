-- 1) base info per project, get TRT from DateRaised to ProjComplete.
--    BusinessDays excludes weekends only. Public holidays not included yet.
WITH base AS (
    SELECT
        p.ProjectNo,
        p.PartNo,
        p.WorkscopeID,
        p.DateRaised,
        p.ProjComplete,
        CASE 
            WHEN p.ProjComplete IS NULL THEN NULL
            ELSE DATEDIFF(DAY, p.DateRaised, p.ProjComplete)
                 - 2 * DATEDIFF(WEEK, p.DateRaised, p.ProjComplete)
        END AS BusinessDays
    FROM dbo.tblProjects AS p
    WHERE p.ProjComplete IS NOT NULL
),

-- 2) Monthly aggregate per (PartNoFor, WorkscopeIDFor)
monthly AS (
    SELECT
        b.PartNo,
        b.WorkscopeID,
        DATEFROMPARTS(YEAR(b.DateRaised), MONTH(b.DateRaised), 1) AS MonthStart,
        YEAR(b.DateRaised) * 100 + MONTH(b.DateRaised)            AS PeriodInt,

        COUNT(*)                                                   AS ProjectCount,
        SUM(CAST(b.BusinessDays AS DECIMAL(18,4)))                 AS TotalBusinessDays_SUM,  -- workload
        AVG(CAST(b.BusinessDays AS DECIMAL(18,4)))                 AS AvgBusinessDays         -- per-project average TRT
    FROM base AS b
    GROUP BY
        b.PartNo,
        b.WorkscopeID,
        DATEFROMPARTS(YEAR(b.DateRaised), MONTH(b.DateRaised), 1),
        YEAR(b.DateRaised) * 100 + MONTH(b.DateRaised)
),

-- 3) Rolling-12 for AvgBusinessDays (efficiency)
rolled AS (
    SELECT
        m.PartNo,
        m.WorkscopeID,
        m.MonthStart,
        m.PeriodInt,
        m.ProjectCount,
        m.TotalBusinessDays_SUM,
        m.AvgBusinessDays,

        -- Rolling mean
        AVG(m.AvgBusinessDays) OVER (
            PARTITION BY m.PartNo, m.WorkscopeID
            ORDER BY m.PeriodInt
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ) AS rolling_12_avg,

        -- Rolling sample STD (for z-score / future inference)
        STDEV(m.AvgBusinessDays) OVER (
            PARTITION BY m.PartNo, m.WorkscopeID
            ORDER BY m.PeriodInt
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ) AS rolling_12_stdev,

        -- Rolling population STD (for historical stability / CV)
        STDEVP(m.AvgBusinessDays) OVER (
            PARTITION BY m.PartNo, m.WorkscopeID
            ORDER BY m.PeriodInt
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ) AS rolling_12_stdevp,

        -- Rolling count (window size actually used in the first 11 rows)
        COUNT(*) OVER (
            PARTITION BY m.PartNo, m.WorkscopeID
            ORDER BY m.PeriodInt
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ) AS rolling_12_count
    FROM monthly AS m
)

-- 4) Output + z-score (anomaly on efficiency) + rolling CV, limited to 2024-01 ~ 2025-12
SELECT
    r.PartNo,
    r.WorkscopeID,
    r.ProjectCount,
    r.TotalBusinessDays_SUM,                   -- workload in that month
    r.AvgBusinessDays,                         -- average TRT in that month (efficiency)
    r.rolling_12_avg,                          -- rolling 12M average TRT
    r.rolling_12_stdev,
    r.rolling_12_stdevp,

    -- Rolling CV (historical): guard against tiny mean; return NULL when not interpretable.
    CASE
        WHEN r.rolling_12_count < 12 THEN NULL
        WHEN r.rolling_12_avg IS NULL OR r.rolling_12_stdevp IS NULL THEN NULL
        WHEN ABS(r.rolling_12_avg) < 0.1 * r.rolling_12_stdevp THEN NULL   -- mean too small, CV not meaningful
        ELSE r.rolling_12_stdevp / ABS(r.rolling_12_avg)
    END AS rolling_12_CV,

    -- Z-score (use sample std), guard against null / zero / tiny variance.
    CASE 
        WHEN r.rolling_12_count < 12 THEN NULL                         -- incomplete window
        WHEN r.AvgBusinessDays IS NULL OR r.rolling_12_avg IS NULL THEN NULL
        WHEN r.rolling_12_stdev IS NULL OR r.rolling_12_stdev <= 1e-6 THEN NULL
        ELSE (r.AvgBusinessDays - r.rolling_12_avg) / NULLIF(r.rolling_12_stdev, 0.0)
    END AS zscore_rolling_12,

    r.MonthStart,
    r.PeriodInt
FROM rolled AS r
WHERE r.MonthStart >= DATEFROMPARTS(2024,1,1)
  AND r.MonthStart <  DATEFROMPARTS(2026,1,1)
ORDER BY r.PartNo, r.WorkscopeID, r.PeriodInt;