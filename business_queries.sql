-- Q1. Which cities have the highest number of customers placing orders?

select c.customer_city as City,count(c.customer_id) as Number_of_Customers
from customers as c
join orders as o
on c.customer_id = o.customer_id 
group by c.customer_city
order by Number_of_Customers desc
limit 5;


-- Q2. How are delivered orders distributed based on delivery timeliness compared to the estimated delivery date?

SELECT 
    CASE
        WHEN DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date) < 0 
            THEN 'Delivered Before Time'
        WHEN DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date) = 0 
            THEN 'Delivered On Time'
        WHEN DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date) BETWEEN 1 AND 2 
            THEN 'Delivered Late (≤2 Days)'
        ELSE 'Delivered Very Late (>2 Days)'
    END AS delivery_status,
    
    COUNT(order_id) AS total_orders
FROM orders
WHERE order_status = 'delivered'
GROUP BY delivery_status
ORDER BY total_orders DESC;


-- Q3. How does delivery delay vary across different customer review scores?

SELECT 
    r.review_score,
    AVG(DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date)) AS avg_delay
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
GROUP BY r.review_score
ORDER BY r.review_score;


-- Q4. What is the month-over-month revenue growth trend over time?

WITH monthly_revenue AS (
    SELECT 
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS date,
        YEAR(o.order_purchase_timestamp) AS year,
        monthname(o.order_purchase_timestamp) AS Month,
        SUM(op.payment_value) AS revenue
    FROM orders o
    JOIN order_payments op ON o.order_id = op.order_id
    GROUP BY date,year,Month
)

SELECT 
    date,year,Month,
    revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY year, Month)) /
        LAG(revenue) OVER (ORDER BY year, Month) * 100,
    2) AS growth_percent

FROM monthly_revenue;



-- Q5. Which product categories generate the highest total sales revenue?

SELECT 
    p.product_category_name,
    SUM(oi.price) AS total_sales
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY total_sales DESC
LIMIT 10;


-- Q6. How are sellers ranked based on their total sales performance?

SELECT 
    seller_id,
    SUM(price) AS total_sales,
    RANK() OVER (ORDER BY SUM(price) DESC) AS seller_rank
FROM order_items
GROUP BY seller_id
limit 10;


-- Q7. Which states contribute the most to overall revenue?


SELECT 
    c.customer_state,
    SUM(op.payment_value) AS revenue
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_payments op ON o.order_id = op.order_id
GROUP BY c.customer_state
ORDER BY revenue DESC;


-- Q8. What percentage of product price does shipping cost represent on average?

SELECT 
    ROUND(AVG(freight_value / price) * 100, 2) AS avg_shipping_percent
FROM order_items;


-- Q9. Which payment methods are most frequently used by customers?

SELECT 
    payment_type,
    COUNT(*) AS usage_count
FROM order_payments
GROUP BY payment_type
ORDER BY usage_count DESC;


-- Q10. How can customers be classified into activity or churn-risk segments based on their purchase gap patterns?

WITH customer_orders AS (
    SELECT 
        c.customer_unique_id,
        o.order_purchase_timestamp,
        LAG(o.order_purchase_timestamp) OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp
        ) AS prev_order_date
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
),
gaps AS (
    SELECT 
        customer_unique_id,
        DATEDIFF(order_purchase_timestamp, prev_order_date) AS gap_days
    FROM customer_orders
    WHERE prev_order_date IS NOT NULL
),
max_gaps AS (
    SELECT 
        customer_unique_id,
        MAX(gap_days) AS max_gap
    FROM gaps
    GROUP BY customer_unique_id
)

SELECT 
    CASE
        WHEN max_gap <= 30 THEN 'Active'
        WHEN max_gap BETWEEN 31 AND 90 THEN 'At Risk'
        WHEN max_gap BETWEEN 91 AND 180 THEN 'Churn Risk'
        ELSE 'Likely Churned'
    END AS customer_status,
    COUNT(*) AS customers
