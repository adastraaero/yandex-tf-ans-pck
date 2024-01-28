#!/bin/bash
#скрипт выводит аргумент на экран
#если аргумента нет он его просит ввести

if [ -f $1 ]; then
	echo please provide an argument
	read ARG
else
	ARG=$1
fi

echo your argument was $ARG
