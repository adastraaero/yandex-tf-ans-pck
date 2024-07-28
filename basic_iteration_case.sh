#!/bin/bash
echo how are you?
#считываем ответ в переменную
read BLAH
#переводим все строчные буквы в заглавные, т.к. case casesensitive
#вместо $() есть олдскул метод записи когда используются обратные кавычки,
#даннй метод используется для записи какой либо выполнимой команды,результат работы 
#резульатат работы которой будет использоваться в скрипте.

BLAH=$(echo $BLAH | tr a-z A-Z)
print $BLAH
#если ответ пустой то вызодим
[ -z $BLAH ] && exit 1

case $BLAH in
	GOOD)
	echo wonderful!
	;;
        BAD)
	echo life is pain
	;;
	*)
	echo I can\'t understand you bro
	;;
esac

