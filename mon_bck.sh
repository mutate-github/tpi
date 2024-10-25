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
HOST_DB_SET=$($BASEDIR/iniget.sh $CONFIG backup host:db:set)
hours_since_lvl0=$($BASEDIR/iniget.sh $CONFIG backup hours_since_lvl0)
hours_since_lvl1=$($BASEDIR/iniget.sh $CONFIG backup hours_since_lvl1)
hours_since_arch=$($BASEDIR/iniget.sh $CONFIG backup hours_since_arch)
hours_since_ctrl=$($BASEDIR/iniget.sh $CONFIG backup hours_since_ctrl)

for HOST in $(xargs -n1 echo <<< "$HOSTS"); do
  echo "HOST="$HOST
  $BASEDIR/test_ssh.sh $CLIENT $HOST
  if [ "$?" -ne 0 ]; then echo "test_ssh.sh not return 0, continue"; continue; fi
  DBS=$($BASEDIR/iniget.sh $CONFIG $HOST db)
  for DB in $(xargs -n1 echo <<< "$DBS"); do
    echo "DB="$DB
    for HDS in $(xargs -n1 echo <<< $HOST_DB_SET); do
      BHOST=$(awk -F: '{print $1}' <<< $HDS)
      BDB=$(awk -F: '{print $2}' <<< $HDS)
      if [[ $HOST = $BHOST && $DB = $BDB ]]; then
        hours=($($WRTPI $HOST $DB rman last | awk -v DB=$DB 'BEGIN{IGNORECASE=1}/^.+[0-9] .+[0-9] .+[0-9] .+[0-9] .+[0-9] .+[0-9]$/{ if ($0 ~ DB) print }'))
        LAST_FULL="${hours[1]}"
        LAST_LEV0="${hours[2]}"
        LAST_LEV1="${hours[3]}"
        LAST_BCK="${hours[4]}"
        LAST_ARCH="${hours[5]}"
        LAST_CTRL="${hours[6]}"

        echo "LF: $LAST_FULL  L0: $LAST_LEV0  L1: $LAST_LEV1  LB: $LAST_BCK  LA:$LAST_ARCH LC: $LAST_CTRL " 
        echo "HSL0: $hours_since_lvl0  HSL1: $hours_since_lvl1  HSARCH: $hours_since_arch  HSCTRL: $hours_since_ctrl"

        LAST_LEV0=$( [[ $LAST_FULL > $LAST_LEV0 ]] && echo $LAST_FULL || echo $LAST_LEV0 )
        echo "LAST_LEV0: "$LAST_LEV0
        TRG_FILE_LVL0="$LOGDIR/mon_bck_${HOST}_${DB}_LVL0.trg"
        TRG_FILE_LVL1="$LOGDIR/mon_bck_${HOST}_${DB}_LVL1.trg"
        TRG_FILE_ARCH="$LOGDIR/mon_bck_${HOST}_${DB}_ARCH.trg"
        TRG_FILE_CTRL="$LOGDIR/mon_bck_${HOST}_${DB}_CTRL.trg"
        if [ ! -f "$TRG_FILE_LVL0" ]; then
           [[ "$LAST_LEV0" -ge "$hours_since_lvl0" ]] && (touch "$TRG_FILE_LVL0"; echo "$LAST_LEV0 -ge $hours_since_lvl0" | $BASEDIR/send_msg.sh $CONFIG $HOST $DB "TRIGER: there was no level0 backup for $hours_since_lvl0 hours")
        else
           [[ "$LAST_LEV0" -lt "$hours_since_lvl0" ]] && (rm "$TRG_FILE_LVL0"; echo "$LAST_LEV0 -lt $hours_since_lvl0" | $BASEDIR/send_msg.sh $CONFIG $HOST $DB "RECOVER: there was no level0 backup for $hours_since_lvl0 hours")
        fi

        if [ ! -f "$TRG_FILE_LVL1" ]; then
           [[ "$LAST_LEV1" -ge "$hours_since_lvl1" ]] && (touch "$TRG_FILE_LVL1"; echo "$LAST_LEV1 -ge $hours_since_lvl1" | $BASEDIR/send_msg.sh $CONFIG $HOST $DB "TRIGER: there was no level1 backup for $hours_since_lvl1 hours")
        else
           [[ "$LAST_LEV1" -lt "$hours_since_lvl1" ]] && (rm "$TRG_FILE_LVL1"; echo "$LAST_LEV1 -lt $hours_since_lvl1" | $BASEDIR/send_msg.sh $CONFIG $HOST $DB "RECOVER: there was no level1 backup for $hours_since_lvl1 hours")
        fi

        if [ ! -f "$TRG_FILE_ARCH" ]; then
           [[ "$LAST_ARCH" -ge "$hours_since_arch" ]] && (touch "$TRG_FILE_ARCH"; echo "$LAST_ARCH -ge $hours_since_arch" | $BASEDIR/send_msg.sh $CONFIG $HOST $DB "TRIGER: there was no archivelogs backup for $hours_since_arch hours")
        else
           [[ "$LAST_ARCH" -lt "$hours_since_arch" ]] && (rm "$TRG_FILE_ARCH"; echo "$LAST_ARCH -lt $hours_since_arch" | $BASEDIR/send_msg.sh $CONFIG $HOST $DB "RECOVER: there was no archivelogs backup for $hours_since_arch hours")
        fi

        if [ ! -f "$TRG_FILE_CTRL" ]; then
           [[ "$LAST_CTRL" -ge "$hours_since_ctrl" ]] && (touch "$TRG_FILE_CTRL"; echo "$LAST_CTRL -ge $hours_since_ctrl" | $BASEDIR/send_msg.sh $CONFIG $HOST $DB "TRIGER: there was no controlfile backup for $hours_since_ctrl hours")
        else
           [[ "$LAST_CTRL" -lt "$hours_since_ctrl" ]] && (rm "$TRG_FILE_CTRL"; echo "$LAST_CTRL -lt $hours_since_ctrl" | $BASEDIR/send_msg.sh $CONFIG $HOST $DB "RECOVER: there was no controlfile backup for $hours_since_ctrl hours")
        fi
     fi
    done
  done
done
#NAME       LAST_FULL  LAST_LEV0  LAST_LEV1   LAST_BCK  LAST_ARCH  LAST_CTRL
#MPRD              -1        111         11         11          1          1

#[backup]
#hours_since_lvl0=120
#hours_since_lvl1=120
#hours_since_arch=4
#hours_since_ctrl=4
#host:db:set=kikdb02:EPS:u15:REDUNDANCY:1:nocatalog:0

