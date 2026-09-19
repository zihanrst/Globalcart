-- 1. Review score distribution

SELECT
    review_score,

    COUNT(*) AS reviews,

    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        2
    ) AS share_pct

FROM reviews

GROUP BY review_score

ORDER BY review_score;

-- 2. Late delivery vs review score

WITH order_reviews AS (

    SELECT
        order_id,
        AVG(review_score) AS avg_review_score

    FROM reviews

    GROUP BY order_id
)

SELECT
    CASE
        WHEN o.is_late = TRUE
            THEN 'Late'
        ELSE 'On time / Early'
    END AS delivery_status,

    COUNT(*) AS reviewed_orders,

    ROUND(
        AVG(r.avg_review_score)::numeric,
        2
    ) AS avg_review_score,

    ROUND(
        AVG(
            CASE
                WHEN r.avg_review_score <= 2
                THEN 1
                ELSE 0
            END
        ) * 100,
        2
    ) AS low_rating_rate_pct

FROM orders o

JOIN order_reviews r
    ON o.order_id = r.order_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL

GROUP BY 1;

-- 3. Delay severity vs customer rating

WITH order_reviews AS (

    SELECT
        order_id,
        AVG(review_score) AS avg_review_score

    FROM reviews

    GROUP BY order_id
)

SELECT
    CASE
        WHEN o.delay_days <= -7
            THEN '7+ days early'

        WHEN o.delay_days BETWEEN -6 AND -1
            THEN '1-6 days early'

        WHEN o.delay_days = 0
            THEN 'On estimated date'

        WHEN o.delay_days BETWEEN 1 AND 3
            THEN '1-3 days late'

        WHEN o.delay_days BETWEEN 4 AND 7
            THEN '4-7 days late'

        WHEN o.delay_days > 7
            THEN '7+ days late'
    END AS delivery_band,

    COUNT(*) AS reviewed_orders,

    ROUND(
        AVG(r.avg_review_score)::numeric,
        2
    ) AS avg_review_score,

    ROUND(
        AVG(
            CASE
                WHEN r.avg_review_score <= 2
                THEN 1
                ELSE 0
            END
        ) * 100,
        2
    ) AS low_rating_rate_pct

FROM orders o

JOIN order_reviews r
    ON o.order_id = r.order_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL

GROUP BY 1

ORDER BY MIN(o.delay_days);

-- 4. Repeat customer analysis

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