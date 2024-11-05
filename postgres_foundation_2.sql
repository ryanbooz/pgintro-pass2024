/*
 * Let's review a few things about CASE
 */
SELECT * FROM film;

SELECT * FROM FiLm;

SELECT * FROM "Film";

SELECT * FROM film WHERE title LIKE 'iron%';

SELECT * FROM film WHERE title ILIKE 'iron%';

SELECT * FROM film WHERE title ~ 'iron';

SELECT * FROM film WHERE title ~* 'iron';

-- The tilda is actually a shortcut for Regex
SELECT * FROM film WHERE title ~* '^iron';
SELECT * FROM film WHERE title ~* '^iron.?man';
SELECT * FROM film WHERE title ~* '^iron.?man\W\d';

/*
 * We can use dollar quotes with text to avoid weird double quotes, and make the overall
 * text/query easier to read across multiple lines and such.
 * 
 * We'll see other examples of dollar quoting a bit later in the function/procedure section.
 */
SELECT $$Contains a listing of all rentals for all stores and
  provides the rental and return dates to ensure that
  we can easily find videos that are available$$;

COMMENT ON TABLE public.rental IS $$Contains a listing of all rentals for all stores and
  provides the rental and return dates to ensure that
  we can easily find videos that are available$$;

-- Another good example is formating output strings
SELECT FORMAT($_$INSERT INTO genre_new (genre_id, name) VALUES (%s,%L)$_$,genre_id, name) 
	from film_genre fg;
 

/*
 * Casting data types... the basics
 */
-- There's the traditional CAST function
SELECT cast(100 AS text);

-- More often than not, you'll see the PostgreSQL shorthand
SELECT 100::TEXT; 
SELECT '100'::int;
SELECT '100.1'::int; --Oops
SELECT '100.1'::numeric;

SELECT round(10.1::float8, 2);

SELECT round(10.1::numeric, 2);

/* 
 * With PostgreSQL 16 and above, you can also separate thousands
 * using an underscore for readability.
 */ 
SELECT 10000;
SELECT 10_000;
SELECT 10_000_000.5;


/*
 * It's the small things. To return a subset of rows you need
 * to use LIMIT, not TOP.
 */
SELECT * FROM film LIMIT 10;

SELECT * FROM film WHERE title ~* '^pa.*' LIMIT 10;


/*
 * LIMIT/OFFSET instead of OFFSET/FETCH
 */
SELECT * FROM film WHERE title ~* '^p.*'
ORDER BY title 
LIMIT 10
OFFSET 0;

SELECT * FROM film WHERE title ~* '^p.*'
ORDER BY title 
LIMIT 10
OFFSET 10;


/*
 * Grouping and ordering
 * 
 * Aliases work in both operations as well as column numbers
 */
SELECT substring(title, 1,3) title_start, count(*) total_titles
FROM film 
GROUP BY title_start
ORDER BY total_titles desc;

SELECT substring(title, 1,3) title_start, count(*) total_titles
FROM film 
GROUP BY 1
ORDER BY 2 desc;

/*
 * Date parts and math
 */
SELECT date_part('month',lower(rental_period))::INT rental_month, count(*) total_rentals
FROM rental
GROUP BY rental_month
ORDER BY total_rentals DESC;


-- By day?
EXPLAIN (ANALYZE, buffers)
SELECT to_char(lower(rental_period), 'MM-dd'), count(*)
FROM rental
WHERE rental_period <@ tstzrange('2023-07-01'::timestamptz,NULL)
--WHERE lower(rental_period) > '2023-07-01'::timestamptz
GROUP BY 1
ORDER BY 2 DESC;

-- Date math is also very easy
SELECT now(); -- CURRENT SYSTEM time

SELECT now() - '6 hours'::INTERVAL; -- six HOURs ago

-- What is the interval of subtracting these two dates?
SELECT now() - '2024-11-01'::timestamptz;


-- For the first 10 days of July?
SELECT to_char(lower(rental_period), 'MM-dd'), count(*)
FROM rental
WHERE lower(rental_period) > '2023-07-01' AND lower(rental_period) <= '2023-07-01'::timestamptz + INTERVAL '10 days'
GROUP BY 1
ORDER BY 2 DESC;

-- But, of course, we're using a rangetype, so just use a range
SELECT to_char(lower(rental_period), 'MM-dd'), count(*)
FROM rental
WHERE rental_period <@ tstzrange('2023-07-01'::timestamptz,'2023-07-11'::timestamptz)
GROUP BY 1
ORDER BY 2 DESC;


/*************************************************************************************************
 * Generating sample data using generate_series()
 *************************************************************************************************/
SELECT * FROM generate_series(1,10);

SELECT * FROM generate_series(1,10,1.25);

-- This also works with dates
SELECT * FROM generate_series('2022-11-01','2022-11-15','1 hour'::interval);

SELECT * FROM generate_series('2022-11-01','2022-11-15','1 hour 25 minutes 30 seconds'::interval);

-- Remember, the output is just a SET which we can CROSS JOIN
-- to create more rows/data. We saw this earlier.
SELECT * FROM 
	generate_series(1,5) a, 
	generate_series(now()-'1 hour'::INTERVAL, now(), '10 minutes') b
