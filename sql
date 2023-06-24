CREATE PROCEDURE data_refresh()
LANGUAGE plpgsql
AS $$
BEGIN
DROP TABLE IF EXISTS detailed_table, summary_table, raw_data;

CREATE TABLE raw_data
AS
SELECT c.name as genre, r.rental_id, p.amount as sales
FROM category c
LEFT JOIN film_category f ON c.category_id = f.category_id
LEFT JOIN inventory i ON f.film_id = i.film_id
LEFT JOIN rental r ON i.inventory_id = r.inventory_id
LEFT JOIN payment p ON r.rental_id = p.rental_id
ORDER BY rental_id;

CREATE TABLE detailed_table
AS
SELECT genre, COUNT(rental_id) AS count_rentals, percentage_of(COUNT(rental_id), (SELECT COUNT(rental_Id) FROM raw_data)) AS percent_rentals, SUM(sales) AS sum_sales, percentage_of(SUM(sales), (SELECT SUM(sales) FROM raw_data)) AS percent_sales,
    CAST(percentage_of(SUM(sales), (SELECT SUM(sales) FROM raw_data)) / percentage_of(COUNT(rental_id), (SELECT COUNT(rental_Id) FROM raw_data)) AS DECIMAL(10,2)) AS normalized_sales
FROM raw_data
GROUP BY genre
ORDER BY normalized_sales DESC;

CREATE TABLE summary_table (
    performance_indicator VARCHAR, genre VARCHAR, val NUMERIC
);

INSERT INTO summary_table
VALUES (
    ('MOST SALES', (SELECT a.genre FROM detailed_table a LEFT OUTER JOIN detailed_table b ON a.sum_sales < b.sum_sales WHERE b.genre IS NULL),  (SELECT a.sum_sales FROM detailed_table a LEFT OUTER JOIN detailed_table b ON a.sum_sales < b.sum_sales WHERE b.genre IS NULL)),
    ('MOST RENTALS', (SELECT a.genre FROM detailed_table a LEFT OUTER JOIN detailed_table b ON a.count_rentals < b.count_rentals WHERE b.genre IS NULL), (SELECT a.count_rentals FROM detailed_table a LEFT OUTER JOIN detailed_table b ON a.count_rentals < b.count_rentals WHERE b.genre IS NULL)),
    ('HIGHEST SALES', (SELECT a.genre FROM detailed_table a LEFT OUTER JOIN detailed_table b ON a.normalized_sales < b.normalized_sales WHERE b.genre IS NULL), (SELECT a.normalized_sales FROM detailed_table a LEFT OUTER JOIN detailed_table b ON a.normalized_sales < b.normalized_sales WHERE b.genre IS NULL))
);

RETURN;
END;
$$;


