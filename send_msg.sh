#!/bin/bash
set -f
# for case +(...|...)
shopt -s extglob

HOST=$1
DB=$2
shift
shift
ALL=$*
echo "ALL: "$ALL

msg=$(cat; echo x)
msg=${msg%x}

BASEDIR=`dirname $0`
LOGDIR="$BASEDIR/../log"
if [ ! -d "$LOGDIR" ]; then mkdir -p "$LOGDIR"; fi
MAILS=`$BASEDIR/iniget.sh mon.ini mail script`
WMMAIL="$BASEDIR/$MAILS"
MPREFIX=`$BASEDIR/iniget.sh mon.ini mail prefix`
ADMINS=`$BASEDIR/iniget.sh mon.ini admins email`
MMHOSTS=`$BASEDIR/iniget.sh mon.ini mail host:db:set`
TGHOSTS=`$BASEDIR/iniget.sh mon.ini telegram host:db:set`
NAME_PARENT=$(awk -F/ '{print $NF}' /proc/"$PPID"/cmdline)

send_email()
{ printf %s "$msg" | $WMMAIL -s "$MPREFIX ${HOST}/${DB} ${ALL}" $ADMINS ; }

check_script_and_send_email()
{
case "$NAME_PARENT" in
  ${SCRIPTS})   send_email ;;
           *)   if [[ "${SCRIPTS}" =~ "%" ]]; then echo "MM ALL SCRIPTS!"; send_email ; fi  ;;
esac
}

send_tlgrm()
{ printf %s "$msg" | $BASEDIR/ttlgrm_bot.sh ${MPREFIX} ${HOST} ${DB} ${ALL} ; }

check_script_and_send_tlgrm()
{
case "$NAME_PARENT" in
  ${SCRIPTS})   send_tlgrm ;;
           *)   if [[ "${SCRIPTS}" =~ "%" ]]; then echo "TG ALL SCRIPTS! "; send_tlgrm ; fi  ;;
esac
}

# send msg to email
# printf %s "$msg" | $WMMAIL -s "$MPREFIX ${HOST}/${DB} ${ALL}" $ADMINS
for HDS in $(echo $MMHOSTS | xargs -n1 echo); do
#alpha:aisutf:%
#beta:aisutf:mon_db.sh:mon_alert.sh:mon_diskspace.sh
  PHOST=$(echo $HDS | awk -F: '{print $1}')
  PDB=$(echo $HDS | awk -F: '{print $2}')
  SCRIPTS=$(echo $HDS | cut -d':' -f3-)
  SCRIPTS='+('$(echo $SCRIPTS | sed 's/:/|/g')')'
  if [ "$PHOST" = "$HOST" -o "$PHOST" = "%" ]; then
    echo "BINGO: is my host in regestry mail: "$HOST
    shopt -s extglob
    case "$PHOST" in
       "$HOST")  case "$PDB" in
                   "$DB")  check_script_and_send_email ; break ;;
                   *)      echo "MM ALL DATABASES! " ; check_script_and_send_email ;;
                 esac
                 ;;
       '%')      echo "MM ALL HOSTS! "; check_script_and_send_email ; break ;;
    esac
  fi
done

# send msg to telegram bot
# printf %s "$msg" | $BASEDIR/ttlgrm_bot.sh ${MPREFIX} ${HOST} ${DB} ${ALL}
for HDS in $(echo $TGHOSTS | xargs -n1 echo); do
#alpha:aisutf:%
#beta:aisutf:mon_db.sh:mon_alert.sh:mon_diskspace.sh
  PHOST=$(echo $HDS | awk -F: '{print $1}')
  PDB=$(echo $HDS | awk -F: '{print $2}')
  SCRIPTS=$(echo $HDS | cut -d':' -f3-)
  SCRIPTS='+('$(echo $SCRIPTS | sed 's/:/|/g')')'
  if [ "$PHOST" = "$HOST" -o "$PHOST" = "%" ]; then
    echo "BINGO: is my host in regestry telegram: "$HOST
    shopt -s extglob
    case "$PHOST" in
       "$HOST")   case "$PDB" in
                    "$DB")  check_script_and_send_tlgrm ; break ;;
                    *)    echo "TG ALL DATABASES! " ; check_script_and_send_tlgrm ;;
                  esac
                  ;;
       '%')       echo "TG ALL HOSTS! "; check_script_and_send_tlgrm ; break ;;
    esac
  fi
done


