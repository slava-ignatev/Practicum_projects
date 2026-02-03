--Задача: Определить регионы с наибольшим количеством зарегистрированных доноров.
SELECT region, COUNT(id)
FROM donorsearch.user_anon_data
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10
/* 
Выводы: 
У более 100 000 доноров не заполнен город. Рекомендуем сделать это поле обязательным для последующих задач анализа
Наибольшее количество доноров было в Москве и Санкт-Петербурге.
*/


--Задача: Вывести топ-5 регионов по количеству донаций и определить долю платных донаций по каждому региону
SELECT 
	region, 
	COUNT(id) AS "Всего донаций", 
	COUNT(ID) FILTER (WHERE donation_type = 'Платно') AS "Всего платных донаций",
	ROUND(100.0 * COUNT(ID) FILTER (WHERE donation_type = 'Платно') / COUNT(id),2) AS "Доля платных донаций"
FROM donorsearch.donation_anon
WHERE region != 'Не указан'
GROUP BY 1
ORDER BY 2 DESC, 3 DESC
LIMIT 5
/*
Выводы: 
Лидером по количеству донаций (20 277) был Татарстан. 
Наибольшее количество платных донаций (1664) было в Югре. Также этот регион показал наибольшую долю платных донаций в ТОП-5 регионах.
Можно наращивать долю платных донаций в регоинах-лидерах и расширять объем маркетинговых инвестиций в Югре для роста охвата

*/


--Задача: Изучить динамику общего количества донаций в месяц за 2022 и 2023 годы.

SELECT COUNT(DISTINCT id) AS "Количество донаций", 
	DATE_TRUNC('month', donation_date)::date AS "Дата донации"
FROM donorsearch.donation_anon
WHERE EXTRACT(YEAR FROM donation_date) BETWEEN '2022' AND '2023'
GROUP BY 2
ORDER BY 2
/*
Выводы: 
Максимальное количество донаций(3523) зафиксировано в марте 2023 года, а минимальное(1509) в ноября 2023 года.

-- В 2022 году наблюдается устойчивый рост активности доноров в течение года за исключением небольших спадов в мае и июне.
-- В 2023 году наблюдается спад активности доноров в середине и конце года по сравнению с началом года.
-- В оба года наблюдаются пики активности в весенние месяцы март и апрель.

-- Рекомендации:
-- Увеличить маркетинговые и рекламные кампании в летние месяцы, чтобы компенсировать снижение активности доноров.
-- Провести дополнительные акции и мероприятия в конце года (октябрь-ноябрь), чтобы увеличить количество донаций.
-- Проводить регулярные кампании по привлечению доноров в течение всего года, с особыми акцентами на периоды снижения активности.


*/


--Задача: Определить наиболее активных доноров в системе, учитывая только данные о зарегистрированных и подтвержденных донациях.

SELECT DISTINCT ad.id "Идентификатор пользователя", 
	COUNT(da.id) "Количество подтвержденных донаций"
FROM donorsearch.user_anon_data AS ad 
	JOIN donorsearch.donation_anon AS da ON ad.id = da.user_id
WHERE donation_status = 'Принята' AND confirmed_donations > 0
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10
/*
 * Выводы: 
Наибольшее количество донаций (361) зарегистрировано у пользователя 235 391. 
У ТОП-10 пользователей количество подтвержденных донаций было выше 200. Можно ориентироваться на этот уровень при разработке системы лояльности
*/


-- Задачи: Разделить пользователей на группы, посчитать количество доноров и долю почетных доноров
SELECT 	
	CASE
		WHEN EXTRACT(YEAR FROM AGE(current_date, birth_date)) <= 18 THEN 'Менее 18'
		WHEN EXTRACT(YEAR FROM AGE(current_date, birth_date)) BETWEEN 18 AND 25 THEN '18-25'
		WHEN EXTRACT(YEAR FROM AGE(current_date, birth_date)) BETWEEN 26 AND 35 THEN '26-35'
		WHEN EXTRACT(YEAR FROM AGE(current_date, birth_date)) BETWEEN 36 AND 45 THEN '36-45'
		WHEN EXTRACT(YEAR FROM AGE(current_date, birth_date)) > 45 THEN '45+'
		ELSE 'Возраст не указан'
	END AS age_type,
COUNT(id) AS total_donors,
COUNT(id) FILTER (WHERE honorary_donor is not null) AS "Количество почетных доноров",
ROUND(100.0 * COUNT(id) FILTER (WHERE honorary_donor is not null) / COUNT(id), 2) AS "Доля почетных доноров"
FROM donorsearch.user_anon_data uad
GROUP BY 1
ORDER BY 2 DESC,3 DESC

/*
 * Выводы: 
У основной доли пользователей не указан возраст, что ограничивает возможность аналитики.
Наибольшее количество доноров среди тех, кто указал возраст - доноры в возрасте 26-35 лет. 
У аудитории 36-45 лет около 18% почетных доноров, что является максимальным значением среди других возрастов.
Учитывая, что около 1167 доноров попали в категорию менее 18 лет нужно перепровить корректность заполнения анкет.

*/


--Задача: Оценить, как система бонусов влияет на зарегистрированные в системе донации.

