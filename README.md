# GlobalCart — End-to-End Business Analytics

[English](README.md) | [中文](README_CN.md)

**Python · Pandas · PostgreSQL · SQL · Tableau**

GlobalCart is an end-to-end business analytics project built on the **Brazilian E-Commerce Public Dataset by Olist**. Using approximately **100K marketplace orders**, the project demonstrates a complete workflow from raw relational data to operational insights and interactive dashboards.

## Business Context & Objectives

The project focuses on four practical business questions:

1. How is the business performing over time?
2. Where are fulfillment delays concentrated, and which regions should be prioritised?
3. Which sellers and product categories combine high business value with fulfillment risk?
4. How is delivery performance associated with customer experience?

Workflow:

`Raw CSV → Python Profiling & Cleaning → PostgreSQL → SQL Analysis & Analytical Views → Tableau Dashboard`

## Key Design Decisions

- **Profile before cleaning:** missing delivery timestamps were analysed by order lifecycle status instead of being removed blindly.
- **Grain before JOIN:** order-, item-, seller- and category-level metrics were calculated at the correct grain to avoid duplicate counting.
- **Unknown ≠ False:** late-delivery flags use nullable logic so orders without delivery evidence are not misclassified as on-time.
- **SQL as the business logic layer:** reusable PostgreSQL views contain metric definitions and analytical logic; Tableau focuses on presentation and interaction.
- **Prioritisation beyond a single rate:** fulfillment priority was evaluated using **Rate × Volume × Promise Setting**, rather than Late Rate alone.

## Tableau Dashboard

### 1. Executive Overview
Business scale, order status, monthly orders and merchandise GMV.

![Executive Overview](dashboard/executive_overview.png)

### 2. Fulfillment Performance
Delivery speed, late-rate distribution, state-level priorities, fulfillment stages, and promised vs actual delivery time.

![Fulfillment Performance](dashboard/fulfillment_performance.png)

### 3. Seller & Category Operations
Seller risk matrix, top categories by GMV, and category-level fulfillment risk and impact.

![Seller & Category Operations](dashboard/seller_category_operations.png)

### 4. Customer Experience
Review distribution, repeat customer rate, and the relationship between delay severity and customer ratings.

![Customer Experience](dashboard/customer_experience.png)

## Selected Findings

- **Late Rate alone can be misleading:** AL had the highest late rate, but high-volume states such as SP and RJ affected far more customers.
- **Transit was the largest fulfillment gap:** late orders showed a much larger increase in transit time than in pre-carrier handling time.
- **Delivery delay was strongly associated with poorer reviews:** late orders averaged **2.27** review score vs **4.29** for on-time/early orders; orders delayed 7+ days had a **79.18%** low-rating rate.

## Environment & Tech Stack

| Layer | Tools |
|---|---|
| Development | macOS, VS Code, Python 3.12, virtual environment (`.venv`) |
| Data Processing | Pandas, NumPy, Jupyter |
| Database / ETL | PostgreSQL 18, SQLAlchemy, psycopg, python-dotenv |
| SQL Development | DBeaver, PostgreSQL |
| Visualisation | Tableau Desktop |
| Version Control | Git, GitHub |

## Repository Contents

- `notebooks/` — data profiling
- `src/` — cleaning and PostgreSQL loading scripts
- `sql/` — business analysis and BI views
- `dashboard/` — Tableau screenshots / workbook
- `README_CN.md` — Chinese project overview

> Dataset: Brazilian E-Commerce Public Dataset by Olist (Kaggle)
