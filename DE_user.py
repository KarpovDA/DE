#Скрипт запонляет таблицу users
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
df=pd.read_csv(file, delimiter=',')
df=df.fillna('nan')
df=df.to_numpy().tolist()
for lst in df:
   if lst[7] == 'nan':
       lst[7] = None

cur.executemany("insert into users (Person, Current_Age, Retirement_Age, Birth_Year, Birth_Month, Gender, Address, Apartment, City,State, Zipcode, Latitude, Longitude, Per_Capita_Income_Zipcode, Yearly_Income_Person, Total_Debt, FICO_Score, NUM_CREDIT_CARDS) values (:1, :2, :3, TO_DATE( :4, 'YYYY' ) , TO_DATE(:5, 'MM'), :6, :7, :8, :9, :10, :11, :12, :13, :14, :15, :16, :17, :18)", df)
con.commit()
cur.close()
con.close()
