-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 04 - Data quality checks
-- MAGIC Each query returns a `check_name` and `failed_rows`. **All should be 0** except the
-- MAGIC informational ones marked (info). In a real pipeline these become a DQ table / alerts or
-- MAGIC Lakeflow Declarative Pipelines `EXPECT` constraints.

-- COMMAND ----------

USE CATALOG workspace;

SELECT 'bronze vs gold row count mismatch' AS check_name,
       ABS((SELECT COUNT(*) FROM flights_bronze.flights) - (SELECT COUNT(*) FROM flights_gold.fact_flights)) AS failed_rows
UNION ALL
SELECT 'null flight_date', COUNT(*) FROM flights_gold.fact_flights WHERE flight_date IS NULL
UNION ALL
SELECT 'orphan airline_code (not in dim)', COUNT(*)
FROM flights_gold.fact_flights f LEFT ANTI JOIN flights_gold.dim_airline d USING (airline_code)
UNION ALL
SELECT 'orphan origin airport (not in dim)', COUNT(*)
FROM flights_gold.fact_flights f LEFT ANTI JOIN flights_gold.dim_airport d ON f.origin_airport_code = d.airport_code
UNION ALL
SELECT 'duplicate airport_code in dim', COUNT(*) FROM (
  SELECT airport_code FROM flights_gold.dim_airport GROUP BY airport_code HAVING COUNT(*) > 1)
UNION ALL
SELECT 'cancelled flight with arrival delay', COUNT(*) FROM flights_gold.fact_flights
WHERE is_cancelled = 1 AND arr_delay_min IS NOT NULL
UNION ALL
SELECT '(info) flights mapped to UNK airport', COUNT(*) FROM flights_gold.fact_flights
WHERE origin_airport_code = 'UNK' OR dest_airport_code = 'UNK'
UNION ALL
SELECT '(info) duplicate flight keys', COUNT(*) FROM (
  SELECT flight_date, airline_code, flight_number, origin_airport_code
  FROM flights_gold.fact_flights GROUP BY ALL HAVING COUNT(*) > 1);
