                          #PROJECT E-COMMERCE
#                      -------------------------
#____________________________________________________________________________________________
#This project involves analyzing a dataset from an e-commerce platform to extract meaningful
#insights about sales performance, customer behavior, and product dynamics.

#The analysis combines SQL queries and Python data manipulation to answer a series of
#business questions and derive actionable intelligence.
#_____________________________________________________________________________________________

create database if not exists ecommerce;
use ecommerce;

# 1. List all unique cities where customers are located
select distinct customer_city from customers;

# 2. Count the number of orders placed in 2017.
select count(order_id) from orders where year(order_purchase_timestamp) = 2017;

# 3. Find the total sales per category.
select 
products.product_category category,
round(sum(payments.payment_value),2) sales
from products 
join order_items
on products.product_id=order_items.product_id  #since there was no direct join from product to
join payments
on payments.order_id = order_items.order_id
group by category;

#4. Calculate the percentage of orders that were paid in installments.
#(payment in installment is greater then 1)
select count(payment_installments)
from payments
where payment_installments >=1;

select count(payment_installments)
from payments;
          # or
select (sum(case when payment_installments >=1 then 1 else 0 end))/count(*)*100
from payments;

#5. Count the number of customers from each state.
select customer_state, count(customer_unique_id)
from customers
group by customer_state;

#6. Calculate the number of orders per month in 2018.
select monthname(order_purchase_timestamp) as months,count(order_id) as order_count
from orders where year(order_purchase_timestamp) = 2018
group by months;

#7. Find the average number of products per order, grouped by customer city
with count_per_order as 
(select orders.order_id,orders.customer_id,count(order_items.order_id) as oi
from orders
join order_items
on orders.order_id=order_items.order_id
group by orders.order_id,orders.customer_id)

select customers.customer_city,avg(count_per_order.oi) as average_order
from customers
join count_per_order
on customers.customer_id=count_per_order.customer_id
group by customers.customer_city;

#8. Calculate the percentage of total revenue contributed by each product category.
select
products.product_category category,  #we have already calculated sales per product (3)
round((sum(payments.payment_value)/(select sum(payment_value) from payments))*100,2) sales
from products 
join order_items
on products.product_id=order_items.product_id  
join payments
on payments.order_id = order_items.order_id
group by category
order by sales;

# 9.Identify the correlation between product price and the number of times a product has been purchased.
select products.product_category as products,
count(order_items.product_id) as count,
round(avg(order_items.price),2) as avg_price
from products
join order_items
on products.product_id=order_items.product_id
group by products.product_category;

# 10. Calculate the total revenue generated by each seller, and rank them by revenue.
select *,dense_rank()over(order by revenue desc) as rn
from
(select
order_items.seller_id,round(sum(payments.payment_value),2) as revenue
from order_items
join payments
on order_items.order_id = payments.order_id
group by order_items.seller_id)as a;

# 11. Calculate the moving average of order values for each customer over their order history.
select 
	customer_id,
	order_purchase_timestamp,
	payment,
	avg(payment) over (
		partition by customer_id 
        order by order_purchase_timestamp
        rows between 2 preceding and current row) as moving_average
from 
	(select orders.customer_id,orders.order_purchase_timestamp,
	payments.payment_value as payment
	from payments join orders
	on payments.order_id = orders.order_id) as a;
    
# 12. Calculate the cumulative sales per month for each year.
select years,months, payments,
round(sum(payments) over (order by years, months),2) as cumulative_Sales
from
(select
	year(orders.order_purchase_timestamp) as years,
    month(orders.order_purchase_timestamp) as months,
    round(sum(payments.payment_value),2) as payments
from orders
    join payments
    on orders.order_id = payments.order_id
    group by years ,months order by years , months) as a;
    
# 13. Calculate the year-over-year growth rate of total sales.
select years, payments,
lag(payments,1) over (order by years) as previous_payments,
round(((payments - (lag(payments,1) over (order by years))) /
lag(payments,1) over (order by years)) *100,2) as year_growth
from
(select
	year(orders.order_purchase_timestamp) as years,
    round(sum(payments.payment_value),2) as payments
from orders
    join payments
    on orders.order_id = payments.order_id
    group by years order by years) as a;
    
# 14. Calculate the retention rate of customers, defined as the percentage of customers who make another purchase within 6 months of their first purchase.
with a as (select
        customers.customer_id,
        min(orders.order_purchase_timestamp) as first_order
    from customers
    join orders
    on customers.customer_id = orders.customer_id
    group by customers.customer_id
),
b as ( select
        a.customer_id,
        count(distinct orders.order_purchase_timestamp) as next_order
    from a
    join orders
    on orders.customer_id = a.customer_id
    and orders.order_purchase_timestamp > a.first_order
    and orders.order_purchase_timestamp < date_add(a.first_order, interval 6 month)
    group by a.customer_id
)
select
    100 * (COUNT(distinct b.customer_id) / COUNT(distinct a.customer_id)) as percentage
FROM a
LEFT JOIN b
ON a.customer_id = b.customer_id;

# 15. Identify the top 3 customers who spent the most money in each year.

select years,customer_id,payment,d_rank
from
(select year(orders.order_purchase_timestamp) years,
orders.customer_id,
sum(payments.payment_value) payment,
dense_rank() over(partition by year(orders.order_purchase_timestamp)
order by sum(payments.payment_value) desc) d_rank
from orders join payments 
on payments.order_id = orders.order_id
group by year(orders.order_purchase_timestamp),
orders.customer_id) as a
where d_rank <=3;