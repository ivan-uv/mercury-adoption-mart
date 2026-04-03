# %% [markdown]
# # Pandas & Polars: Complete Walkthrough
# **Dataset: 2015–2019 Boston Marathon Results (~132,000 runners)**
#
# This file walks through everything you need to know about pandas and polars,
# side by side, using real marathon data. Run each cell interactively in VS Code
# (Ctrl+Shift+P → "Run Cell" or Shift+Enter).
#
# ## Setup
# ```
# uv sync
# ```

# %%
# === SETUP & DATA LOADING ===
import pandas as pd
import polars as pl
import requests
from io import StringIO

BASE_URL = "https://raw.githubusercontent.com/adrian3/Boston-Marathon-Data-Project/refs/heads/master/results{year}.csv"

# Download all 5 years — f-string loop, not a hardcoded list, because the
# URL pattern is perfectly predictable. Add a `year` column to each.
frames = []
for year in range(2015, 2020):
    url = BASE_URL.format(year=year)
    print(f"Downloading {year}...")
    csv_text = requests.get(url).text
    df = pd.read_csv(StringIO(csv_text), na_values=["NULL", ""], on_bad_lines="skip")
    df["year"] = year
    frames.append(df)

pdf = pd.concat(frames, ignore_index=True)

# Real-world data is messy: `age` has a stray "M" in 2019, `place_overall`
# has comma-formatted strings like "1,000", some columns flip between float
# (all-NaN) and string across years. Clean it up before converting to polars.
for col in ["place_overall", "age", "seconds", "overall", "gender_result", "division_result"]:
    pdf[col] = pd.to_numeric(
        pdf[col].astype(str).str.replace(",", "", regex=False), errors="coerce"
    )

# pl.from_pandas() converts a pandas DataFrame to polars — the standard
# interop path. We use it here because the raw CSVs have comma-formatted
# numbers ("1,000") and ragged lines that trip up polars' strict CSV parser.
plf = pl.from_pandas(pdf, nan_to_null=True)
print(f"\nLoaded {len(pdf)} runners across 5 years")

# %% [markdown]
# ---
# # 1. Reading Data
# Pandas and polars both read CSVs easily, but the APIs differ slightly.
# We already loaded multi-year data above — here's how a single file works.

# %%
# === PANDAS: Read CSV ===
print(f"pandas DataFrame: {pdf.shape[0]} rows × {pdf.shape[1]} columns")
print(f"Type: {type(pdf)}")
pdf.head()

# %%
# === POLARS: Read CSV ===
print(f"polars DataFrame: {plf.shape[0]} rows × {plf.shape[1]} columns")
print(f"Type: {type(plf)}")
plf.head()

# %% [markdown]
# ---
# # 2. Core Data Structures
#
# | Concept | Pandas | Polars |
# |---------|--------|--------|
# | 1D data | `pd.Series` | `pl.Series` |
# | 2D data | `pd.DataFrame` | `pl.DataFrame` |
# | Lazy eval | No native (use method chaining) | `pl.LazyFrame` |
# | Index | Yes (row labels) | **No index** — polars is index-free |

# %%
# === PANDAS: Series ===
ages_pd = pdf["age"]
print(f"Type: {type(ages_pd)}")
print(f"dtype: {ages_pd.dtype}")
print(f"Index: {ages_pd.index[:5].tolist()}")  # pandas Series have an index
ages_pd.head()

# %%
# === POLARS: Series ===
ages_pl = plf["age"]
print(f"Type: {type(ages_pl)}")
print(f"dtype: {ages_pl.dtype}")
# No index in polars! Rows are accessed by position only.
ages_pl.head()

# %% [markdown]
# ---
# # 3. Inspecting Data
# First things to do with any new dataset.

# %%
# === PANDAS: Inspect ===
print("--- dtypes ---")
print(pdf.dtypes)
print("\n--- info ---")
pdf.info()
print("\n--- describe ---")
pdf.describe()

# %%
# === POLARS: Inspect ===
print("--- dtypes ---")
print(plf.dtypes)
print("\n--- schema ---")
print(plf.schema)
print("\n--- describe ---")
plf.describe()

