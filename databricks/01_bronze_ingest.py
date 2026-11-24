# Databricks notebook source
# MAGIC %md
# MAGIC # 01 - Bronze: land raw CSVs into Delta tables
# MAGIC
# MAGIC **Rule of bronze:** keep the data exactly as the source sent it (every column as STRING),
# MAGIC and add lineage columns so any row can be traced back to its file and load time.
# MAGIC Typing / cleaning happens in silver, so a bad value never breaks ingestion.

# COMMAND ----------

from pyspark.sql import functions as F

RAW_PATH = "/Volumes/workspace/flights_bronze/raw"
TARGET_SCHEMA = "workspace.flights_bronze"

SOURCES = {
    "flights.csv": "flights",
    "airlines.csv": "airlines",
    "airports.csv": "airports",
}

# COMMAND ----------

def ingest_csv(file_name: str, table_name: str) -> int:
    df = (
        spark.read
        .option("header", True)
        .option("inferSchema", False)        # everything as string in bronze
        .csv(f"{RAW_PATH}/{file_name}")
        .withColumn("_source_file", F.col("_metadata.file_path"))
        .withColumn("_ingested_at", F.current_timestamp())
    )
    (
        df.write
        .mode("overwrite")                   # full reload; see README for incremental option
        .option("overwriteSchema", True)
        .saveAsTable(f"{TARGET_SCHEMA}.{table_name}")
    )
    return spark.table(f"{TARGET_SCHEMA}.{table_name}").count()

# COMMAND ----------

for file_name, table_name in SOURCES.items():
    rows = ingest_csv(file_name, table_name)
    print(f"{TARGET_SCHEMA}.{table_name:<10} <- {file_name:<14} {rows:>12,} rows")

# COMMAND ----------

# MAGIC %md
# MAGIC Expected: flights ≈ 5,819,079 rows, airlines = 14, airports = 322.
# MAGIC
# MAGIC **Interview note — incremental loading:** for a feed that keeps arriving, replace the
# MAGIC `overwrite` with Auto Loader (`spark.readStream.format("cloudFiles")`) and
# MAGIC `.trigger(availableNow=True)`; it tracks which files were already processed via a checkpoint.
