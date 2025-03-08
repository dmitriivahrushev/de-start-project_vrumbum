-- Этап 1. Создание и заполнение БД

-- Создал схемы raw_data (Сырой слой данных)
CREATE SCHEMA IF NOT EXISTS raw_data; 

-- Создал таблицу sales.
CREATE TABLE IF NOT EXISTS raw_data.sales (
    id int4,
    auto varchar(50),
    gasoline_consumption varchar(50),
    price float4,
    date varchar(50),
    person_name varchar(50),
    phone varchar(50),
    discount int4,
    brand_origin varchar(50) 
);

-- Заполнил таблицу sales данными через Импорт в DBeaver.
-- Создал схему car_shop и таблицы с данными.
CREATE SCHEMA IF NOT EXISTS car_shop;
CREATE TABLE IF NOT EXISTS car_shop.specifications(
    spec_id SERIAL PRIMARY KEY, -- Создание первичного ключа
    gasoline_consumption DECIMAL(3,1) NULL -- Подходит для хранения расхода топлива. Может принимать NULL т.к в в данных присутствуют Электромобили.
);

CREATE TABLE IF NOT EXISTS car_shop.car_models(
    model_id SERIAL PRIMARY KEY, -- Создание первичного ключа
    model VARCHAR(50), -- Обычно для моделей автомобилей достаточно длины около 30–50 символов.
    spec_id INTEGER, -- Тип данных для внешнего ключа (FOREIGN KEY) должен соответствовать типу данных первичного ключа (PRIMARY KEY) той таблицы, на которую он ссылается.
    CONSTRAINT spec_id_fkey FOREIGN KEY (spec_id) REFERENCES car_shop.specifications(spec_id) -- Создание внешнего ключа.   
);
CREATE TABLE IF NOT EXISTS car_shop.colors(
    color_id SERIAL PRIMARY KEY, -- Создание первичного ключа
    color VARCHAR(20) -- Самым длинным названием цвета на английском языке считается "Maximum Red" — это оттенок красного цвета, разработанный художником Стюартом Дэвисом в 1962 году. Название состоит из 11 букв, включая пробел.   
);

CREATE TABLE IF NOT EXISTS car_shop.manufacturer_countries(
    origin_id SERIAL PRIMARY KEY, -- Создание первичного ключа
    brand_origin VARCHAR(50) -- Подходит для названия страны производителя автомобилей.
);

CREATE TABLE IF NOT EXISTS car_shop.customers(
    customer_id SERIAL PRIMARY KEY, -- Создание первичного ключа
    name VARCHAR(50), -- Для имени и фамилии будет достаточно 50 символов.
    phone VARCHAR(50) -- В телефоне содержатся числа и буквы поэтому VARCHAR. 
);


CREATE TABLE IF NOT EXISTS car_shop.sales(
    sale_id SERIAL PRIMARY KEY, -- Создание первичного ключа
    price DECIMAL(10, 2), -- Использую этот тип данных, т.к важна точность расчетов.
    discount DECIMAL(5, 2), -- Использую этот тип данных, т.к важна точность расчетов.
    date TIMESTAMP, -- TIMESTAMP — это универсальный тип данных для хранения даты и времени.
    brand VARCHAR(50), -- Формат для хранения марки авто.
    origin_id INTEGER, -- Поле для внешнего ключа (FOREIGN KEY). 
    color_id INTEGER, -- Поле для внешнего ключа (FOREIGN KEY). 
    model_id INTEGER, -- Поле для внешнего ключа (FOREIGN KEY).
    customer_id INTEGER,-- Поле для внешнего ключа (FOREIGN KEY).
    CONSTRAINT customer_id_fkey FOREIGN KEY (customer_id) REFERENCES car_shop.customers(customer_id), -- Создание внешнего ключа.  
    CONSTRAINT origin_id_fkey FOREIGN KEY (origin_id) REFERENCES car_shop.manufacturer_countries(origin_id), -- Создание внешнего ключа. 
    CONSTRAINT color_id_fkey FOREIGN KEY (color_id) REFERENCES car_shop.colors(color_id), -- Создание внешнего ключа. 
    CONSTRAINT model_id_fkey FOREIGN KEY (model_id) REFERENCES car_shop.car_models(model_id) -- Создание внешнего ключа. 
);





-- Заполнение таблиц данными
INSERT INTO car_shop.specifications(gasoline_consumption)
SELECT DISTINCT
    CASE 
      WHEN 
        gasoline_consumption = 'null' OR gasoline_consumption IS NULL THEN NULL
        ELSE CAST(gasoline_consumption AS decimal(3,1)) 
    END AS gasoline_consumption
