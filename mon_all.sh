#!/bin/bash

CLIENT="$1"

BASEDIR=`dirname $0`
echo $BASEDIR
#cd $BASEDIR

echo ""
echo "START ALL MONITORING *****************************************************************************"`date`
echo "Monitor: ================================================================================ mon_ping_ssh.sh"
$BASEDIR/mon_ping_ssh.sh 
echo "Monitor: ================================================================================ mon_disksp.sh"
$BASEDIR/mon_disksp.sh
echo "Monitor: ================================================================================ mon_swap.sh"
$BASEDIR/mon_swap.sh
echo "Monitor: ================================================================================ mon_load.sh"
$BASEDIR/mon_load.sh
echo "Monitor: ================================================================================ mon_db.sh"
$BASEDIR/mon_db.sh $CLIENT
echo "Monitor: ================================================================================ mon_alert.sh"
$BASEDIR/mon_alert.sh
#$BASEDIR/mon_adrcial.sh
echo "Monitor: ================================================================================ mon_fra.sh"
$BASEDIR/mon_fra.sh
echo "Monitor: ================================================================================ mon_tbs.sh"
$BASEDIR/mon_tbs.sh
echo "Monitor: ================================================================================ mon_stb.sh"
$BASEDIR/mon_stb.sh
echo "Monitor: ================================================================================ mon_db_files.sh"
$BASEDIR/mon_db_files.sh
echo "Monitor: ================================================================================ mon_limsess.sh"
$BASEDIR/mon_limsess.sh
echo "Monitor: ================================================================================ mon_lock.sh"
$BASEDIR/mon_lock.sh
echo "FINISH ALL MONITORING ****************************************************************************"`date`

