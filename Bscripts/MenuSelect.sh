#!/bin/bash

echo 'choose a directory: '
select dir in /bin /usr /etc
do
	#only continue if user has selected something
	if [ -n "$dir" ]
	then
		DIR=$dir
		echo you have selected $DIR
		export DIR
		break
	else
		echo invalid choice
	fi
done
