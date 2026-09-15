-- Sakila XL generator — reproduces Sakila_XL.sqlite from a plain copy of the
-- real sakila_master.db (v1.0.0 release in this repo).
--
--   cp sakila_master.db Sakila_XL.sqlite
--   sqlite3 Sakila_XL.sqlite < sakila_xl_generate.sql
--
-- Inflates the real dataset from ~46,273 rows to ~3.28M rows (customer/film/
-- payment/rental scaled the most; country/language/category left untouched
-- as fixed enum-like tables) by cycling through the existing real values
-- (names, titles, etc.) rather than generating meaningless random noise, so
-- the result stays a recognizable video-rental-store schema. Every new
-- primary key starts strictly after the table's real MAX(pk) — not
-- COUNT(*), since a couple of tables (address, rental) have small internal
-- gaps in their real id sequences, confirmed via direct inspection before
-- writing this script, not assumed.
--
-- The AFTER INSERT/UPDATE triggers are dropped before the bulk inserts and
-- restored after: this script's own INSERTs already set last_update
-- directly, and (a real SQLite quirk, confirmed by testing, not folklore)
-- leaving an AFTER INSERT trigger active that UPDATEs the very table being
-- bulk-inserted into via a recursive CTE causes the CTE to restart and
-- produce duplicate rows.
--
-- No new third-party content is introduced — every new row is either a
-- verbatim copy of real Sakila column values or a deterministic function of
-- one (a numeric suffix, a modular index). See CREDITS.md.

DROP TRIGGER actor_trigger_ai;
DROP TRIGGER actor_trigger_au;
DROP TRIGGER country_trigger_ai;
DROP TRIGGER country_trigger_au;
DROP TRIGGER city_trigger_ai;
DROP TRIGGER city_trigger_au;
DROP TRIGGER address_trigger_ai;
DROP TRIGGER address_trigger_au;
DROP TRIGGER language_trigger_ai;
DROP TRIGGER language_trigger_au;
DROP TRIGGER category_trigger_ai;
DROP TRIGGER category_trigger_au;
DROP TRIGGER customer_trigger_ai;
DROP TRIGGER customer_trigger_au;
DROP TRIGGER film_trigger_ai;
DROP TRIGGER film_trigger_au;
DROP TRIGGER film_actor_trigger_ai;
DROP TRIGGER film_actor_trigger_au;
DROP TRIGGER film_category_trigger_ai;
DROP TRIGGER film_category_trigger_au;
DROP TRIGGER inventory_trigger_ai;
DROP TRIGGER inventory_trigger_au;
DROP TRIGGER staff_trigger_ai;
DROP TRIGGER staff_trigger_au;
DROP TRIGGER store_trigger_ai;
DROP TRIGGER store_trigger_au;
DROP TRIGGER payment_trigger_ai;
DROP TRIGGER payment_trigger_au;
DROP TRIGGER rental_trigger_ai;
DROP TRIGGER rental_trigger_au;
-- Sakila XL generator: inflates the real Sakila dataset (schema/data unchanged
-- for existing rows) with additional synthetic rows that reuse real values
-- cyclically, so the result stays a recognizable "video rental store" schema
-- rather than random noise. All new PKs start after the real max id so
-- nothing in the original ~46,273 rows is touched or overwritten.

PRAGMA journal_mode = OFF;
PRAGMA synchronous = OFF;

BEGIN TRANSACTION;

-- actor: 200 -> 2,200 (+2,000)
WITH RECURSIVE seq(n) AS (
  SELECT 1 UNION ALL SELECT n+1 FROM seq WHERE n < 2000
)
INSERT INTO actor (actor_id, first_name, last_name, last_update)
SELECT
  200 + n,
  (SELECT first_name FROM actor WHERE actor_id = ((n-1) % 200) + 1),
  (SELECT last_name  FROM actor WHERE actor_id = ((n*37-1) % 200) + 1) || '_' || n,
  DATETIME('now')
FROM seq;

-- city: 600 -> 3,600 (+3,000)
WITH RECURSIVE seq(n) AS (
  SELECT 1 UNION ALL SELECT n+1 FROM seq WHERE n < 3000
)
INSERT INTO city (city_id, city, country_id, last_update)
SELECT
  600 + n,
  (SELECT city FROM city WHERE city_id = ((n-1) % 600) + 1) || '_' || n,
  (n % 109) + 1,
  DATETIME('now')
FROM seq;

-- address: 603 rows but real MAX(address_id)=605 (two gaps at 257/518 within
-- range, not contiguous) -> 605 + 49,400, referencing the now-3,600-row city
-- pool. Uses a ROW_NUMBER()-ranked view instead of raw PK modular arithmetic,
-- since address_id isn't dense (unlike every other table cycled here).
DROP VIEW IF EXISTS address_ranked;
CREATE TEMP VIEW address_ranked AS
  SELECT ROW_NUMBER() OVER (ORDER BY address_id) AS rn, address, district, postal_code, phone
  FROM address;

