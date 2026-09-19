-- 1. Data coverage

SELECT
    MIN(order_purchase_timestamp) AS first_order_date,
    MAX(order_purchase_timestamp) AS last_order_date,
    COUNT(*) AS total_orders
FROM orders;

-- 2. Order status distribution

SELECT
    order_status,
    COUNT(*) AS orders,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS order_share_pct
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- 3. Delivered business overview

SELECT
    COUNT(DISTINCT o.order_id) AS delivered_orders,

    ROUND(
        SUM(oi.price),
        2
    ) AS merchandise_gmv,

    ROUND(
        SUM(oi.freight_value),
        2
    ) AS freight_revenue,

    ROUND(
        SUM(oi.item_total_value),
        2
    ) AS gross_order_value,

    ROUND(
        SUM(oi.price)
        / COUNT(DISTINCT o.order_id),
        2
    ) AS merchandise_aov

FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered';

-- 4. Monthly business performance

SELECT
    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    )::date AS month,

    COUNT(DISTINCT o.order_id) AS orders,

    ROUND(
        SUM(oi.price),
        2
    ) AS merchandise_gmv,

    ROUND(
        SUM(oi.price)
        / COUNT(DISTINCT o.order_id),
        2
    ) AS aov

FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered'

GROUP BY 1
ORDER BY 1;

-- 5. MoM Growth
WITH monthly_sales AS (
    SELECT
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        )::date AS month,

        COUNT(DISTINCT o.order_id) AS orders,
        SUM(oi.price) AS merchandise_gmv

    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY 1
),

monthly_growth AS (
    SELECT
        month,
        orders,
        merchandise_gmv,

        LAG(orders) OVER (
            ORDER BY month
        ) AS previous_month_orders,

        LAG(merchandise_gmv) OVER (
            ORDER BY month
        ) AS previous_month_gmv

    FROM monthly_sales
)

SELECT
    month,
    orders,
    ROUND(merchandise_gmv, 2) AS merchandise_gmv,

    ROUND(
        (orders - previous_month_orders)
        * 100.0
        / NULLIF(previous_month_orders, 0),
        2
    ) AS order_mom_pct,

    ROUND(
        (merchandise_gmv - previous_month_gmv)
        * 100.0
        / NULLIF(previous_month_gmv, 0),
        2
    ) AS gmv_mom_pct

FROM monthly_growth

WHERE month >= '2017-02-01'

ORDER BY month;