FROM max_gaps
GROUP BY customer_status
ORDER BY customers DESC;


-- Q11. Which product categories have low average customer ratings and high shipping costs, indicating potential service or quality issues?

SELECT 
    p.product_category_name,pc.product_category_name_english as Product,
    AVG(r.review_score) AS avg_rating,
    AVG(oi.freight_value) AS avg_freight,
    COUNT(*) AS total_orders
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN order_reviews r ON oi.order_id = r.order_id
Join product_category_name_translation as pc ON p.product_category_name = pc.product_category_name
GROUP BY p.product_category_name , pc.product_category_name_english
HAVING avg_rating < 3.5
ORDER BY total_orders DESC;


-- Q12. How are customers distributed across spending segments based on their average order payment value?

SELECT 
    spending_segment,
    COUNT(*) AS customers
FROM (
    SELECT 
        c.customer_unique_id,
        CASE
            WHEN AVG(op.payment_value) < 57 THEN 'Low Spender'
            WHEN AVG(op.payment_value) BETWEEN 57 AND 114 THEN 'Medium Spender'
            ELSE 'High Spender'
        END AS spending_segment
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments op ON o.order_id = op.order_id
    GROUP BY c.customer_unique_id
) t
GROUP BY spending_segment
ORDER BY customers DESC;


-- Q13. How is total revenue distributed among seller performance tiers based on sales ranking groups?

WITH seller_sales AS (
    SELECT seller_id, SUM(price) AS total_sales
    FROM order_items
    GROUP BY seller_id
),
ranked AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY total_sales DESC) AS seller_group
    FROM seller_sales
)
SELECT 
    seller_group,
    SUM(total_sales) AS revenue,
    ROUND(SUM(total_sales) / (SELECT SUM(total_sales) FROM seller_sales) * 100, 2) AS revenue_percent
FROM ranked
GROUP BY seller_group
ORDER BY seller_group;


-- Q14. How does revenue vary across different delivery timeliness categories?

SELECT 
    CASE
        WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) < 0 
            THEN 'Delivered Before Time'
        WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) = 0 
            THEN 'Delivered On Time'
        WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) BETWEEN 1 AND 2 
            THEN 'Delivered Late (≤2 Days)'
        ELSE 'Delivered Very Late (>2 Days)'
    END AS delivery_status,

    COUNT(o.order_id) AS total_orders,
    ROUND(SUM(op.payment_value), 2) AS total_revenue

FROM orders o
JOIN order_payments op ON o.order_id = op.order_id

WHERE o.order_status = 'delivered'
GROUP BY delivery_status
ORDER BY total_revenue DESC;


-- Q15. How is revenue distributed across orders with positive, neutral, and negative customer reviews?

SELECT 
    CASE 
        WHEN r.review_score <= 2 THEN 'Negative'
        WHEN r.review_score = 3 THEN 'Neutral'
        ELSE 'Positive'
    END AS review_category,
    SUM(op.payment_value) AS revenue
FROM order_reviews r
JOIN orders o ON r.order_id = o.order_id
JOIN order_payments op ON o.order_id = op.order_id
GROUP BY review_category;


-- Q16. Which product categories have unusually high shipping costs as a percentage of product price?

SELECT 
    p.product_category_name,pc.product_category_name_english as Product,
    ROUND(AVG(oi.freight_value / oi.price) * 100, 2) AS shipping_percent
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN product_category_name_translation  as pc on p.product_category_name = pc.product_category_name
GROUP BY p.product_category_name , pc.product_category_name_english
HAVING shipping_percent > 40
ORDER BY shipping_percent DESC;


-- Q17. What is the total revenue generated in each calendar month when combining data across all years?

SELECT 
    MONTH(o.order_purchase_timestamp) AS month_number,
    MONTHNAME(o.order_purchase_timestamp) AS month_name,
    ROUND(SUM(op.payment_value), 2) AS total_revenue
FROM orders o
JOIN order_payments op 
    ON o.order_id = op.order_id
GROUP BY month_number, month_name
ORDER BY month_number;