WITH RECURSIVE seq(n) AS (
  SELECT 1 UNION ALL SELECT n+1 FROM seq WHERE n < 49400
)
INSERT INTO address (address_id, address, address2, district, city_id, postal_code, phone, last_update)
SELECT
  605 + n,
  (SELECT address FROM address_ranked WHERE rn = ((n-1) % 603) + 1) || ' #' || n,
  NULL,
  (SELECT district FROM address_ranked WHERE rn = ((n*13-1) % 603) + 1),
  ((n-1) % 3600) + 1,
  (SELECT postal_code FROM address_ranked WHERE rn = ((n-1) % 603) + 1),
  (SELECT phone FROM address_ranked WHERE rn = ((n*7-1) % 603) + 1),
  DATETIME('now')
FROM seq;

DROP VIEW address_ranked;

-- film: 1,000 -> 10,000 (+9,000)
WITH RECURSIVE seq(n) AS (
  SELECT 1 UNION ALL SELECT n+1 FROM seq WHERE n < 9000
)
INSERT INTO film (film_id, title, description, release_year, language_id, original_language_id,
                  rental_duration, rental_rate, length, replacement_cost, rating, special_features, last_update)
SELECT
  1000 + n,
  (SELECT title FROM film WHERE film_id = ((n-1) % 1000) + 1) || ' (Copy ' || n || ')',
  (SELECT description FROM film WHERE film_id = ((n-1) % 1000) + 1),
  (SELECT release_year FROM film WHERE film_id = ((n-1) % 1000) + 1),
  ((n-1) % 6) + 1,
  NULL,
  (SELECT rental_duration FROM film WHERE film_id = ((n-1) % 1000) + 1),
  (SELECT rental_rate FROM film WHERE film_id = ((n-1) % 1000) + 1),
  (SELECT length FROM film WHERE film_id = ((n-1) % 1000) + 1),
  (SELECT replacement_cost FROM film WHERE film_id = ((n-1) % 1000) + 1),
  (SELECT rating FROM film WHERE film_id = ((n-1) % 1000) + 1),
  (SELECT special_features FROM film WHERE film_id = ((n-1) % 1000) + 1),
  DATETIME('now')
FROM seq;

-- film_category: one row per new film (film 1,000 -> 10,000), 1:1
WITH RECURSIVE seq(n) AS (
  SELECT 1 UNION ALL SELECT n+1 FROM seq WHERE n < 9000
)
INSERT INTO film_category (film_id, category_id, last_update)
SELECT
  1000 + n,
  ((n-1) % 16) + 1,
  DATETIME('now')
FROM seq;

-- film_actor: 5 distinct actors per new film (2,200 actors, 2200/5=440 spacing
-- guarantees 5 distinct actor_ids per film with no PK collision)
WITH RECURSIVE seq(n) AS (
  SELECT 1 UNION ALL SELECT n+1 FROM seq WHERE n < 9000
)
INSERT INTO film_actor (actor_id, film_id, last_update)
SELECT ((( (n-1) + (k*440) ) % 2200) + 1), 1000 + n, DATETIME('now')
FROM seq, (SELECT 0 AS k UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4);

-- customer: 599 -> 50,003 (+49,404), referencing the real 2 stores and the
-- expanded 50,003-row address pool (offset past the addresses staff/store
-- already use, to reduce (harmless but odd-looking) address reuse)
WITH RECURSIVE seq(n) AS (
  SELECT 1 UNION ALL SELECT n+1 FROM seq WHERE n < 49404
)
INSERT INTO customer (customer_id, store_id, first_name, last_name, email, address_id, active, create_date, last_update)
SELECT
  599 + n,
  ((n-1) % 2) + 1,
  (SELECT first_name FROM customer WHERE customer_id = ((n-1) % 599) + 1),
  (SELECT last_name  FROM customer WHERE customer_id = ((n*11-1) % 599) + 1) || '_' || n,
  'synthetic_customer_' || (599+n) || '@example.invalid',
  605 + ((n-1) % 49400) + 1,
  'Y',
  DATETIME('now'),
  DATETIME('now')
FROM seq;

-- inventory: 4,581 -> ~100,000 (+95,419), spread across all 10,000 films and
-- the real 2 stores
WITH RECURSIVE seq(n) AS (
  SELECT 1 UNION ALL SELECT n+1 FROM seq WHERE n < 95419
)
INSERT INTO inventory (inventory_id, film_id, store_id, last_update)
SELECT
  4581 + n,
  ((n-1) % 10000) + 1,
  ((n-1) % 2) + 1,
  DATETIME('now')