# %% [markdown]
# ---
# # 4. Selecting Columns
#
# **Key difference**: Polars uses `select()` with expressions, not bracket indexing
# for multiple columns.

# %%
# === PANDAS: Select columns ===
# Single column → Series
print(type(pdf["name"]))

# Multiple columns → DataFrame
subset_pd = pdf[["display_name", "age", "gender", "official_time", "seconds"]]
subset_pd.head()

# %%
# === POLARS: Select columns ===
# Single column → Series
print(type(plf["name"]))

# Multiple columns → DataFrame (use select)
subset_pl = plf.select(["display_name", "age", "gender", "official_time", "seconds"])
# Or with expressions:
subset_pl2 = plf.select(
    pl.col("display_name"), pl.col("age"), pl.col("gender"),
    pl.col("official_time"), pl.col("seconds"),
)
subset_pl.head()

# %% [markdown]
# ---
# # 5. Filtering Rows
#
# **Key difference**: Polars uses `filter()` with expressions.
# Pandas uses boolean indexing.

# %%
# === PANDAS: Filter ===
# Runners under 25
young_pd = pdf[pdf["age"] < 25]
print(f"Runners under 25: {len(young_pd)}")

# Multiple conditions (use & for AND, | for OR, wrap each in parentheses)
# Sub-3-hour = under 10800 seconds
young_fast_pd = pdf[(pdf["age"] < 25) & (pdf["seconds"] < 10800)]
print(f"Under 25 AND sub-3-hour: {len(young_fast_pd)}")

# String filtering
kenya_pd = pdf[pdf["country_residence"] == "Kenya"]
print(f"Kenyan runners: {len(kenya_pd)}")

# %%
# === POLARS: Filter ===
# Runners under 25
young_pl = plf.filter(pl.col("age") < 25)
print(f"Runners under 25: {len(young_pl)}")

# Multiple conditions
young_fast_pl = plf.filter((pl.col("age") < 25) & (pl.col("seconds") < 10800))
print(f"Under 25 AND sub-3-hour: {len(young_fast_pl)}")

# String filtering
kenya_pl = plf.filter(pl.col("country_residence") == "Kenya")
print(f"Kenyan runners: {len(kenya_pl)}")

# %% [markdown]
# ---
# # 6. Adding / Modifying Columns
#
# **Key difference**: Polars uses `with_columns()`. Pandas assigns directly.

# %%
# === PANDAS: Add columns ===
# Convert seconds to minutes
pdf["minutes"] = pdf["seconds"] / 60

# Hours as a readable float
pdf["hours"] = pdf["seconds"] / 3600

# Speed in mph (26.2 miles / hours)
pdf["mph"] = 26.2 / pdf["hours"]

pdf[["display_name", "official_time", "seconds", "minutes", "hours", "mph"]].head(10)

# %%
# === POLARS: Add columns ===
plf = plf.with_columns(
    (pl.col("seconds") / 60).alias("minutes"),
    (pl.col("seconds") / 3600).alias("hours"),
)

# Can chain another with_columns (or do it all in one)
plf = plf.with_columns(
    (pl.lit(26.2) / pl.col("hours")).alias("mph"),
)

plf.select("display_name", "official_time", "seconds", "minutes", "hours", "mph").head(10)

# %% [markdown]
# ---
# # 7. Sorting
#
# Both libraries use `sort_values` (pandas) or `sort` (polars).

# %%
# === PANDAS: Sort ===
# Fastest finishers
fastest_pd = pdf.sort_values("seconds").head(10)
fastest_pd[["display_name", "gender", "age", "country_residence", "official_time", "year"]]

# %%
# === POLARS: Sort ===
fastest_pl = plf.sort("seconds").head(10)
fastest_pl.select("display_name", "gender", "age", "country_residence", "official_time", "year")

# %%
# Sort by multiple columns
# Pandas
pdf.sort_values(["gender", "seconds"], ascending=[True, True]).head(5)

# %%
# Polars
plf.sort(["gender", "seconds"]).head(5)

# %% [markdown]
# ---
# # 8. GroupBy & Aggregation
#
# **Key difference**: Polars groupby returns results via `agg()` with expressions.
# Pandas uses a different API with `.agg()` or direct methods.

