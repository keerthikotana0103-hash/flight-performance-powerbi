# Power BI: Flight Performance report

## 1. Connect to Databricks

1. In Databricks, go to **SQL Warehouses**, open the Serverless Starter Warehouse and select **Connection details**. Copy the **Server hostname** and **HTTP path**.
2. Create a token. Click your avatar, then **Settings > Developer > Access tokens > Generate new token**. Give it a short lifetime and **never commit it to git**.
3. In Power BI Desktop, go to **Get data > Azure Databricks**. (The "Databricks" connector works too.)
   - Server hostname / HTTP path: paste the values from step 1.
   - Data connectivity mode: **Import** (see the trade-offs below).
   - Authentication: **Personal Access Token**.
4. In the navigator, open `workspace > flights_gold` and select:
   `fact_flights`, `dim_airline`, `dim_airport`, `dim_date` (+ `agg_daily_airline_origin` for the aggregation exercise).

> If 5.8M rows is slow to load on your laptop, filter in Power Query on `flight_date` (for example the first 6 months). Check that **View Native Query** is enabled, which shows that query folding is working.

## 2. Model (Model view)

| From (many) | To (one) | Active | Cross-filter |
|---|---|---|---|
| `fact_flights[flight_date]` | `dim_date[date]` | ✅ | Single |
| `fact_flights[airline_code]` | `dim_airline[airline_code]` | ✅ | Single |
| `fact_flights[origin_airport_code]` | `dim_airport[airport_code]` | ✅ | Single |
| `fact_flights[dest_airport_code]` | `dim_airport[airport_code]` | ❌ inactive | Single |

Then:
- Select `dim_date`, then **Mark as date table** using `date`.
- **Sort by column**: `month_name` by `month_number`, and `day_name` by `day_of_week_number`.
- Hide the fact's key columns (`airline_code`, the `*_airport_code` columns, `flight_date`) so that users slice by dimensions.
- Set the data category of `dim_airport[latitude]` / `[longitude]` to Latitude / Longitude, and `city` to City.
- Create the `_Measures` table and paste the measures from [dax/measures.dax](dax/measures.dax).
- Set formats: % measures as Percentage with 1 decimal place, minutes as Whole number.

## 3. Report pages

| Page | Visuals |
|---|---|
| **Overview** | KPI cards (Total Flights, On-Time %, Cancellation %, Avg Arrival Delay), line chart of flights + On-Time % by `year_month`, slicers for airline, month and origin state. Title bound to `[Report Title]`. |
| **Airlines** | Bar chart of On-Time % by airline (conditional colour from `[On-Time % Color]`), stacked bar of delay-cause minutes by airline, and a table with rank. |
| **Airports** | Map (bubble size = Total Flights, colour = Avg Arrival Delay), matrix of the top 10 worst routes (`route`, using a Top N filter on Avg Arrival Delay with Total Flights > 500). |
| **Time patterns** | Matrix heatmap with `day_name` × `sched_dep_hour` and Avg Arrival Delay as background colour, plus cancellation reasons in a donut chart. |
| **Airport detail** (drill-through) | Drill-through field `dim_airport[airport_name]`, showing departures vs `[Arrivals (by Destination)]`, a delay trend and the top destinations. |
| Tooltip page | A small page (Page type = Tooltip) showing On-Time % and flights for the hovered airline. |

Also add: **bookmarks** to toggle chart and table views, a **field parameter** that switches the measure between On-Time %, Cancellation % and Avg Delay, and **sync slicers** across pages.

## 4. Save in a git-friendly format

**File > Save as > Power BI project (.pbip)** and save into this `powerbi/` folder as `FlightPerformance.pbip`.
In **Options > Preview features**, enable **Store semantic model using TMDL format**.

The model is saved as readable text files (`*.SemanticModel/definition/*.tmdl`) and the report as JSON. This means git diffs show exactly which measure or visual changed. `.gitignore` already excludes the local cache (`.pbi/cache.abf`, `localSettings.json`).

## 5. Optional extras (good interview talking points)
- **RLS**: see [dax/rls_roles.dax](dax/rls_roles.dax).
- **Aggregations**: load `fact_flights` in DirectQuery and `agg_daily_airline_origin` in Import mode, then use **Manage aggregations** to map them. Visuals at day/airline/origin grain hit the small in-memory table, and detail visuals fall back to DirectQuery.
- **Incremental refresh**: create the `RangeStart`/`RangeEnd` parameters, filter `flight_date` on them, then set the policy (for example, store 2 years and refresh the last 7 days).
- **Performance Analyzer** and **DAX Studio**: capture the slowest visual, then explain what you changed.
