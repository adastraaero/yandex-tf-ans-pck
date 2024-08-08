#!/bin/bash

count=0;
total=0; 

for i in $( awk '{ print $1; }' summ.txt )
   do 
     total=$(echo $total+$i | bc )
     ((count++))
   done
echo "scale=3; $total / $count" | bc
