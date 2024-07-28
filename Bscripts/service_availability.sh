#/bin/bash
# script monitors service availability

#########################exit code documentation
# 3: mo argument provided
# 4: for service is not running
###############################################




# make sure that service name is provided as an argument
if [ -z $1 ]; then
	echo you need to provide service name when starting this script
	exit 3
else
	SERVICE=$1
fi
	

# run without stopping to do the monitoring task
#verify that $SERVICE is running
if ps aux | grep $SERVICE | grep -v grep | grep -v service_availability
then 
	echo all good
else
	echo \$SERVICE could not not be found as a process
	echo Make sure that \$SERVICE is running and try again
	echo 'The command ps aux | grep $SERVICE should show the service up and running'
	exit 4
fi


# monitor $SERVICE

while ps aux | grep $SERVICE | grep -v grep | grep -v service_availability
do
	sleep 10
done
# actions if services is failing 
#assuming that the service processname can be started with the service command
service $SERVICE start
logger service_availability: $SERVICE restarted
mail -s "service_availability: $SERVICE restarted at $(date +%d-%m-%Y %H:%M)" root < .
