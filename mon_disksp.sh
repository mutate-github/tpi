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
HOSTS=$($BASEDIR/iniget.sh $CONFIG servers host)
limPER=$($BASEDIR/iniget.sh $CONFIG diskspace limitPER)
limGB=$($BASEDIR/iniget.sh $CONFIG diskspace limitGB)

for HOST in $(xargs -n1 echo <<< "$HOSTS"); do
  LOGF=$LOGDIR/mon_diskspace_${HOST}.log
  LOGF_HEAD=$LOGDIR/mon_diskspace_${HOST}_head.log
  echo "HOST: "$HOST
  OS=$(ssh $HOST "uname")
  case "$OS" in
   Linux)
          ssh "$HOST" "/sbin/ifconfig -a | awk '/inet .*ask/{print \$2}' | grep -v 127.0.0.1; echo ""; df -kP -x squashfs" > $LOGF
          PCT_=$(cat $LOGF | grep -v "/mnt" | awk '/\/.*/{print $5" "int($4/1024/1024)}' | sed -e 's/%//' | sort -rn | head -1)
          PCT=$(echo "$PCT_" | cut -d " " -f 1)
          FS_=$(echo $PCT_ | cut -d " " -f 2)
          ;;
   AIX)   ssh "$HOST" "/usr/sbin/ifconfig -a | awk '/inet .*ask/{print \$2}' | grep -v 127.0.0.1; echo ""; df -k" > $LOGF
          cat $LOGF
          PCT_=$(cat $LOGF | egrep -v "-" | awk '/\/.*/{print $4" "int($3/1024/1024)}' | sed -e 's/%//' | sort -rn | head -1)
          PCT=$(echo "$PCT_" | cut -d " " -f 1)
          FS_=$(echo $PCT_ | cut -d " " -f 2)
          ;;
  esac
  if [ "$PCT" -gt "$limPER" -a "$FS_" -lt "$limGB" ]; then
    echo -e "Fired: "$0"\n" > $LOGF_HEAD
    cat $LOGF_HEAD $LOGF | $BASEDIR/send_msg.sh $CONFIG $HOST NULL "DISKSPACE usage warning: (current: ${PCT} %, threshold: ${limPER} % and below ${limGB} Gb)"
    rm $LOGF_HEAD
  fi
  rm $LOGF
done