-- Создаем CTE, в котором подготовим показатели для анализа
WITH active_user AS(
SELECT uad.id,
uad.confirmed_donations,
COALESCE(uab.user_bonus_count, 0) AS user_bonus_count
FROM donorsearch.user_anon_data uad LEFT JOIN donorsearch.user_anon_bonus uab ON uad.id = uab.user_id
)
-- В основной таблице используем категоризацию по наличию бонусов
SELECT CASE
	WHEN user_bonus_count > 0
		THEN 'Получили бонус'
	ELSE 'Не получили бонус'
END AS "Тип",
	COUNT(id) AS "Всего пользователей",
	ROUND(AVG(confirmed_donations), 2) AS "Среднее количество донаций"
FROM active_user
GROUP BY 1
/*
 * Выводы: 
Основная доля пользователей не получили бонусы
У пользователей которые получили бонус среднее количество донаций было выше.
Дополнительно можно исследовать механику начисления бонусов, чтобы учесть действительно ли мотивируют бонусы или наоборот, у человека бонус получен за 
высокое количество донаций.
*/


--Исследовать вовлечение новых доноров через социальные сети. Узнать, сколько по каким каналам пришло доноров, и среднее количество донаций по каждому каналу.
SELECT
	 CASE 
	 WHEN autho_tg THEN 'TG'
	 WHEN autho_vk THEN 'VK'
	 WHEN autho_ok THEN 'OK'
	 WHEN autho_yandex THEN 'Yandex'
	 WHEN autho_google THEN 'Google'
	 ELSE 'Не привязана соцсеть'
	 END AS "social",
	 COUNT(id) total_users, 
	 ROUND(AVG(uad.confirmed_donations),2) avg_donations
FROM donorsearch.user_anon_data uad
GROUP BY 1
ORDER BY 2 DESC
/*
 * Выводы: 
Наибольшее количество пользователей верифицировались с помощью VK.
Наибольшее количество средних донаций было у пользователей авторизованных с помощью Телеграм. При этом количество таких пользователей было минимальным.
Наименьшее количество донаций было от пользователей пришедших с Одноклассников

Можно тестировать расширение охвата в Телеграме и Яндексе, т.к эти площадки показали наибольшее количество средних донаций, но проигрывают другим
по объему пользователей.
*/



--Задача: Сравнить активность однократных доноров со средней активностью повторных доноров.
--WITH one AS (
SELECT 
COUNT(DISTINCT id) AS total_users,
ROUND(AVG(confirmed_donations),2) AS avg_donations, 
		CASE 
		WHEN confirmed_donations = 1 THEN 'One-time'
		WHEN confirmed_donations > 1 THEN 'Repeat'
		END AS type
FROM donorsearch.user_anon_data uad
WHERE confirmed_donations > 0
GROUP BY 3
/*
 * Выводы: 
Учитывая среднее количество донаций у повторных доноров, значимой точкой ростой является перевод пользователей с одной донацией в статус повторных.
Для этого можно использовать ретаргетинговые сценарии для веб и мобильного трафика.
*/

--Задача: Сравнить данные о планируемых донациях с фактическими данными, чтобы оценить эффективность планирования.
SELECT 
 	dp.donation_type ,
 	COUNT(uad.user_id) AS fact_donations,
	COUNT(dp.user_id) AS plan_donations,
    ROUND(COUNT(uad.user_id)::numeric / COUNT(dp.user_id) * 100, 2) as success_rate -- Процент
FROM donorsearch.donation_plan dp 
LEFT JOIN donorsearch.donation_anon uad 
    ON uad.user_id = dp.user_id 
    AND uad.donation_date = dp.donation_date -- Факт не раньше плана
    AND uad.donation_date <= dp.donation_date + 14 -- И не позже чем через 2 недели
GROUP BY 1
/*
 * Выводы: 
Доля успешных донаций для безвозмездных доноров составила 21,6%, а для платных - 13,2%.
Эту цифру можно использовать для прогнозирования запасов материала в центрах.
Если важно растить дисциплину, одной из гипотез будет рост конверсии в доходимость за счет настройки системы напоминаний для платных донаций.
*/


--Задача: Оценить скорость активации между датой регистрации пользователя и его первой фактической донацией (donation_date)
WITH main AS (SELECT 
	uad.id, 
	uad.registration_date,
	MIN(da.donation_date) AS first_donation
FROM donorsearch.user_anon_data uad 
	JOIN donorsearch.donation_anon da ON uad.id = da.user_id
WHERE 
	confirmed_donations > 0 
	AND uad.registration_date <= da.donation_date AND da.donation_date <= current_date
GROUP BY 1
)
SELECT id, 
AVG(first_donation - registration_date),
ROUND(AVG(first_donation - registration_date) OVER (),2) AS avg_days_before_donation
FROM main
GROUP BY id, main.first_donation, registration_date
ORDER BY 2 DESC

/*
 * Выводы: 
В среднем от регистрации до первой транзакции проходит 138 дней. Важно снижать эту метрику, если у проекта нет запаса прочности.
3163 пользователя дошли до первой донации дольше, чем в среднем по сервису. Вероятно для таких пользователей слабо сработала система онбординга. 
Важно выявить портрет такой аудитории и продумать персональные сценарии
*/