FROM raw_data.sales;


INSERT INTO car_shop.car_models(
    model,
    spec_id
)
SELECT DISTINCT
    CASE WHEN r.auto LIKE '%Tesla%' THEN TRIM(SPLIT_PART(r.auto, ' ', 2) || ' ' || SPLIT_PART(r.auto, ' ', 3) , ',') ELSE TRIM(SPLIT_PART(r.auto, ' ', 2), ',')END,
    s.spec_id
FROM raw_data.sales AS r
LEFT JOIN car_shop.specifications AS s ON (s.gasoline_consumption IS NOT DISTINCT FROM NULLIF(r.gasoline_consumption, 'null')::decimal(3,1));


INSERT INTO car_shop.colors(color)
SELECT DISTINCT SPLIT_PART(r.auto, ',', 2) AS color
FROM raw_data.sales AS r;


INSERT INTO car_shop.manufacturer_countries(brand_origin)
SELECT DISTINCT 
    CASE 
    	WHEN brand_origin = 'null' THEN 'Germany' -- Заметил, что в текущем датасете у Porsche отсутствует информация о стране-производителе, поэтому добавил Германию.
    	ELSE brand_origin
    END   
FROM raw_data.sales;


INSERT INTO car_shop.customers (name, phone)
SELECT DISTINCT person_name, phone
FROM raw_data.sales;


INSERT INTO car_shop.sales(
    price,
    discount,
    date,
    brand,
    color_id,
    model_id,
    origin_id,
    customer_id
)
SELECT 
    price,
    discount,
    date,
    SPLIT_PART(r.auto, ' ', 1) AS brand,
    color_id,
    model_id,
    origin_id,
    customer_id
FROM raw_data.sales AS r
LEFT JOIN car_shop.colors AS c ON c.color = SPLIT_PART(r.auto, ',', 2) 
LEFT JOIN car_shop.car_models AS cm ON cm.model = CASE WHEN r.auto LIKE '%Tesla%' THEN TRIM(SPLIT_PART(r.auto, ' ', 2) || ' ' || SPLIT_PART(r.auto, ' ', 3) , ',') ELSE TRIM(SPLIT_PART(r.auto, ' ', 2), ',')END
LEFT JOIN car_shop.manufacturer_countries AS mc ON mc.brand_origin = CASE WHEN r.brand_origin='null' THEN 'Germany' ELSE r.brand_origin END
LEFT JOIN car_shop.customers AS cus ON cus.name = r.person_name;


-- Этап 2. Создание выборок

---- Задание 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра `gasoline_consumption`.
SELECT 
    ROUND(
        (
            COUNT(CASE WHEN s.gasoline_consumption IS NULL THEN 1 END)::DECIMAL /
            COUNT(c.model_id)
        ) * 100,
        0
    ) AS electric_cars_percentage
FROM car_shop.car_models c
LEFT JOIN car_shop.specifications s ON c.spec_id = s.spec_id;
---- Задание 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.
SELECT
    brand AS brand_name,
    EXTRACT(YEAR FROM date) AS year,
    AVG(price) AS price_avg
FROM car_shop.sales
GROUP BY brand, date
ORDER BY brand ASC, date ASC; 
---- Задание 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.
SELECT
    EXTRACT(MONTH FROM date) AS month,
    EXTRACT(YEAR FROM date) AS year,
    ROUND(AVG(price), 2) AS price_avg
FROM car_shop.sales
GROUP BY month, year
ORDER BY month ASC;
---- Задание 4. Напишите запрос, который выведет список купленных машин у каждого пользователя.
SELECT name AS person, STRING_AGG(brand, ',') AS cars
FROM car_shop.sales
JOIN car_shop.car_models m USING(model_id)
JOIN car_shop.customers c USING(customer_id)
GROUP BY name;
---- Задание 5. Напишите запрос, который покажет количество всех пользователей из США.
SELECT COUNT(name) AS persons_from_usa_count
FROM car_shop.customers
WHERE phone LIKE '+1%';
---- Задание 6. Напишите запрос, который вернёт самую большую и самую маленькую цену
---- продажи автомобиля с разбивкой по стране без учёта скидки. 
---- Цена в колонке price дана с учётом скидки.
SELECT 
    mc.brand_origin, 
    MAX(price - discount ) AS price_max, 
    MIN(price - discount) AS price_min
FROM car_shop.sales AS s
JOIN car_shop.manufacturer_countries AS mc USING(origin_id)
GROUP BY mc.brand_origin;
