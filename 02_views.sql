-- =====================================================
-- Nuclear Energy in Europe (2010-2025)
-- Analytical views
-- These are the tables that Python and Power BI read from,
-- so every calculation lives here and both tools see the same numbers.
-- =====================================================


-- v_nuclear: the main table, one row per country per year.
-- It's the raw data plus everything we worked out in the exploration:
-- capacity factor, year-over-year change, yearly ranking and the
-- inconsistency flag from the generation vs share check.

CREATE OR REPLACE VIEW energy.v_nuclear AS
WITH base AS (
  SELECT
    *,
    SAFE_DIVIDE(Nuclear_Generation_TWh * 1e6,
                Installed_Capacity_MW * 8760)                    AS capacity_factor,
    SAFE_DIVIDE(Nuclear_Generation_TWh, Nuclear_Share_Pct / 100) AS implied_total_twh,
    LAG(Nuclear_Generation_TWh)
      OVER (PARTITION BY Country ORDER BY Year)                  AS prev_generation_twh
  FROM energy.nuclear_raw
),
with_median AS (
  SELECT
    *,
    PERCENTILE_CONT(implied_total_twh, 0.5)
      OVER (PARTITION BY Country)                                AS country_median_twh
  FROM base
)
SELECT
  Country,
  Year,
  Cluster_Type,
  Installed_Capacity_MW,
  Nuclear_Generation_TWh,
  Nuclear_Share_Pct,
  ROUND(capacity_factor, 3)                                      AS capacity_factor,
  ROUND(implied_total_twh, 1)                                    AS implied_total_twh,

  -- How much generation changed compared to the year before (empty for 2010)
  ROUND(Nuclear_Generation_TWh - prev_generation_twh, 2)         AS yoy_change_twh,
  ROUND(SAFE_DIVIDE(Nuclear_Generation_TWh - prev_generation_twh,
                    prev_generation_twh), 3)                     AS yoy_change_pct,

  -- Where the country ranks among the 14 for generation that year
  RANK() OVER (PARTITION BY Year
               ORDER BY Nuclear_Generation_TWh DESC)              AS generation_rank,

  -- TRUE when generation and share don't agree (more than 30% off the usual level).
  -- Years with zero share can't be checked, so they count as not flagged.
  COALESCE(ABS(SAFE_DIVIDE(implied_total_twh, country_median_twh) - 1) > 0.30,
           FALSE)                                                AS is_inconsistent
FROM with_median;


-- v_europe_yearly: the big picture, one row per year for Europe as a whole.
-- Handy for KPI cards and the overall trend line.

CREATE OR REPLACE VIEW energy.v_europe_yearly AS
SELECT
  Year,
  SUM(Installed_Capacity_MW)            AS total_capacity_mw,
  ROUND(SUM(Nuclear_Generation_TWh), 1) AS total_generation_twh,
  COUNTIF(Installed_Capacity_MW > 0)    AS active_countries
FROM energy.nuclear_raw
GROUP BY Year;


-- v_country_change: how each country moved between 2010 and 2025.
-- Positive change means nuclear grew its share, negative means it shrank.

CREATE OR REPLACE VIEW energy.v_country_change AS
SELECT
  Country,
  MAX(IF(Year = 2010, Nuclear_Share_Pct, NULL))           AS share_2010,
  MAX(IF(Year = 2025, Nuclear_Share_Pct, NULL))           AS share_2025,
  ROUND(MAX(IF(Year = 2025, Nuclear_Share_Pct, NULL))
      - MAX(IF(Year = 2010, Nuclear_Share_Pct, NULL)), 1) AS share_change_pts,
  MAX(IF(Year = 2010, Nuclear_Generation_TWh, NULL))      AS generation_2010,
  MAX(IF(Year = 2025, Nuclear_Generation_TWh, NULL))      AS generation_2025
FROM energy.nuclear_raw
GROUP BY Country;


-- Quick check: should return 11, the same rows found in the exploration
SELECT COUNT(*) AS flagged_rows
FROM energy.v_nuclear
WHERE is_inconsistent;
