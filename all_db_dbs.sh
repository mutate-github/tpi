#!/bin/bash

lst="$*"

if [ "$#" -eq 0 ]; then
  echo "This script execute some commands or sql\script on remote server for all databases" 
  echo "Usage: $0 [server]"
fi

if [ -z "$lst" ]; then
  :
fi

BASEDIR=`dirname $0`
LOGDIR="$BASEDIR/../log"
if [ ! -d "$LOGDIR" ]; then mkdir -p "$LOGDIR"; fi
WRTPI="$BASEDIR/rtpi"
SET_ENV_F="$BASEDIR/set_env"
SET_ENV=$(cat $SET_ENV_F)
SCRIPT_NAME="$BASEDIR/exec_one_all_db_$$.sh"

echo "================================================================================="

for srv in $lst; do
  echo $svr
  SSHConnectTimeout=7
  [[ -z "$SSHConnectTimeout" ]] && SSHConnectTimeout=5
  ssh -o ConnectTimeout=$SSHConnectTimeout -q $srv exit
  if [ "$?" -eq 0 ]; then

  $WRTPI $srv | awk -F" ora_pmon_" '/ ora_pmon_/{print $2}' |  while read sid; do
      echo "SERVER: "$srv ", DB: "$sid

      $WRTPI $srv $sid size maxext

#cat <<EOFF >  $SCRIPT_NAME
##!/bin/bash
#set -f
#sid=\$1
#$SET_ENV
#sqlplus -s '/ as sysdba' <<EOS
#set lines 230
#column name for a30
#column value for a90
#select name, value from v\$diag_info;
#EOFF
#       cat $SCRIPT_NAME | ssh $srv "/bin/bash -s $sid"
#       rm $SCRIPT_NAME
       echo "================================================================================="
  done
  else
    echo "Not answered host: "$srv
  fi
done


