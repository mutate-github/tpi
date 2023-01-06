#!/bin/bash

BASEDIR=`dirname $0`
echo $BASEDIR
#cd $BASEDIR

$BASEDIR/mon_diskspace.sh
$BASEDIR/mon_tbs.sh
$BASEDIR/mon_stb.sh
$BASEDIR/mon_fra.sh
$BASEDIR/mon_alert.sh
#$BASEDIR/mon_adrci_alert.sh
$BASEDIR/mon_ping_ssh.sh
$BASEDIR/mon_db.sh

