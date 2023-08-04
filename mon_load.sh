#!/bin/sh
set -f

BASEDIR=`dirname $0`
LOGDIR="$BASEDIR/../log"
#MAILS=`$BASEDIR/iniget.sh mon.ini mail script`
#WMMAIL="$BASEDIR/$MAILS"
#MPREFIX=`$BASEDIR/iniget.sh mon.ini mail prefix`
HOSTS=`$BASEDIR/iniget.sh mon.ini servers host`
#ADMINS=`$BASEDIR/iniget.sh mon.ini admins email`
limPER=`$BASEDIR/iniget.sh mon.ini load limitPER`


for HOST in `echo "$HOSTS" | xargs -n1 echo`; do
  LOGF=$LOGDIR/mon_swap_${HOST}.log
  LOGF_HEAD=$LOGDIR/mon_swap_${HOST}_head.log
  echo "HOST: "$HOST
  OS=`ssh $HOST "uname"`
  case "$OS" in
   Linux)
          ssh "$HOST" "cat /proc/loadavg | awk '{printf (\"%3.0f\", \$2)}'" > $LOGF
          PCT=$(head -1 $LOGF)
          ;;
   AIX)   ssh "$HOST" "lparstat 6 1 | tail -1 | awk '{printf (\"%3.0f\", \$7)}'" > $LOGF
          PCT=$(head -1 $LOGF)
          ;;
  esac
  if [ "$PCT" -ge "$limPER" ]; then
    echo -e "Fired: "$0"\n" > $LOGF_HEAD
    cat $LOGF_HEAD $LOGF | $BASEDIR/send_msg.sh $HOST NULL "Overall OS Load warning: (current: ${PCT} %, threshold: ${limPER} %)"
    rm $LOGF_HEAD
  fi
  rm $LOGF
done


