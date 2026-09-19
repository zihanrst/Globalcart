-- ============================================================
-- 01. Executive Overview KPI
-- ============================================================

CREATE OR REPLACE VIEW vw_executive_kpis AS

WITH delivered_sales AS (
    SELECT
        COUNT(DISTINCT o.order_id) AS delivered_orders,
        SUM(oi.price) AS merchandise_gmv
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
)

SELECT
    (SELECT COUNT(*) FROM orders) AS total_orders,

    ds.delivered_orders,

    ROUND(
        ds.merchandise_gmv,
        2
    ) AS merchandise_gmv,

    ROUND(
        ds.merchandise_gmv
        / NULLIF(ds.delivered_orders, 0),
        2
    ) AS merchandise_aov,

    ROUND(
        (
            SELECT COUNT(*)
            FROM orders
            WHERE order_status = 'canceled'
        ) * 100.0
        / NULLIF(
            (SELECT COUNT(*) FROM orders),
            0
        ),
        2
    ) AS cancellation_rate_pct

FROM delivered_sales ds;

-- ============================================================
-- 02. Monthly Business Performance
-- ============================================================

CREATE OR REPLACE VIEW vw_monthly_business AS

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

      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'

    GROUP BY 1
),

monthly_growth AS (

    SELECT
        month,
        orders,
        merchandise_gmv,

        LAG(orders)
        OVER (ORDER BY month)
            AS previous_month_orders,

        LAG(merchandise_gmv)
        OVER (ORDER BY month)
            AS previous_month_gmv

    FROM monthly_sales
)

SELECT
    month,

    orders,

    ROUND(
        merchandise_gmv,
        2
    ) AS merchandise_gmv,

    ROUND(
        merchandise_gmv
        / NULLIF(orders, 0),
        2
    ) AS merchandise_aov,

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

ORDER BY month;

-- ============================================================
-- 03. Order Status Distribution
-- ============================================================

CREATE OR REPLACE VIEW vw_order_status AS

SELECT
    order_status,

    COUNT(*) AS orders,

    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        2
    ) AS order_share_pct

FROM orders

GROUP BY order_status;

-- ============================================================
-- 04. Delivery Performance Bands
-- ============================================================

CREATE OR REPLACE VIEW vw_delivery_bands AS

SELECT

    CASE
        WHEN delay_days <= -7
            THEN '7+ days early'

        WHEN delay_days BETWEEN -6 AND -1
            THEN '1-6 days early'

        WHEN delay_days = 0
            THEN 'On estimated date'

        WHEN delay_days BETWEEN 1 AND 3
            THEN '1-3 days late'

        WHEN delay_days BETWEEN 4 AND 7
            THEN '4-7 days late'

        WHEN delay_days > 7
            THEN '7+ days late'
    END AS delivery_band,

    CASE
        WHEN delay_days <= -7 THEN 1
        WHEN delay_days BETWEEN -6 AND -1 THEN 2
        WHEN delay_days = 0 THEN 3
        WHEN delay_days BETWEEN 1 AND 3 THEN 4
        WHEN delay_days BETWEEN 4 AND 7 THEN 5
        WHEN delay_days > 7 THEN 6
    END AS sort_order,

    COUNT(*) AS orders,

    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        2
    ) AS share_pct

FROM orders

WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL

GROUP BY 1, 2;

-- ============================================================
-- 05. State Fulfillment Priority
-- ============================================================

CREATE OR REPLACE VIEW vw_state_fulfillment AS

SELECT
    c.customer_state,

    COUNT(*) AS delivered_orders,

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
    ) AS avg_actual_delivery_days,

    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    o.order_estimated_delivery_date
                    - o.order_purchase_timestamp
                )
            ) / 86400
        )::numeric,
        2
    ) AS avg_promised_days,

    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    o.order_estimated_delivery_date
                    - o.order_delivered_customer_date
                )
            ) / 86400
        )::numeric,
        2
    ) AS avg_buffer_days

FROM orders o

JOIN customers c
    ON o.customer_id = c.customer_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL

GROUP BY c.customer_state

HAVING COUNT(*) >= 100;

-- ============================================================
-- 06. Late vs On-Time Fulfillment Stage
-- ============================================================

CREATE OR REPLACE VIEW vw_fulfillment_stage AS

SELECT

    CASE
        WHEN is_late = TRUE
            THEN 'Late'
        ELSE 'On time / Early'
    END AS delivery_status,

    COUNT(*) AS orders,

    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_carrier_date
                    - order_approved_at
                )
            ) / 86400
        )::numeric,
        2
    ) AS avg_pre_carrier_days,

    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_delivered_carrier_date
                )
            ) / 86400
        )::numeric,
        2
    ) AS avg_transit_days,

    ROUND(
        AVG(delivery_days)::numeric,
        2
    ) AS avg_total_delivery_days

FROM orders

WHERE order_status = 'delivered'
  AND order_approved_at IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL

