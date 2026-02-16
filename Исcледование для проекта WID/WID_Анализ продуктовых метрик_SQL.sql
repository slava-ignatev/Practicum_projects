-- Считаем DAU
SELECT
	date AS DAY,
	count(DISTINCT user_id) dau
FROM
	wid_test_dataset
GROUP BY
	1;
-- Считаем MAU
SELECT
	EXTRACT(MONTH FROM date) AS MONTH,
	count(DISTINCT user_id) mau
FROM
	wid_test_dataset
GROUP BY
	1;
-- Считаем WAU
SELECT
	EXTRACT(week FROM date) week,
	count(DISTINCT user_id) wau
FROM
	wid_test_dataset
GROUP BY
	1;
-- Расчитаем конверсионные метрики
SELECT
	-- Считаем количество пользователей по всем этапам
	COUNT(DISTINCT user_id) AS "Всего юзеров",
	COUNT(DISTINCT user_id) FILTER (
	WHERE event = 'visit') AS "Всего юзеров с визитом",
	COUNT(DISTINCT user_id) FILTER (
	WHERE event = 'signup') AS "Всего регистраций",
	COUNT(DISTINCT user_id) FILTER (
	WHERE event = 'subscribe') AS "Всего подписок",
	COUNT(DISTINCT user_id) FILTER (
WHERE
	event IN ('add_item', 'create_outfit', 'ai_recommendation')) AS "Количество активных юзеров"
,
	-- Считаем конверсию в регистрацию
	ROUND(
    (COUNT(DISTINCT user_id) FILTER (WHERE event = 'signup'))::NUMERIC * 100
    / 
    NULLIF(COUNT(DISTINCT user_id) FILTER (WHERE event = 'visit'), 0), 
    2
) AS CR_f_visit_to_signup,
	-- Считаем конверсию из регистрации в активного пользователя. Обращу внимание, что здесь конверсия будет выше 100%, т.к все пользователи проявляли активность
	ROUND(
    (COUNT(DISTINCT user_id) FILTER (WHERE event IN ('add_item', 'create_outfit', 'ai_recommendation')))::NUMERIC * 100
    / 
    NULLIF(COUNT(DISTINCT user_id) FILTER (WHERE event = 'signup'), 0), 
    2
) AS CR_signup_to_active_user,
	-- Считаем конверсию из активного пользователя в подписку
	ROUND(
    (COUNT(DISTINCT user_id) FILTER (WHERE event = 'subscribe'))::NUMERIC * 100
    / 
    NULLIF(COUNT(DISTINCT user_id) FILTER (WHERE event IN ('add_item', 'create_outfit', 'ai_recommendation')), 0), 
    2
) AS CR_active_to_suscribe
FROM
	wid_test_dataset;
-- Рассчитаем retention rate
-- Считаем новых пользователей
WITH new_users AS (
SELECT
	DISTINCT date AS first_visit_date,
	user_id
FROM
	wid_test_dataset
WHERE
	event = 'visit'),
-- Вычисляем количество дней с первого визита для пользователя
active_users AS (
SELECT
	t.user_id,
	(t.date::date - n.first_visit_date::date) AS day_since_f_visit
FROM
	wid_test_dataset t
JOIN new_users n ON
	t.user_id = n.user_id)
-- Считаем ретеншн, как отношение количества пользователей с активностью на n-день на общее количество новых пользователей
SELECT
	ROUND(
        COUNT(DISTINCT user_id) FILTER (WHERE day_since_f_visit = 7)::NUMERIC 
        / (SELECT COUNT(*) FROM new_users)::NUMERIC * 100, 
    2) AS retention_rate_7,
	ROUND(
        COUNT(DISTINCT user_id) FILTER (WHERE day_since_f_visit = 30)::NUMERIC 
        / (SELECT COUNT(*) FROM new_users)::NUMERIC * 100, 
    2) AS retention_rate_30
FROM
	active_users;
