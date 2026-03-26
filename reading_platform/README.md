# 📚 Reading Platform — Analytics Data Warehouse

An end-to-end analytics project built on a fictional book-reading platform. Covers the full data pipeline from raw seed data through staging, mart dimensions and facts, to analytical wide tables — built with **dbt + DuckDB**.

---

## Project Structure

```
reading_platform/
│
├── seeds/                        # Raw CSV source data (loaded via dbt seed)
│   ├── authors.csv
│   ├── books.csv
│   ├── users.csv
│   ├── subscriptions.csv
│   ├── payments.csv
│   ├── reading_sessions.csv
│   ├── reviews.csv
│   └── seeds.yml                 # Column types
│
├── models/
│   ├── raw/                      # Views directly on top of seeds — no logic
│   │   ├── raw_authors.sql
│   │   ├── raw_books.sql
│   │   ├── raw_users.sql
│   │   ├── raw_subscriptions.sql
│   │   ├── raw_payments.sql
│   │   ├── raw_reading_sessions.sql
│   │   ├── raw_reviews.sql
│   │   └── raw.yml               # Add data_tests for values
│   │
│   ├── staging/                  # Clean, renamed, typed, surrogate-keyed models
│   │   ├── stg_authors.sql
│   │   ├── stg_books.sql
│   │   ├── stg_users.sql
│   │   ├── stg_subscriptions.sql
│   │   ├── stg_payments.sql
│   │   ├── stg_reading_sessions.sql
│   │   ├── stg_reviews.sql
│   │   └── staging.yml
│   │
│   └── mart/                     # Dimensional model + analytical wide tables
│       ├── dim_authors.sql       # Author dimension with total book count
│       ├── dim_books.sql         # Book dimension with denormalised author info
│       ├── dim_users.sql         # User dimension with engagement metrics
│       ├── dim_date.sql          # Generated date spine 2019–2030
│       ├── fct_reading_sessions.sql   # Grain: 1 row per session (incremental)
│       ├── fct_reviews.sql            # Grain: 1 row per review (incremental)
│       ├── fct_transactions.sql       # Grain: 1 row per billing attempt (incremental)
│       ├── book_performance.sql       # Wide table: book metrics + window rankings
│       ├── user_stats.sql             # Wide table: user metrics + window rankings
│       ├── daily_book_stats.sql       # Grain: 1 row per book per day (incremental)
│       ├── daily_user_stats.sql       # Grain: 1 row per user per day (incremental)
│       └── mart.yml
│
├── macros/                       # Custom Jinja macros (empty by default)
├── analyses/                     # Ad-hoc SQL queries (not materialised)
├── tests/                        # Custom singular tests
├── snapshots/                    # SCD snapshots (not yet implemented)
├── packages.yml                  # dbt-utils dependency
├── dbt_project.yml
└── profiles.yml                  # DuckDB connection config
```

---

## Data Model Overview

```
seeds (CSV files)
    └── raw_* (views — no transformation)
            └── stg_* (staging — clean, typed, surrogate keys added)
                    │
                    ├── dim_authors          (table)
                    ├── dim_books            (table) 
                    ├── dim_users            (table)
                    ├── dim_date             (table, generated)
                    │
                    ├── fct_reading_sessions (incremental) ◄── dim_users, dim_books, dim_date
                    ├── fct_reviews          (incremental) ◄── dim_users, dim_books, dim_date
                    ├── fct_transactions     (incremental) ◄── dim_users, dim_date
                    │
                    ├── book_performance     (table) ◄── fct_reading_sessions, fct_reviews, dim_books
                    ├── user_stats           (table) ◄── fct_reading_sessions, fct_transactions, fct_reviews, dim_users
                    ├── daily_book_stats     (incremental) ◄── fct_reading_sessions, dim_books
                    └── daily_user_stats     (incremental) ◄── fct_reading_sessions, dim_users
```

### Seed row counts