GROUP BY 1;

-- ============================================================
-- 07. Seller Performance
-- ============================================================

CREATE OR REPLACE VIEW vw_seller_performance AS

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

HAVING COUNT(*) >= 100;

-- ============================================================
-- 08. Category Business + Fulfillment Performance
-- ============================================================

CREATE OR REPLACE VIEW vw_category_performance AS

WITH order_categories AS (

    SELECT
        oi.order_id,

        p.product_category,

        SUM(oi.price) AS category_gmv

    FROM order_items oi

    JOIN products p
        ON oi.product_id = p.product_id

    GROUP BY
        oi.order_id,
        p.product_category
)

SELECT
    oc.product_category,

    COUNT(*) AS category_orders,

    ROUND(
        SUM(oc.category_gmv),
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

FROM order_categories oc

JOIN orders o
    ON oc.order_id = o.order_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL

GROUP BY oc.product_category

HAVING COUNT(*) >= 300;

-- ============================================================
-- 09. Review Score Distribution
-- ============================================================

CREATE OR REPLACE VIEW vw_review_distribution AS

SELECT
    review_score,

    COUNT(*) AS reviews,

    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        2
    ) AS review_share_pct

FROM reviews

GROUP BY review_score;

-- ============================================================
-- 10. Delivery vs Customer Experience
-- ============================================================

CREATE OR REPLACE VIEW vw_delivery_customer_experience AS

WITH order_reviews AS (

    SELECT
        order_id,

        AVG(review_score) AS avg_review_score

    FROM reviews

    GROUP BY order_id
),

reviewed_orders AS (

    SELECT
        o.order_id,

        o.is_late,

        o.delay_days,

        r.avg_review_score

    FROM orders o

    JOIN order_reviews r
        ON o.order_id = r.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)

SELECT

    CASE
        WHEN delay_days <= -7
            THEN '7+ days early'

        WHEN delay_days BETWEEN -6 AND -1
            THEN '1-6 days early'

        WHEN delay_days = 0
            THEN 'On estimated date'

        WHEN delay_days BETWEEN 1 AND 3
            THEN '1-3 days late'

        WHEN delay_days BETWEEN 4 AND 7
            THEN '4-7 days late'

        WHEN delay_days > 7
            THEN '7+ days late'
    END AS delivery_band,

    CASE
        WHEN delay_days <= -7 THEN 1
        WHEN delay_days BETWEEN -6 AND -1 THEN 2
        WHEN delay_days = 0 THEN 3
        WHEN delay_days BETWEEN 1 AND 3 THEN 4
        WHEN delay_days BETWEEN 4 AND 7 THEN 5
        WHEN delay_days > 7 THEN 6
    END AS sort_order,

    CASE
        WHEN is_late = TRUE
            THEN 'Late'
        ELSE 'On time / Early'
    END AS delivery_status,

    COUNT(*) AS reviewed_orders,

    ROUND(
        AVG(avg_review_score)::numeric,
        2
    ) AS avg_review_score,

    ROUND(
        AVG(
            CASE
                WHEN avg_review_score <= 2
                THEN 1
                ELSE 0
            END
        ) * 100,
        2
    ) AS low_rating_rate_pct

FROM reviewed_orders

GROUP BY
    1,
    2,
    3;

-- ============================================================
-- 11. Repeat Customer KPI
-- ============================================================

CREATE OR REPLACE VIEW vw_repeat_customer_kpis AS

WITH customer_orders AS (

    SELECT
        c.customer_unique_id,

        COUNT(DISTINCT o.order_id) AS orders

    FROM customers c

    JOIN orders o
        ON c.customer_id = o.customer_id

    GROUP BY c.customer_unique_id
)

SELECT
    COUNT(*) AS unique_customers,

    SUM(
        CASE
            WHEN orders > 1
            THEN 1
            ELSE 0
        END
    ) AS repeat_customers,

    ROUND(
        AVG(
            CASE
                WHEN orders > 1
                THEN 1
                ELSE 0
            END
        ) * 100,
        2
    ) AS repeat_customer_rate_pct,

    ROUND(
        AVG(orders)::numeric,
        2
    ) AS avg_orders_per_customer

FROM customer_orders;

-- ============================================================
-- 12. Fulfillment KPI
-- ============================================================

CREATE OR REPLACE VIEW vw_fulfillment_kpis AS

SELECT
    COUNT(*) AS analyzable_delivered_orders,

    ROUND(
        AVG(delivery_days)::numeric,
        2
    ) AS avg_delivery_days,

    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY delivery_days)::numeric,
        2
    ) AS median_delivery_days,

    ROUND(
        AVG(is_late::int) * 100,
        2
    ) AS late_rate_pct,

    ROUND(
        AVG(
            CASE
                WHEN is_late = TRUE
                THEN delay_days
            END
        )::numeric,
        2
    ) AS avg_delay_days_late

FROM orders

WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;