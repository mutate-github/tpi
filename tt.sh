#!/bin/bash

BASEDIR=`dirname $0`
HOST_DB_SET=`$BASEDIR/iniget.sh mon.ini backup host:db:set | tail -1`

echo $HOST_DB_SET


CATALOG=`echo $HOST_DB_SET | awk -F: '{print $6}'`

echo $CATALOG

  shopt -s nocasematch
  if [[ "$CATALOG" = NOcatalog ]]; then
     echo OK
  fi
  shopt -u nocasematch



