## Overview

SQL and Power BI project on the Online Retail II dataset.
Goal is to move from raw ecommerce orders to clear views of revenue, products, countries, and returns.

Full write up with screenshots sits in `docs/CohensProjectSummary.pdf`.

## At a glance

* Dataset: Online Retail II (UK based online store)
* Rows: about 541,909 order lines
* Tech stack: PostgreSQL, pgAdmin, Power BI
* Focus: revenue trend, customer and product value, country performance, returns

Key insights in one line:

* Revenue grows strongly into 2011 Q4
* A small group of customers and products drives most revenue
* Returns remove about 8 percent of gross revenue

## What this repo shows

* How raw CSV loads into PostgreSQL
* How staging tables become clean order, customer, product, and country tables
* How targeted SQL answers business questions
* How those query results feed a one page Power BI dashboard

## Files and structure

* `sql/`

  * `01_create_tables.sql`
  * `02_cleaning.sql`
  * `03_analysis_queries.sql`

* `data_raw/`

  * Notes and link to the original Online Retail II dataset

* `data_clean/`

  * CSV outputs from the analysis queries, ready for Power BI

* `dashboard/`

  * Main Power BI screenshot

* `docs/`

  * `CohensProjectSummary.pdf`
  * `analysis_log.txt`

* `databasescreenshots/`

  * Screenshots of table creation and row count checks

* `queryresults/`

  * Screenshots of key query outputs

## How to run the SQL

1. Create a PostgreSQL database named `online_retail`.
2. Run `sql/01_create_tables.sql` to create base and aggregate tables.
3. Load the Online Retail II CSV into `raw_orders`.
4. Run `sql/02_cleaning.sql` to build `clean_orders`, `returns_orders`, `order_level`, `customer_metrics`, and `product_metrics`.
5. Run `sql/03_analysis_queries.sql` to generate result sets for the dashboard and key findings.

## How to view the dashboard

1. Open Power BI Desktop.
2. Load the CSV files from `data_clean/`.
3. Rebuild visuals based on the field names, or open the `.pbix` file if it is included in the repo.
4. Main visuals:

   * Revenue by quarter
   * Revenue by country
   * Products with highest returns rate
   * Revenue by month
   * Top products by revenue
   * Average order value by country

## Why this project matters

This project shows end to end work:

* Working with a real, messy retail dataset
* Building a small analytical model in SQL
* Translating business questions into queries
* Turning those results into a clean dashboard for stakeholders and recruiters
