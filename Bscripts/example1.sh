#!/bin/bash
if test -z $1 || [ -z $2 ]; then
	echo "This script requires 2 arguments, got $#"
else
	echo "At least 2 variables are set"
fi

if [[ $1 > $2 ]]; then
	echo "1st argument is bigger than 2nd"
elif [[ $1 < $2 ]]; then
	echo "2nd arguemnt is bigger than 1st"
else
	echo "arguments are equal"
fi
