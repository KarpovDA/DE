#Скрипт запонляет таблицу cards
import cx_Oracle
import pandas as pd
import easygui

ip = '79.164.32.101'
port = 1522
service_name = 'ORCL'
dsn = cx_Oracle.makedsn(ip, port, service_name=service_name)
user='student_karpov'
password= 'student_karpov'

con = cx_Oracle.connect(user, password, dsn)

cur=con.cursor()
file = easygui.fileopenbox("Выберите файл", filetypes= "*.csv")
df=pd.read_csv(file, delimiter=',')
df=df.fillna('nan')

df=df.to_numpy().tolist()

cur.executemany("insert into cards(Users, CARD_INDEX, Card_Brand, Card_Type, Card_Number, EXPIRES, CVV, Has_Chip, Cards_Issued, Credit_Limit, Acct_Open_Date, Year_PIN_last_Changed) values (:1, :2, :3, :4, :5, TO_DATE(:6, 'MM/YYYY'), :7, :8, :9, :10, TO_DATE(:11, 'MM/YYYY'), TO_DATE(:12, 'YYYY'))", df)
con.commit()
cur.close()
con.close()
