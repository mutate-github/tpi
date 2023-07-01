#!/bin/bash
set -f

HOST=$1
DB=$2
shift
shift

msg=$(cat; echo x)
msg=${msg%x}

BASEDIR=`dirname $0`
LOGDIR="$BASEDIR/../log"
MAILS=`$BASEDIR/iniget.sh mon.ini mail script`
WMMAIL="$BASEDIR/$MAILS"
MPREFIX=`$BASEDIR/iniget.sh mon.ini mail prefix`
ADMINS=`$BASEDIR/iniget.sh mon.ini admins email`
HOSTS=`$BASEDIR/iniget.sh mon.ini telegram host:db:set`
NAME_PARENT=$(awk -F/ '{print $NF}' /proc/"$PPID"/cmdline)

# send msg to email
printf %s "$msg" | $WMMAIL -s "$MPREFIX $* ${HOST}/${DB}" $ADMINS 

# send msg to telegram bot
for HDS in $(echo $HOSTS | xargs -n1 echo); do
#beta:aisutf:mon_db.sh:mon_alert.sh:mon_diskspace.sh
  PHOST=$(echo $HDS | awk -F: '{print $1}')
  PDB=$(echo $HDS | awk -F: '{print $2}')
  if [ "$HOST" = "$PHOST" -a "$DB" = "$PDB" ]; then
    SCRIPTS=$(echo $HDS | awk -F: '{print substr($0,index($0,$3))}')
    SCRIPTS='+('$(echo $SCRIPTS | sed 's/:/|/g')')'

    shopt -s extglob
    case "$NAME_PARENT" in
      ${SCRIPTS})   printf %s "$msg" | $BASEDIR/ttlgrm_bot.sh $MPREFIX ${HOST} ${DB}  ;;
               *)   echo  "NAME_PARENT: "$NAME_PARENT" Not matched!"  ;;
    esac
  fi 
done

