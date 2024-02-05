#!/bin/bash
set -f
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
cft*|kik*|bd*|prov*)        [ -r ~/db12kik.env ] && source ~/db12kik.env ;;
EPS*|creditc)               [ -r ~/db12.env ] && source ~/db12.env ;;
KIKOPDR)                    [ -r ~/db11.env ] && source ~/db11.env ;;
jet|ja)                     [ -r /etc/profile.ora ] && source /etc/profile.ora ;;
aisutf*|unit*|crm)          [ -r ~/.ora_env ] && source ~/.ora_env ;;
askona*|aixtdb*|sbaskona)   [ -r ~/.profile ] && source ~/.profile ;;
egais*|GOLD506*)            [ -r ~/.bashrc ] && source ~/.bashrc ;;
unc*)                       [ -r ~/${sid}_setenv.sh ] && source ~/${sid}_setenv.sh ;;
# opndb)                    [ -r ~/BRSKDB_setenv.sh && source ~/BRSKDB_setenv.sh ; login_str="tal/tal@'(DESCRIPTION=(ADDRESS=(COMMUNITY=TCP.WORLD)(PROTOCOL=TCP)(HOST=172.16.104.36)(PORT=1525))(CONNECT_DATA=(SERVICE_NAME=opndb)))'" ;;
opndb*|obk*)                : ;;
INSIS*|insis*|alfa|ALFA)    : ;;
dbprod|dbprog)              : ;;
*) #        if [ -r ~/.bashrc ]; then . ~/.bashrc ; fi
   #        if [ -r ~/.bash_profile ]; then . ~/.bash_profile ; fi
   #        if [ -r ~/.profile ]; then . ~/.profile ; fi
   case $(uname | awk -F_ '{print $1}') in
      Linux)  [ -r ~/.bash_profile ] && source ~/.bash_profile
              rc=$(find . -maxdepth 1 -name "${sid}_setenv.sh" -print -quit)
              if [ -n "$rc" ]; then . ~/${sid}_setenv.sh ; fi
              ;;
      AIX)    [ -r ~/.profile ] && source ~/.profile
              [ -r ~/.bashrc ] && source ~/.bashrc
              ;;
      *)      ;;
   esac
;;
esac

export ORACLE_SID=$sid

VALUE=$(sqlplus -s '/as sysdba' <<'EOS'
set lines 250  heading off feedback off pagesize 0 trimspool on timing off
select value from v$system_parameter where name='diagnostic_dest';
EOS
)

echo "diagnostic_dest: "$VALUE
cd $VALUE

trc=$(echo "show homes;"  | adrci | grep 'diag/rdbms/.*/'$sid'$')
tns3=$(echo "show homes;"  | adrci | grep 'diag/tnslsnr/.*/')
echo "trc: "$trc
echo "tns3: "$tns3

echo "set home for diag/rdbms traces: "$trc
echo "set home for listener tns3: "$tns3
echo "age: "$age

for trc_ in $(echo $trc | xargs); do
  echo "purge diag/rdbms/ ALERT TRACE INCIDENT CDUMP: "$trc_
  adrci exec="set home $trc_ ; migrate schema"
  adrci exec="set home $trc_ ; purge -age $age -type ALERT"
  adrci exec="set home $trc_ ; purge -age $age -type TRACE"
  adrci exec="set home $trc_ ; purge -age $age -type INCIDENT"
  adrci exec="set home $trc_ ; purge -age $age -type CDUMP"
done

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
case $(uname | awk -F_ '{print $1}') in
  Linux)   find $VALUE  -type f -mtime +$audit -name "*.aud" | xargs -i -P20 rm {} ;;
  *)       find $VALUE  -type f -mtime +$audit -name "*.aud" -exec rm {} \; ;;
esac