ORDER BY b,a;



/**************************************************************************************************
 * Anonymous code blocks
 **************************************************************************************************/
DO
$$
DECLARE 
	f record;
	frating TEXT = 'G';
	sqlstr TEXT;
BEGIN 
	
	sqlstr = FORMAT($_$SELECT title, COALESCE(runtime,0)::text runtime 
	       FROM film 
	       WHERE rating = %L
	       ORDER BY runtime DESC, title
	       LIMIT 10$_$,frating);
	
    FOR f IN EXECUTE sqlstr
    LOOP 
		RAISE NOTICE '%(% mins)', f.title, f.runtime ;
    END LOOP;
END;
$$	


/*
 * JOIN USING vs. regular
 */

SELECT * FROM film f
	INNER JOIN film_crew fc ON f.film_id = fc.film_id;

-- ambiguous error
SELECT film_id, title, job FROM film f
	INNER JOIN film_crew fc ON f.film_id = fc.film_id;

-- duplicate join key rows are gone
SELECT film_id, title, job FROM film f
	INNER JOIN film_crew fc USING(film_id);


/*
 * LATERAL JOIN
 */
SELECT full_name, title, lower(rental_period)
FROM customer c 
	LEFT JOIN LATERAL (
		SELECT title, rental_period FROM film f
			INNER JOIN inventory USING(film_id)
			INNER JOIN rental using(inventory_id)
		WHERE c.customer_id = rental.customer_id 
		ORDER BY lower(rental_period) DESC 
		LIMIT 1
	) f1 ON TRUE
ORDER BY 3
LIMIT 10;

/*
 * Slow...... indexes?
 */
CREATE INDEX inventory_film_id_idx ON inventory (film_id);
CREATE INDEX rental_inventory_id_idx ON rental (inventory_id);
CREATE INDEX rental_customer_id_idx ON rental (customer_id);

/*
 * FILTER with aggregates
 * 
 * Get a count of active and inactive users
 */
SELECT (SELECT count(*) FROM customer WHERE activebool = TRUE) active_users,
	(SELECT count(*) FROM customer WHERE activebool = false) inactive_users;

SELECT sum(CASE WHEN activebool=TRUE THEN 1 ELSE 0 END) AS active_users,
	   sum(CASE WHEN activebool=FALSE THEN 1 ELSE 0 END) AS inactive_users
FROM customer;

-- FILTER simplifies this and makes it more readable
SELECT count(*) FILTER (WHERE activebool = TRUE) active_users,
	   count(*) FILTER (WHERE activebool = FALSE) inactive_users
FROM customer;

/*
 * ON CONFLICT and UPSERT - no... really!
 * 
 * In psql I ran this to get the rows quickly for testing:
 * 
 * COPY (SELECT customer_id, store_id, first_name, last_name, email, active FROM customer ORDER BY customer_id limit 5)
 *  TO STDOUT CSV;
 * 
 */

SELECT FORMAT($_$(%s,%s,%L,%L),$_$,customer_id,store_id,full_name,email) 
	from customer ORDER BY customer_id LIMIT 5;

INSERT INTO customer (customer_id, store_id, full_name, email) VALUES
(1,82,'Mr. Sylvan Rolfson DDS','reidwaelchi@gulgowski.info'),
(2,100,'Miss Mack Boyle','kimconn@bergnaum.biz'),
(3,143,'Rodrigo Rice','dokon17@aufderhar.name'),
(4,144,'Tre Krajcik','ybrakus@hackett.org'),
(5,142,'Dallas Lebsack','kristyabernathy@franecki.org')
--ON CONFLICT (customer_id) DO NOTHING;
--ON CONFLICT ON CONSTRAINT customer_pkey DO NOTHING;
--ON CONFLICT ON CONSTRAINT customer_pkey DO UPDATE SET email = EXCLUDED.email;

-- Did that update work?
SELECT * FROM customer ORDER BY customer_id LIMIT 5;

/*
 * This is particularly useful for "static" data that's updated
 * with an idempotent script 
 * 
 * Assume this is a longer script that has all static data
 * for a city and we want to insert one for Seattle
 */
SELECT FORMAT($_$(%s,%L),$_$,genre_id,name) 
	FROM film_genre fg
	ORDER BY genre_id;

INSERT INTO film_genre (genre_id, name) VALUES
(12,'Adventure'),
(14,'Fantasy'),
(16,'Animation'),
(18,'Drama'),
(27,'Horror'),
(28,'Action'),
(35,'Comedy'),
(36,'History'),
(37,'Western'),
(53,'Thriller'),
(80,'Crime'),
(99,'Documentary'),
(878,'Science Fiction'),
(9648,'Mystery'),
(10402,'Music'),
(10749,'Romance'),
(10751,'Family'),
(10752,'War'),
(10770,'TV Movie'),
(20000,'Sci-Fi')
ON CONFLICT (genre_id) DO NOTHING;

SELECT * FROM film_genre fg ORDER BY genre_id DESC;
--DELETE FROM film_genre WHERE genre_id = 20000;