# %%
# === PANDAS: GroupBy ===
# Average finish time by gender
print(pdf.groupby("gender")["seconds"].mean())
print()

# Multiple aggregations
gender_stats_pd = pdf.groupby("gender")["seconds"].agg(["count", "mean", "median", "min", "max"])
print(gender_stats_pd)

# %%
# === POLARS: GroupBy ===
# Average finish time by gender
print(plf.group_by("gender").agg(pl.col("seconds").mean()))
print()

# Multiple aggregations
gender_stats_pl = plf.group_by("gender").agg(
    pl.col("seconds").count().alias("count"),
    pl.col("seconds").mean().alias("mean"),
    pl.col("seconds").median().alias("median"),
    pl.col("seconds").min().alias("min"),
    pl.col("seconds").max().alias("max"),
)
print(gender_stats_pl)

# %%
# === PANDAS: GroupBy with multiple columns ===
country_gender_pd = (
    pdf.groupby(["country_residence", "gender"])["seconds"]
    .agg(["count", "mean"])
    .reset_index()
    .sort_values("count", ascending=False)
    .head(10)
)
country_gender_pd

# %%
# === POLARS: GroupBy with multiple columns ===
country_gender_pl = (
    plf.group_by(["country_residence", "gender"])
    .agg(
        pl.col("seconds").count().alias("count"),
        pl.col("seconds").mean().alias("mean"),
    )
    .sort("count", descending=True)
    .head(10)
)
country_gender_pl

# %% [markdown]
# ---
# # 9. Aggregation Functions Reference
#
# | Operation | Pandas | Polars |
# |-----------|--------|--------|
# | Count | `.count()` | `.count()` |
# | Sum | `.sum()` | `.sum()` |
# | Mean | `.mean()` | `.mean()` |
# | Median | `.median()` | `.median()` |
# | Min / Max | `.min()` / `.max()` | `.min()` / `.max()` |
# | Std dev | `.std()` | `.std()` |
# | Quantile | `.quantile(0.75)` | `.quantile(0.75)` |
# | Nunique | `.nunique()` | `.n_unique()` |
# | First / Last | `.first()` / `.last()` | `.first()` / `.last()` |

# %%
# Quick aggregation examples
# Pandas
print("=== Pandas ===")
print(f"Total runners: {pdf['name'].count()}")
print(f"Avg age: {pdf['age'].mean():.1f}")
print(f"Fastest time (sec): {pdf['seconds'].min()}")
print(f"Countries represented: {pdf['country_residence'].nunique()}")
print(f"Years: {sorted(pdf['year'].unique())}")

# %%
# Polars
print("=== Polars ===")
print(f"Total runners: {plf['name'].count()}")
print(f"Avg age: {plf['age'].mean():.1f}")
print(f"Fastest time (sec): {plf['seconds'].min()}")
print(f"Countries represented: {plf['country_residence'].n_unique()}")
print(f"Years: {plf['year'].unique().sort().to_list()}")

# %% [markdown]
# ---
# # 10. String Operations
#
# Pandas: `df["col"].str.method()`
# Polars: `pl.col("col").str.method()`

# %%
# === PANDAS: String ops ===
# Uppercase names
pdf["name_upper"] = pdf["name"].str.upper()

# Extract last name (before the comma — name is "Last, First" format)
pdf["extracted_last"] = pdf["name"].str.split(",").str[0].str.strip()

# Check if city contains "Boston"
boston_locals_pd = pdf[pdf["city"].str.contains("Boston", na=False)]
print(f"Runners from cities with 'Boston': {len(boston_locals_pd)}")

pdf[["name", "name_upper", "extracted_last", "display_name"]].head()

# %%
# === POLARS: String ops ===
plf = plf.with_columns(
    # Uppercase names
    pl.col("name").str.to_uppercase().alias("name_upper"),

    # Extract last name (before the comma)
    pl.col("name").str.split(",").list.first().str.strip_chars().alias("extracted_last"),
)

# Check if city contains "Boston"
boston_locals_pl = plf.filter(pl.col("city").str.contains("Boston"))
print(f"Runners from cities with 'Boston': {len(boston_locals_pl)}")

