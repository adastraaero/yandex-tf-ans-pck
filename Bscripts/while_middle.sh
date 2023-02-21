#!/bin/bash
#This script was written to copy pictures that are made with a wbcam to a wb directory. Every five minutes a picture is taken.
#Every hour, a new directory is created, holding the images ofr that hour.Every day, a new directory is created containing 24 subdirectories.







PICSDIR=/var/www/mity/webcam

WEBDIR=/home/mity/pics


while true; do
	DATE=`date +%Y%m%d`
	HOUR=`date +%H`
	mkdir $WEBDIR/"$DATE"

	while [ $HOUR -ne '00' ]; do
		DESTDIR=$WEBDIR/"$DATE"/"$HOUR"
		mkdir "$DESTDIR"
		mv $PICSDIR/*.jpg "$DESTDIR"/
		sleep 3600
		HOUR=`date +%H`
	done
done

