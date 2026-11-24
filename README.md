# ✈️ US Flight Performance Analytics: Databricks + Power BI

An end-to-end analytics project on **5.8M US domestic flights (2015)**:
raw CSV ➜ **Databricks** (medallion: bronze / silver / gold, Unity Catalog, Delta) ➜ **Power BI** (star schema, DAX, RLS) ➜ **git** (PBIP/TMDL).

```
Kaggle CSVs ──upload──▶ UC Volume ──▶ bronze (raw, strings)
                                          │  01_bronze_ingest.py
                                          ▼
                                       silver (typed, cleaned)
                                          │  02_silver_clean.sql
                                          ▼
                                       gold (star schema + agg)  ──SQL Warehouse──▶ Power BI (Import)
                                          │  03_gold_star_schema.sql
                                          ▼
                                       04_data_quality_checks.sql
```

## Repository layout

| Path | What it is |
|---|---|
| `databricks/` | Notebooks in source format. You can import them into Databricks or connect the repo as a Git folder. |
| `powerbi/` | Connection and modelling guide, the DAX measures, the date table, RLS, and later the `.pbip` project. |
| `docs/interview_qa.md` | Interview questions and answers tied to this project. **Read this before an interview.** |
| `docs/insights.md` | Fill in your own findings and numbers as you build. |
| `data/` | Local CSV copies. Git-ignored, so they're never committed. |

## Step-by-step

### Day 1: Setup and data
1. Create a free account in **Databricks Free Edition** at databricks.com (search "Databricks Free Edition"). No credit card is needed.
2. Download **"2015 Flight Delays and Cancellations"** from Kaggle (dataset `usdot/flight-delays`). It contains `flights.csv` (~565 MB), `airlines.csv` and `airports.csv`. You can keep a copy in `data/`.
3. In Databricks, go to **Workspace > Import** and import the four files from `databricks/`. Alternatively, go to **Workspace > Create > Git folder** and point it at your GitHub repo for this project.
4. Run `00_setup.sql`, then upload the 3 CSVs to the `workspace.flights_bronze.raw` volume.

### Day 2: Pipeline
5. Run `01_bronze_ingest.py`, then `02_silver_clean.sql`, then `03_gold_star_schema.sql`.
6. Run `04_data_quality_checks.sql`. Every check should be 0 except the (info) rows. Understand **why** each check exists.
7. Explore the data. Write 3–5 SQL queries answering business questions (worst airline, worst airport, delay by hour) and record the answers in `docs/insights.md`.

### Day 3–4: Power BI
8. Follow [powerbi/README.md](powerbi/README.md): connect, build the model and relationships, add the measures, and build the 4 pages plus the drill-through page.
9. Save as **.pbip** into `powerbi/`, then commit.

### Day 5: Advanced and interview prep
10. Add RLS, a field parameter, and bookmarks. Optionally, try the aggregation table in a composite model.
11. Run Performance Analyzer and write down one optimisation you made.
12. Rehearse `docs/interview_qa.md`, especially the 60-second project pitch.

## Git workflow

```powershell
git checkout -b feature/airlines-page
# ...make changes in Power BI (saved as .pbip) or the notebooks...
git add .
git commit -m "Add airlines page with on-time ranking"
git checkout main
git merge feature/airlines-page
```

> 🔐 Never commit Databricks tokens, `.env` files or `.pbix` files containing credentials. `.gitignore` covers the common cases.

## Known data issues (good interview stories)
- **October 2015**: origin/destination airports are 5-digit DOT IDs instead of IATA codes. They are flagged in silver and mapped to `UNK` in gold.
- Delay-cause columns are populated only when arrival delay is 15 minutes or more. They're converted from NULL to 0 in silver.
- Departure and arrival times are `HHMM` integers, not times. `sched_dep_hour` is derived from them.
