#!/bin/bash
set -f
# for case +(...|...)
shopt -s extglob

CONFIG="$1"
shift

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
MAILS=$($BASEDIR/iniget.sh $CONFIG mail script)
WMMAIL="$BASEDIR/$MAILS"
MPREFIX=$($BASEDIR/iniget.sh $CONFIG mail prefix)
ADMINS=$($BASEDIR/iniget.sh $CONFIG admins email)
MMHOSTS=$($BASEDIR/iniget.sh $CONFIG mail host:db:set)
TGHOSTS=$($BASEDIR/iniget.sh $CONFIG telegram host:db:set)
#NAME_PARENT=$(awk -F/ '{print $NF}' /proc/"$PPID"/cmdline)
NAME_PARENT=$(awk -F/ '{print $NF}' /proc/"$PPID"/comm)
echo "send_msg.sh NAME_PARENT: "$NAME_PARENT
echo "send_msg.sh comm: "$(cat /proc/$PPID/comm)

send_email()
{ echo "send_msg.sh WMMAIL: "$WMMAIL ; printf %s "$msg" | $WMMAIL -s "$MPREFIX ${HOST}/${DB} ${ALL}" $ADMINS ; }

check_script_and_send_email()
{
case "$NAME_PARENT" in
  ${SCRIPTS})   send_email ;;
           *)   if [[ "${SCRIPTS}" =~ "%" ]]; then echo "MM ALL SCRIPTS!"; send_email ; fi  ;;
esac
}

send_tlgrm()
{ printf %s "send_tlgrm_MSG: $msg" | head -15; printf %s "$msg" | head -15 | $BASEDIR/ttlgrm_bot.sh $CONFIG $MPREFIX $HOST $DB $ALL ; }

check_script_and_send_tlgrm()
{
echo "send_msg.sh NAME_PARENT: "$NAME_PARENT
echo "send_msg.sh SCRIPTS: "$SCRIPTS
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
# printf %s "$msg" | $BASEDIR/ttlgrm_bot.sh $CONFIG $MPREFIX $HOST $DB $ALL
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
                    "$DB")   echo "TG DB: "$DB ; check_script_and_send_tlgrm ; break ;;
                    *)    echo "TG ALL DATABASES! " ; check_script_and_send_tlgrm ;;
                  esac
                  ;;
       '%')       echo "TG ALL HOSTS! "; check_script_and_send_tlgrm ; break ;;
    esac
  fi
done


