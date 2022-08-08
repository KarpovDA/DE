--создание РК в таблицу transactions
create unique  index transaction_pk_idx on transactions(transaction_time, users, card) local parallel 8 nologging;
create index transaction_city_idx on transactions(merchant_city) local parallel 8 nologging;

alter table TRANSACTIONS 
add constraint TRANSACTIONS_PK 
primary key (transaction_time, users, card) 
using index transaction_pk_idx novalidate;



-- строит отчет с мошеннические транзакциями обоих типов
-- в первой части транзаекции совершенные в разных городах в течении дня
-- для примера выбран промежуток между 2018-01-01 и 2018-01-02
WITH t  AS (
SELECT /*+ PARALLEL (8) */ TRANSACTION_time, CARD, users, merchant_city FROM TRANSACTIONS
WHERE merchant_city != 'ONLINE'
AND TO_DATE('2018-01-01', 'YYYY-MM-DD') < TRANSACTION_time AND  TRANSACTION_time < TO_DATE('2018-01-02', 'YYYY-MM-DD'))
SELECT /*+ PARALLEL (8) */    MAX(t2.TRANSACTION_TIME) AS FRAUD_DT, t1.USERS AS Client_ID, 
		'different cities' AS FRAUD_TYPE, sysdate AS REPORT_DT 
FROM t t1
INNER JOIN t t2 ON 0<=(t2.TRANSACTION_time-t1.TRANSACTION_time) 
			AND (t2.TRANSACTION_time-t1.TRANSACTION_time)<=1 
			AND t1.users=t2.USERs 
			AND t1.CARD=t2.CARD
			AND t1.merchant_city<>t2.merchant_city
GROUP BY t1.TRANSACTION_time, t1.MERCHANT_CITY, t1.USERS, t1.CARD
UNION 
-- во второй части транзакции, которые совершались по просроченным картам
SELECT /*+ PARALLEL (8) */  MAX(TRANSACTION_TIME) AS FRAUD_DT, t.USERS AS Client_ID,
							'expired card' AS FRAUD_TYPE, sysdate AS REPORT_DT 
FROM  t
JOIN CARDS c ON t.USERs=c.Users AND  t.card=c.CARD_INDEX 
WHERE TRANSACTION_time>expires
GROUP BY t.USERS

