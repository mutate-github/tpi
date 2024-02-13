Usage: /home/t.mukhametshin/start/tpi/tpi <DBSID/PDB> sess_id [p|ph [FALSE] <param>] [services] [dir] | a [SPID\SID\OS_client_PID] | lock | db | audit | health | oratop | sga | pga | size | arch | redo | undo | sesstat | topseg | o . | s . | t . | i . | l . | c . | u . | r. | trg . | profile | links | latch | bind | pipe | longops | scheduler | job | rman | get_ddl | trace | kill | exec | alert | report ash/awr | corrupt | sql | ash | dhash | spm
"" - ACTIVE | a - Allsess | in - INACTIVE | k - KILLED | [access OBJECT] - active sess which accessing OBJECT | SPID\SID\OS_client_PID [PEEKED_BINDS OUTLINE all ALLSTATS ADVANCED last adaptive PREDICATE partition|p] [param_name] - sess param info from V$SES_OPTIMIZER_ENV by [param_name]
p [FALSE] [PAR1 PAR2 ..] | ph [FALSE] [PARAMETER] | services | dir - instance parameters or hidden parameters, [FALSE] - only changed parameters, v$services, dba_directories
db [ nls|option|properties|fusage ] - v$instance, v$database, dba_registry, dba_registry_sqlpatch, nls_database_paramters, v$option, database_properties information
audit - DDL users audit
health [cr | hot] - Database health parameters (HWM sessions, Hit Ratio / Get Misses cache, System Events Waits, Consistent Read buffers in SGA | Hot buffers)
oratop [ h | dhsh [dd/mm/yy-HH:MI-HH:MI(hours) - def3d] ] - Database and Instance parameters, h - history V$SYSMETRIC_HISTORY V$ACTIVE_SESSION_HISTORY, dhsh - dba_hist_sysmetric_history dba_hist_snapshot
sga - SGA information
pga - PGA sessions information
size [days | tbs [free] | temp | sysaux | df [io|usage|lastseg[TBS]] | maxseg TBS | fra | grows (days)] - Size of DB+archl (7 def), tablespaces, datafiles (HWM in DF+script), maxseg in all DB\TBS, FRA info + db_recovery_file_dest usage; ( alter system set "_enable_space_preallocation"=0 )
arch - archivelog, V$LOG V$ARCHIVE_DEST V$ARCHIVE_DEST_STATUS GV$MANAGED_STANDBY V$STANDBY_LOG information
redo [logs] - redo information
undo [recovery] - undo active transaction information, recovery information
sesstat [ list | sess SESS_ID [STATNAME] | STATNAME ] - sesstat information, where 'list' - STATISTIC NAMES, sess SESS_ID - sesstat for session, STATNAME - name particular of STATISTIC NAME
topseg [SEGMENT_NAME] [OWNER] - top 20 segments statistics information from V$SEGMENT_STATISTICS or SEGMENT_NAME statistics
o OBJECT_NAME | OBJECT_ID | invalid [OWNER] | ddl [last N hours] - dba_objects information
s SEGMENT_NAME [OWNER] - dba_segments information
t [part] TABLE_NAME [OWNER] - dba_tables, dba_part_tables, dba_tab_partitions, dba_tab_subpartitions information
i [part] INDEX_NAME|TABLE_NAME [OWNER] - dba_indexes, dba_part_indexes, dba_ind_partitions, dba_ind_subpartitions information
l LOB_NAME - dba_lobs information
c [ CONSTRAINT_NAME | T TABLE_NAME | PK PRIMARY_KEY | FK (TABLE_NAME [OWNER] | %) ] - dba_constraints, dba_cons_columns information, PK - Who refs to the PK, FK - Tables with non-indexed foreign keys
u [ USERNAME [{sys|role|tab} PRIVILEGE] ] - dba_users, dba_sys_privs, dba_role_privs, dba_tab_privs information
r [ {role|granted_role} ROLE ] - role_role_privs information
trg [ "" | [TRIGGER_NAME] [TRIGGER_OWNER] | t [TABLE_NAME] [TABLE_OWNER] ] - dba_triggers information, "" - LOGON or STARTUP triggers
profile [PROFILE] - profiles information
links [LINK_NAME] - links information
latch - latch information
lock [lib | obj OBJECT_NAME] - blocking locks information, lib - library lock information
bind [SQL] - sql not using bind variable information
pipe [PIPE_NAME] - pipes information, read PIPE_NAME
longops [SID | MESSAGE | rman] - active session longops for SID or MESSAGE or rman backup elapsed time
scheduler [JOB_NAME | run JOB_NAME [hours] | log JOB_NAME [hours] | autotask ] - dba_scheduler_jobs information, log | run JOB_NAME [hours] - dba_scheduler_job_log | dba_scheduler_job_run_details for JOB_NAME in last [hours]
job [OWNER] - dba_jobs information
rman [DAYS|cfg] - RMAN backups | v$rman_configuration information
get_ddl TYPE OBJECT (OWNER) - dbms_metadata.get_ddl extract dml, OBJECT - may be % or %mask%
trace [SID SERIAL LEVEL] [db on|off] - Trace for session, Level: 0-Disable, 1-Enable, 4-Enable with Binds, 8-Enable with Waits, 12-4+8, Trace all db sessions: on \ off
kill SID SERIAL - Kill session
exec - execute "SQL Commands" Note: Must be escaped with \ characters: * ; ' ! ( ) ( alter system set "_ash_sample_all"=true )
alert [num] - tail -num alert_[sid].log, default num = 100
report [ash text|html -60] -for last hour, [awr text|html DD/MM/YYYY HH24_begin HH24_end], [awrdd text|html DD1/MM/YYYY HH24_begin HH24_end DD2/MM/YYYY HH24_begin HH24_end], [awrsql text|html DD/MM/YYYY HH24_begin HH24_end sql_id], [addm text DD/MM/YYYY HH24_begin HH24_end] - oracle reports
corrupt [ROWID] [DBA (number)] [FB (file) (block)] - Find object by ROWID, Find object by DBA, Find DB Object in dba_extents by file/block, v$database_block_corruption v$nonlogged_block information
sql SQL_ID | SQLTEXT [plan SQL_ID] [sqlstat [SQL_ID|par|inv|fch|sor|exe|pio|lio|row|cpu|ela|iow|mem] [executions] ] - Find out sql_id by SQLTEXT\SQL_ID from V$SQL, plan from VSQL_PLAN by sql_id, sqlstat from V$SQLSTAT by sql_id
ash [dd/mm/yy-HH:MI-HH:MI(hours) - def1h] [ event | sess [SID SERIAL# [all|nosqlid] | SQL_ID] | where [FIELD CONDITION] | sql [top [event]] [all [event]] [SQL_ID|SQL_TEXT] | plan SQL_ID PHV [fmt display plan] | sqlstat [SQL_ID|par|inv|fch|sor|exe|pio|lio|row|cpu|ela|iow|mem] [executions] | temp [sizeMb] | (tmc)chart ] - Top SQL, Events, Sessions V$ACTIVE_SESSION_HISTORY
dhash [dd/mm/yy-HH:MI-HH:MI(hours) - def1h] [ event | sess [SID SERIAL# [all|nosqlid] | SQL_ID] | where [FIELD CONDITION] | sql [top [event]] [all [event]] [SQL_ID|SQL_TEXT] | plan SQL_ID PHV [fmt display plan] | sqlstat [SQL_ID|pio|lio|cpu|exe|ela|fch|sor|iow|row] [executions] | growseg [TBS] [SEGMENT] | segstat [SEGMENT] [OWNER] | temp [sizeMb] | (tmc)chart ] - Top SQL, Events, Sessions DBA_HIST_ACTIVE_SESS_HISTORY
spm [days def7 - baselines] [find %|SQL_HANDLE SQL_PLAN_NAME] [ blplan %|SQL_HANDLE (PLAN_NAME) | blexec [count] | bllpfcc SQL_ID PLAN_HASH_VALUE [SQL_HANDLE] | bllpfawr SQL_ID PLAN_HASH_VALUE MIN_SNAP_ID MAX_SNAP_ID | blchattr SQL_HANDLE PLAN_NAME ATTR VALUE | blchplan NEW_SQL_ID NEW_PHV OLD_SQLSET_NAME | blevolve SQL_HANDLE PLAN_NAME | sqlset_list SQLSET_NAME OWNER | sqlset_plan SQLSET_NAME SQL_ID [PHV] | sqlset_drop SQLSET_NAME | bldrop SQL_HANDLE (PLAN_NAME) | sqltune [SQL_ID | awr SQL_ID begin_snap end_snap] | sqltune_report TASK_NAME | sqltune_accept TASK_NAME | sqltune_create_plan_bl TASK_NAME OWNER PLAN_HASH_VALUE | sqltune_list [TASK_NAME] [cnt] | sqltune_drop TASK_NAME | sql_profiles | sql_profile_chattr TASK_NAME ATTR VALUE | sql_profile_drop NAME | hints profile|baseline|patch NAME | sqlpatch_list | sqlpatch_create SQL_ID 'HINTS"\'"' | sqlpatch_alter PATCHNAME enable|disable | sqlpatch_drop PATCHNAME | report_sql_monitor SQL_ID ]

