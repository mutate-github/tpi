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

for HOST in $(xargs -n1 echo <<< "$HOSTS"); do
  LOGF=$LOGDIR/mon_fs_${HOST}.log
  LOGF_FS_DIFF=$LOGDIR/mon_fs_${HOST}_diff.log
  LOGF_FS_OLD=$LOGDIR/mon_fs_${HOST}_old.log
  touch $LOGF_FS_OLD

  echo "HOST: "$HOST
  $BASEDIR/test_ssh.sh $CLIENT $HOST
  if [ "$?" -ne 0 ]; then echo "test_ssh.sh not return 0, continue"; continue; fi
  OS=$(ssh $HOST "uname")
  case "$OS" in
    Linux) ssh "$HOST" "df -kP -x squashfs | awk '{print \$1\" \"\$6}'" > $LOGF
        ;;
    AIX)   ssh "$HOST" "df -k | awk '{print \$1\" \"\$7}'" > $LOGF
        ;;
  esac
  diff $LOGF_FS_OLD $LOGF > $LOGF_FS_DIFF

  if [ -s $LOGF_FS_DIFF ]; then
      cat $LOGF_FS_DIFF | $BASEDIR/send_msg.sh $CONFIG $HOST NULL "FS mountpoint has been changed:"
  fi
  cp $LOGF $LOGF_FS_OLD
  rm $LOGF_FS_DIFF $LOGF
done