/*
 * Arrays, arrays, arrays! 
 * 
 * I honestly love the array functionality of Postgres 🎉
 */
SELECT film_id, title, genre_ids FROM film;

SELECT film_id, title, UNNEST(genre_ids) FROM film;

SELECT film_id, title, genre_ids[0] FROM film;
-- Just kidding. Almost everything in PostgreSQL is 1-based.
SELECT film_id, title, genre_ids[1] FROM film;

SELECT film_id, title, genre_ids[2:] FROM film;

SELECT film_id, title, array_length(genre_ids,1) FROM film;


-- Searching arrays
SELECT film_id, title, genre_ids FROM film WHERE '{12}' @> genre_ids;

SELECT film_id, title, genre_ids FROM film WHERE genre_ids <@ '{12,14,16}';

-- The array has to be on the right-hand side! Not as intuitive
SELECT film_id, title, genre_ids FROM film WHERE '12' = ANY(genre_ids);


-- Creating arrays as aggregates for further processing
SELECT inventory_id, rental_period FROM rental
ORDER BY inventory_id;

SELECT inventory_id, array_agg(rental_period) rental_dates FROM rental
GROUP BY inventory_id 
ORDER BY inventory_id;

SELECT inventory_id, array_agg(rental_period ORDER BY lower(rental_period) DESC) rental_dates FROM rental
GROUP BY inventory_id 
ORDER BY inventory_id;

-- Use this in conjunction with other array operators!
SELECT inventory_id, array_to_string(array_agg(lower(rental_period)),',') rental_dates FROM rental
GROUP BY inventory_id 
ORDER BY inventory_id;

-- We can take values and create arrays for later processing
SELECT string_to_array(title, ' ') FROM film;

-- string_to_array is a SET RETURNING FUNCTION which can return the ORDINALITY 
-- of the elements that it returns. If we CROSS JOIN the output of 'film' to 
-- the function, we can expand the return and get the order of the words in the
-- title.
SELECT film_id, g.* FROM film CROSS JOIN LATERAL UNNEST(string_to_array(title, ' ')) WITH ORDINALITY AS g(w,o);

-- You can remove the CROSS JOIN with just an implicit comma
SELECT film_id, g.* FROM film, UNNEST(string_to_array(title, ' ')) WITH ORDINALITY AS g(w,o);


/*
 * Crazy fun with arrays and WORDLE!
 */
select * from regexp_matches($$Not as easy as you think
							#Wordle 511 3/6*
							🟨⬜🟨⬜⬜
							⬜🟨🟨🟨🟨
							🟩🟩🟩🟩🟩
						$$,'([🟩|🟧|🟨|🟦|⬛|⬜|]{5})','g') WITH ORDINALITY AS g(guess, guess_num);



WITH wordle_score AS (
	select * from regexp_matches($$Not as easy as you think
							#Wordle 511 3/6*
							🟨⬜🟨⬜⬜
							⬜🟨🟨🟨🟨
							🟩🟩🟩🟩🟩
						$$,'([🟩|🟧|🟨|🟦|⬛|⬜|]{5})','g') WITH ORDINALITY AS g(guess, guess_num)
)					
SELECT * FROM wordle_score;


-- Break it apart even further to get each separate letter
WITH wordle_score AS (
	select * from regexp_matches($$Not as easy as you think
							#Wordle 511 3/6*
							🟨⬜🟨⬜⬜
							⬜🟨🟨🟨🟨
							🟩🟩🟩🟩🟩
						$$,'([🟩|🟧|🟨|🟦|⬛|⬜|]{5})','g') WITH ORDINALITY AS g(guess, guess_num)
)					
SELECT *
FROM wordle_score ws,
	regexp_matches(ws.guess[1],'([⬛|🟩|🟨|⬜]{1})','g') WITH ORDINALITY AS r(c1, letter)

	
	
-- Now we can aggregate those individual letters
-- to see how many letters were right/wrong for each guess
WITH wordle_score AS (
	select * from regexp_matches($$Not as easy as you think
							#Wordle 511 3/6*
							🟨⬜🟨⬜⬜
							⬜🟨🟨🟨🟨
							🟩🟩🟩🟩🟩
						$$,'([🟩|🟧|🟨|🟦|⬛|⬜|]{5})','g') WITH ORDINALITY AS g(guess, guess_num)
)					
SELECT 
	guess_num,
	count(*) FILTER (WHERE c1[1]='🟩') AS c_correct,
	count(*) FILTER (WHERE c1[1]='🟨') AS c_partial,
	count(*) FILTER (WHERE c1[1] IN ('⬛','⬜')) AS c_incorrect
FROM wordle_score ws,
	regexp_matches(ws.guess[1],'([⬛|🟩|🟨|⬜]{1})','g') WITH ORDINALITY AS r(c1, letter)
GROUP BY 1;



/*
 * SELECT FOR UPDATE - Advanced
 * 
 * Open up another connection in psql or another DBeaver Script
 */
BEGIN; -- must BEGIN a TRANSACTION TO see this
	SELECT * FROM film ORDER BY film_id LIMIT 10 FOR UPDATE;

COMMIT;

