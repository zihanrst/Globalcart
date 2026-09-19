from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
import os

from sqlalchemy import create_engine
from sqlalchemy.engine import URL


# --------------------------------------------------
# 1. Paths
# --------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parent.parent
PROCESSED_DIR = PROJECT_ROOT / "data" / "processed"


# --------------------------------------------------
# 2. Load database configuration
# --------------------------------------------------

load_dotenv(PROJECT_ROOT / ".env")

database_url = URL.create(
    drivername="postgresql+psycopg",
    username=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD"),
    host=os.getenv("DB_HOST"),
    port=int(os.getenv("DB_PORT", 5432)),
    database=os.getenv("DB_NAME"),
)

engine = create_engine(database_url)


# --------------------------------------------------
# 3. Load processed CSV files
# --------------------------------------------------

customers = pd.read_csv(
    PROCESSED_DIR / "customers.csv"
)

products = pd.read_csv(
    PROCESSED_DIR / "products.csv"
)

sellers = pd.read_csv(
    PROCESSED_DIR / "sellers.csv"
)

orders = pd.read_csv(
    PROCESSED_DIR / "orders.csv",
    parse_dates=[
        "order_purchase_timestamp",
        "order_approved_at",
        "order_delivered_carrier_date",
        "order_delivered_customer_date",
        "order_estimated_delivery_date",
    ]
)

order_items = pd.read_csv(
    PROCESSED_DIR / "order_items.csv",
    parse_dates=["shipping_limit_date"]
)

reviews = pd.read_csv(
    PROCESSED_DIR / "reviews.csv",
    parse_dates=[
        "review_creation_date",
        "review_answer_timestamp",
    ]
)

# Preserve nullable boolean semantics
orders["is_delivered"] = orders["is_delivered"].astype("boolean")
orders["is_canceled"] = orders["is_canceled"].astype("boolean")
orders["is_late"] = orders["is_late"].astype("boolean")


print("Processed CSV files loaded.")


# --------------------------------------------------
# 4. Load data into PostgreSQL
# --------------------------------------------------

# Load parent tables before child tables
customers.to_sql(
    "customers",
    engine,
    if_exists="append",
    index=False,
    chunksize=5000
)

print(f"customers loaded: {len(customers):,}")


products.to_sql(
    "products",
    engine,
    if_exists="append",
    index=False,
    chunksize=5000
)

print(f"products loaded: {len(products):,}")


sellers.to_sql(
    "sellers",
    engine,
    if_exists="append",
    index=False,
    chunksize=5000
)

print(f"sellers loaded: {len(sellers):,}")


orders.to_sql(
    "orders",
    engine,
    if_exists="append",
    index=False,
    chunksize=5000
)

print(f"orders loaded: {len(orders):,}")

reviews.to_sql(
    "reviews",
    engine,
    if_exists="append",
    index=False,
    chunksize=5000
)

print(f"reviews loaded: {len(reviews):,}")


order_items.to_sql(
    "order_items",
    engine,
    if_exists="append",
    index=False,
    chunksize=5000
)

print(f"order_items loaded: {len(order_items):,}")


print("All tables loaded successfully.")