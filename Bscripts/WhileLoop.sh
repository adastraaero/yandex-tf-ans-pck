#!/bin/bash

LIMIT=19 # upper limit

echo
echo "Printing Numbers 1 trough 20 (but not 3 and 11)."

a=0

while [ $a -le "$LIMIT" ]
do
	a=$(($a+1))


if [ "$a" -eq 3 ] || [ "$a" -eq 11 ] #Excludes 3 and 11
then
	continue # Skip res of this particular loop iterations
fi

echo -n "$a " # This will not execute for 3 and 11.

done

# Exercise:
# Why does the loop print up to 20?

echo; echo

echo  Printing Numbers 1 trough 20, but something happens after 2.

#############################################################################

# Same loop, but substituting 'break' for 'continue'.

a=0

while [ "$a" -le "$LIMIT" ]
do
	a=$(($a+1))

	if [ "$a" -gt 2 ]
	then
		break  # Skip the entire loop
        fi
echo -n "$a "
done
echo; echo; echo

exit 0

