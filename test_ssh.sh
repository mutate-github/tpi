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
    echo "" | $BASEDIR/send_msg.sh $CONFIG $HOST NULL "RECOVER: On $HOST $MSG"
  fi
  exit 0
else
  if [ ! -f $TRG_FILE ]; then
    touch $TRG_FILE
    MSG="SSH not responding"
    echo "$TRG_FILE is not exists. created. For host: $HOST $MSG"
    echo "" | $BASEDIR/send_msg.sh $CONFIG $HOST NULL "TRIGGER: On $HOST $MSG" 
  else
    echo "$TRG_FILE is exists. Skip for host: $HOST"
  fi
  exit 127
fi

