-- TV shows project 

USE tv_series;
SELECT * FROM tv_shows;

-- creating a duplicate
CREATE TABLE tv_shows_clean
LIKE tv_shows;

SELECT * FROM tv_shows_clean; 

INSERT tv_shows_clean
SELECT * FROM tv_shows;

-- 1. removing columns
ALTER TABLE tv_shows_clean
DROP COLUMN MyUnknownColumn,
DROP COLUMN Type;
SELECT * FROM tv_shows_clean;

-- 1.standardize data

ALTER TABLE tv_shows_clean
CHANGE COLUMN `Rotten Tomatoes` Rotten_Tomatoes text; -- to avoid using backticks

SELECT * FROM tv_shows_clean;

-- setting IMDb to decimal
UPDATE tv_shows_clean
SET IMDb = LEFT(IMDb, LOCATE('/', IMDb)-1)
WHERE IMDb LIKE '%/%';

UPDATE tv_shows_clean
SET IMDb = NULL
WHERE IMDb = '' OR IMDb NOT REGEXP '^[0-9]+(\.[0-9]+)?$';

ALTER TABLE tv_shows_clean 
MODIFY COLUMN IMDb DECIMAL(4,1);

-- setting RottenTomatoes to decimal
UPDATE tv_shows_clean
SET Rotten_Tomatoes = LEFT(Rotten_Tomatoes, LOCATE('/', Rotten_Tomatoes)-1)
WHERE Rotten_Tomatoes LIKE '%/%';

UPDATE tv_shows_clean
SET Rotten_Tomatoes = NULL
WHERE Rotten_Tomatoes = '' OR Rotten_Tomatoes NOT REGEXP '^[0-9]+(\.[0-9]+)?$';

ALTER TABLE tv_shows_clean
MODIFY COLUMN Rotten_Tomatoes DECIMAL (5,1);

-- adding avg rating column
ALTER TABLE tv_shows_clean
ADD COLUMN Rotten_Tomatoes_10 DECIMAL(4,1);

UPDATE tv_shows_clean
SET Rotten_Tomatoes_10 = Rotten_Tomatoes / 10;

ALTER TABLE tv_shows_clean
ADD COLUMN Average_Rating DECIMAL (4,1);

UPDATE tv_shows_clean
SET Average_Rating = ROUND((IMDb + Rotten_Tomatoes) /2,1);

-- 2. Working with data
-- Preliminary summary statistics
SELECT 
	COUNT(*) AS total_shows,
    AVG(Average_Rating) AS avg_rating,
    MIN(Average_Rating) AS min_rating,
    MAX(Average_Rating) AS max_rating
FROM tv_shows_clean;

SELECT
    ROUND(AVG(CASE WHEN Netflix = 1 THEN Average_Rating END),1) AS avg_rating_netflix,
    ROUND(AVG(CASE WHEN Hulu = 1 THEN Average_Rating END),1) AS avg_rating_hulu,
    ROUND(AVG(CASE WHEN `Prime Video` = 1 THEN Average_Rating END),1) AS avg_rating_primevideo,
    ROUND(AVG(CASE WHEN `Disney+` = 1 THEN Average_Rating END),1) AS avg_rating_disneyplus
FROM tv_shows_clean;

-- best shows
SELECT 
	Title, `Year`, Average_Rating, 
	CONCAT(
		CASE WHEN Netflix = 1 THEN "Netflix " ELSE "" END,
        CASE WHEN Hulu = 1 THEN 'Hulu ' ELSE '' END,
        CASE WHEN `Prime Video` = 1 THEN 'Prime Video ' ELSE '' END,
        CASE WHEN `Disney+` = 1 THEN 'Disney+ ' ELSE '' END) AS Platform
FROM tv_shows_clean
ORDER BY Average_Rating DESC
LIMIT 10;
	
-- age groups analysis
SELECT 
    CASE WHEN Age = '' THEN 'Unknown' ELSE Age END AS Age,
    ROUND(AVG(Average_Rating), 1) AS avg_rating,
    COUNT(*) AS num_shows
FROM tv_shows_clean
GROUP BY CASE WHEN Age = '' THEN 'Unknown' ELSE Age END;

-- average rating by year
SELECT * FROM tv_shows_clean;
SELECT Year, ROUND(AVG(Average_Rating),1) AS Avg_Rating 
from tv_shows_clean
GROUP BY Year
ORDER BY Year DESC;

-- column for number platforms and correlation rating/number of platforms
ALTER TABLE tv_shows_clean
ADD COLUMN Plat_Count INT;

UPDATE tv_shows_clean
SET Plat_Count = Netflix + Hulu +`Prime Video` + `Disney+` ; 

SELECT Plat_Count, ROUND(AVG(Average_Rating),1) AS avg_rating
FROM tv_shows_clean
GROUP BY Plat_Count;


