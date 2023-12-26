#!/bin/sh
set -f

BASEDIR=`dirname $0`
LOGDIR="$BASEDIR/../log"
if [ ! -d "$LOGDIR" ]; then mkdir -p "$LOGDIR"; fi
#MAILS=`$BASEDIR/iniget.sh mon.ini mail script`
#WMMAIL="$BASEDIR/$MAILS"
#MPREFIX=`$BASEDIR/iniget.sh mon.ini mail prefix`
HOSTS=`$BASEDIR/iniget.sh mon.ini servers host`
#ADMINS=`$BASEDIR/iniget.sh mon.ini admins email`
limPER=`$BASEDIR/iniget.sh mon.ini swap limitPER`


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
    cat $LOGF_HEAD $LOGF | $BASEDIR/send_msg.sh $HOST NULL "Swap usage warning: (current: ${PCT} %, threshold: ${limPER} %)"
    rm $LOGF_HEAD
  fi
  rm $LOGF
done


