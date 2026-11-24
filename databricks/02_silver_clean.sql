-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 02 - Silver: type, clean, rename, decode
-- MAGIC
-- MAGIC * `TRY_CAST` instead of `CAST` → a bad value becomes NULL instead of failing the job (serverless runs in ANSI mode).
-- MAGIC * snake_case names, units in the name (`_min`, `_miles`).
-- MAGIC * Build a real `flight_date` from YEAR/MONTH/DAY.
-- MAGIC * Decode cancellation reason letters.
-- MAGIC * **Known source issue:** in October 2015 the origin/destination columns contain 5-digit numeric
-- MAGIC   DOT airport IDs instead of IATA codes. We flag them here and map them to `UNK` in gold.

-- COMMAND ----------

USE CATALOG workspace;

CREATE OR REPLACE TABLE flights_silver.airlines AS
SELECT
  TRIM(IATA_CODE) AS airline_code,
  TRIM(AIRLINE)   AS airline_name
FROM flights_bronze.airlines;

-- COMMAND ----------

CREATE OR REPLACE TABLE flights_silver.airports AS
SELECT
  TRIM(IATA_CODE)            AS airport_code,
  TRIM(AIRPORT)              AS airport_name,
  TRIM(CITY)                 AS city,
  TRIM(STATE)                AS state,
  TRIM(COUNTRY)              AS country,
  TRY_CAST(LATITUDE  AS DOUBLE) AS latitude,
  TRY_CAST(LONGITUDE AS DOUBLE) AS longitude
FROM flights_bronze.airports;

-- COMMAND ----------

CREATE OR REPLACE TABLE flights_silver.flights
CLUSTER BY (flight_date)
AS
SELECT
  make_date(TRY_CAST(YEAR AS INT), TRY_CAST(MONTH AS INT), TRY_CAST(DAY AS INT)) AS flight_date,
  TRY_CAST(DAY_OF_WEEK AS INT)              AS day_of_week,       -- 1 = Monday
  TRIM(AIRLINE)                             AS airline_code,
  TRY_CAST(FLIGHT_NUMBER AS INT)            AS flight_number,
  TRIM(TAIL_NUMBER)                         AS tail_number,
  TRIM(ORIGIN_AIRPORT)                      AS origin_airport,
  TRIM(DESTINATION_AIRPORT)                 AS dest_airport,

  TRY_CAST(SCHEDULED_DEPARTURE AS INT)                    AS sched_dep_hhmm,
  CAST(FLOOR(TRY_CAST(SCHEDULED_DEPARTURE AS INT) / 100) AS INT) AS sched_dep_hour,

  TRY_CAST(DEPARTURE_DELAY AS INT)          AS dep_delay_min,
  TRY_CAST(ARRIVAL_DELAY   AS INT)          AS arr_delay_min,
  TRY_CAST(TAXI_OUT        AS INT)          AS taxi_out_min,
  TRY_CAST(TAXI_IN         AS INT)          AS taxi_in_min,
  TRY_CAST(AIR_TIME        AS INT)          AS air_time_min,
  TRY_CAST(DISTANCE        AS INT)          AS distance_miles,

  TRY_CAST(CANCELLED AS INT) = 1            AS is_cancelled,
  TRY_CAST(DIVERTED  AS INT) = 1            AS is_diverted,
  CASE CANCELLATION_REASON
    WHEN 'A' THEN 'Airline / Carrier'
    WHEN 'B' THEN 'Weather'
    WHEN 'C' THEN 'National Air System'
    WHEN 'D' THEN 'Security'
  END                                       AS cancellation_reason,

  -- Delay-cause minutes are only reported when arrival delay >= 15; otherwise NULL -> 0
  COALESCE(TRY_CAST(AIRLINE_DELAY       AS INT), 0) AS delay_carrier_min,
  COALESCE(TRY_CAST(WEATHER_DELAY       AS INT), 0) AS delay_weather_min,
  COALESCE(TRY_CAST(AIR_SYSTEM_DELAY    AS INT), 0) AS delay_nas_min,
  COALESCE(TRY_CAST(SECURITY_DELAY      AS INT), 0) AS delay_security_min,
  COALESCE(TRY_CAST(LATE_AIRCRAFT_DELAY AS INT), 0) AS delay_late_aircraft_min,

  (ORIGIN_AIRPORT RLIKE '^[0-9]+$' OR DESTINATION_AIRPORT RLIKE '^[0-9]+$') AS has_numeric_airport_code,

  _source_file,
  _ingested_at
FROM flights_bronze.flights;

-- COMMAND ----------

SELECT COUNT(*) AS rows, MIN(flight_date), MAX(flight_date),
       SUM(CAST(has_numeric_airport_code AS INT)) AS numeric_code_rows
FROM flights_silver.flights;
