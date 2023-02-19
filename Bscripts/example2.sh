#!/bin/bash
if (( $1 < 10)); then
	echo "argument is less than 10"
else
	echo "argument is more or equal to 10"
fi

(( 10 - $1 )); echo "Exit code of (( 10 - $1 )) is $?"

for (( i=$1; i>0; i-- )); do
	echo -n "$i"
done
echo
echo "Weird math resulted in $(( $1 + ($1*20) - ($1^22) ))"
