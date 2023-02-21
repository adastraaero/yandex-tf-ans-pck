#!/bin/bash
RND=$(($RANDOM % 3))
echo "Guess the number between 0 and 2"
read NUMBER
[ $NUMBER -gt 2 ] || [ $NUMBER -lt 0 ] && echo "No! You have to choose between 0 and 2"  && exit 123
[ $RND -ne $NUMBER ] && echo "Wrong! The number is $RND"  && exit 1
echo "You've guessed right"
