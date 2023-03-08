#!/bin/bash
read -p "kek:" myvar
if [ $myvar -lt 10 ]
then 
	echo "ok"
else 
	echo "no"
fi
