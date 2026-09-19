-- 1. Seller business contribution

SELECT
    oi.seller_id,

    COUNT(DISTINCT oi.order_id) AS orders,

    COUNT(*) AS items_sold,

    ROUND(
        SUM(oi.price),
        2
    ) AS merchandise_gmv,

    ROUND(
        SUM(oi.freight_value),
        2
    ) AS freight_value,

    ROUND(
        SUM(oi.price)
        / COUNT(DISTINCT oi.order_id),
        2
    ) AS gmv_per_order

FROM order_items oi

JOIN orders o
    ON oi.order_id = o.order_id

WHERE o.order_status = 'delivered'

GROUP BY oi.seller_id

ORDER BY merchandise_gmv DESC

LIMIT 20;

-- 2. Seller volume and fulfillment risk

WITH seller_orders AS (

    SELECT
        oi.seller_id,
        oi.order_id,

        SUM(oi.price) AS seller_order_gmv

    FROM order_items oi

    GROUP BY
        oi.seller_id,
        oi.order_id
)

SELECT
    so.seller_id,

    COUNT(*) AS seller_orders,

    ROUND(
        SUM(so.seller_order_gmv),
        2
    ) AS merchandise_gmv,

    SUM(
        CASE
            WHEN o.is_late = TRUE
            THEN 1
            ELSE 0
        END
    ) AS late_orders,

    ROUND(
        AVG(o.is_late::int) * 100,
        2
    ) AS late_rate_pct,

    ROUND(
        AVG(o.delivery_days)::numeric,
        2
    ) AS avg_delivery_days

FROM seller_orders so

JOIN orders o
    ON so.order_id = o.order_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL

GROUP BY so.seller_id

HAVING COUNT(*) >= 100

ORDER BY late_orders DESC;

-- 3. Category business performance

SELECT
    p.product_category,

    COUNT(DISTINCT oi.order_id) AS orders,

    COUNT(*) AS items_sold,

    ROUND(
        SUM(oi.price),
        2
    ) AS merchandise_gmv,

    ROUND(
        SUM(oi.price)
        / COUNT(DISTINCT oi.order_id),
        2
    ) AS category_revenue_per_order,

    ROUND(
        AVG(oi.price),
        2
    ) AS avg_item_price

FROM order_items oi

JOIN products p
    ON oi.product_id = p.product_id

JOIN orders o
    ON oi.order_id = o.order_id

WHERE o.order_status = 'delivered'

GROUP BY p.product_category

ORDER BY merchandise_gmv DESC

LIMIT 20;

-- 4. Category fulfillment performance

WITH order_categories AS (

    SELECT DISTINCT
        oi.order_id,
        p.product_category

    FROM order_items oi

    JOIN products p
        ON oi.product_id = p.product_id
)

SELECT
    oc.product_category,

    COUNT(*) AS category_orders,

    SUM(
        CASE
            WHEN o.is_late = TRUE
            THEN 1
            ELSE 0
        END
    ) AS late_orders,

    ROUND(
        AVG(o.is_late::int) * 100,
        2
    ) AS late_rate_pct,

    ROUND(
        AVG(o.delivery_days)::numeric,
        2
    ) AS avg_delivery_days

FROM order_categories oc

JOIN orders o
    ON oc.order_id = o.order_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL

GROUP BY oc.product_category

HAVING COUNT(*) >= 300

ORDER BY late_orders DESC;