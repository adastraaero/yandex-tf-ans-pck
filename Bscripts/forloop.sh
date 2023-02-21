#!/bin/bash

for i in {1..1000}; do
	if [ $i -eq 5 ]; then
		echo "skipping 5"
		continue
	fi
	if [ $i -eq 7 ]; then
		echo "exiting loop at 7"
		break
	fi
	echo "[[[ number $i ]]]"
done
echo "Good bye !"