plf.select("name", "name_upper", "extracted_last", "display_name").head()

# %% [markdown]
# ---
# # 11. Missing / Null Data
#
# This dataset has a realistic null pattern: split times (5k, 10k, etc.)
# are populated for 2015–2017 but entirely NULL for 2018–2019.
# States are missing for international runners, etc.

# %%
# === PANDAS: Missing data ===
print("--- Null counts ---")
print(pdf.isnull().sum())
print(f"\nTotal nulls: {pdf.isnull().sum().sum()}")

# %%
# Drop rows with any null in specific columns
clean_pd = pdf.dropna(subset=["seconds", "official_time"])
print(f"Before: {len(pdf)}, After dropping nulls: {len(clean_pd)}")

# Fill nulls
filled_pd = pdf["state"].fillna("Unknown")
print(f"Nulls in state before fill: {pdf['state'].isnull().sum()}")
print(f"Nulls in state after fill: {filled_pd.isnull().sum()}")

# %%
# === POLARS: Missing data ===
print("--- Null counts ---")
print(plf.null_count())

# %%
# Drop rows with null in specific columns
clean_pl = plf.drop_nulls(subset=["seconds", "official_time"])
print(f"Before: {len(plf)}, After dropping nulls: {len(clean_pl)}")

# Fill nulls
filled_pl = plf.with_columns(
    pl.col("state").fill_null("Unknown").alias("state_filled"),
)
print(f"Nulls in state before: {plf['state'].null_count()}")
print(f"Nulls in state_filled after: {filled_pl['state_filled'].null_count()}")

# %% [markdown]
# ---
# # 12. Joins / Merges
#
# Let's create a secondary DataFrame to demonstrate joins.
# Note: `country_residence` values are truncated to ~7 chars in this data
# (e.g., "United " for United States) — a realistic data quality issue.

# %%
# Create a continent lookup matching the truncated country names in our data
continent_data = {
    "country_residence": [
        "United ", "Canada", "Kenya", "Ethiopi", "Japan",
        "Mexico", "Brazil", "Germany", "France", "China",
    ],
    "continent": [
        "North America", "North America", "Africa", "Africa", "Asia",
        "North America", "South America", "Europe", "Europe", "Asia",
    ],
}

# %%
# === PANDAS: Merge ===
continent_pd = pd.DataFrame(continent_data)

# Left join (keep all runners, add continent where available)
merged_pd = pdf.merge(continent_pd, on="country_residence", how="left")
print(f"Rows after merge: {len(merged_pd)}")
merged_pd[["display_name", "country_residence", "continent"]].head(10)

# %%
# === POLARS: Join ===
continent_pl = pl.DataFrame(continent_data)

# Left join
merged_pl = plf.join(continent_pl, on="country_residence", how="left")
print(f"Rows after join: {len(merged_pl)}")
merged_pl.select("display_name", "country_residence", "continent").head(10)

# %% [markdown]
# ### Join Types Reference
#
# | Type | Pandas `how=` | Polars `how=` | Keeps |
# |------|--------------|--------------|-------|
# | Inner | `"inner"` | `"inner"` | Only matching rows |
# | Left | `"left"` | `"left"` | All left + matching right |
# | Right | `"right"` | `"right"` | All right + matching left |
# | Outer | `"outer"` | `"full"` | All rows from both |
# | Cross | `"cross"` | `"cross"` | Cartesian product |

# %% [markdown]
# ---
# # 13. Window Functions
#
# Window functions compute values across a group but return a value
# for every row (unlike groupby which collapses rows).

# %%
# === PANDAS: Window functions ===
# Rank within gender (per year)
pdf["gender_rank"] = pdf.groupby(["year", "gender"])["seconds"].rank(method="min")

# Running average (rolling) of finish time by overall position
pdf_sorted = pdf.sort_values(["year", "overall"])
pdf_sorted["rolling_avg_10"] = pdf_sorted.groupby("year")["seconds"].transform(
    lambda s: s.rolling(window=10).mean()
)