| Seed file | Rows |
|---|---|
| authors.csv | 30 |
| books.csv | 80 |
| users.csv | 200 |
| subscriptions.csv | 220 |
| payments.csv | 1,906 |
| reading_sessions.csv | 600 |
| reviews.csv | 300 |

---

## Stack

| Component | Tool |
|---|---|
| Warehouse | DuckDB (local file `reading_platform.duckdb`) |
| Transformation | dbt Core 1.11 |
| Adapter | dbt-duckdb |
| Packages | dbt-utils (surrogate keys) |
| Python | see `requirements.txt` |

**Materialisation strategy:**

| Layer | Materialisation |
|---|---|
| raw | view |
| staging | view |
| dimensions | table |
| fact tables | incremental |
| wide mart tables | table |
| daily aggregates | incremental |

---

## Getting Started

**1. Install Python dependencies**
```bash
pip install -r requirements.txt
```

**2. Install dbt packages**
```bash
dbt deps
```

**3. Verify connection**
```bash
dbt debug
```

**4. Load seed data**
```bash
dbt seed
```

**5. Build everything (run + test in DAG order)**
```bash
dbt build
```

Or step by step:
```bash
dbt run    # build all models
dbt test   # run all tests
```

**6. Generate and view documentation**
```bash
dbt docs generate
dbt docs serve
```

---

## Incremental Strategy

Fact and daily aggregate models use incremental materialisation — on first run they build fully, on subsequent runs they only process new records based on a timestamp filter.

| Model | Incremental key |
|---|---|
| `fct_reading_sessions` | `started_at > max(started_at)` |
| `fct_reviews` | `created_at > max(created_at)` |
| `fct_transactions` | `started_at > max(started_at)` |
| `daily_book_stats` | `session_date > max(session_date)` |
| `daily_user_stats` | `session_date > max(session_date)` |

Force a full rebuild after schema changes:
```bash
dbt build --full-refresh --select fct_reading_sessions fct_reviews fct_transactions daily_book_stats daily_user_stats
```

---

## Testing

Tests are defined across three YAML files — `seeds.yml`, `staging.yml`, and `mart.yml` — and cover every layer of the pipeline.

| Test type | What it covers |
|---|---|
| `unique` + `not_null` | Every primary key and surrogate key |
| `relationships` | All foreign key references across the dimensional model |
| `accepted_values` | All enum columns — genre, language, country, plan_type, device_type, payment_method, status, rating, etc. |

```bash
# run all tests
dbt test

# test a specific model
dbt test --select fct_reading_sessions

# test a specific layer
dbt test --select staging
dbt test --select mart

# test by type
dbt test --select test_type:relationships
dbt test --select test_type:not_null
```

Total: **241 data tests** across 23 models and 7 seeds.

---

## Analytical Insights

The following insights were derived by querying the mart layer after a full `dbt build`.

---

### 1. Genre Performance

| # | Genre | Books | Authors | Unique Readers | Sessions | Avg Rating |
|---|---|---|---|---|---|---|
| 1 | Romance | 3 | 3 | 19 | 20 | ⭐ 3.95 |
| 2 | Biography | 6 | 6 | 47 | 47 | ⭐ 3.94 |
| 3 | History | 10 | 10 | 82 | 85 | ⭐ 3.94 |
| 4 | Mystery | 10 | 7 | 62 | 62 | ⭐ 3.92 |
| 5 | Thriller | 8 | 8 | 54 | 56 | ⭐ 3.81 |
| 6 | Fantasy | 10 | 8 | 77 | 77 | ⭐ 3.80 |
| 7 | Fiction | 7 | 7 | 52 | 54 | ⭐ 3.75 |
| 8 | Sci-Fi | 5 | 4 | 39 | 39 | ⭐ 3.75 |
| 9 | Horror | 8 | 7 | 65 | 67 | ⭐ 3.37 |
| 10 | Self-Help | 7 | 7 | 54 | 56 | ⭐ 3.18 |

**Key takeaways:**

