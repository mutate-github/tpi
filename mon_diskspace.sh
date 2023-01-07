#!/bin/sh
set -f

BASEDIR=`dirname $0`
MAILS=`$BASEDIR/iniget.sh mon.ini mail script`
WMMAIL=`which $MAILS`
MPREFIX=`$BASEDIR/iniget.sh mon.ini mail prefix`
HOSTS=`$BASEDIR/iniget.sh mon.ini servers host`
ADMINS=`$BASEDIR/iniget.sh mon.ini admins email`
limPER=`$BASEDIR/iniget.sh mon.ini diskspace limitPER`
limGB=`$BASEDIR/iniget.sh mon.ini diskspace limitGB`

echo `date`" BEGIN ========================================================= "

for HOST in `echo "$HOSTS" | xargs -n1 echo`; do
  LOGF=$BASEDIR/log/mon_diskspace_${HOST}.log
  LOGF_HEAD=$BASEDIR/log/mon_diskspace_${HOST}_head.log
  OS=`ssh $HOST "uname"`
  case "$OS" in
   Linux)
          ssh "$HOST" "/sbin/ifconfig -a | awk '/inet .*ask/{print \$2}' | grep -v 127.0.0.1; echo ""; df -kP -x squashfs" > $LOGF
          PCT_=`cat $LOGF | grep -v "/mnt" | awk '/\/.*/{print $5" "int($4/1024/1024)}' | sed -e 's/%//' | sort -rn | head -1`
          PCT=`echo "$PCT_" | cut -d " " -f 1`
          FS_=`echo $PCT_ | cut -d " " -f 2`
          ;;
   AIX)   ssh "$HOST" "/usr/sbin/ifconfig -a | awk '/inet .*ask/{print \$2}' | grep -v 127.0.0.1; echo ""; df -k" > $LOGF
          cat $LOGF
          PCT_=`cat $LOGF | egrep -v "-" | awk '/\/.*/{print $4" "int($3/1024/1024)}' | sed -e 's/%//' | sort -rn | head -1`
          PCT=`echo "$PCT_" | cut -d " " -f 1`
          FS_=`echo $PCT_ | cut -d " " -f 2`
          ;;
  esac
  if [ "$PCT" -gt "$limPER" -a "$FS_" -lt "$limGB" ]; then
    echo "Fired: "$0"\n" > $LOGF_HEAD
    cat $LOGF_HEAD $LOGF | $WMMAIL -s "$MPREFIX DISKSPACE usage warning: $HOST (current: ${PCT} %, threshold: ${limPER} % and below ${limGB} Gb)" $ADMINS
  fi
  rm $LOGF $LOGF_HEAD
done

echo `date`" END ========================================================= "

