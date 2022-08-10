DROP TABLE TRANSACTIONS;

DROP TABLE TRANSACTION_HIST;

DROP TABLE TRANSACTIONS_BAD;

DROP TABLE STG_TRANSACTION;

DROP TABLE cards;

DROP TABLE PAN;

DROP TABLE users;

DROP TABLE meta_increment;

-- таблицу с юзреами
CREATE TABLE users
	(
		USERS integer GENERATED BY DEFAULT AS IDENTITY (START WITH 0 MINVALUE 0) NOT NULL PRIMARY KEY,
		Person VARCHAR2(100) NOT NULL,
		Current_Age int NOT NULL,
		Retirement_Age int NOT NULL,
		Birth_Year DATE NOT NULL,
		Birth_Month DATE NOT NULL,
		Gender VARCHAR2(100) NOT NULL,
		Address VARCHAR2(100) NOT NULL,
		Apartment FLOAT(64),
		City VARCHAR2(100) NOT NULL,
		State VARCHAR2(100) NOT NULL,
		Zipcode int  NOT NULL,
		Latitude FLOAT(64) NOT NULL,
		Longitude FLOAT(64) NOT NULL,
		Per_Capita_Income_Zipcode VARCHAR2(100) NOT NULL,
		Yearly_Income_Person VARCHAR2(100) NOT NULL,
		Total_Debt VARCHAR2(100) NOT NULL,
		FICO_Score int NOT NULL,
		NUM_CREDIT_CARDS int NOT NULL,
		data_ins DATE DEFAULT sysdate,
		data_upd DATE DEFAULT NULL
		);


-- Тригер добавляет дату апдейта при апдейте
CREATE OR REPLACE TRIGGER users_trg_upd BEFORE UPDATE ON users FOR EACH ROW
BEGIN
	:NEW.data_upd := sysdate;
END;
	





--таблица с картами
CREATE TABLE cards
(
		Users integer NOT NULL,
		CARD_INDEX  integer NOT NULL,
		Card_Brand VARCHAR2(100) NOT NULL,
		Card_Type VARCHAR2(100) NOT NULL,
		Card_Number VARCHAR2(20) NOT NULL unique,
		EXPIRES DATE NOT NULL,
		CVV INTEGER NOT NULL,
		Has_Chip VARCHAR2(100) NOT NULL,
		Cards_Issued integer NOT NULL,
		Credit_Limit VARCHAR2(100) NOT NULL,
		Acct_Open_Date DATE NOT NULL,
		Year_PIN_last_Changed Date NOT NULL,
		CONSTRAINT cards_pk PRIMARY KEY (Users, CARD_INDEX),
		data_ins DATE DEFAULT sysdate,
		data_upd DATE DEFAULT NULL,
		constraint cards_fk
		foreign key (Users) references users
		);
--Тригер добавляет дату апдейта при апдейте
CREATE OR REPLACE TRIGGER cards_trg_upd BEFORE UPDATE ON cards FOR EACH ROW
BEGIN
	:NEW.data_upd := sysdate;
END;




-- Таблци соотвествия PAN-DPAN
CREATE TABLE PAN 
(
	CARD_NUMBER_DPAN VARCHAR2(20) NOT NULL unique,
	CARD_NUMBER_PAN  integer NOT NULL PRIMARY KEY
	);


--при инсерте добавляет соотвествие PAN-DPAN в таблицу PAN и на лету шифрует данные для таблицы cards
CREATE OR REPLACE TRIGGER card_pan_trg_ins BEFORE INSERT ON cards FOR EACH ROW
DECLARE
	default_card_num PAN.CARD_NUMBER_PAN%TYPE;
BEGIN
	default_card_num:=:NEW.Card_Number;
	IF LENGTH(:NEW.Card_Number) < 16 THEN :NEW.Card_Number := REPLACE (:NEW.Card_Number,SUBSTR(:NEW.Card_Number, 7, 5), 'XXXXX');
		ELSE :NEW.Card_Number := REPLACE (:NEW.Card_Number,SUBSTR(:NEW.Card_Number, 7, 6), 'XXXXXX');
	END IF;
	INSERT  INTO PAN (CARD_NUMBER_DPAN, CARD_NUMBER_PAN)
	VALUES (:NEW.Card_Number, default_card_num);
END;


