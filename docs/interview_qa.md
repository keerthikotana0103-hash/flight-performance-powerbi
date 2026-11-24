# Interview Q&A, tied to this project

Practise saying these answers out loud. The best answers use **this project** as the example ("In my flight dashboard I…").

---

## A. The project pitch (have this ready word for word)

**"Tell me about a Power BI project you've done."**

> I built an end-to-end flight performance analytics solution on 5.8 million US domestic flights from 2015.
> I landed the raw DOT CSVs in a Unity Catalog volume in **Databricks** and used a **medallion architecture**: bronze kept the raw data as strings with lineage columns, silver typed and cleaned it, and gold exposed a **star schema**, with one fact table at a grain of one row per flight and dimensions for airline, airport and date.
> During cleaning I found that **October's airport codes were 5-digit numeric IDs instead of IATA codes**. Rather than drop 486k rows, I mapped them to an "Unknown" member so that totals stayed correct and airport visuals didn't show blanks. I also wrote data quality checks for orphan keys and row-count reconciliation.
> In **Power BI** I connected to a Databricks SQL warehouse in Import mode and built measures for on-time %, cancellation rate, delay-cause breakdowns and month-over-month trends. I used an **inactive relationship with USERELATIONSHIP** for destination analysis, plus **dynamic RLS** by airline, drill-through, and a field parameter.
> The whole thing is version-controlled in **git** using the PBIP/TMDL format, so model changes are reviewable diffs.
> The main insight was that **late-arriving aircraft was the biggest delay cause, not weather**, and delays build up through the day, peaking in the evening. *(Check these numbers against your own results.)*

**Follow-ups they'll ask:** *What was hardest?* (the numeric airport codes, or getting the date grain right). *What would you do differently?* (Auto Loader for incremental loads, Lakeflow pipelines with expectations, deployment pipelines).

---

## B. Data modelling

**Why a star schema?**
VertiPaq compresses narrow dimension tables and a long fact table very well. Filters flow cleanly one-to-many, from dimension to fact, and DAX stays simple. A single flat table repeats text values, gets bigger, and makes time intelligence and role-playing harder.

**What is the grain of your fact table?**
One row per scheduled flight. You must state the grain first, because every measure depends on it.

**Fact vs dimension?**
A fact holds events or measurements, with numeric values and foreign keys. A dimension holds descriptive attributes used to filter and group.

**How did you handle origin AND destination airports?**
A role-playing dimension. `dim_airport` has two relationships to the fact. Origin is active and destination is inactive. Measures that need destination use `USERELATIONSHIP`. The alternative is to import `dim_airport` twice, as "Origin Airport" and "Destination Airport". That's easier for users but takes more memory.

**Why avoid bi-directional relationships?**
They can cause ambiguous filter paths, slower queries and unexpected results. Use them only deliberately, for example for many-to-many bridges. Prefer `CROSSFILTER` inside a single measure.

**Many-to-many?**
Use a bridge table, or the native many-to-many cardinality setting. Explain the risk that totals may not add up.

**Snowflake vs star?**
Snowflake normalises dimensions, for example airport → state table. In Power BI, flatten into a star for performance and simplicity.

**What is a degenerate dimension?**
An attribute kept on the fact without its own table, such as `flight_number` or `tail_number`.

**SCD Type 1 vs 2?**
Type 1 overwrites the old value. Type 2 adds a new row with valid_from / valid_to dates to keep history. For example, if an airline changed its name, Type 2 keeps old flights under the old name. In Databricks you'd implement it with `MERGE` or Lakeflow `AUTO CDC`.

---

## C. DAX

**Calculated column vs measure?**
A column is computed at refresh, row by row, and stored, so it uses memory. You can slice by it. A measure is computed at query time in filter context and isn't stored. Prefer measures. Use columns only when you need to slice, filter or sort by the value.

**Row context vs filter context?**
Row context means "the current row", which exists in calculated columns and iterators (SUMX, FILTER). Filter context is the set of filters coming from visuals, slicers and CALCULATE. Row context does **not** filter anything by itself.

