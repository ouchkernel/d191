C. Provide original SQL code in a text format that creates the detailed and summary tables to hold your report table sections.

```
CREATE TABLE detailed_table AS
SELECT
    genre,
    COUNT(rental_id) AS count_rentals,
    COUNT(rental_id)::DECIMAL(10, 5) / (SELECT COUNT(rental_id) FROM raw_data) * 100 AS percent_rentals,
    SUM(sales) AS sum_sales,
    SUM(sales)::DECIMAL(10, 5) / (SELECT SUM(sales) FROM raw_data) * 100 AS percent_sales,
    (SUM(sales)::DECIMAL(10, 5) / (SELECT SUM(sales) FROM raw_data)) / (COUNT(rental_id)::DECIMAL(10, 5) / (SELECT COUNT(rental_id) FROM raw_data))::DECIMAL(10, 5) AS normalized_sales
FROM
    raw_data
GROUP BY
    genre
ORDER BY
    normalized_sales DESC;

CREATE TABLE summary_table (
    perf_indicator VARCHAR,
    genre VARCHAR,
    val NUMERIC
);

WITH max_sales AS (
  SELECT a.genre, a.sum_sales
  FROM detailed_table a
  LEFT JOIN detailed_table b ON a.sum_sales < b.sum_sales
  WHERE b.genre IS NULL
),
max_rentals AS (
  SELECT a.genre, a.count_rentals
  FROM detailed_table a
  LEFT JOIN detailed_table b ON a.count_rentals < b.count_rentals
  WHERE b.genre IS NULL
),
highest_sales AS (
  SELECT a.genre, a.normalized_sales
  FROM detailed_table a
  LEFT JOIN detailed_table b ON a.normalized_sales < b.normalized_sales
  WHERE b.genre IS NULL
)
INSERT INTO summary_table (perf_indicator, genre, val)
VALUES
  ('MOST SALES', (SELECT genre FROM max_sales), (SELECT sum_sales FROM max_sales)),
  ('MOST RENTALS', (SELECT genre FROM max_rentals), (SELECT count_rentals FROM max_rentals)),
  ('HIGHEST SALES', (SELECT genre FROM highest_sales), (SELECT normalized_sales FROM highest_sales));


```

B. Provide original code for function(s) in text format that perform the transformation(s) you identified in part A4.

```
CREATE OR REPLACE FUNCTION percentage_of(
  part DECIMAL(10, 4),
  total DECIMAL(10, 4)
)
RETURNS DECIMAL(10, 2)
LANGUAGE plpgsql
AS $$
DECLARE 
  percentage DECIMAL(10, 5);
BEGIN
  percentage := part / total;
  RETURN CAST(percentage * 100 AS DECIMAL(10, 2));
END;
$$;
```

D. Provide an original SQL query in a text format that will extract the raw data needed for the detailed section of your report from the source database.

```
CREATE TABLE raw_data AS
SELECT c.name AS genre, r.rental_id, p.amount AS sales
FROM category c
LEFT JOIN film_category fc ON c.category_id = fc.category_id
LEFT JOIN (
  SELECT i.inventory_id, i.film_id
  FROM inventory i
) AS I ON fc.film_id = I.film_id
LEFT JOIN rental r ON I.inventory_id = r.inventory_id
LEFT JOIN payment p ON r.rental_id = p.rental_id
ORDER BY r.rental_id;
```

E. Provide original SQL code in a text format that creates a trigger on the detailed table of the report that will continually update the summary table as data is added to the detailed table.

```
CREATE OR REPLACE FUNCTION updater_function()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM summary_table;
  
  WITH max_sales AS (
    SELECT a.genre, a.sum_sales
    FROM detailed_table a
    LEFT JOIN detailed_table b ON a.sum_sales < b.sum_sales
    WHERE b.genre IS NULL
  ),
  max_rentals AS (
    SELECT a.genre, a.count_rentals
    FROM detailed_table a
    LEFT JOIN detailed_table b ON a.count_rentals < b.count_rentals
    WHERE b.genre IS NULL
  ),
  highest_sales AS (
    SELECT a.genre, a.normalized_sales
    FROM detailed_table a
    LEFT JOIN detailed_table b ON a.normalized_sales < b.normalized_sales
    WHERE b.genre IS NULL
  )
  INSERT INTO summary_table (perf_indicator, genre, val)
  VALUES
    ('MOST SALES', (SELECT genre FROM max_sales), (SELECT sum_sales FROM max_sales)),
    ('MOST RENTALS', (SELECT genre FROM max_rentals), (SELECT count_rentals FROM max_rentals)),
    ('HIGHEST SALES', (SELECT genre FROM highest_sales), (SELECT normalized_sales FROM highest_sales));
  
  RETURN NEW;
END;
$$;


CREATE TRIGGER updater
 AFTER INSERT
 ON detailed_table
 FOR EACH STATEMENT
 EXECUTE PROCEDURE updater_function();
```

F. Provide an original stored procedure in a text format that can be used to refresh the d

```
CREATE OR REPLACE PROCEDURE data_refresh()
LANGUAGE plpgsql
AS $$
BEGIN
    DROP TABLE IF EXISTS detailed_table, summary_table, raw_data;

    CREATE TABLE raw_data AS
    SELECT c.name AS genre, r.rental_id, p.amount AS sales
    FROM category c
    LEFT JOIN film_category fc ON c.category_id = fc.category_id
    LEFT JOIN inventory i ON fc.film_id = i.film_id
    LEFT JOIN rental r ON i.inventory_id = r.inventory_id
    LEFT JOIN payment p ON r.rental_id = p.rental_id
    ORDER BY r.rental_id;

    CREATE TABLE detailed_table AS
    SELECT genre, COUNT(rental_id) AS count_rentals, percentage_of(COUNT(rental_id), (SELECT COUNT(rental_id) FROM raw_data)) AS percent_rentals, SUM(sales) AS sum_sales, percentage_of(SUM(sales), (SELECT SUM(sales) FROM raw_data)) AS percent_sales,
        CAST(percentage_of(SUM(sales), (SELECT SUM(sales) FROM raw_data)) / percentage_of(COUNT(rental_id), (SELECT COUNT(rental_id) FROM raw_data)) AS DECIMAL(10,2)) AS normalized_sales
    FROM raw_data
    GROUP BY genre
    ORDER BY normalized_sales DESC;

    CREATE TABLE summary_table (
        performance_indicator VARCHAR,
        genre VARCHAR,
        val NUMERIC
    );

    INSERT INTO summary_table
    SELECT
        'MOST SALES',
        a.genre,
        a.sum_sales
    FROM detailed_table a
    LEFT OUTER JOIN detailed_table b ON a.sum_sales < b.sum_sales
    WHERE b.genre IS NULL
    UNION ALL
    SELECT
        'MOST RENTALS',
        a.genre,
        a.count_rentals
    FROM detailed_table a
    LEFT OUTER JOIN detailed_table b ON a.count_rentals < b.count_rentals
    WHERE b.genre IS NULL
    UNION ALL
    SELECT
        'HIGHEST SALES',
        a.genre,
        a.normalized_sales
    FROM detailed_table a
    LEFT OUTER JOIN detailed_table b ON a.normalized_sales < b.normalized_sales
    WHERE b.genre IS NULL;

    RETURN;
END;
$$;
```

Run call data_refresh() to show everything has been refreshed.