FROM seq;

-- rental: 16,044 rows but real MAX(rental_id)=16,049 (a gap) -> 16,049 +
-- 1,483,956, spread across the full 100,000-row inventory pool, 50,003-row
-- customer pool, and the real 2 staff
WITH RECURSIVE seq(n) AS (
  SELECT 1 UNION ALL SELECT n+1 FROM seq WHERE n < 1483956
)
INSERT INTO rental (rental_id, rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT
  16049 + n,
  DATETIME('now', '-' || ((n % 3650) + 1) || ' days'),
  ((n-1) % 100000) + 1,
  ((n-1) % 50003) + 1,
  DATETIME('now', '-' || (n % 3640) || ' days'),
  ((n-1) % 2) + 1,
  DATETIME('now')
FROM seq;

-- payment: driven 1:1 off the newly-inserted rental rows above, so every
-- payment.rental_id/customer_id/staff_id reference is guaranteed valid by
-- construction. Real payment MAX is also 16,049, so reusing rental_id
-- directly as payment_id lands exactly right with no separate arithmetic.
INSERT INTO payment (payment_id, customer_id, staff_id, rental_id, amount, payment_date, last_update)
SELECT
  r.rental_id,
  r.customer_id,
  r.staff_id,
  r.rental_id,
  (SELECT amount FROM payment WHERE payment_id = ((r.rental_id * 3 - 1) % 16049) + 1),
  r.rental_date,
  DATETIME('now')
FROM rental r
WHERE r.rental_id > 16049;

COMMIT;
CREATE TRIGGER actor_trigger_ai AFTER INSERT ON actor
 BEGIN
  UPDATE actor SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER actor_trigger_au AFTER UPDATE ON actor
 BEGIN
  UPDATE actor SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER country_trigger_ai AFTER INSERT ON country
 BEGIN
  UPDATE country SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER country_trigger_au AFTER UPDATE ON country
 BEGIN
  UPDATE country SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER city_trigger_ai AFTER INSERT ON city
 BEGIN
  UPDATE city SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER city_trigger_au AFTER UPDATE ON city
 BEGIN
  UPDATE city SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER address_trigger_ai AFTER INSERT ON address
 BEGIN
  UPDATE address SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER address_trigger_au AFTER UPDATE ON address
 BEGIN
  UPDATE address SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER language_trigger_ai AFTER INSERT ON language
 BEGIN
  UPDATE language SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER language_trigger_au AFTER UPDATE ON language
 BEGIN
  UPDATE language SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER category_trigger_ai AFTER INSERT ON category
 BEGIN
  UPDATE category SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER category_trigger_au AFTER UPDATE ON category
 BEGIN
  UPDATE category SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER customer_trigger_ai AFTER INSERT ON customer
 BEGIN
  UPDATE customer SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER customer_trigger_au AFTER UPDATE ON customer
 BEGIN
  UPDATE customer SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER film_trigger_ai AFTER INSERT ON film
 BEGIN
  UPDATE film SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER film_trigger_au AFTER UPDATE ON film
 BEGIN
  UPDATE film SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER film_actor_trigger_ai AFTER INSERT ON film_actor
 BEGIN
  UPDATE film_actor SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER film_actor_trigger_au AFTER UPDATE ON film_actor
 BEGIN
  UPDATE film_actor SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER film_category_trigger_ai AFTER INSERT ON film_category
 BEGIN
  UPDATE film_category SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER film_category_trigger_au AFTER UPDATE ON film_category
 BEGIN
  UPDATE film_category SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER inventory_trigger_ai AFTER INSERT ON inventory
 BEGIN
  UPDATE inventory SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER inventory_trigger_au AFTER UPDATE ON inventory
 BEGIN
  UPDATE inventory SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER staff_trigger_ai AFTER INSERT ON staff
 BEGIN
  UPDATE staff SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER staff_trigger_au AFTER UPDATE ON staff
 BEGIN
  UPDATE staff SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER store_trigger_ai AFTER INSERT ON store
 BEGIN
  UPDATE store SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER store_trigger_au AFTER UPDATE ON store
 BEGIN
  UPDATE store SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER payment_trigger_ai AFTER INSERT ON payment
 BEGIN
  UPDATE payment SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER payment_trigger_au AFTER UPDATE ON payment
 BEGIN
  UPDATE payment SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER rental_trigger_ai AFTER INSERT ON rental
 BEGIN
  UPDATE rental SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
CREATE TRIGGER rental_trigger_au AFTER UPDATE ON rental
 BEGIN
  UPDATE rental SET last_update = DATETIME('NOW')  WHERE rowid = new.rowid;
 END;
