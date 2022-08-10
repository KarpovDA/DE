-- если записей нет то добавит апись "01.01.1800 00:00:00"
insert into meta_increment
select to_timestamp('01.01.1800 00:00:00', 'dd/mm/yyyy HH24:MI:SS')
from dual
where (select count(*) from meta_increment) = 0;


--INSERT транзакций совершенных в одно время с одлной карты одного юзеора в таблицу TRANSACTIONS_BAD
INSERT /*+ APPEND */ /*+ PARALLEL (8) */ INTO TRANSACTIONS_BAD (TRANSACTION_TIME, Users, CARD, AMOUNT, Use_Chip, 
							  Merchant_Name, Merchant_City, Merchant_State, ZIP, 
							  MCC, ERR)
					  SELECT TRANSACTION_TIME, Users, CARD, AMOUNT, Use_Chip, Merchant_Name, Merchant_City, Merchant_State, ZIP, MCC, ERR 
		FROM STG_TRANSACTION 
		WHERE (TRANSACTION_TIME, USERS, CARD) IN (
					SELECT TRANSACTION_TIME, USERS, CARD FROM  STG_TRANSACTION
					GROUP BY TRANSACTION_TIME, USERS, CARD
					HAVING count(ID) > 1);	

					
--INSERT хороших транзакций с датой больше или равной чем последняя дата тразнакции			  
INSERT /*+ APPEND */ /*+ PARALLEL (8) */ INTO TRANSACTIONS (TRANSACTION_TIME, Users, CARD, AMOUNT, Use_Chip, 
							  Merchant_Name, Merchant_City, Merchant_State, ZIP, 
							  MCC, ERR)
					  SELECT TRANSACTION_TIME, Users, CARD, AMOUNT, Use_Chip, Merchant_Name, Merchant_City, Merchant_State, ZIP, MCC, ERR 
		FROM STG_TRANSACTION 
		WHERE id IN (
					SELECT MAX(ID) FROM  STG_TRANSACTION
					GROUP BY TRANSACTION_TIME, USERS, CARD
					HAVING count(ID) = 1)
				AND TRANSACTION_TIME > (SELECT max_date FROM meta_increment);
				
							  
							  
					
--UPDATE или INSERT только тех данных которых нет в основной таблице.				
merge /*+ APPEND */ /*+ PARALLEL (8) */ into TRANSACTIONS tr
USING (
		SELECT TRANSACTION_TIME, Users, CARD, AMOUNT, Use_Chip, Merchant_Name, Merchant_City, Merchant_State, ZIP, MCC, ERR 
		FROM STG_TRANSACTION 
		WHERE id IN (
					SELECT MAX(ID) FROM  STG_TRANSACTION
					GROUP BY TRANSACTION_TIME, USERS, CARD
					HAVING count(ID) = 1)
				AND TRANSACTION_TIME <= (SELECT max_date FROM meta_increment)
MINUS 
SELECT TRANSACTION_TIME, Users, CARD, AMOUNT, Use_Chip, Merchant_Name, Merchant_City, Merchant_State, ZIP, MCC, ERR  FROM TRANSACTIONS ) stg_tr
ON (stg_tr.TRANSACTION_TIME = tr.TRANSACTION_TIME AND stg_tr.USERS=tr.USERS AND stg_tr.CARD=tr.CARD)
when matched then update SET 
							tr.AMOUNT=stg_tr.AMOUNT, tr.Use_Chip=stg_tr.Use_Chip, tr.Merchant_Name=stg_tr.Merchant_Name,
							tr.Merchant_City=stg_tr.Merchant_City, tr.Merchant_State=stg_tr.Merchant_State, tr.ZIP=stg_tr.ZIP,
							tr.MCC=stg_tr.MCC, tr.ERR=stg_tr.ERR
when not matched then insert (tr.TRANSACTION_TIME, tr.Users, tr.CARD, tr.AMOUNT, tr.Use_Chip, 
							  tr.Merchant_Name, tr.Merchant_City, tr.Merchant_State, tr.ZIP, 
							  tr.MCC, tr.ERR)
					  VALUES (stg_tr.TRANSACTION_TIME, stg_tr.Users, stg_tr.CARD, stg_tr.AMOUNT, stg_tr.Use_Chip, 
							  stg_tr.Merchant_Name, stg_tr.Merchant_City, stg_tr.Merchant_State, stg_tr.ZIP, 
							  stg_tr.MCC, stg_tr.ERR);
							  
							  
							 

--Обновление последней даты транзакции в таблицу с методанными
update meta_increment set max_date = (
        select coalesce((
            select max(TRANSACTION_TIME) 
            from STG_TRANSACTION ), max_date) 
        from meta_increment);
 
--Очистка таблицы
TRUNCATE TABLE STG_TRANSACTION;






	
