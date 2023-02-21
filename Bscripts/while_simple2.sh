#!/bin/bash
file=/etc/passwd

while IFS= read -r line; do
	echo $line
done < "$file"
