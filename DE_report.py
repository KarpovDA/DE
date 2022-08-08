#Мини скрипт с небольшим интерфейсом, который принимает две даты и делает отчет в за этот период времени
#Файл(report.csv) создается в том же месте где скрипт, креды прятать не стал для простоты(и так в общем доступе)
#Реализовал проверку формата вводимых данных для исключений инъекций.
#Если формат даты не совпадает с YYYY-MM-DD, то скрипт закрывается
import cx_Oracle
import pandas as pd
from easygui import *
import re
import sys

ip = '79.164.32.101'
port = 1522
service_name = 'ORCL'
dsn = cx_Oracle.makedsn(ip, port, service_name=service_name)
user='student_karpov'
password= 'student_karpov'

con = cx_Oracle.connect(user, password, dsn)

cur=con.cursor()



msg = 'Пожалуйста, введите дату начала и конца отчетного периода'
title = 'Отчет по мошенническими действиями'
fieldNames = ["Дата начала отчета в формате YYYY-MM-DD", "Дата конца отчета в формате YYYY-MM-DD"]
fieldValues = multenterbox(msg, title, fieldNames)
d_start=fieldValues[0]
d_end=fieldValues[1]


for date in fieldValues:
    pattern = re.compile("^\d\d\d\d-\d\d-\d\d$")
    if pattern.match(date) == None:
        sys.exit()





request=f'''WITH t  AS (
SELECT /*+ PARALLEL (8) */ TRANSACTION_time, CARD, users, merchant_city FROM TRANSACTIONS
WHERE merchant_city != 'ONLINE'
AND TO_DATE('{d_start}', 'YYYY-MM-DD') < TRANSACTION_time AND  TRANSACTION_time < TO_DATE('{d_end}', 'YYYY-MM-DD'))
SELECT /*+ PARALLEL (8) */    MAX(t2.TRANSACTION_TIME) AS FRAUD_DT, t1.USERS AS Client_ID, 
		'different cities' AS FRAUD_TYPE, sysdate AS REPORT_DT 
FROM t t1
INNER JOIN t t2 ON 0<=(t2.TRANSACTION_time-t1.TRANSACTION_time) 
			AND (t2.TRANSACTION_time-t1.TRANSACTION_time)<=1 
			AND t1.users=t2.USERs 
			AND t1.CARD=t2.CARD
			AND t1.merchant_city<>t2.merchant_city
GROUP BY t1.TRANSACTION_time, t1.MERCHANT_CITY, t1.USERS,t1.CARD
UNION 
SELECT /*+ PARALLEL (8) */  MAX(TRANSACTION_TIME) AS FRAUD_DT, t.USERS AS Client_ID,
							'expired card' AS FRAUD_TYPE, sysdate AS REPORT_DT 
FROM  t
JOIN CARDS c ON t.USERs=c.Users AND  t.card=c.CARD_INDEX 
WHERE TRANSACTION_time>expires
GROUP BY t.USERS'''

cur.execute(request)
report = cur.fetchall()
df=pd.DataFrame(report)
df.to_csv('./report1.csv', sep=',', header=['FRAUD_DT','Client_ID','FRAUD_TYPE','REPORT_DT'])

cur.close()
con.close()
