#!/bin/bash


echo -n "Do you like cold Beer? [yes/no]:"
read answer
case $answer in
	[Yy] | [Yy][Ee][Ss] )
		echo "That's right"
		;;
	[Nn] | [Nn][Oo] )
		echo ":(";
		exit 1
		;;
	*) echo "Enter Y[es] or N[o]"
		;;
esac