-- 1. Overall fulfillment performance

SELECT
    COUNT(*) AS delivered_orders,

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
    ) AS avg_delay_days_for_late_orders

FROM orders

WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;

-- 2. Delivery performance bands

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

        ELSE 'Unknown'
    END AS delivery_band,

    COUNT(*) AS orders,

    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        2
    ) AS share_pct

FROM orders

WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL

GROUP BY 1
ORDER BY
    MIN(delay_days);

-- 3. Fulfillment performance by customer state

SELECT
    c.customer_state,

    COUNT(*) AS delivered_orders,

    ROUND(
        AVG(o.delivery_days)::numeric,
        2
    ) AS avg_delivery_days,

    ROUND(
        AVG(o.is_late::int) * 100,
        2
    ) AS late_rate_pct,

    ROUND(
        AVG(
            CASE
                WHEN o.is_late = TRUE
                THEN o.delay_days
            END
        )::numeric,
        2
    ) AS avg_delay_days_for_late_orders

FROM orders o

JOIN customers c
    ON o.customer_id = c.customer_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL

GROUP BY c.customer_state

HAVING COUNT(*) >= 100

ORDER BY late_rate_pct DESC;

-- 4. Fulfillment stage decomposition

SELECT
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
  AND order_delivered_customer_date IS NOT NULL;

-- 5. Compare late vs on-time orders

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

GROUP BY 1

ORDER BY delivery_status;

-- 6. Delivery promise vs actual performance by state

SELECT
    c.customer_state,

    COUNT(*) AS delivered_orders,

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
        AVG(o.delivery_days)::numeric,
        2
    ) AS avg_actual_delivery_days,

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
    ) AS avg_delivery_buffer_days,

    ROUND(
        AVG(o.is_late::int) * 100,
        2
    ) AS late_rate_pct

FROM orders o

JOIN customers c
    ON o.customer_id = c.customer_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL

GROUP BY c.customer_state

HAVING COUNT(*) >= 100

ORDER BY avg_promised_days DESC;

-- 7. Fulfillment priority by state

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

HAVING COUNT(*) >= 100

ORDER BY late_orders DESC;