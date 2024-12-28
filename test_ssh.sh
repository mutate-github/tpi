#!/bin/bash
set -f

# Usage $0 CLIENT HOST

CLIENT="$1"
HOST="$2"
BASEDIR=$(dirname $0)
CONFIG="mon.ini"
if [ -n "$CLIENT" ]; then
  shift
  CONFIG=${CONFIG}.${CLIENT}
  if [ ! -s "$BASEDIR/$CONFIG" ]; then echo "Exiting... Config not found: "$CONFIG ; exit 128; fi
fi
# echo "Using config: ${CONFIG}"
LOGDIR="$BASEDIR/../log"
if [ ! -d "$LOGDIR" ]; then mkdir -p "$LOGDIR"; fi
SCRIPT_NAME=$(basename $0)

# echo "HOST="$HOST
TRG_FILE="$LOGDIR/${SCRIPT_NAME}_${HOST}.trg"
SSHConnectTimeout=$($BASEDIR/iniget.sh $CONFIG others SSHConnectTimeout)
[[ -z "$SSHConnectTimeout" ]] && SSHConnectTimeout=5
ssh -o ConnectTimeout=$SSHConnectTimeout -q $HOST exit
if [ "$?" -eq 0 ]; then
  if [ -f $TRG_FILE ]; then
    rm $TRG_FILE
    MSG="SSH responds"
    echo "" | $BASEDIR/send_msg.sh $CONFIG $HOST NULL "RECOVER: $MSG"
  fi
  exit 0
else
  MSG="SSH is NOT responding"
  if [ ! -f $TRG_FILE ]; then
    touch $TRG_FILE
    echo "$TRG_FILE is not exists. created. For host: $HOST $MSG"
    echo "" | $BASEDIR/send_msg.sh $CONFIG $HOST NULL "TRIGGER: $MSG" 
  else
    echo "$TRG_FILE is exists."
    REPEAT_MINUTES=$($BASEDIR/iniget.sh $CONFIG standby repeat_minutes)
    FF=$(find "$TRG_FILE" -mmin +$REPEAT_MINUTES 2>/dev/null | wc -l)
    if [ "$FF" -eq 1 ]; then
       echo $MSG | $BASEDIR/send_msg.sh $CONFIG $HOST $DB "- TRIGGER REPEAT: $(date +%H:%M:%S-%d/%m/%y) $MSG REPEAT_MINUTES=${REPEAT_MINUTES})"
       echo "TRIGGER REPEAT: $(date +%H:%M:%S-%d/%m/%y) $MSG REPEAT_MINUTES=${REPEAT_MINUTES}   host: "${HOST} " database: "${DB}
    fi
  fi
  exit 127
fi

