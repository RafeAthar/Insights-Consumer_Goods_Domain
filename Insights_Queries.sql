use `gdb023`;

-- show tables;
-- describe dim_product;
-- SELECT * FROM dim_product LIMIT 15;
/*
SELECT variant, COUNT(variant) 
FROM dim_product 
GROUP BY variant;

SELECT division, segment, category, COUNT(product_code) 
FROM dim_product 
GROUP BY division, segment, category;

SELECT region, sub_zone, COUNT(customer_code) 
FROM dim_customer 
GROUP BY region, sub_zone;
*/


/* 
1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.
*/

select distinct market
from dim_customer
where customer= 'Atliq Exclusive' and region = 'APAC';
     
-- answer with sales details 
with cust_sales_data as (
	select  cust.market, sales.sold_quantity*price.gross_price sale_amount    --  sales.product_code, sales.fiscal_year,
	from dim_customer cust
	join fact_sales_monthly sales
	on cust.customer_code = sales.customer_code
	join fact_gross_price price
	on sales.product_code = price.product_code and sales.fiscal_year = price.fiscal_year
	where cust.customer = 'Atliq Exclusive' and region='APAC')
select market, round(sum(sale_amount)/1000000, 2) as total_sales_in_2020_and_2021_mln 
from cust_sales_data
group by market;


/*
2. What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields, 
unique_products_2020 
unique_products_2021 
percentage_chg
*/
with product_year as
(select pr.product_code,pr.product, mfc.cost_year
from dim_product pr
join fact_manufacturing_cost mfc
on pr.product_code = mfc.product_code)
select z.unique_products_2020 , o.unique_products_2021, round((o.unique_products_2021 - z.unique_products_2020)/z.unique_products_2020*100, 2) AS percentage_chg  FROM
(select count(distinct product_code) AS unique_products_2020 from product_year where cost_year=2020) z,
(select count(distinct product_code) AS unique_products_2021 from product_year where cost_year=2021) o;


/*
3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. 
The final output contains 2 fields, 
segment 
product_count
*/
select segment, count(distinct product_code) as product_count  
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;


/*
4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? 
The final output contains these fields, 
segment 
product_count_2020 
product_count_2021 
difference 
*/
with product_year as
(select pr.product_code,pr.segment, mfc.cost_year
from dim_product pr
join fact_manufacturing_cost mfc
on pr.product_code = mfc.product_code)
select z.segment, z.product_count_2020 , o.product_count_2021 , o.product_count_2021 - z.product_count_2020 AS difference  
FROM
(select segment, count(distinct product_code) AS product_count_2020 from product_year where cost_year=2020 group by segment) z
join
(select segment, count(distinct product_code) AS product_count_2021 from product_year where cost_year=2021 group by segment) o 
on z.segment = o.segment
order by difference desc;


/*
5. Get the products that have the highest and lowest manufacturing costs. 
The final output should contain these fields, 
product_code 
product 
manufacturing_cost
*/
with product_year as
(select pr.product_code, pr.product, mfc.manufacturing_cost
from dim_product pr
join fact_manufacturing_cost mfc
on pr.product_code = mfc.product_code)
select product_code, product, round(manufacturing_cost,2) as manufacturing_cost
from product_year 
where 
manufacturing_cost = (select max(manufacturing_cost) from product_year)
or
manufacturing_cost = (select min(manufacturing_cost) from product_year);


/*
6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. 
The final output contains these fields, 
customer_code 
customer 
average_discount_percentage 
*/
with cust_invoice as
(select cust.customer, invoice.*
from dim_customer cust
join fact_pre_invoice_deductions invoice
on cust.customer_code = invoice.customer_code
where cust.market='India' and invoice.fiscal_year = 2021)
select customer_code, customer, round(sum(pre_invoice_discount_pct)/count(customer_code), 4) AS average_discount_percentage
from cust_invoice
group by customer_code
order by average_discount_percentage desc
limit 5;


/*
7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month . 
This analysis helps to get an idea of low and high-performing months and take strategic decisions. 
The final report contains these columns: 
Month 
Year 
Gross sales Amount 
*/
with cust_sales_data as 
	(
	select  sales.date, sales.fiscal_year, sales.sold_quantity*price.gross_price as sale_amount  
	from dim_customer cust
	join fact_sales_monthly sales
	on cust.customer_code = sales.customer_code
	join fact_gross_price price
	on sales.product_code = price.product_code and sales.fiscal_year = price.fiscal_year
	where cust.customer = 'Atliq Exclusive'
    )
select extract(month from `date`) as `Month`, extract(year from `date`) as `Year`, round( SUM(sale_amount), 0 ) as `Gross sales Amount`
from cust_sales_data
group by `Month`, `Year`;


/*
8. In which quarter of 2020, got the maximum total_sold_quantity? 
The final output contains these fields sorted by the total_sold_quantity, 
Quarter 
total_sold_quantity 
*/
select 
case when extract(month from `date`) in (9,10,11) then 'Q1'
	when extract(month from `date`) in (12,1,2) then 'Q2'
    when extract(month from `date`) in (3,4,5) then 'Q3'
    else 'Q4'
end as `Quarter`, 
sum(sold_quantity) as total_sold_quantity
from fact_sales_monthly
where extract(YEAR FROM `date`) = 2020
group by `Quarter`
order by total_sold_quantity desc
-- limit 1
;
 

/*
9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
The final output contains these fields, 
channel 
gross_sales_mln 
percentage
*/
with total_gross_sales AS
(
select round(SUM(fsm.sold_quantity*fgp.gross_price)/1000000, 2) AS total_gross_sales_mln
from dim_customer cust
join fact_sales_monthly fsm
on cust.customer_code = fsm.customer_code
join fact_gross_price fgp
on fsm.product_code = fgp.product_code
	AND fsm.fiscal_year = fgp.fiscal_year
WHERE fsm.fiscal_year = 2021
)
select cust.channel, round(SUM(fsm.sold_quantity*fgp.gross_price)/1000000, 2) AS gross_sales_mln
, (round(SUM(fsm.sold_quantity*fgp.gross_price)/1000000, 2)/total_gross_sales.total_gross_sales_mln)*100 AS percentage 
from dim_customer cust
join fact_sales_monthly fsm
on cust.customer_code = fsm.customer_code
join fact_gross_price fgp
on fsm.product_code = fgp.product_code
	AND fsm.fiscal_year = fgp.fiscal_year
, total_gross_sales
WHERE fsm.fiscal_year = 2021
group by cust.channel
order by gross_sales_mln desc
-- limit 1
;


/* 
10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
The final output contains these fields, 
division 
product_code 
product 
total_sold_quantity 
rank_order 
*/
with prod_sales_21 AS
(select pr.division, pr.product_code, pr.product,  SUM(fsm.sold_quantity) AS total_sold_quantity
from dim_product pr
join fact_sales_monthly fsm
on pr.product_code = fsm.product_code
where fsm.fiscal_year=2021
group by pr.division, pr.product_code)
select * from 
(select prod_sales_21.*, row_number() 
over(partition by division order by total_sold_quantity desc) as rank_order
from prod_sales_21) x
where x.rank_order <4;