-- Считаем DAU по устройстам
SELECT
	device,
	date,
	count(DISTINCT user_id) dau
FROM
	wid_test_dataset
GROUP BY
	1,
	2
ORDER BY
	2;
-- Считаем WAU по устройствам
SELECT
	device,
	EXTRACT(week FROM date) week,
	count(DISTINCT user_id) wau
FROM
	wid_test_dataset
GROUP BY
	1,
	2
ORDER BY
	week;
-- Считаем MAU по устройствам
SELECT
	device,
	EXTRACT(MONTH FROM date) AS MONTH,
	count(DISTINCT user_id) mau
FROM
	wid_test_dataset
GROUP BY
	1,
	2
ORDER BY
	2;
-- Cчитаем конверсионные метрики по источникам
SELECT
	SOURCE,
	-- Считаем количество пользователей по всем этапам
	COUNT(DISTINCT user_id) AS "Всего юзеров",
	COUNT(DISTINCT user_id) FILTER (
	WHERE event = 'visit') AS "Всего юзеров с визитом",
	COUNT(DISTINCT user_id) FILTER (
	WHERE event = 'signup') AS "Всего регистраций",
	COUNT(DISTINCT user_id) FILTER (
	WHERE event = 'subscribe') AS "Всего подписок",
	COUNT(DISTINCT user_id) FILTER (
WHERE
	event IN ('add_item', 'create_outfit', 'ai_recommendation')) AS "Количество активных юзеров"
,
	-- Считаем конверсию в регистрацию
	ROUND(
    (COUNT(DISTINCT user_id) FILTER (WHERE event = 'signup'))::NUMERIC * 100
    / 
    NULLIF(COUNT(DISTINCT user_id) FILTER (WHERE event = 'visit'), 0), 
    2
) AS CR_to_signup,
	-- Считаем конверсию из регистрации в активного пользователя. Обращу внимание, что здесь конверсия будет выше 100%, т.к все пользователи проявляли активность
	ROUND(
    (COUNT(DISTINCT user_id) FILTER (WHERE event IN ('add_item', 'create_outfit', 'ai_recommendation')))::NUMERIC * 100
    / 
    NULLIF(COUNT(DISTINCT user_id) FILTER (WHERE event = 'signup'), 0), 
    2
) AS CR_to_active_user,
	-- Считаем конверсию из активного пользователя в подписку
	ROUND(
    (COUNT(DISTINCT user_id) FILTER (WHERE event = 'subscribe'))::NUMERIC * 100
    / 
    NULLIF(COUNT(DISTINCT user_id) FILTER (WHERE event IN ('add_item', 'create_outfit', 'ai_recommendation')), 0), 
    2
) AS CR_to_suscribe
FROM
	wid_test_dataset
GROUP BY
	1;
-- Рассчитаем retention rate по устройствам
-- Считаем новых пользователей
WITH new_users AS (
SELECT
	DISTINCT date AS first_visit_date,
	user_id
FROM
	wid_test_dataset
WHERE
	event = 'visit'),
-- Вычисляем количество дней с первого визита для пользователя
active_users AS (
SELECT
	device,
	t.user_id,
	(t.date::date - n.first_visit_date::date) AS day_since_f_visit
FROM
	wid_test_dataset t
JOIN new_users n ON
	t.user_id = n.user_id)
-- Считаем ретеншн, как отношение количества пользователей с активностью на n-день на общее количество новых пользователей
SELECT
	device,
	ROUND(
        COUNT(DISTINCT user_id) FILTER (WHERE day_since_f_visit = 7)::NUMERIC 
        / (SELECT COUNT(*) FROM new_users)::NUMERIC * 100, 
    2) AS retention_rate_7,
	ROUND(
        COUNT(DISTINCT user_id) FILTER (WHERE day_since_f_visit = 30)::NUMERIC 
        / (SELECT COUNT(*) FROM new_users)::NUMERIC * 100, 
    2) AS retention_rate_30
FROM
	active_users
GROUP BY
	1;