pdf_sorted[["display_name", "year", "gender", "official_time", "gender_rank", "rolling_avg_10"]].head(15)

# %%
# === POLARS: Window functions ===
# Rank within gender using over()
plf = plf.with_columns(
    pl.col("seconds").rank(method="min").over("year", "gender").alias("gender_rank"),
)

# Rolling average (sort first, then use rolling)
plf_sorted = plf.sort("year", "overall")
plf_sorted = plf_sorted.with_columns(
    pl.col("seconds").rolling_mean(window_size=10).alias("rolling_avg_10"),
)

plf_sorted.select("display_name", "year", "gender", "official_time", "gender_rank", "rolling_avg_10").head(15)

# %% [markdown]
# ### `over()` — Polars' Killer Feature
#
# In polars, `over()` applies an expression within groups without collapsing rows.
# It's like a SQL window function. Pandas equivalent requires `groupby().transform()`.

# %%
# === PANDAS: groupby transform ===
pdf["avg_time_by_gender"] = pdf.groupby("gender")["seconds"].transform("mean")
pdf["time_vs_gender_avg"] = pdf["seconds"] - pdf["avg_time_by_gender"]
pdf[["display_name", "gender", "official_time", "avg_time_by_gender", "time_vs_gender_avg"]].head()

# %%
# === POLARS: over() ===
plf = plf.with_columns(
    pl.col("seconds").mean().over("gender").alias("avg_time_by_gender"),
    (pl.col("seconds") - pl.col("seconds").mean().over("gender")).alias("time_vs_gender_avg"),
)
plf.select("display_name", "gender", "official_time", "avg_time_by_gender", "time_vs_gender_avg").head()

# %% [markdown]
# ---
# # 14. Lazy Evaluation (Polars Only)
#
# Polars' **LazyFrame** builds a query plan and optimizes it before execution.
# This is one of polars' biggest advantages — it can reorder operations,
# push down filters, and eliminate unnecessary columns automatically.

# %%
# === POLARS: Lazy evaluation ===
# Convert to LazyFrame
lazy = plf.lazy()
print(f"Type: {type(lazy)}")

# Build a query (nothing executes yet!)
query = (
    lazy
    .filter(pl.col("gender") == "F")
    .filter(pl.col("age") < 30)
    .select("display_name", "age", "country_residence", "official_time", "seconds", "year")
    .sort("seconds")
    .head(20)
)

# See the optimized query plan
print("\n--- Query Plan ---")
print(query.explain())

# %%
# Execute with .collect()
result = query.collect()
print(f"Result: {result.shape[0]} rows × {result.shape[1]} columns")
result

# %% [markdown]
# ### Why Lazy Matters
# - **Predicate pushdown**: filters are pushed as early as possible
# - **Projection pushdown**: only needed columns are read
# - **Query optimization**: operations are reordered for efficiency
# - **Parallel execution**: polars automatically parallelizes operations
#
# For large datasets, lazy evaluation can be **dramatically** faster than eager.
# Pandas has no equivalent — every operation executes immediately.

# %% [markdown]
# ---
# # 15. Method Chaining
#
# Both libraries support chaining, but polars is designed around it.

# %%
# === PANDAS: Method chaining ===
result_pd = (
    pdf
    .query("gender == 'M' and age >= 40 and age < 50")
    .groupby("country_residence")["seconds"]
    .agg(["count", "mean"])
    .reset_index()
    .rename(columns={"count": "num_runners", "mean": "avg_seconds"})
    .query("num_runners >= 50")
    .sort_values("avg_seconds")
    .head(10)
)
result_pd

# %%
# === POLARS: Method chaining ===
result_pl = (
    plf
    .filter(
        (pl.col("gender") == "M")
        & (pl.col("age") >= 40)
        & (pl.col("age") < 50)
    )
    .group_by("country_residence")
    .agg(
        pl.col("seconds").count().alias("num_runners"),
        pl.col("seconds").mean().alias("avg_seconds"),
    )
    .filter(pl.col("num_runners") >= 50)
    .sort("avg_seconds")
    .head(10)
)
result_pl

# %% [markdown]
# ---
# # 16. Reshaping Data (Pivot / Melt)

