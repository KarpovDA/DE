#Файл который преобразовывает файл CSV (изменяет формат даты и добавляет 12ое значение в 11ое)
import pandas as pd
import easygui
file = easygui.fileopenbox("Выберите файл", filetypes= "*.csv")

# В некоторых строчках при чтении определяется один дополнительый стоблец, так как ошибки в поле Err записыавются через ","

file1 = open(file, 'r')
Lines = file1.read().splitlines()
csv=[]
for line in Lines[1:]:
    line=line.split(',')
    if len(line)>11:
        line[10]=line[10]+' '+line.pop(11)
    line[0]=line[0][:-4]
    csv.append(line)
df = pd.DataFrame(csv)
df.to_csv('!!!'+file, sep=',')

