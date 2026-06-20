CREATE TABLE practice.cleaned_data as
SELECT  
    ucsd.dateCrawled,
    ucsd.name,
    ucsd.seller,
    ucsd.offerType,
    ucsd.price,
    ucsd.abtest,
    ucsd.vehicleType,
    ucsd.yearOfRegistration,
    ucsd.monthOfRegistration,
    ucsd.gearbox,
    ucsd.powerPS,
    ucsd.model,
    ucsd.brand,
    ucsd.kilometer,
    ucsd.fuelType,
    ucsd.notRepairedDamage,
    ucsd.dateCreated,
    ucsd.postalCode, 
    ucsd.Lattitude,
    ucsd.Longitude,
    ucsd.lastSeen,
    
    (2016 - ucsd.yearOfRegistration) AS vehicle_age,
    
    DATEDIFF(
        STR_TO_DATE(ucsd.lastSeen, '%m/%d/%Y %H:%i'), 
        STR_TO_DATE(ucsd.dateCreated, '%m/%d/%Y %H:%i')
    ) AS days_on_market 

FROM practice.used_car_sales_dataset ucsd 
WHERE
    ucsd.yearOfRegistration >= 1980 
    AND ucsd.yearOfRegistration <= 2016
    AND ucsd.price > 100 
    AND ucsd.price <= 150000
    AND ucsd.powerPS > 10 
    AND ucsd.powerPS <= 1000
    AND ucsd.brand IS NOT NULL
    AND ucsd.model IS NOT NULL;
#Query 1#
#High-level market overview(Q1)#
select 
count(*) total_listing, 
round(avg(cd.price), 2) as average_price_euro,
round(avg(cd.kilometer), 2) as average_mileage_km,
round(avg(cd.days_on_market), 1) as average_days_on_market 
from practice.cleaned_data cd;

#Brand and model dominance (Q3)#
select
cd.brand ,
count(*) as total_listings,
round(count(*) * 100.0/ Sum(count(*)) over (), 2) as market_share_percent,
ROUND(avg(cd.price), 2) as avg_price_euro
from practice.cleaned_data cd 
group by cd.brand
order by total_listings desc
limit 10;

#Fasted selling vehicle (Q6)#
select 
cd.brand, cd.model,
count(*) as total_listings,
round(avg(days_on_market), 1) as avg_days_to_sell
from practice.cleaned_data cd 
group by cd.brand, cd.model
having count(*) >=50
order by avg_days_to_sell asc
limit 10;

#Query 2#
#the depreciation curve (Q4)#
select
cd.vehicle_age , 
count(*) as total_listings,
round(avg(cd.price), 2) as avg_price_euro
from practice.cleaned_data cd 
group by cd.vehicle_age 
order by cd.vehicle_age asc;

#Gearbox price premium (Q5)#

select 
cd.vehicle_age,
round(avg(case when cd.gearbox= 'automatik' then cd.price end),2) as avg_price_automatic,
round(avg(case when cd.gearbox= 'manuell' then cd.price end),2) as avg_price_manual,
round(
(avg(case when cd.gearbox ='automatik' then cd.price end) - avg(case when gearbox= 'manuell' then price end))
/ avg(case when cd.gearbox ='manuell' then cd.price end) * 100,2 
) as automatic_premium_percent
from practice.cleaned_data cd
where gearbox in ('automatik', 'manuell')
group by cd.vehicle_age
order by cd.vehicle_age asc;

#Damage value Penalty(Q7)#

select
cd.notRepairedDamage,
count(*) as total_listings,
round(avg(price), 2) as avg_price_euro
from practice.cleaned_data cd
where cd.notRepairedDamage in ('ja', 'nein')
group by cd.notRepairedDamage;

#The 150,000 km psychological barrier (Q8)#
select 
case 
	when cd.kilometer < 50000 then 'A: < 50k KM'
	when cd.kilometer >= 50000 and cd.kilometer < 100000 then 'B: 50k - 100k KM'
	when cd.kilometer >=100000 and cd.kilometer < 150000 then 'C: 100k - 150k KM'
	else 'D: > 150k KM (Threhold)'	
end as mileage_tier,
count(*) as total_listings,
round(avg(cd.price), 2) as avg_price_euro
from practice.cleaned_data cd
group by mileage_tier
order by mileage_tier asc;

#Query 3#
#Underpriced alert engine(Q10)#
WITH ModelStats AS (
    SELECT 
        cd.brand,
        cd.model,
        AVG(cd.price) AS avg_price,
        STDDEV(cd.price) AS std_price,
        COUNT(*) AS total_count
    FROM practice.cleaned_data cd 
    WHERE cd.price <= 150000 -- Hard stop limit to prevent luxury/typo spammers from breaking the average
    GROUP BY cd.brand, cd.model
    HAVING COUNT(*) >= 10
)
SELECT 
    cd.brand,
    cd.model,
    cd.name,
    cd.yearOfRegistration,
    cd.kilometer,
    cd.price,
    ROUND(ms.avg_price, 2) AS market_average_price,
    ROUND(ms.avg_price - (0.5 * ms.std_price), 2) AS bargain_target_baseline,
    -- Calculate exact positive savings
    ROUND(ms.avg_price - cd.price, 2) AS savings_below_average
FROM practice.cleaned_data cd
JOIN ModelStats ms 
    ON cd.brand = ms.brand AND cd.model = ms.model
WHERE 
    cd.yearOfRegistration >= 2003
    AND cd.notRepairedDamage = 'nein'
    AND cd.kilometer < 150000
    -- CRITICAL FILTERS: Price must be realistic, and must be lower than our bargain baseline
    AND cd.price > 100
    AND cd.price <= 150000
    AND cd.price < (ms.avg_price - (0.5 * ms.std_price))
ORDER BY savings_below_average DESC
LIMIT 50;