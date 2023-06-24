B.	Provide original code for function(s) in text format that perform the transformation(s) you identified in part A4.

```
CREATE OR REPLACE FUNCTION percentage_of(
	part DECIMAL(10, 4),
	total DECIMAL(10, 4)
)
RETURNS DECIMAL(10, 2)
LANGUAGE plpgsql
AS
$$
DECLARE percentage DECIMAL(10, 5);

BEGIN
SELECT part/total INTO percentage;
RETURN CAST(percentage*100 AS DECIMAL(10, 2));
END;
$$;
```