#!/bin/bash
set -f

CLIENT="$1"
BASEDIR=`dirname $0`
CONFIG="mon.ini"
if [ -n "$CLIENT" ]; then
  shift
  CONFIG=${CONFIG}.${CLIENT}
  if [ ! -s "$BASEDIR/$CONFIG" ]; then echo "Exiting... Config not found: "$CONFIG ; exit 128; fi
fi
echo "Using config: ${CONFIG}"

LOGDIR="$BASEDIR/../log"
if [ ! -d "$LOGDIR" ]; then mkdir -p "$LOGDIR"; fi
HOSTS=`$BASEDIR/iniget.sh $CONFIG servers host`
limPER=`$BASEDIR/iniget.sh $CONFIG swap limitPER`


for HOST in `echo "$HOSTS" | xargs -n1 echo`; do
  LOGF=$LOGDIR/mon_swap_${HOST}.log
  LOGF_HEAD=$LOGDIR/mon_swap_${HOST}_head.log
  echo "HOST: "$HOST
  OS=`ssh $HOST "uname"`
  case "$OS" in
   Linux)
          ssh "$HOST" "free | grep 'Swap' | awk '{t = \$2+1; u = \$3; printf (\"%3.0f\", u/(t/100))}'" > $LOGF
          PCT=$(head -1 $LOGF)
          ;;
   AIX)   ssh "$HOST" "lsps -s | tail +2  | cut -d% -f1 | awk '{printf \$2}'" > $LOGF
          PCT=$(head -1 $LOGF)
          ;;
  esac
  if [ "$PCT" -ge "$limPER" ]; then
    echo -e "Fired: "$0"\n" > $LOGF_HEAD
    cat $LOGF_HEAD $LOGF | $BASEDIR/send_msg.sh $CONFIG $HOST NULL "Swap usage warning: (current: ${PCT} %, threshold: ${limPER} %)"
    rm $LOGF_HEAD
  fi
  rm $LOGF
done


