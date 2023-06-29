#!/bin/sh

BASEDIR=`dirname $0`
TLGRM_CMD=`$BASEDIR/iniget.sh mon.ini telegram cmd`
TLGRM_CHT=`$BASEDIR/iniget.sh mon.ini telegram chat_id`
$TLGRM_CMD mark0 $TLGRM_CHT "sender: $(hostname)
\`${*} \`"


