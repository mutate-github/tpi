#!/bin/bash

CLIENT=$1

BASEDIR=`dirname $0`
TLGRM_CMD=`$BASEDIR/iniget.sh mon.ini.$CLIENT telegram cmd`
TLGRM_CHT=`$BASEDIR/iniget.sh mon.ini.$CLIENT telegram chat_id`
$TLGRM_CMD mark0 $TLGRM_CHT "sender: $(hostname)
\`${*} \`"


