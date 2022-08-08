#Заполняет таблицу STG_TRANSACTION
import cx_Oracle
import pandas as pd
import easygui


ip = ''
port = 1522
service_name = 'ORCL'
dsn = cx_Oracle.makedsn(ip, port, service_name=service_name)
user=''
password= ''

con = cx_Oracle.connect(user, password, dsn)

cur=con.cursor()
file = easygui.fileopenbox("Выберите файл", filetypes= "*.csv")
df=pd.read_csv(file , delimiter=',', error_bad_lines=False)


df=df.fillna('nan')
df=df.to_numpy().tolist()
for lst in df:
    for i in range(len(lst)):
        if lst[i] =='nan':
            lst[i]= None
print(len(df))


cur.executemany("insert /*+ APPEND */ /*+ PARALLEL (8) */  into STG_TRANSACTION (ID, TRANSACTION_TIME, Users, CARD, AMOUNT, Use_Chip, Merchant_Name, Merchant_City, Merchant_State, ZIP, MCC, ERR) values (:1, TO_DATE(:2, 'YYYY-MM-DD HH24:MI:SS'), :3, :4, :5, :6, :7, :8, :9, :10, :11, :12)", df)
con.commit()                                                                                                                              #'DD.MM.YYYY HH24:MI:SS'    YYYY-MM-DD HH24:MI:SS.FF3

cur.close()
con.close()


