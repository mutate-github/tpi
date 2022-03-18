#!/bin/sh

#export PROMPT_COMMAND='PS1=`echo "\n\[\e[0;33m\][\D{%d.%m.%Y %H:%M:%S}] \[\e[01;31m\]\u@\h:\$ORACLE_SID \[\e[1;34m\]\w\n\$ \[\e[0;32m\]\[\e[0m\]"`'
#alias rtpi='~/oracle12client/run_tpi.sh'

# . /home/oracle/.dbs_alias
. /etc/profile.d/00-dbs-aliases.sh

P1_=$1
shift
args=$*
# args=`echo $args | tr '$' '~'`
args=$(echo $args | sed  's|\$|\\$|g')
wtpi=`which tpi`

# echo "host: "$P1_
# echo "args: "$args
# alias | grep "$P1_"

case "$P1_" in
 s-dtln-wmsdb*|db06.wms.korablik.ru)
   cat $wtpi | eval $P1_ "sudo -i -u oracle /bin/sh -s $args"
   ;;
 storgco|ikb)
   $wtpi $P1_ $args
   ;;
 [0-9]*) 
   cat $wtpi | ssh $P1_ "/bin/sh -s $args"
   ;;
 *) 
   cat $wtpi | eval $P1_ '/bin/sh -s $args'
   ;;
esac

exit
#######################################################

host=$1
HST=$host
# HST=`awk '$2=="'$host'"{print $1}' /app/start/etc/hosts`
# if [ "$HST" = "" ]; then
#  HST=$host
# fi
shift
args=$*

case $host in
askona*|192.168.1.132|192.168.1.131) username=grid ;;
*) username=oracle ;;
esac

cat ~/oracle12client/tpi | ssh $username@$HST "/bin/sh -s $args"

exit

