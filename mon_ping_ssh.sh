#!/bin/sh
set -f

BASEDIR=`dirname $0`
#MAILS=`$BASEDIR/iniget.sh mon.ini mail script`
#WMMAIL="$BASEDIR/$MAILS"
#MPREFIX=`$BASEDIR/iniget.sh mon.ini mail prefix`
HOSTS=`$BASEDIR/iniget.sh mon.ini servers host`
#ADMINS=`$BASEDIR/iniget.sh mon.ini admins email`

for HOST in `echo "$HOSTS" | xargs -n1 echo`; do
  MSG=""
  ping -w3 -W 10 $HOST
  if [ $? -eq 0 ]; then
    ssh -q $HOST exit
    if [ $? -eq 0 ]; then
      :
    else MSG="SSH warning: "
    fi
  else MSG="PING warning: "
  fi
  if [ -n "$MSG" ]; then
#    echo "" | $WMMAIL -s "$MPREFIX $MSG host $HOST - not responding" $ADMINS
    echo "" | $BASEDIR/send_msg.sh $HOST $DB "$MSG host $HOST - not responding"
  fi
done

