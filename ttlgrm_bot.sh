#!/bin/bash
set -f

# usage: echo "body message" | ttlgrm_bot.sh config MSG_FRM_SRV1 HOST1 DB1

CONFIG=$1
MPREFIX=$2
HOST=$3
DB=$4
shift
shift
shift
shift
ALL=$*

msg=$(cat; echo x)
msg=${msg%x}

BASEDIR=$(dirname $0)
TLGRM_CMD=$($BASEDIR/iniget.sh $CONFIG telegram cmd)
TLGRM_CHT=$($BASEDIR/iniget.sh $CONFIG telegram chat_id)
$TLGRM_CMD mark0 $TLGRM_CHT "sender: \`${MPREFIX} ${HOST}/${DB} ${ALL}\`
\`\`\`
${msg} \`\`\`"

