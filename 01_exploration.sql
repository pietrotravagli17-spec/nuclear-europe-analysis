-- =====================================================
-- Nuclear Energy in Europe (2010-2025)
-- Data exploration and quality checks
-- Run in BigQuery against energy.nuclear_raw
-- =====================================================


-- 01. First things first: how big is this dataset?
-- I'm expecting 14 countries with data from 2010 to 2025, so 224 rows in total.

SELECT
  COUNT(*)                AS row_count,
  COUNT(DISTINCT Country) AS country_count,
  MIN(Year)               AS first_year,
  MAX(Year)               AS last_year
FROM energy.nuclear_raw;


-- 02. Does every country have all 16 years, with no gaps or duplicates?
-- If this comes back empty, we're good.

SELECT
  Country,
  COUNT(*)             AS year_rows,
  COUNT(DISTINCT Year) AS distinct_years
FROM energy.nuclear_raw
GROUP BY Country
HAVING COUNT(*) != 16
    OR COUNT(DISTINCT Year) != 16;


-- 03. Looking for missing values and anything that can't exist in the real world,
-- like negative generation or a share above 100%.
-- Ideally every column here shows 0.

SELECT
  COUNTIF(Installed_Capacity_MW IS NULL)  AS null_capacity,
  COUNTIF(Nuclear_Generation_TWh IS NULL) AS null_generation,
  COUNTIF(Nuclear_Share_Pct IS NULL)      AS null_share,
  COUNTIF(Installed_Capacity_MW < 0
          OR Nuclear_Generation_TWh < 0
          OR Nuclear_Share_Pct NOT BETWEEN 0 AND 100) AS out_of_range
FROM energy.nuclear_raw;


-- 04. A quick profile of each country to get a feel for the data.
-- If min and max capacity differ, the country opened or closed reactors
-- along the way (think Germany, Finland, Slovakia).
-- A high standard deviation on the share means it jumps around a lot year to year.

SELECT
  Country,
  ANY_VALUE(Cluster_Type)               AS cluster_type,
  MIN(Installed_Capacity_MW)            AS min_capacity_mw,
  MAX(Installed_Capacity_MW)            AS max_capacity_mw,
  ROUND(AVG(Nuclear_Generation_TWh), 1) AS avg_generation_twh,
  ROUND(AVG(Nuclear_Share_Pct), 1)      AS avg_share_pct,
  ROUND(STDDEV(Nuclear_Share_Pct), 1)   AS share_std_dev
FROM energy.nuclear_raw
GROUP BY Country
ORDER BY avg_generation_twh DESC;


-- 05. Sanity check: is the generation realistic given how much capacity is installed?
-- The capacity factor compares what plants actually produced with what they
-- could produce running flat out all year (capacity x 8,760 hours).
-- We multiply TWh by a million to get MWh, so the units match.
-- Nuclear plants usually sit around 0.7-0.9. Anything above 1 would be impossible.

SELECT
  Country,
  Year,
  ROUND(SAFE_DIVIDE(Nuclear_Generation_TWh * 1e6,
                    Installed_Capacity_MW * 8760), 3) AS capacity_factor
FROM energy.nuclear_raw
WHERE Installed_Capacity_MW > 0   -- skip Germany after the phase-out, there's nothing to divide by
ORDER BY capacity_factor DESC;


-- 06. This is the interesting one: do generation and share actually agree?
--
-- If a country produces X TWh of nuclear and that's Y% of its electricity,
-- then its total electricity must be X / Y. A country's total consumption
-- doesn't swing wildly from one year to the next, so if this number suddenly
-- jumps, something in the data doesn't add up.
--
-- I'm flagging any year that's more than 30% away from the country's usual level.
-- Result: 11 rows (France 2022, Germany 2019-2021 and seven Netherlands years).

-- Work out the implied total electricity for every row
WITH base AS (
  SELECT
    Country,
    Year,
    Nuclear_Generation_TWh,
    Nuclear_Share_Pct,
    SAFE_DIVIDE(Nuclear_Generation_TWh, Nuclear_Share_Pct / 100) AS implied_total_twh
  FROM energy.nuclear_raw
),

-- Find each country's "normal" level, using the median so outliers don't skew it
with_median AS (
  SELECT
    *,
    PERCENTILE_CONT(implied_total_twh, 0.5) OVER (PARTITION BY Country) AS country_median_twh
  FROM base
)

-- Keep only the years that stray too far from normal
SELECT
  Country,
  Year,
  Nuclear_Generation_TWh,
  Nuclear_Share_Pct,
  ROUND(implied_total_twh, 1)  AS implied_total_twh,
  ROUND(country_median_twh, 1) AS country_median_twh,
  ROUND(SAFE_DIVIDE(implied_total_twh, country_median_twh) - 1, 2) AS deviation  -- 0.36 means 36% above normal
FROM with_median
WHERE ABS(SAFE_DIVIDE(implied_total_twh, country_median_twh) - 1) > 0.30
ORDER BY Country, Year;
