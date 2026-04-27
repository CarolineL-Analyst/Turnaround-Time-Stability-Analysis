-- =============================================================================
-- MRO Turnaround Time (TRT) Analysis
-- Portfolio sample SQL — table and field names have been generalized from the
-- original implementation. The SQL logic, statistical methods, and edge case
-- handling reflect the production version used in operational reviews.
--
-- Grain: PartNumber x WorkscopeCode x Month
-- Output window: 2024-01 through 2025-12
-- =============================================================================


-- 1) Base layer: per-project TRT in business days.
--    Business days = calendar days minus weekend days, approximated using the
--    DATEDIFF(WEEK) trick. Public holidays are not yet excluded — acceptable
--    for trend analysis at monthly grain, but worth revisiting if daily-level
--    TRT precision becomes important.
WITH base AS (
    SELECT
        p.ProjectID,
        p.PartNumber,
        p.WorkscopeCode,
        p.ProjectStartDate,
        p.ProjectCompletedDate,
        CASE 
            WHEN p.ProjectCompletedDate IS NULL THEN NULL
            ELSE DATEDIFF(DAY, p.ProjectStartDate, p.ProjectCompletedDate)
                 - 2 * DATEDIFF(WEEK, p.ProjectStartDate, p.ProjectCompletedDate)
        END AS BusinessDays
    FROM dbo.ProjectOperationalData AS p
    WHERE p.ProjectCompletedDate IS NOT NULL  -- only completed projects contribute to TRT
),

-- 2) Monthly aggregate per (PartNumber, WorkscopeCode).
--    Two complementary measures:
--      - SUM  -> workload signal (how much shop floor time was consumed)
--      - AVG  -> efficiency signal (per-project TRT, the actual KPI)
monthly AS (
    SELECT
        b.PartNumber,
        b.WorkscopeCode,
        DATEFROMPARTS(YEAR(b.ProjectStartDate), MONTH(b.ProjectStartDate), 1) AS MonthStart,
        YEAR(b.ProjectStartDate) * 100 + MONTH(b.ProjectStartDate)            AS PeriodInt,

        COUNT(*)                                                              AS ProjectCount,
        SUM(CAST(b.BusinessDays AS DECIMAL(18,4)))                            AS TotalBusinessDays_SUM,  -- workload
        AVG(CAST(b.BusinessDays AS DECIMAL(18,4)))                            AS AvgBusinessDays         -- per-project TRT
    FROM base AS b
    GROUP BY
        b.PartNumber,
        b.WorkscopeCode,
        DATEFROMPARTS(YEAR(b.ProjectStartDate), MONTH(b.ProjectStartDate), 1),
        YEAR(b.ProjectStartDate) * 100 + MONTH(b.ProjectStartDate)
),

-- 3) Rolling 12-month statistics on AvgBusinessDays (the efficiency signal).
--    Rolling 12 chosen to smooth seasonality (MRO demand has annual cycles
--    driven by fleet maintenance schedules) while still being responsive to
--    multi-quarter trend shifts.
rolled AS (
    SELECT
        m.PartNumber,
        m.WorkscopeCode,
        m.MonthStart,
        m.PeriodInt,
        m.ProjectCount,
        m.TotalBusinessDays_SUM,
        m.AvgBusinessDays,

        -- Rolling mean: baseline TRT for the part/workscope combination
        AVG(m.AvgBusinessDays) OVER (
            PARTITION BY m.PartNumber, m.WorkscopeCode
            ORDER BY m.PeriodInt
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ) AS rolling_12_avg,

        -- Sample STD: used for z-score (treats the 12-month window as a sample
        -- of an underlying process, appropriate for inferring whether the
        -- current month is unusual relative to recent history)
        STDEV(m.AvgBusinessDays) OVER (
            PARTITION BY m.PartNumber, m.WorkscopeCode
            ORDER BY m.PeriodInt
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ) AS rolling_12_stdev,

        -- Population STD: used for CV (treats the 12-month window as the
        -- complete recent history we care about, appropriate for describing
        -- observed stability rather than inferring about a wider population)
        STDEVP(m.AvgBusinessDays) OVER (
            PARTITION BY m.PartNumber, m.WorkscopeCode
            ORDER BY m.PeriodInt
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ) AS rolling_12_stdevp,

        -- Actual window size — needed because the first 11 rows of any
        -- part/workscope series will have a partial window
        COUNT(*) OVER (
            PARTITION BY m.PartNumber, m.WorkscopeCode
            ORDER BY m.PeriodInt
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ) AS rolling_12_count
    FROM monthly AS m
)

-- 4) Final output: workload, efficiency, rolling stability (CV), and anomaly
--    flag (z-score). Restricted to 2024-01 through 2025-12 for review scope.
SELECT
    r.PartNumber,
    r.WorkscopeCode,
    r.ProjectCount,
    r.TotalBusinessDays_SUM,                   -- monthly workload
    r.AvgBusinessDays,                         -- monthly efficiency (TRT KPI)
    r.rolling_12_avg,                          -- 12-month baseline TRT
    r.rolling_12_stdev,
    r.rolling_12_stdevp,

    -- Rolling CV: coefficient of variation as a stability metric.
    -- Interpretation: lower CV = more predictable TRT for that part/workscope.
    CASE
        -- Partial window: not enough history for a stable CV
        WHEN r.rolling_12_count < 12 THEN NULL

        -- Defensive: either input missing
        WHEN r.rolling_12_avg IS NULL OR r.rolling_12_stdevp IS NULL THEN NULL

        -- CV becomes unstable / not meaningful when the mean approaches zero
        -- relative to the std. Returning NULL is safer than emitting a huge
        -- ratio that would mislead the operations review.
        WHEN ABS(r.rolling_12_avg) < 0.1 * r.rolling_12_stdevp THEN NULL

        ELSE r.rolling_12_stdevp / ABS(r.rolling_12_avg)
    END AS rolling_12_CV,

    -- Z-score: how unusual is this month's TRT relative to the rolling window?
    -- Used as an anomaly trigger for review discussion, not as an automatic
    -- pass/fail signal.
    CASE 
        -- Partial window: z-score not interpretable
        WHEN r.rolling_12_count < 12 THEN NULL

        -- Defensive: either input missing
        WHEN r.AvgBusinessDays IS NULL OR r.rolling_12_avg IS NULL THEN NULL

        -- Near-zero std would produce a meaningless or infinite z-score.
        -- The 1e-6 threshold catches both NULL and effectively-constant windows.
        WHEN r.rolling_12_stdev IS NULL OR r.rolling_12_stdev <= 1e-6 THEN NULL

        ELSE (r.AvgBusinessDays - r.rolling_12_avg) / NULLIF(r.rolling_12_stdev, 0.0)
    END AS zscore_rolling_12,

    r.MonthStart,
    r.PeriodInt
FROM rolled AS r
WHERE r.MonthStart >= DATEFROMPARTS(2024, 1, 1)
  AND r.MonthStart <  DATEFROMPARTS(2026, 1, 1)
ORDER BY r.PartNumber, r.WorkscopeCode, r.PeriodInt;
