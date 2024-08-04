#!/bin/bash
#This script may be useful whe your git host has downtime, and instead of manualy typing git pull multiple times
#until the host is online, you can run the script once.It will try to pull the repository until it is successful.
#The script will print "Waiting for the git host..." and sleep for one second until the git host goes online.
#Once the repository is pulled, it will print "The git repository is pulled"
until git pull &> /dev/null
do
	echo "Whaiting for the git host ..."
	sleep 1
done


echo -e "\nThe git repository is pulled."

