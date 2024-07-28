#!/bin/bash

array=(one two there four [5]=five)

#Показываем размера массива * - ссылается на все элемнты массива, # - считает эти элементы
echo "Array size: ${#array[*]}"


# - Выводит все значения в массиве:wq:wq
echo "Array items:"
for item in ${array[*]}
do
	printf " %s\n" $item
done

echo " Array indexes:"
for index in ${!array[*]}
do
	printf " %d\n" $index
done


echo "Array items and index:"
for index in ${!array[*]}
do
	printf "%4d: %s\n" $index ${array[$index]}
done
