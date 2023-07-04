#!/bin/bash
set -f

# usage: echo "body message" | ttlgrm_bot.sh MSG_FRM_SRV1 HOST1 DB1

MPREFIX=$1
HOST=$2
DB=$3
shift
shift
shift
ALL=$*

msg=$(cat; echo x)
msg=${msg%x}

BASEDIR=`dirname $0`
TLGRM_CMD=`$BASEDIR/iniget.sh mon.ini telegram cmd`
TLGRM_CHT=`$BASEDIR/iniget.sh mon.ini telegram chat_id`
$TLGRM_CMD mark0 $TLGRM_CHT "sender: \`${MPREFIX} ${HOST}/${DB} ${ALL}\`
\`${msg} \`"