# %%
# === PANDAS: Pivot ===
# Average finish time by country and gender (top 5 countries)
top_countries = pdf["country_residence"].value_counts().head(5).index.tolist()
pivot_pd = (
    pdf[pdf["country_residence"].isin(top_countries)]
    .pivot_table(values="seconds", index="country_residence", columns="gender", aggfunc="mean")
    .round(0)
)
pivot_pd

# %%
# === POLARS: Pivot ===
top_countries_pl = (
    plf["country_residence"]
    .value_counts()
    .sort("count", descending=True)
    .head(5)["country_residence"]
    .to_list()
)

pivot_pl = (
    plf
    .filter(pl.col("country_residence").is_in(top_countries_pl))
    .pivot(on="gender", index="country_residence", values="seconds", aggregate_function="mean")
)
pivot_pl

# %%
# === PANDAS: Melt (unpivot) ===
# Melt split times into long format (only 2015–2017 have split data)
split_cols = ["5k", "10k", "15k", "20k", "half", "25k", "30k", "35k", "40k"]
melted_pd = (
    pdf[pdf["year"] <= 2017][["display_name", "year"] + split_cols]
    .head(5)
    .melt(
        id_vars=["display_name", "year"],
        value_vars=split_cols,
        var_name="checkpoint",
        value_name="split_time",
    )
)
melted_pd.head(15)

# %%
# === POLARS: Unpivot (melt) ===
split_cols_pl = ["5k", "10k", "15k", "20k", "half", "25k", "30k", "35k", "40k"]
melted_pl = (
    plf
    .filter(pl.col("year") <= 2017)
    .select(["display_name", "year"] + split_cols_pl)
    .head(5)
    .unpivot(
        on=split_cols_pl,
        index=["display_name", "year"],
        variable_name="checkpoint",
        value_name="split_time",
    )
)
melted_pl.head(15)

# %% [markdown]
# ---
# # 17. Applying Custom Functions
#
# **Key difference**: Polars discourages row-wise apply (it's slow).
# Use expressions instead. Pandas `.apply()` is convenient but slow.

# %%
# === PANDAS: Apply ===
# Categorize finish time (seconds-based thresholds)
def pace_category(secs):
    if pd.isna(secs):
        return "DNF"
    elif secs < 10800:   # 3 hours
        return "Elite (<3h)"
    elif secs < 14400:   # 4 hours
        return "Fast (3-4h)"
    elif secs < 18000:   # 5 hours
        return "Average (4-5h)"
    else:
        return "Recreational (5h+)"

pdf["pace_cat"] = pdf["seconds"].apply(pace_category)
print(pdf["pace_cat"].value_counts())

# %%
# === POLARS: Use when/then/otherwise (preferred over apply!) ===
plf = plf.with_columns(
    pl.when(pl.col("seconds").is_null())
    .then(pl.lit("DNF"))
    .when(pl.col("seconds") < 10800)
    .then(pl.lit("Elite (<3h)"))
    .when(pl.col("seconds") < 14400)
    .then(pl.lit("Fast (3-4h)"))
    .when(pl.col("seconds") < 18000)
    .then(pl.lit("Average (4-5h)"))
    .otherwise(pl.lit("Recreational (5h+)"))
    .alias("pace_cat")
)
print(plf["pace_cat"].value_counts().sort("pace_cat"))

# %% [markdown]
# ### Performance Note
# Polars `when/then/otherwise` runs as a vectorized operation (fast!).
# Pandas `apply()` runs Python for each row (slow!).
# Always prefer expressions over apply in both libraries when possible.

# %% [markdown]
# ---
# # 18. Concatenation
#
# Stacking DataFrames vertically or horizontally.
# (We already used concat to combine years — here's another example.)

# %%
# Split data and recombine
# === PANDAS ===
males_pd = pdf[pdf["gender"] == "M"]
females_pd = pdf[pdf["gender"] == "F"]
combined_pd = pd.concat([males_pd, females_pd], ignore_index=True)
print(f"Pandas concat: {len(males_pd)} + {len(females_pd)} = {len(combined_pd)}")

