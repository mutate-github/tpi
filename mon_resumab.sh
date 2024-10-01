#!/bin/bash
set -f

CLIENT="$1"
BASEDIR=$(dirname $0)
CONFIG="mon.ini"
if [ -n "$CLIENT" ]; then
  shift
  CONFIG=${CONFIG}.${CLIENT}
  if [ ! -s "$BASEDIR/$CONFIG" ]; then echo "Exiting... Config not found: "$CONFIG ; exit 128; fi
fi
echo "Using config: ${CONFIG}"

LOGDIR="$BASEDIR/../log"
if [ ! -d "$LOGDIR" ]; then mkdir -p "$LOGDIR"; fi
WRTPI="$BASEDIR/rtpi"
HOSTS=$($BASEDIR/iniget.sh $CONFIG servers host)
SET_ENV_F="$BASEDIR/set_env"
SET_ENV=$(<$SET_ENV_F)

for HOST in $(xargs -n1 echo <<< "$HOSTS"); do
  echo "HOST="$HOST
  DBS=$($BASEDIR/iniget.sh $CONFIG $HOST db)
  for DB in $(xargs -n1 echo <<< "$DBS"); do
    echo "DB="$DB
    RCNT=$($WRTPI $HOST $DB resumable | awk '/RESUMABLE_COUNT/{f=1;getline;getline}f')
    RCNTLIM=$($BASEDIR/iniget.sh $CONFIG others resumable)

    if [[ -n "$RCNTLIM" && "$RCNT" -gt "$RCNTLIM" ]]; then
      echo "" | $BASEDIR/send_msg.sh $CONFIG $HOST $DB "RESUMABLE_COUNT sessions limit warning: (current: $RCNT, limit: $RCNTLIM)"
    fi
  done # DB
done # HOST

