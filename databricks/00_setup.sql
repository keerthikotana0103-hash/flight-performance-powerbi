-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 00 - Setup: catalog objects for the Flight Performance project
-- MAGIC
-- MAGIC Medallion layout inside the Free Edition `workspace` catalog:
-- MAGIC
-- MAGIC | Schema | Purpose |
-- MAGIC |---|---|
-- MAGIC | `flights_bronze` | Raw CSVs landed as-is (all strings) + ingestion metadata. Also holds the `raw` volume for uploads. |
-- MAGIC | `flights_silver` | Typed, cleaned, renamed, decoded. One row per flight. |
-- MAGIC | `flights_gold`   | Star schema for Power BI: `fact_flights`, `dim_*`, aggregates. |
-- MAGIC
-- MAGIC After running this, upload `flights.csv`, `airlines.csv`, `airports.csv` to
-- MAGIC **Catalog > workspace > flights_bronze > Volumes > raw > Upload to this volume**.

-- COMMAND ----------

USE CATALOG workspace;

CREATE SCHEMA IF NOT EXISTS flights_bronze COMMENT 'Raw landed data (as-is)';
CREATE SCHEMA IF NOT EXISTS flights_silver COMMENT 'Cleaned and typed data';
CREATE SCHEMA IF NOT EXISTS flights_gold   COMMENT 'Star schema served to Power BI';

CREATE VOLUME IF NOT EXISTS flights_bronze.raw COMMENT 'Upload the Kaggle CSV files here';

-- COMMAND ----------

-- Verify the files are uploaded (run after upload)
LIST '/Volumes/workspace/flights_bronze/raw/';
