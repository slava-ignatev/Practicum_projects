/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 *
 * Автор: Игнатьев Вячеслав
 * Дата: 11.09.2025
*/


-- Задача 1. Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Сегментируем объявления по времени публикации.
    cte1 AS (
SELECT
	id,
	CASE
		WHEN days_exposition BETWEEN 1 AND 30 THEN '1-30 days'
		WHEN days_exposition BETWEEN 31 AND 90 THEN '31-90 days'
		WHEN days_exposition BETWEEN 91 AND 180 THEN '91-180 days'
		WHEN days_exposition >180 THEN '181+ days'
		ELSE 'non category'
	END AS category
FROM real_estate.advertisement),
main_cte AS (
SELECT
	-- Категоризация по городу и области.
	CASE
		WHEN city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
		ELSE 'Ленинградская область'
	END AS city_category,
	category,
	-- Расчет основных агрегаций.
	COUNT(f.id) AS total_ads,
	ROUND(AVG(last_price/total_area)::NUMERIC,2) AS avg_price,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY (total_area))AS median_area,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY (rooms))AS median_rooms,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY (balcony))AS median_balcony
FROM
	real_estate.advertisement a LEFT JOIN cte1 USING (id)
	LEFT JOIN real_estate.flats f ON f.id = a.id
	LEFT JOIN real_estate.city c ON c.city_id = f.city_id
-- Фильтруем по годам, региону и выбросам.
WHERE
	EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018
	AND type_id = 'F8EM'
	AND f.id IN (SELECT * FROM filtered_id)
GROUP BY
	category,
	city_category
ORDER BY
	city_category,
	total_ads DESC)
-- Рассчитываем долю каждого временного сегмента внутри региона.
SELECT *,
	ROUND(total_ads/SUM(total_ads) OVER (PARTITION BY city_category),2) AS SHARE
FROM main_cte;
-- Задача 2. Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
    -- Определяем месяц публикации и месяц снятия объявления.
    main_cte AS (
SELECT
	id,
	last_price,
    EXTRACT(MONTH FROM first_day_exposition) AS start_exposition,
    TO_CHAR(first_day_exposition, 'TMmon') AS start_exposition_month,
    EXTRACT(MONTH FROM first_day_exposition + days_exposition * INTERVAL '1 day') AS end_exposition,
     TO_CHAR(first_day_exposition + days_exposition * INTERVAL '1 day', 'TMmon') AS end_exposition_month,
    total_area
FROM real_estate.advertisement
LEFT JOIN real_estate.flats f USING(id)
LEFT JOIN real_estate.city c ON c.city_id = f.city_id
WHERE EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018
	AND type_id = 'F8EM' AND f.id IN (SELECT id FROM filtered_id)
),
-- Считаем агрегации для опубликованных объявлений
the_public AS(
SELECT
	start_exposition,
	start_exposition_month,
	COUNT(id) AS total_public_ads,
	ROUND(AVG(last_price/total_area)::NUMERIC,2) AS avg_price_public,
	ROUND(AVG(total_area)::NUMERIC,2) AS avg_s_public
FROM main_cte
GROUP BY start_exposition,start_exposition_month
),
-- Считаем агрегации для снятых объявлений
remove_ads AS(
SELECT
	end_exposition,
	end_exposition_month,
	COUNT(id) AS total_remove_ads,
	ROUND(AVG(last_price/total_area)::NUMERIC,2) AS avg_price_remove,
	ROUND(AVG(total_area)::NUMERIC,2) AS avg_s_remove
FROM main_cte
-- Учитываем только снятые
WHERE end_exposition IS NOT NULL
GROUP BY end_exposition,end_exposition_month
)
-- В основном запросе объединяем два CTE, объединяем по месяцам
-- Ранжируем месяцы по количеству опубликованных и снятых объявлений.
SELECT
	start_exposition_month,
	total_public_ads,
	avg_price_public,
	avg_s_public,
	RANK() OVER (ORDER BY total_public_ads DESC) AS rank_count_p,
	end_exposition_month,
	total_remove_ads,
	avg_price_remove,
	avg_s_remove,
	RANK() OVER (ORDER BY total_remove_ads DESC) AS rank_count_r
FROM the_public
JOIN remove_ads ON start_exposition = end_exposition
ORDER BY start_exposition, end_exposition;
