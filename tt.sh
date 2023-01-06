#!/bin/bash

BASEDIR=`dirname $0`
HOST_DB_SET=`$BASEDIR/iniget.sh mon.ini backup host:db:set`
LEVEL0=`$BASEDIR/iniget.sh mon.ini backup level0 | sed 's/,/|/g'`
LEVEL1=`$BASEDIR/iniget.sh mon.ini backup level1 | sed 's/,/|/g'`
LEVEL2=`$BASEDIR/iniget.sh mon.ini backup level2 | sed 's/,/|/g'`

for HDS in `echo "$HOST_DB_SET" | xargs -n1 echo`; do

  RP=`echo $HDS | awk -F: '{print $4}' | sed 's/_/ /g'`
  shopt -s nocasematch
  if [[ "$RP" =~ "WINDOW" ]]; then DAYS="DAYS"; else DAYS=""; fi
  shopt -u nocasematch
  RP2=`echo $HDS | awk -F: '{print $5}'`
  RETENTION="CONFIGURE RETENTION POLICY TO "$RP" "$RP2" ${DAYS};"
  echo $RETENTION

done

