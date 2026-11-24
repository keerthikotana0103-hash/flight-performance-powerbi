-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 03 - Gold: star schema for Power BI
-- MAGIC
-- MAGIC ```
-- MAGIC              dim_date
-- MAGIC                 |
-- MAGIC  dim_airline -- fact_flights -- dim_airport (origin, ACTIVE)
-- MAGIC                 |         \___ dim_airport (destination, INACTIVE -> USERELATIONSHIP)
-- MAGIC ```
-- MAGIC
-- MAGIC * **Grain of `fact_flights`: one row per scheduled flight.**
-- MAGIC * Unknown airports (numeric October codes) → `UNK` with a matching row in `dim_airport`,
-- MAGIC   so Power BI never shows a "(Blank)" member and relationships stay many-to-one.
-- MAGIC * `dim_date` built here (single source of truth for every report); a DAX version is in `powerbi/dax/date_table.dax`.
-- MAGIC * `agg_daily_airline_origin` is a pre-aggregated table for Power BI **aggregations / composite models**.

-- COMMAND ----------

USE CATALOG workspace;

CREATE OR REPLACE TABLE flights_gold.dim_airline AS
SELECT airline_code, airline_name FROM flights_silver.airlines
UNION ALL
SELECT 'UNK', 'Unknown'
WHERE NOT EXISTS (SELECT 1 FROM flights_silver.airlines WHERE airline_code = 'UNK');

-- COMMAND ----------

CREATE OR REPLACE TABLE flights_gold.dim_airport AS
SELECT airport_code, airport_name, city, state, country, latitude, longitude,
       CONCAT(city, ', ', state) AS city_state
FROM flights_silver.airports
UNION ALL
SELECT 'UNK', 'Unknown airport', 'Unknown', 'NA', 'USA', NULL, NULL, 'Unknown';

-- COMMAND ----------

CREATE OR REPLACE TABLE flights_gold.dim_date AS
WITH d AS (
  SELECT explode(sequence(DATE'2015-01-01', DATE'2015-12-31', INTERVAL 1 DAY)) AS date
)
SELECT
  date,
  CAST(date_format(date, 'yyyyMMdd') AS INT) AS date_key,
  year(date)                                  AS year,
  quarter(date)                               AS quarter,
  CONCAT('Q', quarter(date))                  AS quarter_name,
  month(date)                                 AS month_number,
  date_format(date, 'MMMM')                   AS month_name,
  date_format(date, 'MMM')                    AS month_short,
  CAST(date_format(date, 'yyyyMM') AS INT)    AS year_month_key,
  date_format(date, 'yyyy-MM')                AS year_month,
  weekofyear(date)                            AS week_of_year,
  dayofmonth(date)                            AS day_of_month,
  weekday(date) + 1                           AS day_of_week_number,   -- 1 = Monday
  date_format(date, 'EEEE')                   AS day_name,
  date_format(date, 'EEE')                    AS day_short,
  weekday(date) >= 5                          AS is_weekend
FROM d;

-- COMMAND ----------

CREATE OR REPLACE TABLE flights_gold.fact_flights
CLUSTER BY (flight_date)
AS
SELECT
  f.flight_date,
  COALESCE(al.airline_code, 'UNK')  AS airline_code,
  COALESCE(o.airport_code,  'UNK')  AS origin_airport_code,
  COALESCE(d.airport_code,  'UNK')  AS dest_airport_code,
  CONCAT(COALESCE(o.airport_code,'UNK'), '-', COALESCE(d.airport_code,'UNK')) AS route,
  f.flight_number,
  f.tail_number,
  f.sched_dep_hour,
  f.dep_delay_min,
  f.arr_delay_min,
  f.taxi_out_min,
  f.taxi_in_min,
  f.air_time_min,
  f.distance_miles,
  CAST(f.is_cancelled AS INT) AS is_cancelled,
  CAST(f.is_diverted  AS INT) AS is_diverted,
  -- DOT definition: arrived < 15 minutes late. Cancelled/diverted are NOT on time.
  CASE WHEN NOT f.is_cancelled AND NOT f.is_diverted AND f.arr_delay_min < 15 THEN 1 ELSE 0 END AS is_on_time,
  f.cancellation_reason,
  f.delay_carrier_min,
  f.delay_weather_min,
  f.delay_nas_min,
  f.delay_security_min,
  f.delay_late_aircraft_min
FROM flights_silver.flights f
LEFT JOIN flights_silver.airlines al ON f.airline_code   = al.airline_code
LEFT JOIN flights_silver.airports o  ON f.origin_airport = o.airport_code
LEFT JOIN flights_silver.airports d  ON f.dest_airport   = d.airport_code;

-- COMMAND ----------

-- Aggregate table: ~5.8M rows -> a few hundred thousand. Used for Power BI "Manage aggregations" demo.
CREATE OR REPLACE TABLE flights_gold.agg_daily_airline_origin AS
SELECT
  flight_date,
  airline_code,
  origin_airport_code,
  COUNT(*)                     AS flights,
  SUM(is_cancelled)            AS cancelled_flights,
  SUM(is_diverted)             AS diverted_flights,
  SUM(is_on_time)              AS on_time_flights,
  SUM(arr_delay_min)           AS sum_arr_delay_min,
  COUNT(arr_delay_min)         AS count_arr_delay,
  SUM(distance_miles)          AS sum_distance_miles
FROM flights_gold.fact_flights
GROUP BY ALL;

-- COMMAND ----------

-- Table / column comments show up in Unity Catalog and help Power BI users
COMMENT ON TABLE flights_gold.fact_flights IS 'One row per scheduled US domestic flight, 2015. Source: US DOT via Kaggle.';
ALTER TABLE flights_gold.fact_flights ALTER COLUMN is_on_time COMMENT '1 if arrived < 15 min late and not cancelled/diverted';

-- COMMAND ----------

SELECT 'fact_flights' AS t, COUNT(*) FROM flights_gold.fact_flights
UNION ALL SELECT 'agg_daily_airline_origin', COUNT(*) FROM flights_gold.agg_daily_airline_origin
UNION ALL SELECT 'dim_airline', COUNT(*) FROM flights_gold.dim_airline
UNION ALL SELECT 'dim_airport', COUNT(*) FROM flights_gold.dim_airport
UNION ALL SELECT 'dim_date', COUNT(*) FROM flights_gold.dim_date;
