#!/bin/sh
set -f

CLIENT="$1"
CONFIG="mon.ini"
if [ -n "$CLIENT" ]; then
  shift
  CONFIG=${CONFIG}.${CLIENT}
  if [ ! -s "$CONFIG" ]; then echo "Exiting... Config not found: "$CONFIG ; exit 128; fi
fi
echo "Using config: ${CONFIG}"

BASEDIR=`dirname $0`
HOSTS=`$BASEDIR/iniget.sh $CONFIG servers host`

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
    echo "" | $BASEDIR/send_msg.sh $CONFIG $HOST $DB "$MSG host $HOST - not responding"
  fi
done

