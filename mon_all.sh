#!/bin/bash

BASEDIR=`dirname $0`
echo $BASEDIR
#cd $BASEDIR

echo ""
echo "START ALL MONITORING *****************************************************************************"`date`
echo "Monitor: ================================================================================ mon_ping_ssh.sh"
$BASEDIR/mon_ping_ssh.sh
echo "Monitor: ================================================================================ mon_diskspace.sh"
$BASEDIR/mon_diskspace.sh
echo "Monitor: ================================================================================ mon_db.sh"
$BASEDIR/mon_db.sh
echo "Monitor: ================================================================================ mon_alert.sh"
$BASEDIR/mon_alert.sh
#$BASEDIR/mon_adrci_alert.sh
echo "Monitor: ================================================================================ mon_fra.sh"
$BASEDIR/mon_fra.sh
echo "Monitor: ================================================================================ mon_tbs.sh"
$BASEDIR/mon_tbs.sh
echo "Monitor: ================================================================================ mon_stb.sh"
$BASEDIR/mon_stb.sh
echo "Monitor: ================================================================================ mon_db_files.sh"
$BASEDIR/mon_db_files.sh
echo "Monitor: ================================================================================ mon_processes_sessions.sh"
$BASEDIR/mon_processes_sessions.sh
echo "FINISH ALL MONITORING ****************************************************************************"`date`