# %%
# === POLARS ===
males_pl = plf.filter(pl.col("gender") == "M")
females_pl = plf.filter(pl.col("gender") == "F")
combined_pl = pl.concat([males_pl, females_pl])
print(f"Polars concat: {len(males_pl)} + {len(females_pl)} = {len(combined_pl)}")

# %% [markdown]
# ---
# # 19. Writing Data
#
# Both support CSV, Parquet, JSON, and more.

# %%
# === PANDAS: Write ===
# pdf.to_csv("output.csv", index=False)
# pdf.to_parquet("output.parquet", index=False)
# pdf.to_json("output.json", orient="records")
print("Pandas write methods: .to_csv(), .to_parquet(), .to_json(), .to_excel()")

# %%
# === POLARS: Write ===
# plf.write_csv("output.csv")
# plf.write_parquet("output.parquet")
# plf.write_json("output.json")
print("Polars write methods: .write_csv(), .write_parquet(), .write_json()")

# %% [markdown]
# ---
# # 20. Performance Comparison
#
# Polars is typically **5-20x faster** than pandas for common operations,
# especially on larger datasets. Key reasons:
#
# 1. **Written in Rust** — no Python GIL overhead for core operations
# 2. **Columnar memory layout** — cache-friendly, like Apache Arrow
# 3. **Lazy evaluation** — query optimizer eliminates wasted work
# 4. **Automatic parallelism** — uses all CPU cores by default
# 5. **No index overhead** — simpler data model = faster operations
#
# When to use each:
# - **Pandas**: huge ecosystem, more tutorials, better for quick exploration,
#   many libraries expect pandas DataFrames
# - **Polars**: better performance, cleaner API, better for production pipelines,
#   large datasets that don't fit well in pandas

# %%
# === Quick timing comparison ===
import time

# Pandas groupby
start = time.time()
for _ in range(100):
    pdf.groupby(["year", "gender", "country_residence"])["seconds"].mean()
pd_time = time.time() - start

# Polars groupby
start = time.time()
for _ in range(100):
    plf.group_by(["year", "gender", "country_residence"]).agg(pl.col("seconds").mean())
pl_time = time.time() - start

print(f"Pandas  100x groupby: {pd_time:.3f}s")
print(f"Polars  100x groupby: {pl_time:.3f}s")
print(f"Polars is {pd_time / pl_time:.1f}x faster")

# %% [markdown]
# ---
# # 21. Quick Reference: Pandas ↔ Polars Translation
#
# | Operation | Pandas | Polars |
# |-----------|--------|--------|
# | Read CSV | `pd.read_csv(f)` | `pl.read_csv(f)` |
# | Select cols | `df[["a","b"]]` | `df.select("a","b")` |
# | Filter rows | `df[df["a"]>5]` | `df.filter(pl.col("a")>5)` |
# | Add column | `df["new"]=expr` | `df.with_columns(expr.alias("new"))` |
# | Sort | `df.sort_values("a")` | `df.sort("a")` |
# | GroupBy | `df.groupby("a")["b"].mean()` | `df.group_by("a").agg(pl.col("b").mean())` |
# | Join | `df.merge(df2,on="a")` | `df.join(df2,on="a")` |
# | Null check | `df.isnull()` | `df.null_count()` |
# | Fill null | `df.fillna(val)` | `df.fill_null(val)` |
# | Drop null | `df.dropna()` | `df.drop_nulls()` |
# | Unique vals | `df["a"].nunique()` | `df["a"].n_unique()` |
# | Value counts | `df["a"].value_counts()` | `df["a"].value_counts()` |
# | Rename cols | `df.rename(columns={"a":"b"})` | `df.rename({"a":"b"})` |
# | Drop cols | `df.drop(columns=["a"])` | `df.drop("a")` |
# | Shape | `df.shape` | `df.shape` |
# | Head | `df.head(n)` | `df.head(n)` |
# | Lazy mode | N/A | `df.lazy()` → `.collect()` |
# | Window fn | `df.groupby("a")["b"].transform("mean")` | `pl.col("b").mean().over("a")` |

# %% [markdown]
# ---
# # Done!
#
# You now know the core of both pandas and polars.
# Head to `practice_questions.py` to test yourself!
