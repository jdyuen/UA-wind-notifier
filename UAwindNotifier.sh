#!/bin/bash
#
#
# This script checks the current windspeed at the University of Alberta EAS north campus weather station
# If the windspeed is within the set range, an email notification is sent.
# Ensure mailx is configured and working

# windspeed range for kite notifications in km/h
MAX_KPH=50
MIN_KPH=20

# max windspeed for badminton notifications in km/h
B_MAX_KPH=5
B_MIN_TEMP=15

#load saved variables from file
#determine working directory
DIR="$( cd "$( dirname "$0" )" && pwd )"
SAVEFILE="/tmp/windSaveFile.txt"
KITEMAILLIST="$DIR/mailListKite"
BMAILLIST="$DIR/mailListBadminton"
if [ -w $SAVEFILE ]; then
   . $SAVEFILE
fi
#write new save file
echo "TIME_LAST_WIND=$TIME_LAST_WIND" > $SAVEFILE
echo "TIME_LAST_B=$TIME_LAST_B" >> $SAVEFILE

#get weather from eas website
WEATHER="`wget -qO- http://easweb.eas.ualberta.ca/page/weather_stations`"
#parse windspeed and convert to km/h in integer
WIND_METERS_SEC="`echo $WEATHER | grep -oP "Wind speed:.{30}" | sed -n 's/.*>\([0-9]*\.[0-9]*\).*/\1/p'`"
WIND_KPH=$(awk "BEGIN{print $WIND_METERS_SEC*3.6}")
WIND_INT=${WIND_KPH/.*}
#parse wind direction
WIND_DIR="`echo $WEATHER | grep -oP "Wind direction:.{40}" | sed -n 's/.*>\([A-Za-z]*\)<.*/\1/p'`"
#parse temperature
TEMP="`echo $WEATHER | grep -oP "Temperature:.{30}" | sed -n 's/.*>\([0-9]*\.[0-9]*\).*/\1/p'`"
TEMP_INT=${TEMP/.*}

#get current conditions from Environment Canada (eg. Light Rain, Sunny, Cloudy)
ENVCAN="`wget -qO- http://www.weatheroffice.gc.ca/city/pages/ab-50_metric_e.html`"
CONDITIONS="`echo $ENVCAN | grep -oP "Condition:.{40}" | sed -n 's/.*<dd>\([A-Za-z ]*\)<.*/\1/p'`"
#is it raining?
RAINING="`echo $CONDITIONS | grep -icP "rain"`"

# check for time variables, calculate time since last notifications
# if variable doesn't exist, set equal to zero
if [ -z $TIME_LAST_WIND ]; then
   TIME_LAST_WIND=0
   echo "TIME_LAST_WIND=$TIME_LAST_WIND" >> $SAVEFILE
fi
if [ -z $TIME_LAST_B ]; then
   TIME_LAST_B=0
   echo "TIME_LAST_B=$TIME_LAST_B" >> $SAVEFILE
fi
TIME_ELAPSED=$(expr $(date +%s) - $TIME_LAST_WIND)
B_TIME_ELAPSED=$(expr $(date +%s) - $TIME_LAST_B)

#calulate change in windspeed
if [ -z $LAST_WIND ]; then
   DELTA_WIND=
fi

#echo message to stdout
date
echo "Current Conditions: $TEMP C, $CONDITIONS
Wind Speed: $WIND_INT km/h $WIND_DIR ($WIND_METERS_SEC m/s)"
echo "Time elapsed since last kite notification: $TIME_ELAPSED sec"
echo "Time elapsed since last badminton notification: $B_TIME_ELAPSED sec"

# if windspeed is in range and we haven't sent an email in a while, compose and send email
if [ $TIME_ELAPSED -ge 3600 -a $RAINING == 0 ]; then
   if [ $MIN_KPH -le $WIND_INT -a $WIND_INT -le $MAX_KPH ]; then
      #record the last time we sent an email
      TIME_LAST_WIND=$(date +%s)
      echo "TIME_LAST_WIND=$TIME_LAST_WIND" >> $SAVEFILE
      #email info
      SUBJECT="Conditions Ripe for Kite Flying!"
      MAILTO=`cat $KITEMAILLIST`
      EMAILMESSAGE='/tmp/windEmailMessage.txt'
      echo "It is $CONDITIONS, $TEMP C and the windspeed is $WIND_INT km/h $WIND_DIR, go fly a kite!" > $EMAILMESSAGE
#      echo "Current Conditions: $CONDITIONS" >> $EMAILMESSAGE
      
      #send email
      mailx -s "$SUBJECT" $MAILTO < $EMAILMESSAGE
      cat $EMAILMESSAGE
   fi
fi

# if windspeed for badminton is in range and we haven't sent an email in a while, compose and send email
if [ $B_TIME_ELAPSED -ge 3600 -a $RAINING == 0 ]; then
   if [ $WIND_INT -le $B_MAX_KPH -a $B_MIN_TEMP -le $TEMP_INT ]; then
      #record the last time we sent an email
      TIME_LAST_B=$(date +%s)
      echo "TIME_LAST_B=$TIME_LAST_B" >> $SAVEFILE
      #email info
      SUBJECT="Conditions Prime for Badminton!"
      MAILTO=`cat $BMAILLIST`
      EMAILMESSAGE='/tmp/windEmailMessage.txt'
      echo "It is $CONDITIONS, $TEMP C and the windspeed is $WIND_INT km/h $WIND_DIR, go play badminton!" > $EMAILMESSAGE
#      echo "Current Conditions: $CONDITIONS" >> $EMAILMESSAGE
      
      #send email
      mailx -s "$SUBJECT" $MAILTO < $EMAILMESSAGE
      cat $EMAILMESSAGE
   fi
fi

# save windspeed for next time
echo "LAST_WIND=$WIND_INT" >> $SAVEFILE