-- при апдейте номера карты добавляет в таблицу PAN новое соотвествие, если при апдейте нет нвого номера карты то тригер не срабатывает
CREATE OR REPLACE TRIGGER card_pan_trg_upd BEFORE UPDATE ON cards FOR EACH ROW
DECLARE
	default_card_num PAN.CARD_NUMBER_PAN%TYPE;
BEGIN
	default_card_num:=:NEW.Card_Number;
	IF LENGTH(:NEW.Card_Number) < 16 THEN :NEW.Card_Number := REPLACE (:NEW.Card_Number,SUBSTR(:NEW.Card_Number, 7, 5), 'XXXXX');
		ELSE :NEW.Card_Number := REPLACE (:NEW.Card_Number,SUBSTR(:NEW.Card_Number, 7, 6), 'XXXXXX');
	END IF;
	DELETE FROM PAN WHERE CARD_NUMBER_DPAN = :OLD.Card_Number;
	DBMS_OUTPUT.put_line(:OLD.Card_Number);
	INSERT  INTO PAN (CARD_NUMBER_DPAN, CARD_NUMBER_PAN)
	VALUES (:NEW.Card_Number, default_card_num);
EXCEPTION
	WHEN INVALID_NUMBER
	THEN 
		NULL;
	WHEN VALUE_ERROR
	THEN 
		NULL;
END;

--при удалении строчки из таблицы cards улдаяет из таблицы PAN данные по номеру карты
CREATE OR REPLACE TRIGGER card_pan_trg_del BEFORE DELETE ON cards FOR EACH ROW
BEGIN
	DBMS_OUTPUT.put_line(:OLD.Card_Number);
	DELETE FROM PAN WHERE CARD_NUMBER_DPAN = :OLD.Card_Number;
END;




--Staging Table для транзакций

CREATE TABLE STG_TRANSACTION
(	
	ID integer,
	TRANSACTION_TIME DATE,
	Users integer,
	CARD integer,
	AMOUNT float,
	Use_Chip varchar(100),
	Merchant_Name integer,
	Merchant_City varchar2(40),
	Merchant_State varchar2(40),
	ZIP integer,
	MCC integer,
	ERR varchar(100));
	--partition by range (TRANSACTION_TIME)
	--INTERVAL(NUMTOYMINTERVAL (1,'MONTH'))
	--(PARTITION FIRST VALUES LESS THAN (TO_DATE('2018-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS')))
	
	
	
-- отключение логировния 
ALTER TABLE STG_TRANSACTION NOLOGGING;



-- таблица для "плохих" транзакий. Если в одно время, по одной карте и по одному пользователю более одной транзакции, то данные
-- попадают в эту таблицу
CREATE TABLE TRANSACTIONS_BAD
(	
	ID integer,
	TRANSACTION_TIME DATE,
	Users integer,
	CARD integer,
	AMOUNT float,
	Use_Chip varchar(100),
	Merchant_Name integer,
	Merchant_City varchar2(40),
	Merchant_State varchar2(40),
	ZIP integer,
	MCC integer,
	ERR varchar(100)
	);
	

-- таблица с "хорошими транзакиями". Автосекционирование по месяцам. PK навешивается уже после того, как данные будут залиты для ускорения.
CREATE TABLE TRANSACTIONS
(	
	TRANSACTION_TIME DATE NOT NULL,
	Users integer NOT NULL,
	CARD integer NOT NULL,
	AMOUNT float NOT NULL,
	Use_Chip varchar(100) NOT NULL,
	Merchant_Name integer NOT NULL,
	Merchant_City varchar2(40) NOT NULL,
	Merchant_State varchar2(40),
	ZIP integer,
	MCC integer,
	ERR varchar(100),
	ins_time DATE DEFAULT sysdate,
	upd_time DATE DEFAULT NULL,
	CONSTRAINT fk_Users
    FOREIGN KEY (Users)
    REFERENCES Users(Users),
    CONSTRAINT fk_Cards
    FOREIGN KEY (USERS, CARD)
    REFERENCES CARDS(USERS, CARD_INDEX))
	partition by range (TRANSACTION_TIME)
	INTERVAL(NUMTOYMINTERVAL (1,'MONTH'))
	(PARTITION FIRST VALUES LESS THAN (TO_DATE('2018-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS'))
	);


    
ALTER TABLE TRANSACTIONS NOLOGGING;

ALTER SESSION ENABLE PARALLEL DML;