- **Romance has the highest average rating (3.95)** despite having the smallest catalogue — only 3 books. High satisfaction combined with thin inventory is a strong signal to acquire more Romance titles.
- **History is the most-read genre** with 82 unique readers and 85 sessions across 10 books, suggesting deep and consistent demand.
- **Self-Help has the lowest average rating (3.18)** — nearly 0.8 points below Romance. With 54 readers engaging, this is a content quality problem, not a discovery problem. Users are finding Self-Help books but leaving disappointed.
- **Horror sits at 3.37** with 65 readers — second lowest rating but healthy engagement, suggesting genre loyalty even when satisfaction is below average.

---

### 2. Revenue Trends (2020–2026)

**Growth phase — 2020 to late 2024**

Revenue grew from under $50/month in mid-2020 to a peak in December 2024 where basic and premium combined exceeded **$1,200/month** ($419.58 basic + $799.60 premium) — roughly a **25× increase** over 4.5 years.

**Premium vs Basic split**

Premium consistently outpaced Basic throughout. By 2024, premium represented 60–70% of monthly revenue, with the gap widening from mid-2022 onwards.

**Payment method evolution**

| Period | Dominant method |
|---|---|
| 2020–2021 | PayPal / Apple Pay |
| 2022–mid 2024 | Apple Pay → Credit Card |
| Late 2024–2025 | Bank Transfer |
| 2026 | Credit Card / Google Pay returning |

Bank transfer becoming dominant in late 2024 likely indicates a shift toward annual billing or enterprise customers — cohorts with stronger retention and higher LTV.

**Decline from 2025 onwards**

Revenue peaked in December 2024 and declined through 2025–2026, dropping back to approximately 2021 levels by mid-2026. Worth monitoring `churn_rate` from `fct_transactions` to determine whether this is organic churn or seed data expiry.

---

### 3. Top Users by Revenue — Engagement Paradox

| # | User | Country | Pages Read | Books Completed | Lifetime Spend |
|---|---|---|---|---|---|
| 1 | U0096 | 🇮🇳 IN | 340 | 0 | $889.52 |
| 2 | U0105 | 🇯🇵 JP | 656 | 0 | $779.61 |
| 3 | U0139 | 🇧🇷 BR | 0 | 0 | $679.66 |
| 4 | U0090 | 🇬🇧 GB | 1,413 | 0 | $599.66 |
| 5 | U0052 | 🇩🇪 DE | 189 | 0 | $579.71 |
| 6 | U0119 | 🇺🇸 US | 900 | 0 | $579.60 |
| 7 | U0148 | 🇬🇧 GB | 1,493 | 0 | $559.57 |
| 8 | U0093 | 🇮🇹 IT | 825 | 0 | $539.65 |
| 9 | U0164 | 🇲🇽 MX | 472 | 0 | $499.72 |
| 10 | U0098 | 🇵🇱 PL | 489 | 0 | $489.68 |

**Key takeaways:**

- **Zero books completed across all top 10 spenders.** The platform's highest-value revenue segment is not finishing any books — a significant engagement-to-revenue disconnect.
- **U0139 (BR) paid $679.66 and read 0 pages.** Third-highest spender, completely inactive as a reader. Likely on an auto-renewing subscription they have forgotten about.
- **U0090 and U0148 (both GB)** read the most pages in this group (1,413 and 1,493) yet completed nothing — suggesting they read broadly across long books without finishing.
- **Geographic spread** across 9 different countries confirms no single market dominates the high-value segment. International retention strategy applies broadly.
- **Actionable signal:** High-spend / zero-completion users are the highest churn risk. A re-engagement campaign targeting this cohort (personalised recommendations, reading streak nudges, completion milestones) could reduce churn without new user acquisition spend.

---

## Sources & References

| Topic                              | Link                                                                      |
|------------------------------------|---------------------------------------------------------------------------|
| Generate data + promts during work | [Chat link](https://claude.ai/share/1e8490a7-53f2-426a-a98e-b1104cb5e445) |