**What is context transition?**
When CALCULATE runs inside a row context, it turns the current row into an equivalent filter context. Any measure reference has an implicit CALCULATE wrapped around it, which is why `AVERAGEX(VALUES(dim_airline[airline_name]), [On-Time %])` works per airline.

**What does CALCULATE do?**
It evaluates an expression in a modified filter context. Its filter arguments add, replace or remove filters, and it is the only function that changes filter context (along with CALCULATETABLE).

**SUM vs SUMX?**
SUM aggregates one column. SUMX iterates a table and evaluates an expression per row, then sums the results. For example, `SUMX(fact, [qty] * [price])`.

**ALL vs ALLEXCEPT vs ALLSELECTED vs REMOVEFILTERS?**
- `ALL(table/col)` removes filters (and can also be used as a table).
- `REMOVEFILTERS` does the same, but only as a CALCULATE modifier, which makes it clearer.
- `ALLEXCEPT(t, col)` removes all filters except the listed columns.
- `ALLSELECTED` removes the visual's own filters but keeps the outer ones (slicers). It's used for "% of visible total".

See `Flights % of All Airlines` and `Flights % of Selection` in `measures.dax`.

**Why DIVIDE instead of `/`?**
It handles division by zero and returns BLANK, or an alternate result you specify.

**Why use VAR?**
It's easier to read, each value is evaluated once (which helps performance), and it's easier to debug because you can `RETURN _var`.

**Time intelligence requirements?**
A contiguous date table with no gaps, covering full years, that is marked as a date table and related to the fact's date.

**FILTER vs a boolean filter in CALCULATE?**
`CALCULATE([m], fact[col] = 1)` is shorthand for `FILTER(ALL(fact[col]), fact[col]=1)`, which filters a single column and is fast. `FILTER(fact, …)` iterates the whole table and should only be used when the condition needs several columns or a measure.

**How do you rank?**
`RANKX(ALL(dim_airline[airline_name]), [On-Time %])`. Wrap it in `HASONEVALUE` so the total row is blank.

**TOPN, ADDCOLUMNS, SUMMARIZE**: see `Best Airline (On-Time %)`.

**ISFILTERED vs ISCROSSFILTERED vs HASONEVALUE vs SELECTEDVALUE**: know one sentence for each.

---

## D. Power Query / data prep

**What is query folding? Why does it matter?**
Power Query translates steps into a source-native query (SQL against Databricks), so the source does the work. Check it by right-clicking a step and choosing **View Native Query**. Steps like adding an index, some custom M functions, or merging across sources break folding. Incremental refresh **requires** folding.

