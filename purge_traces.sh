#!/bin/sh

# ps -ef | awk -F_ '/[p]mon/{print $NF}' | while read i; do ./purge_traces.sh $i; done
#
# usage purge_traces.sh $ORACLE_SID
# Talgat Mukhametshin dba.almaty@gmail.com
if [ "$1" = "" ]; then
    echo "Usage: $0 sid"
    exit
fi

sid=$1

# 3600  - 2.5 days
# 4320  - 3 days
# 5760  - 4 days
# 10080 - 7 days

age=1440         # min
audit=7          # days
size_lim=256M    # size limit for lsn.log

case "$sid" in
cft*|kik*|bd*|prov*)        . ~/db12kik.env ;;
EPS*|creditc)               . ~/db12.env ;;
KIKOPDR)                    . ~/db11.env ;;
jet|ja)                     . /etc/profile.ora ;;
aisutf*|unit*|crm)          . ~/.ora_env ;;
askona*|aixtdb*|sbaskona)   . ~/.profile ;;
egais*|GOLD506*)            . ~/.bashrc ;;
goldwhs)                    . ~/.bash_profile ;;
unc*)                       . ~/${sid}_setenv.sh ;;
goldwhs)                    . ~/.bash_profile ;;
# opndb)                      . ~/BRSKDB_setenv.sh ; login_str="tal/tal@'(DESCRIPTION=(ADDRESS=(COMMUNITY=TCP.WORLD)(PROTOCOL=TCP)(HOST=172.16.104.36)(PORT=1525))(CONNECT_DATA=(SERVICE_NAME=opndb)))'" ;;
opndb|obk)                  : ;;
*) #        if [ -f ~/.bashrc ]; then . ~/.bashrc ; fi
   #        if [ -f ~/.bash_profile ]; then . ~/.bash_profile ; fi
   #        if [ -f ~/.profile ]; then . ~/.profile ; fi
   case $(uname | awk -F_ '{print $1}') in
      Linux)  if [ -f ~/.bash_profile ]; then . ~/.bash_profile ; fi
              rc=$(find . -maxdepth 1 -name "${sid}_setenv.sh" -print -quit)
              if [ -n "$rc" ]; then . ~/${sid}_setenv.sh ; fi
              ;;
      AIX)    if [ -f ~/.profile ]; then . ~/.profile ; fi
              if [ -f ~/.bashrc ]; then . ~/.bashrc ; fi
              ;;
      *)      ;;
   esac
;;
esac

trc=$(echo "show homes;"  | adrci | grep 'diag/rdbms/.*/'$sid'$')
tns3=$(echo "show homes;"  | adrci | grep 'diag/tnslsnr/.*/')

echo "set home for diag/rdbms traces: "$trc
echo "set home for listener tns3: "$tns3
echo "age: "$age

for trc_ in $(echo $trc | xargs); do
  echo "purge diag/rdbms/ ALERT TRACE INCIDENT: "$trc_
  adrci exec="set home $trc_ ; migrate schema"
  adrci exec="set home $trc_ ; purge -age $age -type ALERT"
  adrci exec="set home $trc_ ; purge -age $age -type TRACE"
  adrci exec="set home $trc_ ; purge -age $age -type INCIDENT"
done

VALUE=$(sqlplus -s '/as sysdba' <<'EOS'
set lines 250  heading off feedback off pagesize 0 trimspool on
select value from v$system_parameter where name='diagnostic_dest';
EOS
)

echo "diagnostic_dest: "$VALUE

for tns3_ in $(echo $tns3 | xargs); do
  echo "purge listener ALERT TRACE: "$tns3_
  adrci exec="set home $tns3_ ; migrate schema"
  adrci exec="set home $tns3_ ; purge -age $age -type ALERT"
  adrci exec="set home $tns3_ ; purge -age $age -type TRACE"
  find $VALUE/$tns3_/trace -type f -name "*lsn*.log" -size +$size_lim
  find $VALUE/$tns3_/trace -type f -name "*lsn*.log" -size +$size_lim -exec /bin/bash -c 'echo > {}' \;
done

VALUE=$(sqlplus -S '/ as sysdba' <<'END'
  set pagesize 0 feedback off verify off heading off echo off timing off
  col value for a200
  select value from v$parameter where name='audit_file_dest';
END
)

echo "purge audit logs for $VALUE :"
find $VALUE  -type f -mtime +$audit -name "*.aud" | xargs -i -P20 rm {}
find $VALUE  -type f -mtime +$audit -name "*.aud" -exec rm {} \;