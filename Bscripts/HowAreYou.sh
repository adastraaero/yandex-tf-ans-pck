#!/bin/bash
echo how are you?

read BLAH
BLASH='echo $BLAH | tr a-z A-Z'
# tr переводит ответ в верхний регистр
[ -z $BLAH ] && exit 1
# если ответ пустой то выходим

case $BLAH in
	GOOD)
		echo nice !
		;;
	BAD)
	echo too bad for you
	;;
*)
	echo I don\'t understand answer
	;;
esac
