from pathlib import Path
import pandas as pd


# --------------------------------------------------
# 1. Paths
# --------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parent.parent

RAW_DIR = PROJECT_ROOT / "data" / "raw"
PROCESSED_DIR = PROJECT_ROOT / "data" / "processed"

PROCESSED_DIR.mkdir(parents=True, exist_ok=True)


# --------------------------------------------------
# 2. Load raw data
# --------------------------------------------------

orders = pd.read_csv(RAW_DIR / "olist_orders_dataset.csv")
customers = pd.read_csv(RAW_DIR / "olist_customers_dataset.csv")
order_items = pd.read_csv(RAW_DIR / "olist_order_items_dataset.csv")
products = pd.read_csv(RAW_DIR / "olist_products_dataset.csv")
sellers = pd.read_csv(RAW_DIR / "olist_sellers_dataset.csv")
category_translation = pd.read_csv(
    RAW_DIR / "product_category_name_translation.csv"
)
reviews = pd.read_csv(
    RAW_DIR / "olist_order_reviews_dataset.csv"
)


print("Raw data loaded successfully.")


# --------------------------------------------------
# 3. Clean orders
# --------------------------------------------------

order_date_columns = [
    "order_purchase_timestamp",
    "order_approved_at",
    "order_delivered_carrier_date",
    "order_delivered_customer_date",
    "order_estimated_delivery_date",
]

for column in order_date_columns:
    orders[column] = pd.to_datetime(
        orders[column],
        errors="coerce"
    )


# Operational status flags

orders["is_delivered"] = (
    orders["order_status"] == "delivered"
)

orders["is_canceled"] = (
    orders["order_status"] == "canceled"
)


# Approval time

orders["approval_hours"] = (
    orders["order_approved_at"]
    - orders["order_purchase_timestamp"]
).dt.total_seconds() / 3600


# Total delivery duration

orders["delivery_days"] = (
    orders["order_delivered_customer_date"]
    - orders["order_purchase_timestamp"]
).dt.total_seconds() / 86400


# Days early / late compared with estimated date

orders["delay_days"] = (
    orders["order_delivered_customer_date"].dt.normalize()
    - orders["order_estimated_delivery_date"].dt.normalize()
).dt.days


# Nullable boolean:
# True = late
# False = on time / early
# NA = not delivered

orders["is_late"] = pd.Series(
    pd.NA,
    index=orders.index,
    dtype="boolean"
)

has_delivery_date = (
    orders["order_delivered_customer_date"].notna()
)

orders.loc[
    has_delivery_date,
    "is_late"
] = (
    orders.loc[
        has_delivery_date,
        "delay_days"
    ] > 0
)


# --------------------------------------------------
# 4. Clean order items
# --------------------------------------------------

order_items["shipping_limit_date"] = pd.to_datetime(
    order_items["shipping_limit_date"],
    errors="coerce"
)

order_items["item_total_value"] = (
    order_items["price"]
    + order_items["freight_value"]
)


# --------------------------------------------------
# 5. Clean products
# --------------------------------------------------

products = products.rename(
    columns={
        "product_name_lenght":
            "product_name_length",

        "product_description_lenght":
            "product_description_length",
    }
)


products = products.merge(
    category_translation,
    on="product_category_name",
    how="left"
)


products = products.rename(
    columns={
        "product_category_name_english":
            "product_category"
    }
)


products["product_category"] = (
    products["product_category"]
    .fillna("unknown")
)


# --------------------------------------------------
# 6. Validation
# --------------------------------------------------

assert orders["order_id"].is_unique
assert customers["customer_id"].is_unique
assert products["product_id"].is_unique
assert sellers["seller_id"].is_unique

assert not (
    order_items["order_id"]
    .isin(orders["order_id"])
    .eq(False)
    .any()
)

assert not (
    order_items["product_id"]
    .isin(products["product_id"])
    .eq(False)
    .any()
)

assert not (
    order_items["seller_id"]
    .isin(sellers["seller_id"])
    .eq(False)
    .any()
)

print("Data validation passed.")

# --------------------------------------------------
# Clean reviews
# --------------------------------------------------

review_date_columns = [
    "review_creation_date",
    "review_answer_timestamp",
]

for column in review_date_columns:
    reviews[column] = pd.to_datetime(
        reviews[column],
        errors="coerce"
    )

# --------------------------------------------------
# 7. Export processed data
# --------------------------------------------------

orders.to_csv(
    PROCESSED_DIR / "orders.csv",
    index=False
)

customers.to_csv(
    PROCESSED_DIR / "customers.csv",
    index=False
)

order_items.to_csv(
    PROCESSED_DIR / "order_items.csv",
    index=False
)

products.to_csv(
    PROCESSED_DIR / "products.csv",
    index=False
)

sellers.to_csv(
    PROCESSED_DIR / "sellers.csv",
    index=False
)

reviews.to_csv(
    PROCESSED_DIR / "reviews.csv",
    index=False
)

print("Processed data exported successfully.")