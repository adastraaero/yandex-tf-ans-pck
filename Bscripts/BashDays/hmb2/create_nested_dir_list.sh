#!/bin/bash
##Скрипт создаёт дерево каталогов из файла dirlist.txt
##После создаёт в каждом каталоге 2 файла bashdays1.txt и bashdays2.txt.
##После ждёт 10 сек и проводит замену файла bashdays2.txt на linuxfactory.txt.
## {} - подставляет полное имя найденного файла.
## f%bashdays2.txt - возвращает содержимое переменной с кратчайшим вхождением подстроки.


mkdir -p $(cat dirlist.txt)

for i in $(cat dirlist.txt)
do
  touch $i/bashdays1.txt
  touch $i/bashdays2.txt
done


sleep 10

find . -depth -name "bashdays2.txt" -exec sh -c 'f="{}"; mv -- "$f" "${f%bashdays2.txt}linuxfactory.txt"' \;
