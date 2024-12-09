EXPLAIN
SELECT * FROM film
WHERE release_date > '2023-10-01'::date;

EXPLAIN ANALYZE
SELECT * FROM film
WHERE release_date > '2023-10-01'::date;


EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM film
WHERE release_date > '2023-10-01'::date;


EXPLAIN (ANALYZE,BUFFERS)
SELECT * FROM film f
	JOIN film_cast fc USING (film_id)
	JOIN person p USING (person_id)
WHERE release_date > '2023-10-01'::date;



EXPLAIN (ANALYZE, BUFFERS)
select
    f.film_id,
    f.title,
    rental.store_id,
    sum(payment.amount) as "gross revenue"
from film f
inner join inventory on
    inventory.film_id = f.film_id
inner join rental on
    rental.inventory_id = inventory.inventory_id
inner join payment
    on payment.rental_id = rental.rental_id
where payment.amount is not NULL
    AND rental_period <@ tstzrange('2024-04-01', '2024-07-01')
group by f.title,
         f.film_id,
         rental.store_id
order by
    sum(payment.amount) DESC;


SET work_mem = '20MB';

-- Indexes
-- Automatic deduplication
--CREATE INDEX rental_inventory_id_idx ON bluebox.rental USING btree (inventory_id);
REINDEX TABLE rental;


-- No deduplication
CREATE INDEX rental_inventory_id_idx_nondedup ON bluebox.rental USING btree (inventory_id) WITH (deduplicate_items=OFF);

-- Query the size of the indexes
SELECT indexname, pg_size_pretty(pg_relation_size(pg.oid)) index_size
	FROM pg_indexes pi
JOIN pg_class pg ON pi.indexname = pg.relname 
WHERE pi.tablename = 'rental'
AND indexname~*'inventory_id';


-- Functional indexes
EXPLAIN (ANALYZE,buffers)
SELECT count(*) FROM bluebox.rental 
WHERE upper(rental_period) IS NULL;  


CREATE INDEX rental_rental_period_upper ON bluebox.rental 
   USING btree (upper(rental_period));

  
-- Query the size of the indexes
SELECT indexname, pg_size_pretty(pg_relation_size(pg.oid)) index_size
	FROM pg_indexes pi
JOIN pg_class pg ON pi.indexname = pg.relname 
WHERE pi.tablename = 'rental';  


CREATE INDEX rental_rental_period_upper_null ON bluebox.rental
   USING btree (upper(rental_period))
WHERE upper(rental_period) IS NULL;


-- Composite Indexes
EXPLAIN (ANALYZE,buffers)
SELECT DISTINCT film_id, title, popularity, rating, release_date
FROM film f
	JOIN inventory i USING (film_id)
WHERE i.store_id = 112
	AND f.title ~* '^s'
	AND inventory_id NOT IN (SELECT inventory_id FROM rental WHERE store_id=112 AND upper(rental_period) IS NULL)
ORDER BY title, release_date, popularity DESC;   


CREATE INDEX rental_store_id_upper_rental_null_idx 
ON bluebox.rental USING btree (store_id, upper(rental_period)) 
WHERE upper(rental_period) IS NULL; 


CREATE INDEX film_film_id_incl ON bluebox.film 
USING btree (film_id)
INCLUDE (title, popularity, rating, release_date);

-- Query the size of the indexes
SELECT indexname, pg_size_pretty(pg_relation_size(pg.oid)) index_size
	FROM pg_indexes pi
JOIN pg_class pg ON pi.indexname = pg.relname 
WHERE pi.tablename = 'film';


