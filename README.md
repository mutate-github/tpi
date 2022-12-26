Usage: ./tpi <DBSID> sess_id [p|ph <param>] | a(order by u m o l w) | lock | p  . | db [nls|option|properties] | health | oratop [h] | sga | pga | size [days] [ tbs [free] | temp | df [io|usage|lastseg [TABLESPACE]]|maxseg [TABLESPACE]|fra] | arch | redo [logs] | undo [recovery] | sesstat [STATNAME] | topseg | o . | s . | t . | i . | l . | c . | u . | invalid | profile | links | latch | bind [SQL] | pipe | longops [MESSAGE] [rman] | scheduler | job [OWNER] | get_ddl TYPE OBJECT OWNER | trace | alert | report ash/awr | corrupt [DBA (number)] [FB (file) (block)] | sql | ash | dhash | spm
-e a - all sessions | [access OBJECT] - active sessions which accessing OBJECT | SPID\SID\SERIAL# [p] [parameter_name] - session param info from V$SES_OPTIMIZER_ENV by [parameter_name]
p | ph [PARAMETER] [FALSE] | services | dir - instance parameters or hidden parameters, [FALSE] - only changed parameters, v$services, dba_directories
db [ nls|option|properties ] - v$instance, v$database, dba_registry, dba_registry_sqlpatch, nls_database_paramters, v$option, database_properties information
health - Database health parameters (HWM sessions, Hit Ratio / Get Misses cache, System Events Waits, Latch contention, Hot buffers)
oratop [ h ] - Database and Instance parameters, h - history V$SYSMETRIC_HISTORY V$ACTIVE_SESSION_HISTORY
sga - SGA information
pga - PGA sessions information
size [days] [ tbs [free] | temp | df [io|usage|lastseg[TBS]] | maxseg TBS | fra | grows (days) ] - Size of DB+archl (7 def), tablespaces, datafiles (HWM in DF+script), maxseg in all DB\TBS, FRA info + db_recovery_file_dest usage
arch - archivelog, V$LOG V$ARCHIVE_DEST V$ARCHIVE_DEST_STATUS GV$MANAGED_STANDBY V$STANDBY_LOG information
redo [logs] - redo information
undo [recovery] - undo active transaction information, recovery information
sesstat [ list | sess SESS_ID [STATNAME] | STATNAME ] - sesstat information, where 'list' - STATISTIC NAMES, sess SESS_ID - sesstat for session, STATNAME - name particular of STATISTIC NAME
topseg - top 20 segments statistics information from V$SEGMENT_STATISTICS
o OBJECT_NAME | OBJECT_ID - dba_objects information
s SEGMENT_NAME - dba_segments information
t [part] TABLE_NAME [OWNER] - dba_tables, dba_part_tables, dba_tab_partitions, dba_tab_subpartitions information
i [part] INDEX_NAME|TABLE_NAME [OWNER] - dba_indexes, dba_part_indexes, dba_ind_partitions, dba_ind_subpartitions information
l LOB_NAME - dba_lobs information
c [ CONSTRAINT_NAME | T TABLE_NAME | PK PRIMARY_KEY | FK (TABLE_NAME [OWNER] | %) ] - dba_constraints, dba_cons_columns information, PK - Who refs to the PK, FK - Tables with non-indexed foreign keys
u USERNAME - dba_users information
invalid [OWNER] - invalid objects
profile [PROFILE] - profiles information
links - links information
latch - latch information
lock [lib | obj OBJECT_NAME] - blocking locks information, lib - library lock information
bind [SQL] - sql not using bind variable information
pipe [PIPE_NAME] - pipes information, read PIPE_NAME
longops [SID | MESSAGE | rman] - active session longops for SID or MESSAGE or rman backup elapsed time
scheduler [log|run JOB_NAME [hours]] - dba_scheduler_jobs information, log|run JOB_NAME [hours] - dba_scheduler_job_log | dba_scheduler_job_run_details for JOB_NAME in last [hours]
job [OWNER] - dba_jobs information
get_ddl TYPE OBJECT (OWNER) - dbms_metadata.get_ddl extract dml, OBJECT - may be % or %mask%
trace [SID SERIAL LEVEL] [db on|off] - Trace for session, Level: 0-Disable, 1-Enable, 4-Enable with Binds, 8-Enable with Waits, 12-4+8, Trace all db sessions: on \ off
alert [num] - tail -num alert_[sid].log, default num = 100
report [ash text|html -60] -for last hour, [awr text|html DD/MM/YYYY HH24_begin HH24_end], [awrsql text|html DD/MM/YYYY HH24_begin HH24_end sql_id], [addm text DD/MM/YYYY HH24_begin HH24_end] - oracle reports
corrupt [DBA (number)] - Find DB Object by DBA number, [FB (file) (block)] - Find DB Object in dba_extents by file/block, v$database_block_corruption v$nonlogged_block information
sql SQL_ID | SQLTEXT [plan SQL_ID] [sqlstat SQL_ID] - Find out sql_id by SQLTEXT\SQL_ID from V$SQL, plan from VSQL_PLAN by sql_id, sqlstat from V$SQLSTAT by sql_id
ash [ event [all] (EventName) | sess (SID SERIAL# [all|nosqlid] | SQL_ID) | where [FIELD CONDITION] | sql (SQL_ID|SQL_TEXT) | plan SQL_ID [format display plan] | sqlstat SQL_ID | temp [sizeMb] ] - Top Event, Sessions, SQL V$ACTIVE_SESSION_HISTORY in last time
dhash [dd/mm/yyyy+HH24+hours - def3h] [ event [all] (EventName) | sess (SID SERIAL# [all|nosqlid] | SQL_ID) | where [FIELD CONDITION] | sql (SQL_ID|SQL_TEXT) | plan SQL_ID [fmt display plan] | sqlstat SQL_ID | growseg [SEGMENT] | segstat [OBJ%TYPE] [SIZE] | temp [sizeMb] ] - Top Events, Sessions, SQL from DBA_HIST_ACTIVE_SESS_HISTORY
spm [days def7 - baselines] [ blplan SQL_HANDLE (PLAN_NAME) | blexec [count] | bllpfcc SQL_ID PLAN_HASH_VALUE [SQL_HANDLE] | bllpfawr SQL_ID PLAN_HASH_VALUE MIN_SNAP_ID MAX_SNAP_ID | blchattr SQL_HANDLE PLAN_NAME ATTR VALUE | blchplan NEW_SQL_ID NEW_PHV OLD_SQLSET_NAME | sqlset_list SQLSET_NAME OWNER | sqlset_plan SQLSET_NAME SQL_ID [PHV] | sqlset_drop SQLSET_NAME | bldrop SQL_HANDLE (PLAN_NAME) | usage SQL_ID | sqltune [SQL_ID | awr SQL_ID begin_snap end_snap] | sqltune_report TASK_NAME | sqltune_accept TASK_NAME | sqltune_create_plan_bl TASK_NAME OWNER PLAN_HASH_VALUE | sqltune_list [TASK_NAME] [cnt] | sqltune_drop TASK_NAME | sql_profiles | sql_profile_chattr TASK_NAME ATTR VALUE | sql_profile_drop NAME | report_sql_monitor SQL_ID ]