**Where should transformations happen?**
"As far upstream as possible, as far downstream as necessary" (Roche's maxim). Heavy cleaning belongs in Databricks. Light shaping can happen in Power Query, and only presentation logic goes in DAX.

**Merge vs Append?**
Merge is a join, which adds columns. Append is a union, which adds rows.

**How do you handle errors or nulls?**
Use Replace errors, Keep errors (to audit them), and type every column explicitly. In this project, `TRY_CAST` in silver turns bad values into NULL.

---

## E. Storage modes and performance

**Import vs DirectQuery vs Composite vs Direct Lake?**
- **Import** is the fastest option with the full set of DAX features. Data is as fresh as the last refresh, and model size is limited (1 GB on Pro).
- **DirectQuery** queries the source live. Data is always fresh, but it's slower, some DAX is limited, and the source takes the load.
- **Composite** mixes the two, for example importing the dimensions and the aggregation table while the large fact stays in DirectQuery.
- **Direct Lake** (Fabric) reads Delta/Parquet from OneLake directly, combining near-Import speed with no refresh copy.

**How would you speed up a slow report?**
1. Use **Performance Analyzer** to find the slow visual.
2. Copy its query into **DAX Studio**, then check Server Timings and the storage engine vs formula engine split.
3. Fix the model: remove unused columns, reduce cardinality (split datetime into date + time, round decimals), use integer keys, avoid bi-directional relationships, and turn off auto date/time.
4. Fix the DAX: use VARs, avoid FILTER over whole tables, and avoid nested iterators over large tables.
5. Reduce the number of visuals per page and use aggregations.

**What is VertiPaq?**
The in-memory columnar engine. It compresses each column with dictionary and run-length encoding, so **low cardinality means a small model**. Use VertiPaq Analyzer to see column sizes.

**Incremental refresh?**
Create the `RangeStart`/`RangeEnd` datetime parameters, filter the date column on them (this must fold), then set the policy (archive N years, refresh the last N days). Only new partitions are refreshed.

**Aggregations?**
A small pre-aggregated table (`agg_daily_airline_origin`) mapped through Manage aggregations. The engine answers queries from it automatically when the grain allows.

---

## F. Security and the Power BI Service

**Static vs dynamic RLS?**
Static RLS hard-codes a value per role. Dynamic RLS uses a single role plus `USERPRINCIPALNAME()` and a user-to-entity mapping table. See `rls_roles.dax`.

**Who does RLS apply to?**
Viewers only. Workspace Admins, Members and Contributors see all data.

**OLS?**
Object-level security hides tables or columns. You set it up with Tabular Editor.

**Workspace roles?**
Admin, Member, Contributor and Viewer. Share to consumers through an **App**, not by adding them to the workspace.

**Gateway?**
Needed for on-premises or private-network sources. Databricks is a cloud source, so it usually needs no gateway (unless it uses private link).

**Deployment pipelines?**
Dev → Test → Prod stages, with deployment rules that change the data source or parameters per stage. Alternatively, use **Fabric Git integration** with PBIP files.

**Scheduled refresh limits?**
Pro allows 8 per day and Premium/Fabric capacity allows 48 per day. Refresh is also triggerable via the API or Power Automate.

---

## G. Databricks (they will ask if it's on your CV)

**Medallion architecture?**
- **Bronze**: raw data, kept as-is, with lineage.
- **Silver**: cleaned, conformed and deduplicated.
- **Gold**: business-level models and aggregates. In this project gold is the star schema.

**What is Delta Lake?**
Parquet files plus a transaction log (`_delta_log`). It adds ACID transactions, schema enforcement and evolution, **time travel** (`SELECT … VERSION AS OF 3`), `MERGE`, and `OPTIMIZE`.

**Unity Catalog?**
Centralised governance using a three-level namespace (`catalog.schema.table`). It provides grants, lineage, audit and volumes for files.

**Liquid clustering vs partitioning vs Z-ORDER?**
Liquid clustering (`CLUSTER BY`) is the modern default. It's flexible, the keys can be changed later, and it works well with skewed data. Partitioning suits only very large tables with low-cardinality keys. Z-ORDER is the older approach to co-locating data.

**Why `TRY_CAST`?**
Serverless runs in ANSI mode, where a bad cast fails the whole job. TRY_CAST returns NULL instead, and the DQ checks then catch it.

**Incremental ingestion?**
Auto Loader (`cloudFiles`) with a checkpoint, then `MERGE` into silver for upserts.

**Power BI to Databricks connection details?**
Server hostname + HTTP path of a **SQL warehouse**, authenticated with a PAT for development or OAuth / a service principal in production. You can also **Publish to Power BI** directly from Databricks.

---

## H. Git / CI

**How do you version-control Power BI?**
Save as **PBIP** with **TMDL**. The model and report become text files, which gives reviewable diffs, branching and PRs. Exclude `.pbi/cache.abf` and `localSettings.json`. Never commit tokens. For deployment, use Fabric Git integration or deployment pipelines.

---

## I. Scenario questions (practise these)

1. *"The total row doesn't equal the sum of the rows."* Measures are re-evaluated in the total's filter context, which is expected for averages and ratios. Fix it with `SUMX(VALUES(dim), [measure])` if the business wants a true sum.
2. *"Yesterday's numbers are missing."* Check the refresh history, gateway or credentials expiry (has the PAT expired?), and the incremental refresh window.
3. *"A user sees data they shouldn't."* Check whether they are a workspace Member rather than a Viewer, test with **View as**, and check bi-directional relationships that bypass RLS.
4. *"The report takes 20 seconds to load."* Follow the performance answer in section E.
5. *"Visuals show (Blank) in the airline axis."* Fact keys have no match in the dimension, which means orphan keys. This is exactly why gold maps them to `UNK` and DQ check #3 exists.