-- Историческая таблица транзакций
CREATE TABLE TRANSACTION_HIST
(	
	OPERATION varchar(3),
	TRANSACTION_TIME DATE,
	Users integer,
	CARD integer,
	AMOUNT float,
	Use_Chip varchar(100),
	Merchant_Name integer,
	Merchant_City varchar2(40),
	Merchant_State varchar2(40),
	ZIP integer,
	MCC integer,
	ERR varchar(100),
	start_time DATE DEFAULT sysdate,
	finish_time DATE DEFAULT NULL
	)
	partition by range (TRANSACTION_TIME)
	INTERVAL(NUMTOYMINTERVAL (1,'MONTH'))
	(PARTITION FIRST VALUES LESS THAN (TO_DATE('2018-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS'))
	);
	
ALTER TABLE TRANSACTION_HIST NOLOGGING;

--Тригер вносит запись в таблицу с историей при апдейте основной таблицы транзакций
CREATE OR REPLACE TRIGGER TRANSACTION_HIST_UPD BEFORE update ON TRANSACTIONS FOR EACH ROW 
BEGIN 
:NEW.UPD_TIME := sysdate;
	IF :OLD.upd_time IS NULL 
		THEN 	
			INSERT INTO TRANSACTION_HIST (operation, TRANSACTION_TIME, Users, CARD, AMOUNT, Use_Chip, Merchant_Name, Merchant_City, Merchant_State, ZIP, MCC, ERR, START_TIME, FINISH_TIME)
			VALUES ('upd',:OLD.TRANSACTION_TIME, :OLD.Users, :OLD.CARD, :OLD.AMOUNT, :OLD.Use_Chip, :OLD.Merchant_Name, :OLD.Merchant_City, :OLD.Merchant_State, :OLD.ZIP, :OLD.MCC, :OLD.ERR, :OLD.ins_time, sysdate);
		ELSE 
			INSERT INTO TRANSACTION_HIST (operation, TRANSACTION_TIME, Users, CARD, AMOUNT, Use_Chip, Merchant_Name, Merchant_City, Merchant_State, ZIP, MCC, ERR, START_TIME, FINISH_TIME)
			VALUES ('upd',:OLD.TRANSACTION_TIME, :OLD.Users, :OLD.CARD, :OLD.AMOUNT, :OLD.Use_Chip, :OLD.Merchant_Name, :OLD.Merchant_City, :OLD.Merchant_State, :OLD.ZIP, :OLD.MCC, :OLD.ERR, :OLD.upd_time, sysdate);
	END IF;
END;
	
--Тригер вносит запись в таблицу с историей при удалении из основной таблицы транзакций
CREATE OR REPLACE TRIGGER TRANSACTION_HIST_DEL BEFORE delete ON TRANSACTIONS FOR EACH ROW 
BEGIN 
	IF :OLD.upd_time IS NULL 
		THEN 	
			INSERT INTO TRANSACTION_HIST (operation, TRANSACTION_TIME, Users, CARD, AMOUNT, Use_Chip, Merchant_Name, Merchant_City, Merchant_State, ZIP, MCC, ERR, START_TIME, FINISH_TIME)
			VALUES ('upd',:OLD.TRANSACTION_TIME, :OLD.Users, :OLD.CARD, :OLD.AMOUNT, :OLD.Use_Chip, :OLD.Merchant_Name, :OLD.Merchant_City, :OLD.Merchant_State, :OLD.ZIP, :OLD.MCC, :OLD.ERR, :OLD.ins_time, sysdate);
	ELSE 
			INSERT INTO TRANSACTION_HIST (operation, TRANSACTION_TIME, Users, CARD, AMOUNT, Use_Chip, Merchant_Name, Merchant_City, Merchant_State, ZIP, MCC, ERR, START_TIME, FINISH_TIME)
			VALUES ('upd',:OLD.TRANSACTION_TIME, :OLD.Users, :OLD.CARD, :OLD.AMOUNT, :OLD.Use_Chip, :OLD.Merchant_Name, :OLD.Merchant_City, :OLD.Merchant_State, :OLD.ZIP, :OLD.MCC, :OLD.ERR, :OLD.upd_time, sysdate);
	END IF;
END;

-- таблица будет содерджать последнюю дату транзакции из  основной таблицы TRANSACTIONS
create table meta_increment
(max_date date
);


