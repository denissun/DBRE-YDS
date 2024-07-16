#!/bin/ksh

 ###    NAME
 ###       "DB_Master_Health_Check.sh" - Oracle Database Health check Automation
 ###
 ###    DESCRIPTION
 ###       This script is used to perform Oracle database health check and provide the result in HTML format.
 ###	   This script designed to provide optimal result for Oracle databases in any Unix platform(SunOS/Linux/AIX).
 ### 	   This script takes the threshold value from input parameter file for the specific DB instances.
 ###		  a) Input file format should be "hc_input_<<ORACLE_SID>>.prm"
 ###	   This script creates three output files.
 ###	      a) TOTAL - This file is text format and includes the details which are under threshold value.
 ###		  b) ERROR - This file is text format and includes the details which are above threshold value (or) resulted with any errors.
 ###		  c) HTML  - This file is HTML format and includes the details which are above threshold value (or) resulted with any errors.
 ###
 ###    MODIFIED           (DD/MM/YY)
 ###       xxxxxx           05/07/2015     - Creation
 ###

export EMAIL="xxx@example.com"  

TOlist="xxx@example.com"  
CClist="xxx@example.com"  




hostname=`hostname -s`
export user_name="oracle"


typeset -i ARG_CNT=`echo $#`


if [ $ARG_CNT == 0 ]
then
	echo "No argument passed in the script. Please check" >>$OUTPUT_FILE_ERR
	mailx -r donotreply@example.com -s " Health Check report on `hostname -s`  Failed " ${EMAIL}<$OUTPUT_FILE_ERR
	rm $LOGDIR/hc_*.out
	exit 0

fi

if [ $ARG_CNT -gt 4 ]
then
	echo "More than 4 Arguments are passed as input. Please check" >>$OUTPUT_FILE_ERR
	mail -r donotreply@example.com -s " Health Check report on `hostname -s` Failed " ${EMAIL}<$OUTPUT_FILE_ERR
	rm $LOGDIR/hc_*.out
	exit 0
else
	export ORACLE_SID=$1
	export RAC_MNODE_CHK=$2
	export RAC_MNODE_NAME=$3
	export SOURCE_HOST_LOGDIR=$4

fi


export CURRENT_DAY=`date '+%a' | sed 's/ //g'`
export DATE=`date '+%d%m%Y_%H%M'`

export RUNDIR=`dirname ${0}`
export LOGDIR=${RUNDIR}/log

typeset -i LogDirChk=0

if [ -d "$LOGDIR" ]
then
   LogDirChk=1
else
	mkdir $LOGDIR 2> /tmp/HCLogDircreateChk.log
	typeset -i HCLogDircreateChkCNT=`cat /tmp/HCLogDircreateChk.log|wc -l`
	if [ $HCLogDircreateChkCNT -gt 0 ]
	then
		echo "No Privilage to create $LOGDIR directory. Please check" > /tmp/HCLogprivcheckdir.out
		mail -r donotreply@example.com -s " Health Check report for ${ORACLE_SID} on `hostname -s`  Failed " ${EMAIL}</tmp/HCLogprivcheckdir.out
		rm /tmp/HCLogprivcheckdir.out
		rm /tmp/HCLogDircreateChk.log
		exit 0
	else
		LogDirChk=1
		rm /tmp/HCLogDircreateChk.log
	fi
fi



if [ $LogDirChk == 1 ]
then
	touch $LOGDIR/tempfile.log 2> /tmp/HCLogDirwirtePrivChk.log
	typeset -i HCLogDirwirtePrivChk_Cnt=`cat /tmp/HCLogDirwirtePrivChk.log|wc -l `
	if [ $HCLogDirwirtePrivChk_Cnt -gt 0 ]
	then
		echo "No Privilage to create files in $LOGDIR directory. Please check" > /tmp/HCLogprivcheckfile.out
		mail -r donotreply@example.com -s " Health Check report for ${ORACLE_SID} on `hostname -s` Failed " ${EMAIL}</tmp/HCLogprivcheckfile.out
		rm /tmp/HCLogprivcheckfile.out
		rm /tmp/HCLogDirwirtePrivChk.log
		exit 0
	else
		rm /tmp/HCLogDirwirtePrivChk.log
		rm $LOGDIR/tempfile.log
	fi
fi


OUTPUT_FILE_TOTAL="$LOGDIR/hc_total_$hostname.out"
OUTPUT_FILE_ERR="$LOGDIR/hc_err_$hostname.out"
OUTPUT_FILE_VAL="$LOGDIR/hc_val_$hostname.out"

OUTPUT_FILE_HTML="$LOGDIR/hc_html_$hostname.html"

cat /dev/null > $OUTPUT_FILE_TOTAL
cat /dev/null > $OUTPUT_FILE_ERR
cat /dev/null > $OUTPUT_FILE_VAL

cat /dev/null > $OUTPUT_FILE_HTML




find ${LOGDIR} -mtime +15 -name "HC_*${ORACLE_SID}_*.*" -print -exec rm {} \;


typeset -i prmspace_cnt=0
typeset -i ASM_CHK=0

#BKP_METHOD="RMAN"

GSTATS_CHK="GOOD"
INVOBJ_CHK="GOOD"
BLOCKINGSESS_CHK="GOOD"
INDEX_CHK="GOOD"
CONSTRAINTS_CHK="GOOD"
AFIOR_VAL="GOOD"
INST_CHK="GOOD"
GGCHK_STATUS="GOOD"
TTS_VAL="GOOD"
LRT_VAL="GOOD"
BKP_CHK="GOOD"
CRS_CHK_STATUS="GOOD"




if [ "x$RAC_MNODE_CHK" = "x" ]
then
	typeset -i RAC_MNODE_CHK=1
	echo "RAC_MNODE_CHK : " $RAC_MNODE_CHK
fi
if [[ "$RAC_MNODE_CHK" != +([0-9]) ]]
then
	echo "RAC_MNODE_CHK value is not a Numeric value"
	exit 0
fi


if [ "x$RAC_MNODE_NAME" = "x" ]
then

	RAC_MNODE_NAME=$hostname
	echo "RAC_MNODE_NAME : " $RAC_MNODE_NAME
fi


if [ $RAC_MNODE_CHK == 1 ]
then
	echo '<TABLE cellpadding="3" cellspacing="0" width='500%'>' >>$OUTPUT_FILE_HTML
fi


# Input parameter file checking

if [ -f "$RUNDIR/hc_input_$ORACLE_SID.prm" ]
then

	if [ -f "$LOGDIR/hc_input_$ORACLE_SID_tmp.prm" ]
	then
		rm $LOGDIR/hc_input_$ORACLE_SID_tmp.prm
	fi

	typeset -i prmspace_cnt=`cat $RUNDIR/hc_input_$ORACLE_SID.prm|grep -i " "|wc -l`
	if [ $prmspace_cnt -gt 0 ]
	then
		echo " The file '$RUNDIR/hc_input_$ORACLE_SID.prm' contain Unnecessary spaces. Please check." >>$OUTPUT_FILE_ERR
		cat $RUNDIR/hc_input_$ORACLE_SID.prm|grep -i " ">>$OUTPUT_FILE_ERR
		mail -r donotreply@example.com -s " Health Check report for ${ORACLE_SID} on `hostname -s` Failed " ${EMAIL}<$OUTPUT_FILE_ERR
		rm $LOGDIR/hc_*.out
		exit 0
	fi


	sed 's/=/ /g' $RUNDIR/hc_input_$ORACLE_SID.prm >$LOGDIR/hc_input_$ORACLE_SID_tmp.prm
else
	echo " The file '$RUNDIR/hc_input_$ORACLE_SID.prm' does not exists. Please check." >>$OUTPUT_FILE_ERR
	mail -r donotreply@example.com -s " Health Check report for ${ORACLE_SID} on `hostname -s`  Failed " ${EMAIL}<$OUTPUT_FILE_ERR
	rm $LOGDIR/hc_*.out
	exit 0
fi




STR0=`grep -i "ORACLE_BASE" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
export ORACLE_BASE=`echo $STR0 | awk '{print $2}' | sed -e 's/%//'`


STR2=`grep -i "ORACLE_HOME" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
export ORACLE_HOME=`echo $STR2 | awk '{print $2}' | sed -e 's/%//'`


STR4=`grep -i "RAC_STATUS" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
RACChk=`echo $STR4 | awk '{print $2}' | sed -e 's/%//'`

STR5=`grep -i "GG_STATUS" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
GGCHK=`echo $STR5 | awk '{print $2}' | sed -e 's/%//'`

STR6=`grep -i "DB_VERSION" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
VerChk=`echo $STR6 | awk '{print $2}' | sed -e 's/%//'`

STR7=`grep -i "ActiveSessionThreshold" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
ActiveSessionThreshold=`echo $STR7 | awk '{print $2}' | sed -e 's/%//'`

STR8=`grep -i "InactiveSessionThreshold" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
InactiveSessionThreshold=`echo $STR8 | awk '{print $2}' | sed -e 's/%//'`

STR9=`grep -i "TotalSessionThreshold" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
TotalSessionThreshold=`echo $STR9 | awk '{print $2}' | sed -e 's/%//'`


STR10=`grep -i "LongrunningThreshold" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
LongrunningThreshold=`echo $STR10 | awk '{print $2}' | sed -e 's/%//'`

STR11=`grep -i "ArchDestspaceThreshold" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
ArchDestspaceThreshold=`echo $STR11 | awk '{print $2}' | sed -e 's/%//'`

STR12=`grep -i "CpuFreeThreshold" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
CpuFreeThreshold=`echo $STR12 | awk '{print $2}' | sed -e 's/%//'`

STR13=`grep -i "stale_prec" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
stale_prec=`echo $STR13 | awk '{print $2}' | sed -e 's/%//'`

STR14=`grep -i "GSTATS_OWNER_STR" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
GSTATS_OWNER_STR=`echo $STR14 | awk '{print $2}' | sed -e 's/%//'`


STR141=`grep -i "INVOBJ_OWNER_STR" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
INVOBJ_OWNER_STR=`echo $STR141 | awk '{print $2}' | sed -e 's/%//'`

STR142=`grep -i "DISCONS_OWNER_STR" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
DISCONS_OWNER_STR=`echo $STR142 | awk '{print $2}' | sed -e 's/%//'`


STR15=`grep -i "EXCLUDE_FS_LIST" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
EXCLUDE_FS_LIST=`echo $STR15 | awk '{print $2}' | sed -e 's/%//'`

STR16=`grep -i "TablespaceThreshold" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
TablespaceThreshold=`echo $STR16 | awk '{print $2}' | sed -e 's/%//'`


STR17=`grep -i "GG_HOME_PATH" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
GG_HOME_PATH=`echo $STR17 | awk '{print $2}' | sed -e 's/%//'`

STR18=`grep -i "BKP_METHOD" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
BKP_METHOD=`echo $STR18 | awk '{print $2}' | sed -e 's/%//'`


STR19=`grep -i "FilesystemusedThreshold" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
FilesystemusedThreshold=`echo $STR19 | awk '{print $2}' | sed -e 's/%//'`

STR20=`grep -i "ALERT_LOG_PATH" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
AlertLogFixedPath=`echo $STR20 | awk '{print $2}' | sed -e 's/%//'`

STR21=`grep -i "ASM_BASE" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
export ASM_BASE=`echo $STR21 | awk '{print $2}' | sed -e 's/%//'`

STR22=`grep -i "AVG_FILE_IO_READ_MS" $LOGDIR/hc_input_$ORACLE_SID_tmp.prm |head -1`
export TH_MS=`echo $STR22 | awk '{print $2}' | sed -e 's/%//'`


rm $LOGDIR/hc_input_$ORACLE_SID_tmp.prm


typeset -i Failure_Chk=0

if [ "x$ORACLE_BASE" = "x" ]; then
	echo "ORACLE_BASE value is empty" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
fi


if [ "x$ORACLE_HOME" = "x" ]; then
	echo "ORACLE_HOME value is empty" >>$OUTPUT_FILE_ERR
	Failure_Chk=1

fi

if [ "x$RACChk" = "x" ]; then
	echo "RACChk value is empty" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
elif  [[ "$RACChk" != +([0-9]) ]]
then
	echo "The entered RACChk value is not a Numeric value" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
fi


if [ "x$GGCHK" = "x" ]; then
	echo "GGCHK value is empty" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
elif  [[ "$GGCHK" != +([0-9]) ]]
then
	echo "The entered GGCHK value is not a Numeric value" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
fi


if [ "x$VerChk" = "x" ]; then
	echo "DB Version value is empty" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
elif  [[ "$VerChk" != +([0-9]) ]]
then
	echo "The entered DB Version value is not a Numeric value" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
fi

typeset -i  DBVersion=$VerChk

if [ $VerChk -gt 10 ]
then
	VerChk=1
else
	if [ "x$AlertLogFixedPath" = "x" ]; then
		echo "Alert log path value is empty" >>$OUTPUT_FILE_ERR
		Failure_Chk=1
	fi
fi




if [ "x$ActiveSessionThreshold" = "x" ]; then
	echo "ActiveSessionThreshold  value is empty" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
elif  [[ "$ActiveSessionThreshold" != +([0-9]) ]]
then
	echo "The entered ActiveSessionThreshold  value is not a Numeric value" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
fi


if [ "x$InactiveSessionThreshold" = "x" ]; then
	echo "InactiveSessionThreshold  value is empty" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
elif  [[ "$InactiveSessionThreshold" != +([0-9]) ]]
then
	echo "The entered InactiveSessionThreshold  value is not a Numeric value" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
fi




if [ "x$TotalSessionThreshold" = "x" ]; then
	echo "TotalSessionThreshold  value is empty" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
elif  [[ "$TotalSessionThreshold" != +([0-9]) ]]
then
	echo "The entered TotalSessionThreshold  value is not a Numeric value" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
fi




if [ "x$LongrunningThreshold" = "x" ]; then
	echo "LongrunningThreshold  value is empty" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
elif  [[ "$LongrunningThreshold" != +([0-9]) ]]
then
	echo "The entered LongrunningThreshold  value is not a Numeric value" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
fi




if [ "x$ArchDestspaceThreshold" = "x" ]; then
	echo "ArchDestspaceThreshold  value is empty" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
elif  [[ "$ArchDestspaceThreshold" != +([0-9]) ]]
then
	echo "The entered ArchDestspaceThreshold  value is not a Numeric value" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
fi

if [ "x$CpuFreeThreshold" = "x" ]; then
	echo "CpuFreeThreshold  value is empty" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
elif  [[ "$CpuFreeThreshold" != +([0-9]) ]]
then
	echo "The entered CpuFreeThreshold  value is not a Numeric value" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
fi

if [ "x$stale_prec" = "x" ]; then
	echo "stale_prec  value is empty" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
elif  [[ "$stale_prec" != +([0-9]) ]]
then
	echo "The entered stale_prec  value is not a Numeric value" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
fi



if [ "x$TablespaceThreshold" = "x" ]; then
	echo "TablespaceThreshold  value is empty" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
elif  [[ "$TablespaceThreshold" != +([0-9]) ]]
then
	echo "The entered TablespaceThreshold  value is not a Numeric value" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
fi




if [ "x$FilesystemusedThreshold" = "x" ]; then
	echo "The entered FilesystemusedThreshold  value is empty" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
elif  [[ "$FilesystemusedThreshold" != +([0-9]) ]]
then
	echo "The entered FilesystemusedThreshold  value is not a Numeric value" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
fi

if [ "x$TH_MS" = "x" ]; then
	echo "The entered AVG_FILE_IO_READ_MS  value is empty" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
elif  [[ "$TH_MS" != +([0-9]) ]]
then
	echo "The entered AVG_FILE_IO_READ_MS  value is not a Numeric value" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
fi



if [ $GGCHK == 1 ]
then

	if [ "x$GG_HOME_PATH" = "x" ]; then
		echo "GG_HOME_PATH  value is empty" >>$OUTPUT_FILE_ERR
		Failure_Chk=1
	fi
fi

if [ $RACChk == 1 ]
then

	if [ "x$ASM_BASE" = "x" ]; then
		echo "ASM_BASE value is empty" >>$OUTPUT_FILE_ERR
		Failure_Chk=1
	fi
fi



if [ "x$BKP_METHOD" = "x" ]; then
	echo "The entered BKP_METHOD  value is empty" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
fi

if  [ "$BKP_METHOD" = "RMAN" ] || [ "$BKP_METHOD" = "VSU" ]
then
	DUMMY=1
else
	echo "The entered BKP_METHOD  value is not RMAN/VSU" >>$OUTPUT_FILE_ERR
	Failure_Chk=1
fi


if [ $Failure_Chk == 1 ]
then
	mail -r donotreply@example.com -s " Health Check report for ${ORACLE_SID} on `hostname -s` ${ORACLE_SID} Failed " ${EMAIL}<$OUTPUT_FILE_ERR
	rm $LOGDIR/hc_*.out
	exit 0

fi

# Input parameter's value validations - Ends

export PATH=$PATH:$ORACLE_HOME/bin:$ORACLE_HOME/rdbms/admin
export LD_LIBRARY_PATH=$ORACLE_HOME/lib


#ORASID_CHK=`ps -ef|grep -i "ora_pmon_${ORACLE_SID}"|grep -v grep|wc -l`

ORASID_CHK=`ps -ef|grep -w "ora_pmon_${ORACLE_SID}"|grep -v grep|wc -l`


if [ $ORASID_CHK == 1 ]
then

	# check whether the script can able to connect the DB with parameters provided
	sqlplus -s  "/ as sysdba" << ENDSQL > /tmp/DB_chk_1.out
set echo off pages 3000 lines 800 feedb off time off timi off trimsp on
whenever sqlerror exit 7 rollback
set head off

select 'Database Check Status:',case count(*) when 0 then 'Failed' else 'Good'
end
from
(SELECT INSTANCE_NAME FROM v\$instance
where INSTANCE_NAME='$ORACLE_SID'
)
/

set pages 0

SELECT 'Database Name:',lower(name) from v\$database
/

ENDSQL

	if [ -f "/tmp/DB_chk_1.out" ]
	then
		DCS_VAL="Failed"
		DCS_STR=`grep -i "Database Check Status:" /tmp/DB_chk_1.out |head -1`
		DCS_VAL=`echo $DCS_STR | awk '{print $4}' | sed -e 's/%//'`

		if [ "$DCS_VAL" = "Good" ]
		then
			typeset -i DB_check=1
			echo "INST_CHK: " $INST_CHK >>$OUTPUT_FILE_VAL

			DBNAME_STR=`grep -i "Database Name:" /tmp/DB_chk_1.out |head -1`
			export DBNAME=`echo $DBNAME_STR | awk '{print $3}' | sed -e 's/%//'`

		else
			INST_DB_CHK="ERROR"
		fi
	else
		INST_DB_CHK="ERROR"
	fi
	rm /tmp/DB_chk_1.out
fi


if [ $ORASID_CHK == 0 ] || [ "$INST_DB_CHK" = "ERROR" ]
then

	if [ $ORASID_CHK == 0 ]
	then
		DB_INST_CHK_STR="Not found any OS process for the ORACLE_SID:${ORACLE_SID}"

	elif [ "$INST_DB_CHK" = "ERROR" ]
	then

		DB_INST_CHK_STR="Choose the correct environment variable to connect the DB instance : " $ORACLE_SID
	fi


	if [ $RAC_MNODE_CHK == 1 ]
	then
		echo  $DB_INST_CHK_STR >>$OUTPUT_FILE_ERR
		mail -r donotreply@example.com -s " Health Check report for ${ORACLE_SID} on `hostname -s` ${ORACLE_SID} Failed " ${EMAIL}<$OUTPUT_FILE_ERR
		exit 0
	else
		echo " ">>$OUTPUT_FILE_ERR
		echo "DB Instance Details">>$OUTPUT_FILE_ERR
		echo "=========================================================================================================">>$OUTPUT_FILE_ERR
		echo $DB_INST_CHK_STR >>$OUTPUT_FILE_ERR
		echo " ">>$OUTPUT_FILE_ERR
		INST_CHK="ERROR"
		GSTATS_CHK="INSTANCE DOWN"
		INVOBJ_CHK="INSTANCE DOWN"
		DBFILE_CHK="INSTANCE DOWN"
		BLOCKINGSESS_CHK="INSTANCE DOWN"
		INDEX_CHK="INSTANCE DOWN"
		CONSTRAINTS_CHK="INSTANCE DOWN"
		AFIOR_VAL="INSTANCE DOWN"
		TTS_VAL="INSTANCE DOWN"
		LRT_VAL="INSTANCE DOWN"
		BKP_CHK="INSTANCE DOWN"
		echo "INST_CHK: " $INST_CHK >>$OUTPUT_FILE_VAL
		echo "DBFILE_CHK: " $DBFILE_CHK >>$OUTPUT_FILE_VAL
		echo "BKP_CHK: " $BKP_CHK >>$OUTPUT_FILE_VAL
		echo "LRT_VAL: " $LRT_VAL >>$OUTPUT_FILE_VAL
		echo "AFIOR_VAL: " $AFIOR_VAL >>$OUTPUT_FILE_VAL
		echo "TTS_VAL: " $TTS_VAL >>$OUTPUT_FILE_VAL
		echo "INDEX_CHK: " $INDEX_CHK >>$OUTPUT_FILE_VAL
		echo "CONSTRAINTS_CHK: " $CONSTRAINTS_CHK >>$OUTPUT_FILE_VAL
		echo "BLOCKINGSESS_CHK: " $BLOCKINGSESS_CHK >>$OUTPUT_FILE_VAL
		echo "INVOBJ_CHK: " $INVOBJ_CHK >>$OUTPUT_FILE_VAL
		echo "GSTATS_CHK: " $GSTATS_CHK >>$OUTPUT_FILE_VAL
	fi
fi


## Tablespace free percentage (10 means 90% used )
## ArchDestspaceThreshold ( 70 means 70% used )
## CpuFreeThreshold (60 means CPU used %)

echo "RAC_MNODE_CHK " $RAC_MNODE_CHK
echo "INST_CHK " $INST_CHK
echo "DB_check " $DB_check


# Database Checks
if [ $RAC_MNODE_CHK == 1 ] && [ "$INST_CHK" = "GOOD" ] && [ $DB_check == 1 ]
then

	sqlplus -s  "/ as sysdba" <<ENDSQL
	set echo off pages 10000 lines 800 feedback off time off timi off trimsp on
	whenever sqlerror exit 7 rollback



	spool $LOGDIR/hc_db_temp.out
	set head on
	col host_name for a25
	col instance_name for a25
	col timestamp for a30
	col startup for a30

	select inst_id,instance_name,host_name,to_char(sysdate,'Mon dd, yyyy hh24:mi:ss') as timestamp,to_char(startup_time,'Mon dd, yyyy hh24:mi:ss') startup,shutdown_pending from gv\$instance order by 1
	/

	spool off


	set markup html on

 	spool $LOGDIR/hc_db_temp.html
	select inst_id "Instance ID" ,instance_name "Instance Name",host_name "Host Name",to_char(sysdate,'Mon dd, yyyy hh24:mi:ss') "Timestamp",to_char(startup_time,'Mon dd, yyyy hh24:mi:ss') "Startup Time" from gv\$instance order by 1
	/

	spool off
	set markup html off




	set head off
	spool $LOGDIR/hc_sql_sess.out
	set pages 0
	select i.inst_id,i.instance_name,i.host_name,s.status,count(*) from gv\$session s,gv\$instance i where i.inst_id=s.inst_id and s.status in ('ACTIVE','INACTIVE') and  s.type != 'BACKGROUND' group by i.inst_id,i.instance_name,i.host_name,s.status order by i.inst_id,4
	/

	spool off

	spool $LOGDIR/hc_sql.out

	/* Tablespace Threshold Status */
	select 'Tablespace Threshold Status:',case count(*) when 0 then 'GOOD' else 'Failing'
	end
	from
	(SELECT
	RTRIM(fs.tablespace_name) TABLESPACE_NAME,
	df.totalspace TABLESPACE_TOTAL_SIZE,
	(df.totalspace - fs.freespace) MB_USED,
	fs.freespace MB_FREE,
	round(100 * (fs.freespace / df.totalspace),2) PCT_FREE
	FROM (SELECT tablespace_name, ROUND(SUM(bytes) / 1048576) TotalSpace FROM dba_data_files GROUP BY tablespace_name
	) df, (SELECT tablespace_name, ROUND(SUM(bytes) / 1048576) FreeSpace
	FROM dba_free_space GROUP BY tablespace_name ) fs
	WHERE df.tablespace_name = fs.tablespace_name(+)
	and df.tablespace_name not in ('UNDOTBS')
	and round(100 * (fs.freespace / df.totalspace),2) < $TablespaceThreshold
	order by PCT_FREE ASC
	)
	/


	/* Long running Session */

	SELECT  'Long Running Session:',case count(*) when 0 then 'GOOD' else 'Failing'
	end
	FROM gv\$session WHERE username is not null and sql_id is not null and status='ACTIVE' and last_call_et > $LongrunningThreshold
	/

	/* Archive log Destination */

	SELECT 'Archive Log Destination:'||RTRIM(value) FROM v\$parameter WHERE NAME LIKE 'log_archive_dest%' AND VALUE IS NOT NULL AND lower(VALUE) != 'enable' and lower(value) like 'location=%'
	/
	spool off

	spool $LOGDIR/hc_db_rman.out

	SELECT * FROM (SELECT INPUT_TYPE, STATUS,TO_CHAR(START_TIME,'dd-mm-yy') start_time,TO_CHAR(END_TIME,'dd-mm-yy')   end_time, ELAPSED_SECONDS/3600  hrs FROM V\$RMAN_BACKUP_JOB_DETAILS WHERE INPUT_TYPE IN ('DB INCR','DB FULL') ORDER BY SESSION_KEY DESC) WHERE ROWNUM <= 1
	/
	spool off

	spool $LOGDIR/hc_db_filestatus.out

	col name for a70
	set head on
	set pagesize 10000
	SELECT NAME,STATUS FROM V\$DATAFILE WHERE STATUS NOT IN ('SYSTEM','ONLINE') ORDER BY STATUS,NAME
	/
	spool off

	col owner for a22
	col table_name for a30
	spool $LOGDIR/hc_db_stats.out

	select owner,table_name,last_analyzed from dba_tables where last_analyzed is null and owner NOT IN ($GSTATS_OWNER_STR) and status='VALID' order by owner,table_name
	/

	spool off

	spool $LOGDIR/hc_db_stats_new.out


	SELECT DT.OWNER,
		DT.TABLE_NAME,
		ROUND ( (DELETES + UPDATES + INSERTS) / NUM_ROWS * 100) PERCENTAGE
	FROM   DBA_TABLES DT, DBA_TAB_MODIFICATIONS DTM
	WHERE      DT.OWNER = DTM.TABLE_OWNER
		AND DT.TABLE_NAME = DTM.TABLE_NAME
		AND NUM_ROWS > 0
		AND ROUND ( (DELETES + UPDATES + INSERTS) / NUM_ROWS * 100) >= $stale_prec
		AND OWNER NOT IN ($GSTATS_OWNER_STR)
	ORDER BY 3 desc
	/

	spool off

	spool $LOGDIR/hc_db_invalidobj.out

	select count(*),owner,object_type from dba_objects where status='INVALID' and owner NOT IN ($INVOBJ_OWNER_STR) group by owner,object_type order by 2,1,3
	/
	spool off

	spool $LOGDIR/hc_db_index.out

	col owner for a20
	col index_name for a30
	col table_name for a30
	select owner,index_name,status,table_name from dba_indexes where status='UNUSABLE';

	spool off


	spool $LOGDIR/hc_db_constraints.out

	col owner for a30
	col constraint_type for a35
	select   owner, constraint_type, count(*) Count from     dba_constraints where   status='DISABLED' and owner NOT IN ($DISCONS_OWNER_STR) group by owner, constraint_type;

	spool off


	spool $LOGDIR/hc_db_blockingsess.out
	set head on
	set feedback off
	col BLOCK for 9
	col LMODE for 9
	col INST_ID for 9
	col REQUEST for 9
	col SID for 999999
	col username for a12
	col timeheld format 999999 heading "Time Held|(min)"
	col block format a5 heading "Block"
	col blocking_instance format 99 heading "Blking|Inst_ID"
	col blocking_session format 99999 heading "Blking|SID"
	select
			l.INST_ID,
			l.SID,
			s.serial#,
			s.username,
			l.TYPE,
			decode(l.lmode,0,'None',1,'Null',2,'Row-S',3,'Row-X',4,'Share',5,'S/Row-X',6,'Exclusive') lockheld,
			DECODE(REQUEST,0,'None',1,'Null',2,'Row-S',3,'Row-X',4,'Share', 5,'S/ROW',6,'Exclusive')REQUEST,
			CTIME/60 timeheld ,
			decode(l.BLOCK,0,'No',1, 'Yes', 2, 'Yes') block,
			s.blocking_instance,
			s.blocking_session
	from gv\$lock l,
		gv\$session s
	where (l.ID1,l.ID2,l.TYPE) in
		(select ID1,ID2,TYPE
			from gv\$lock where request>0)
	and l.sid=s.sid
	and l.inst_id=s.inst_id
	order by l.id1, l.lmode desc, l.ctime desc
	/
	spool off
	spool $LOGDIR/Top_sql_details.out
	set lines 800
	set pagesize 3000
	set feedback on
	set echo off


	PROMPT TOP 10 CPU CONSUMING QUERIES SINCE LAST ONE DAY
	PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	select * from (
	select
		SQL_ID,
		sum(CPU_TIME_DELTA),
		sum(DISK_READS_DELTA),
		count(*)
	from
		DBA_HIST_SQLSTAT a, dba_hist_snapshot s
	where
	 s.snap_id = a.snap_id
	 and s.begin_interval_time > sysdate -1
		group by
		SQL_ID
	order by
		sum(CPU_TIME_DELTA) desc)
	where rownum < 10
	/

	PROMPT
	PROMPT TOP 10 SQL STATEMENTS WITH HIGHEST I/O SINCE LAST ONE DAY
	PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	select * from
	(
	SELECT /*+LEADING(x h) USE_NL(h)*/
		   h.sql_id
	,      SUM(10) ash_secs
	FROM   dba_hist_snapshot x
	,      dba_hist_active_sess_history h
	WHERE   x.begin_interval_time > sysdate -1
	AND    h.SNAP_id = X.SNAP_id
	AND    h.dbid = x.dbid
	AND    h.instance_number = x.instance_number
	AND    h.event in  ('db file sequential read','db file scattered read')
	GROUP BY h.sql_id
	ORDER BY ash_secs desc )
	where rownum < 10
	/

	spool off

	set pagesize 0
	set feedback off
set lines 3000
col "Database Size" format a300
col "Free space" format a300
col "Used space" format a300

	spool $LOGDIR/hc_db_size.out

select '<tr><td align="center"><font face="Calibri" size="2px" > ' || round(sum(used.bytes) / 1024 / 1024 / 1024 ) || ' GB </font></td><td align="center"><font face="Calibri" size="2px" >' "Database Size",
round(sum(used.bytes) / 1024 / 1024 / 1024 ) - round(free.p / 1024 / 1024 / 1024) || ' GB </font></td><td align="center"><font face="Calibri" size="2px" >' "Used space",round(free.p / 1024 / 1024 / 1024) || ' GB </font></td></tr>' "Free space"
from    (select     bytes     from     v\$datafile     union     all     select     bytes     from      v\$tempfile     union      all     select      bytes     from   v\$log) used,(select sum(bytes) as p from dba_free_space) free group by free.p;


	spool off;


set pagesize 3000
set markup html on
spool $LOGDIR/hc_db_arch.out

  SELECT INST_ID,TO_CHAR (COMPLETION_TIME, 'DD/MM/YYYY') DAY,
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '00', 1, NULL))
            "00-01",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '01', 1, NULL))
            "01-02",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '02', 1, NULL))
            "02-03",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '03', 1, NULL))
            "03-04",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '04', 1, NULL))
            "04-05",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '05', 1, NULL))
            "05-06",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '06', 1, NULL))
            "06-07",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '07', 1, NULL))
            "07-08",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '08', 1, NULL))
            "08-09",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '09', 1, NULL))
            "09-10",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '10', 1, NULL))
            "10-11",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '11', 1, NULL))
            "11-12",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '12', 1, NULL))
            "12-13",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '13', 1, NULL))
            "13-14",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '14', 1, NULL))
            "14-15",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '15', 1, NULL))
            "15-16",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '16', 1, NULL))
            "16-17",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '17', 1, NULL))
            "17-18",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '18', 1, NULL))
            "18-19",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '19', 1, NULL))
            "19-20",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '20', 1, NULL))
            "20-21",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '21', 1, NULL))
            "21-22",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '22', 1, NULL))
            "22-23",
         SUM (DECODE (TO_CHAR (COMPLETION_TIME, 'HH24'), '23', 1, NULL))
            "23-00",
         COUNT (*) TOTAL
    FROM GV\$ARCHIVED_LOG
WHERE ARCHIVED='YES' AND COMPLETION_TIME >= trunc(sysdate-9)
GROUP BY INST_ID,TO_CHAR (COMPLETION_TIME, 'DD/MM/YYYY')
ORDER BY INST_ID,TO_DATE (DAY, 'DD/MM/YYYY')
/


spool off
set markup html off

set lines 300
set pagesize 0
set feedback off
col file_name for a90

spool $LOGDIR/hc_asm_check.out
select * from (select file_name from dba_data_files where tablespace_name='SYSTEM' ) where rownum < 2;

spool off;


set lines 200 pages 3000
set feedback off
col tablespace_name for a24
col name for a60
set markup html on
spool $LOGDIR/hc_fileiostat.html
select  c.name tablespace_name, b.name file_name,round(a.AVERAGE_READ_TIME,2)
"AVERAGE_READ_TIME(ms)",round(a.AVERAGE_WRITE_TIME,2) "AVERAGE_WRITE_TIME(ms)"
  from v\$FILEMETRIC a, v\$datafile b, v\$tablespace c where a.file_id=b.FILE#
 and  b.TS#=c.TS# and (a.AVERAGE_READ_TIME > ${TH_MS} or a.AVERAGE_WRITE_TIME > ${TH_MS}) order by c.name;

exit


ENDSQL

	echo " ">>$OUTPUT_FILE_TOTAL
	cat $LOGDIR/hc_db_temp.out>>$OUTPUT_FILE_TOTAL

	DB_SESS_FILE="$LOGDIR/hc_sql_sess.out"
	typeset -i INST_VAL_CHK=99999999
	typeset -i TSC_CNT=0
	typeset -i ACNT=0
	typeset -i ICNT=0

	cat /dev/null > $LOGDIR/hc_active_inactive_sess.out
	Session_Cnt_Chk="GOOD"
	typeset -i session_i=0

	while read Sess_line
	do
		LINE_STR="$Sess_line"
		typeset -i session_i=session_i+1
		typeset -i LINE_INST_NUM=`echo $LINE_STR | awk '{print $1}' | sed -e 's/%//'`
		LINE_INST_NAME=`echo $LINE_STR | awk '{print $2}' | sed -e 's/%//'`
		LINE_HOST_NAME=`echo $LINE_STR | awk '{print $3}' | sed -e 's/%//'`
		LINE_SESS_TYPE=`echo $LINE_STR | awk '{print $4}' | sed -e 's/%//'`
		typeset -i LINE_SESS_CNT=`echo $LINE_STR | awk '{print $5}' | sed -e 's/%//'`


		if [ $INST_VAL_CHK != $LINE_INST_NUM ]
		then
			Session_Cnt_Chk="GOOD"
		fi

		if [ $LINE_SESS_TYPE == "ACTIVE" ] && [ $LINE_SESS_CNT -gt $ActiveSessionThreshold ]
		then
			echo " ">>$OUTPUT_FILE_ERR
			echo "=========================================================================================================">>$OUTPUT_FILE_ERR
			echo "ACTIVE SESSION COUNT  " $LINE_SESS_CNT " IS GREATER THAN " $ActiveSessionThreshold " in the instance " $LINE_INST_NAME >>$OUTPUT_FILE_ERR
			echo " ">>$OUTPUT_FILE_ERR
			Session_Cnt_Chk="ERROR"

			echo '<tr>' >>$LOGDIR/hc_active_inactive_sess.out
			echo '<td align="left">' >>$LOGDIR/hc_active_inactive_sess.out
			echo '<font face="Arial" size="2" color="black"><p>' >>$LOGDIR/hc_active_inactive_sess.out
			echo "Active Session Count "$LINE_SESS_CNT" is greater than threshold("$ActiveSessionThreshold") in instance-"$LINE_INST_NAME >>$LOGDIR/hc_active_inactive_sess.out
			echo '</p></font>' >>$LOGDIR/hc_active_inactive_sess.out
			echo '</td>' >>$LOGDIR/hc_active_inactive_sess.out
			echo '</tr>' >>$LOGDIR/hc_active_inactive_sess.out
		fi
		if [ $LINE_SESS_TYPE == "INACTIVE" ] && [ $LINE_SESS_CNT -gt $InactiveSessionThreshold ]
		then
			echo " ">>$OUTPUT_FILE_ERR
			echo "=========================================================================================================">>$OUTPUT_FILE_ERR
			echo "INACTIVE SESSION COUNT  " $LINE_SESS_CNT " IS GREATER THAN " $InactiveSessionThreshold " in the instance " $LINE_INST_NAME >>$OUTPUT_FILE_ERR
			echo " ">>$OUTPUT_FILE_ERR
			Session_Cnt_Chk="ERROR"

			echo '<tr>' >>$LOGDIR/hc_active_inactive_sess.out
			echo '<td align="left">' >>$LOGDIR/hc_active_inactive_sess.out
			echo '<font face="Arial" size="2" color="black"><p>' >>$LOGDIR/hc_active_inactive_sess.out
			echo "Inactive Session Count "$LINE_SESS_CNT" is greater than threshold("$InactiveSessionThreshold") in instance-"$LINE_INST_NAME >>$LOGDIR/hc_active_inactive_sess.out
			echo '</p></font>' >>$LOGDIR/hc_active_inactive_sess.out
			echo '</td>' >>$LOGDIR/hc_active_inactive_sess.out
			echo '</tr>' >>$LOGDIR/hc_active_inactive_sess.out

		fi

		if [ $INST_VAL_CHK == 99999999 ]
		then
			TSC_CNT=$LINE_SESS_CNT
			INST_VAL_CHK=$LINE_INST_NUM
			INUM=$LINE_INST_NUM
			INAME=$LINE_INST_NAME
			IHOST=$LINE_HOST_NAME
			if [ $LINE_SESS_TYPE == "ACTIVE" ]
			then
				ACNT=$LINE_SESS_CNT
			else
				ICNT=$LINE_SESS_CNT
			fi

			cat /dev/null > $LOGDIR/hc_inst_sess_main.out

		elif [ $INST_VAL_CHK == $LINE_INST_NUM ]
		then
			ACNT=$TSC_CNT
			ICNT=$LINE_SESS_CNT
			TSC_CNT=TSC_CNT+$LINE_SESS_CNT
			INST_VAL_CHK=$LINE_INST_NUM
			INUM=$LINE_INST_NUM
			INAME=$LINE_INST_NAME
			IHOST=$LINE_HOST_NAME

		else

			if [ $TSC_CNT -gt $TotalSessionThreshold ]
			then
				echo " ">>$OUTPUT_FILE_ERR
				echo "=========================================================================================================">>$OUTPUT_FILE_ERR
				echo "TOTAL SESSION COUNT  " $TSC_CNT " IS GREATER THAN " $TotalSessionThreshold " in the instance " $INAME >>$OUTPUT_FILE_ERR
				echo " ">>$OUTPUT_FILE_ERR
				Session_Cnt_Chk="ERROR"

				echo '<tr>' >>$LOGDIR/hc_active_inactive_sess.out
				echo '<td align="left">' >>$LOGDIR/hc_active_inactive_sess.out
				echo '<font face="Arial" size="2" color="black"><p>' >>$LOGDIR/hc_active_inactive_sess.out
				echo "Total Session count "$TSC_CNT" is greater than threshold("$TotalSessionThreshold") in instance-"$INAME >>$LOGDIR/hc_active_inactive_sess.out
				echo '</p></font>' >>$LOGDIR/hc_active_inactive_sess.out
				echo '</td>' >>$LOGDIR/hc_active_inactive_sess.out
				echo '</tr>' >>$LOGDIR/hc_active_inactive_sess.out
			fi
			LINE_FULL_STR="$INUM $INAME $IHOST "
			LINE_FULL_STR="$LINE_FULL_STR $ACNT/$ICNT"
			LINE_FULL_STR="$LINE_FULL_STR $Session_Cnt_Chk"

			echo $LINE_FULL_STR >> $LOGDIR/hc_inst_sess_main.out

			if [ $LINE_SESS_TYPE == "ACTIVE" ]
			then
				ACNT=$LINE_SESS_CNT
				ICNT=0
			else
				ACNT=0
				ICNT=$LINE_SESS_CNT
			fi
			INUM=$LINE_INST_NUM
			INAME=$LINE_INST_NAME
			IHOST=$LINE_HOST_NAME
			INST_VAL_CHK=$LINE_INST_NUM
			TSC_CNT=$LINE_SESS_CNT
		fi
	done <"$DB_SESS_FILE"

	if [ $TSC_CNT -gt $TotalSessionThreshold ]
	then
		echo " ">>$OUTPUT_FILE_ERR
		echo "=========================================================================================================">>$OUTPUT_FILE_ERR
		echo "TOTAL SESSION COUNT  " $TSC_CNT " IS GREATER THAN " $TotalSessionThreshold " in the instance " $INAME >>$OUTPUT_FILE_ERR
		Session_Cnt_Chk="ERROR"
		echo " ">>$OUTPUT_FILE_ERR

		echo '<tr>' >>$LOGDIR/hc_active_inactive_sess.out
		echo '<td align="left">' >>$LOGDIR/hc_active_inactive_sess.out
		echo '<font face="Arial" size="2" color="black"><p>' >>$LOGDIR/hc_active_inactive_sess.out
		echo "Total Session count "$TSC_CNT" is greater than threshold("$TotalSessionThreshold") in instance-"$INAME >>$LOGDIR/hc_active_inactive_sess.out
		echo '<p></font>' >>$LOGDIR/hc_active_inactive_sess.out
		echo '</td>' >>$LOGDIR/hc_active_inactive_sess.out
		echo '</tr>' >>$LOGDIR/hc_active_inactive_sess.out
	fi

	LINE_FULL_STR="$LINE_INST_NUM $LINE_INST_NAME $LINE_HOST_NAME "
	LINE_FULL_STR="$LINE_FULL_STR $ACNT/$ICNT"
	LINE_FULL_STR="$LINE_FULL_STR $Session_Cnt_Chk"


	echo $LINE_FULL_STR >> $LOGDIR/hc_inst_sess_main.out

	if [ "$Session_Cnt_Chk" != "GOOD" ]
	then
		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><b><u><a name="Section4">Session Count Details: </a></b></u></font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML
		cat $LOGDIR/hc_active_inactive_sess.out >>$OUTPUT_FILE_HTML
		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML
	fi

	# Datafile status Check
	DBFILE_CHK="GOOD"
	typeset -i DBFILE_STR=`cat $LOGDIR/hc_db_filestatus.out|wc -l`
	if [ $DBFILE_STR == 0 ]; then
		echo "All datafiles are in valid status" >>$OUTPUT_FILE_TOTAL
		DBFILE_CHK="GOOD"
	elif [ $DBFILE_STR -gt 0 ]
	then
		echo "Some datafiles are not in ONLINE status. Please Check." >>$OUTPUT_FILE_ERR
		echo `cat $LOGDIR/hc_db_filestatus.out` >>$OUTPUT_FILE_ERR
		DBFILE_CHK="ERROR"

		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><b><u><a name="Section13">Datafile Status Details: </a></b></u></font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML
		echo '<pre>' >>$OUTPUT_FILE_HTML
		cat $LOGDIR/hc_db_filestatus.out >>$OUTPUT_FILE_HTML
		echo '</pre>' >>$OUTPUT_FILE_HTML
		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML

	fi
	echo "DBFILE_CHK: " $DBFILE_CHK >>$OUTPUT_FILE_VAL
	rm $LOGDIR/hc_db_filestatus.out


	# Backup Check

		cat /dev/null > $LOGDIR/hc_backup_status.out
		#RMAN  backup Check


	if [ "$BKP_METHOD" = "RMAN" ]
	then
		typeset -i RMAN_STR_CNT=`cat $LOGDIR/hc_db_rman.out|wc -l`

		if [ $RMAN_STR_CNT == 0 ]; then
			echo "There is no recent backup taken using RMAN. Please check." >>$OUTPUT_FILE_ERR
			BKP_CHK="ERRORS"
			echo '<tr>' >>$LOGDIR/hc_backup_status.out
			echo '<td align="left">' >>$LOGDIR/hc_backup_status.out
			echo '<font face="Arial" size="2" color="black"><p>' >>$LOGDIR/hc_backup_status.out
			echo "There is no recent backup taken using RMAN. Please check." >>$LOGDIR/hc_backup_status.out
			echo '</p></font>' >>$LOGDIR/hc_backup_status.out
			echo '</td>' >>$LOGDIR/hc_backup_status.out
			echo '</tr>' >>$LOGDIR/hc_backup_status.out

		elif [ $RMAN_STR_CNT -gt 0 ]
		then
			RMAN_STR=`cat $LOGDIR/hc_db_rman.out`
			BKP_TYPE_VAL=`echo $RMAN_STR | awk '{print $1$2}' | sed -e 's/%//'`
			BKP_STATUS_VAL=`echo $RMAN_STR | awk '{print $3}' | sed -e 's/%//'`
			BKP_SDATE_VAL=`echo $RMAN_STR | awk '{print $4}' | sed -e 's/%//'`
			BKP_EDATE_VAL=`echo $RMAN_STR | awk '{print $5}' | sed -e 's/%//'`
			BKP_LASTDAY=`TZ=EST+30 date +'%d-%m-%y'`
			BKP_TODAY=`TZ=EST date +'%d-%m-%y'`

			if [ "$BKP_STATUS_VAL" = "COMPLETED" ]
			then
				if [ "$BKP_EDATE_VAL" = "$BKP_LASTDAY" ] || [ "$BKP_EDATE_VAL" = "$BKP_TODAY" ]
				then
					echo " ">>$OUTPUT_FILE_TOTAL
					echo "=========================================================================================================">>$OUTPUT_FILE_TOTAL
					echo "We have succesfull DB RMAN backup taken on " $BKP_EDATE_VAL >>$OUTPUT_FILE_TOTAL
					echo " ">>$OUTPUT_FILE_TOTAL
					BKP_CHK="GOOD"
				else
                                        BKP_SDATE_VAL=`echo $RMAN_STR | awk '{print $6}' | sed -e 's/%//'`
                                        BKP_EDATE_VAL=`echo $RMAN_STR | awk '{print $7}' | sed -e 's/%//'`
					echo " ">>$OUTPUT_FILE_ERR
					echo "=========================================================================================================">>$OUTPUT_FILE_ERR
					echo "We have no recent (last 2 days) succesfull DB RMAN backup. Last backup taken on " $BKP_EDATE_VAL ".Please check" >>$OUTPUT_FILE_ERR
					echo " ">>$OUTPUT_FILE_ERR

					BKP_CHK="ERRORS"
					echo '<tr>' >>$LOGDIR/hc_backup_status.out
					echo '<td align="left">' >>$LOGDIR/hc_backup_status.out
					echo '<font face="Arial" size="2" color="black"><p>' >>$LOGDIR/hc_backup_status.out
					echo "We have no recent (last 2 days) succesfull DB RMAN backup. Last backup taken on " $BKP_EDATE_VAL ".Please check" >>$LOGDIR/hc_backup_status.out
					echo '</p></font>' >>$LOGDIR/hc_backup_status.out
					echo '</td>' >>$LOGDIR/hc_backup_status.out
					echo '</tr>' >>$LOGDIR/hc_backup_status.out
				fi

			elif [ "$BKP_STATUS_VAL" = "RUNNING" ]
			then
				if [ "$BKP_SDATE_VAL" = "$BKP_LASTDAY" ] || [ "$BKP_SDATE_VAL" = "$BKP_TODAY" ]
				then
					echo " ">>$OUTPUT_FILE_ERR
					echo "=========================================================================================================">>$OUTPUT_FILE_ERR
					echo "DB RMAN backup is currently in RUNNING status, since " $BKP_SDATE_VAL ".Please check." >>$OUTPUT_FILE_ERR
					echo " ">>$OUTPUT_FILE_ERR
					BKP_CHK="RUNNING"
					echo '<tr>' >>$LOGDIR/hc_backup_status.out
					echo '<td align="left">' >>$LOGDIR/hc_backup_status.out
					echo '<font face="Arial" size="2" color="black"><p>' >>$LOGDIR/hc_backup_status.out
					echo "DB RMAN backup is currently in RUNNING status, since " $BKP_SDATE_VAL ".Please check." >>$LOGDIR/hc_backup_status.out
					echo '</p></font>' >>$LOGDIR/hc_backup_status.out
					echo '</td>' >>$LOGDIR/hc_backup_status.out
					echo '</tr>' >>$LOGDIR/hc_backup_status.out
				else
					echo " ">>$OUTPUT_FILE_ERR
					echo "=========================================================================================================">>$OUTPUT_FILE_ERR
					echo "DB RMAN backup is running for very long period , since " $BKP_SDATE_VAL ".Please check." >>$OUTPUT_FILE_ERR
					echo " ">>$OUTPUT_FILE_ERR
					BKP_CHK="ERRORS"
					echo '<tr>' >>$LOGDIR/hc_backup_status.out
					echo '<td align="left">' >>$LOGDIR/hc_backup_status.out
					echo '<font face="Arial" size="2" color="black"><p>' >>$LOGDIR/hc_backup_status.out
					echo "DB RMAN backup is running for very long period , since " $BKP_SDATE_VAL ".Please check." >>$LOGDIR/hc_backup_status.out
					echo '</p></font>' >>$LOGDIR/hc_backup_status.out
					echo '</td>' >>$LOGDIR/hc_backup_status.out
					echo '</tr>' >>$LOGDIR/hc_backup_status.out
				fi

			elif [ "$BKP_STATUS_VAL" = "FAILED" ]
			then
				echo " ">>$OUTPUT_FILE_ERR
				echo "=========================================================================================================">>$OUTPUT_FILE_ERR
				echo "DB RMAN backup is currently in FAILED status on " $BKP_SDATE_VAL ".Please check." >>$OUTPUT_FILE_ERR
				echo " ">>$OUTPUT_FILE_ERR
				BKP_CHK="FAILED"
				echo '<tr>' >>$LOGDIR/hc_backup_status.out
				echo '<td align="left">' >>$LOGDIR/hc_backup_status.out
				echo '<font face="Arial" size="2" color="black"><p>' >>$LOGDIR/hc_backup_status.out
				echo "DB RMAN backup is currently in FAILED status on " $BKP_SDATE_VAL ".Please check." >>$LOGDIR/hc_backup_status.out
				echo '</p></font>' >>$LOGDIR/hc_backup_status.out
				echo '</td>' >>$LOGDIR/hc_backup_status.out
				echo '</tr>' >>$LOGDIR/hc_backup_status.out
			else
				echo " ">>$OUTPUT_FILE_ERR
				echo "=========================================================================================================">>$OUTPUT_FILE_ERR
				echo "DB RMAN backup status is " $BKP_STATUS_VAL" which is not defined.Please check." >>$OUTPUT_FILE_ERR
				echo " ">>$OUTPUT_FILE_ERR
				BKP_CHK="ERRORS"
				echo '<tr>' >>$LOGDIR/hc_backup_status.out
				echo '<td align="left">' >>$LOGDIR/hc_backup_status.out
				echo '<font face="Arial" size="2" color="black"><p>' >>$LOGDIR/hc_backup_status.out
				echo "DB RMAN backup status is " $BKP_STATUS_VAL" which is not a defined one.Please check." >>$LOGDIR/hc_backup_status.out
				echo '</p></font>' >>$LOGDIR/hc_backup_status.out
				echo '</td>' >>$LOGDIR/hc_backup_status.out
				echo '</tr>' >>$LOGDIR/hc_backup_status.out
			fi

		fi


	fi
	rm $LOGDIR/hc_db_rman.out


	# Tablespace check

	TTS_STR=`grep -i "Tablespace Threshold Status:" $LOGDIR/hc_sql.out |head -1`
	TTS_VAL=`echo $TTS_STR | awk '{print $4}' | sed -e 's/%//'`

	if [ "$TTS_VAL" = "Failing" ]
	then
	sqlplus -s  "/ as sysdba" << ENDSQL1
	set echo off pages 1000 lines 800 feedb off time off timi off trimsp on
	col TABLESPACE_NAME for a30
	set heading on
	whenever sqlerror exit 7 rollback
	spool  $LOGDIR/tablespace_temp.out
	SELECT
	RTRIM(fs.tablespace_name) TABLESPACE_NAME,
	df.totalspace TABLESPACE_TOTAL_SIZE,
	(df.totalspace - fs.freespace) MB_USED,
	fs.freespace MB_FREE,
	round(100 * (fs.freespace / df.totalspace),2) PCT_FREE
	FROM (SELECT tablespace_name, ROUND(SUM(bytes) / 1048576) TotalSpace FROM dba_data_files GROUP BY tablespace_name
	) df, (SELECT tablespace_name, ROUND(SUM(bytes) / 1048576) FreeSpace
	FROM dba_free_space GROUP BY tablespace_name ) fs
	WHERE df.tablespace_name = fs.tablespace_name(+)
	and df.tablespace_name not in ('UNDOTBS')
	and round(100 * (fs.freespace / df.totalspace),2) < $TablespaceThreshold
	order by PCT_FREE ASC
	/

	spool off
ENDSQL1

	echo " ">>$OUTPUT_FILE_ERR
	echo "Tablespace Details">>$OUTPUT_FILE_ERR
	echo "=========================================================================================================">>$OUTPUT_FILE_ERR
	cat $LOGDIR/tablespace_temp.out >>$OUTPUT_FILE_ERR

	echo " ">>$OUTPUT_FILE_ERR
	TTS_VAL="ERRORS"

	echo '<tr>' >>$OUTPUT_FILE_HTML
	echo '<td align="left">' >>$OUTPUT_FILE_HTML
	echo '<font face="Arial" size="2"  color="blue"><b><u><a name="Section7">Tablespace Details: </a></b></u></font>' >>$OUTPUT_FILE_HTML
	echo '</td>' >>$OUTPUT_FILE_HTML
	echo '</tr>' >>$OUTPUT_FILE_HTML
	echo '<tr>' >>$OUTPUT_FILE_HTML
	echo '<td align="left">' >>$OUTPUT_FILE_HTML
	echo '<font face="Arial" size="1" color="black">' >>$OUTPUT_FILE_HTML
	echo '<pre>' >>$OUTPUT_FILE_HTML
	cat $LOGDIR/tablespace_temp.out >>$OUTPUT_FILE_HTML
	echo '</pre>' >>$OUTPUT_FILE_HTML
	echo '</font>' >>$OUTPUT_FILE_HTML
	echo '</td>' >>$OUTPUT_FILE_HTML
	echo '</tr>' >>$OUTPUT_FILE_HTML
	echo '<tr>' >>$OUTPUT_FILE_HTML
	echo '<td align="left">' >>$OUTPUT_FILE_HTML
	echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$OUTPUT_FILE_HTML
	echo '</td>' >>$OUTPUT_FILE_HTML
	echo '</tr>' >>$OUTPUT_FILE_HTML

	rm $LOGDIR/tablespace_temp.out
	fi

	echo "TTS_VAL: " $TTS_VAL >>$OUTPUT_FILE_VAL



	# Long running session Details

	LRT_STR=`grep -i "Long Running Session:" $LOGDIR/hc_sql.out |head -1`
	LRT_VAL=`echo $LRT_STR | awk '{print $4}' | sed -e 's/%//'`



	if [ "$LRT_VAL" = "Failing" ]
	then

	sqlplus -s  "/ as sysdba" << ENDSQL2
	set echo off pages 3000 lines 800 feedb off time off timi off trimsp on
	whenever sqlerror exit 7 rollback
	col machine for a20
	col event for a35
	col username for a18
	col osuser for a12
	col inst_id for a11
	set heading on
	col inst_id for 999999
	spool  $LOGDIR/longrunning_temp.out
	select inst_id,username,osuser, sid, serial#,sql_id, machine, event, last_call_et ela_sec, round(last_call_et/60) ela_min
	FROM gv\$session WHERE username is not null and sql_id is not null and status='ACTIVE' and last_call_et > $LongrunningThreshold
	/

	spool off
ENDSQL2

	echo " ">>$OUTPUT_FILE_ERR
	echo "Long Running Session Details">>$OUTPUT_FILE_ERR
	echo "=========================================================================================================">>$OUTPUT_FILE_ERR
	cat $LOGDIR/longrunning_temp.out >>$OUTPUT_FILE_ERR
	echo " ">>$OUTPUT_FILE_ERR
	LRT_VAL="ERRORS"

	echo '<tr>' >>$OUTPUT_FILE_HTML
	echo '<td align="left">' >>$OUTPUT_FILE_HTML
	echo '<font face="Arial" size="2"  color="blue"><b><u><a name="Section8">Long running Session Details: </a></b></u></font>' >>$OUTPUT_FILE_HTML
	echo '</td>' >>$OUTPUT_FILE_HTML
	echo '</tr>' >>$OUTPUT_FILE_HTML
	echo '<tr>' >>$OUTPUT_FILE_HTML
	echo '<td align="left">' >>$OUTPUT_FILE_HTML
	echo '<font face="Arial" size="1" color="black">' >>$OUTPUT_FILE_HTML
	echo '<pre>' >>$OUTPUT_FILE_HTML
	cat $LOGDIR/longrunning_temp.out >>$OUTPUT_FILE_HTML
	echo '</pre>' >>$OUTPUT_FILE_HTML
	echo '</font>' >>$OUTPUT_FILE_HTML
	echo '</td>' >>$OUTPUT_FILE_HTML
	echo '</tr>' >>$OUTPUT_FILE_HTML
	echo '<tr>' >>$OUTPUT_FILE_HTML
	echo '<td align="left">' >>$OUTPUT_FILE_HTML
	echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$OUTPUT_FILE_HTML
	echo '</td>' >>$OUTPUT_FILE_HTML
	echo '</tr>' >>$OUTPUT_FILE_HTML


	rm $LOGDIR/longrunning_temp.out
	fi
	echo "LRT_VAL: " $LRT_VAL >>$OUTPUT_FILE_VAL





	# Avg file I/O Read Details

	typeset -i AFIOR_VALUE=`cat $LOGDIR/hc_fileiostat.html|grep -i "<tr>"|wc -l`

	AFIOR_VALUE=AFIOR_VALUE-1
	if [ $AFIOR_VALUE  -gt 0 ]
	then
		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><b><u><a name="Section8a">Avg file I/O Read(ms) Details: </a></b></u></font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML
		echo '<tr>' >>$OUTPUT_FILE_HTML

		cat $LOGDIR/hc_fileiostat.html >>$OUTPUT_FILE_HTML

		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML
		AFIOR_VAL="ERRORS"

		rm $LOGDIR/hc_fileiostat.html
	fi
	echo "AFIOR_VAL: " $AFIOR_VAL >>$OUTPUT_FILE_VAL



	# Gather stats check

	typeset -i GSTATS_NULL_CNT=`cat $LOGDIR/hc_db_stats.out|wc -l`
	typeset -i GSTATS_OLD_CNT=`cat $LOGDIR/hc_db_stats_new.out|wc -l`

	cat /dev/null > $LOGDIR/hc_db_stats_temp.out

	if [ $GSTATS_NULL_CNT -gt 0 ]
	then
		echo " ">>$OUTPUT_FILE_ERR
		echo "=========================================================================================================">>$OUTPUT_FILE_ERR
		echo "Gather stats not run on below number of tables . Please check.">>$OUTPUT_FILE_ERR
		cat $LOGDIR/hc_db_stats.out >>$OUTPUT_FILE_ERR
		echo " ">>$OUTPUT_FILE_ERR
		GSTATS_CHK="ERRORS"

		echo '<tr>' >>$LOGDIR/hc_db_stats_temp.out
		echo '<td align="left">' >>$LOGDIR/hc_db_stats_temp.out
		echo '<font face="Arial" size="2" color="blue"><p>' >>$LOGDIR/hc_db_stats_temp.out
		echo "Gather stats not run on below number of tables." >>$LOGDIR/hc_db_stats_temp.out
		echo '</p></font>' >>$LOGDIR/hc_db_stats_temp.out
		echo '</td>' >>$LOGDIR/hc_db_stats_temp.out
		echo '</tr>' >>$LOGDIR/hc_db_stats_temp.out

		echo '<tr>' >>$LOGDIR/hc_db_stats_temp.out
		echo '<td align="left">' >>$LOGDIR/hc_db_stats_temp.out
		echo '<font face="Arial" size="1" color="black">' >>$LOGDIR/hc_db_stats_temp.out
		echo '<pre>' >>$LOGDIR/hc_db_stats_temp.out
		cat $LOGDIR/hc_db_stats.out >>$LOGDIR/hc_db_stats_temp.out
		echo '</pre>' >>$LOGDIR/hc_db_stats_temp.out
		echo '</font>' >>$LOGDIR/hc_db_stats_temp.out
		echo '</td>' >>$LOGDIR/hc_db_stats_temp.out
		echo '</tr>' >>$LOGDIR/hc_db_stats_temp.out
	fi

	if [ $GSTATS_OLD_CNT -gt 0 ]
	then
		echo " ">>$OUTPUT_FILE_ERR
		echo "=========================================================================================================">>$OUTPUT_FILE_ERR
		echo "Stale gather stats found on " $GSTATS_OLD_CNT " number of tables . Please check" >>$OUTPUT_FILE_ERR
		cat $LOGDIR/hc_db_stats_new.out >>$OUTPUT_FILE_ERR
		echo " ">>$OUTPUT_FILE_ERR
		GSTATS_CHK="ERRORS"

		echo '<tr>' >>$LOGDIR/hc_db_stats_temp.out
		echo '<td align="left">' >>$LOGDIR/hc_db_stats_temp.out
		echo '<font face="Arial" size="2" color="blue"><p>' >>$LOGDIR/hc_db_stats_temp.out
		echo 'Stale gather stats found on ' $GSTATS_OLD_CNT ' number of tables.' >>$LOGDIR/hc_db_stats_temp.out
		echo '</p></font>' >>$LOGDIR/hc_db_stats_temp.out
		echo '</td>' >>$LOGDIR/hc_db_stats_temp.out
		echo '</tr>' >>$LOGDIR/hc_db_stats_temp.out
		echo '<tr>' >>$LOGDIR/hc_db_stats_temp.out
		echo '<td align="left">' >>$LOGDIR/hc_db_stats_temp.out
		echo '<font face="Arial" size="1" color="black">' >>$LOGDIR/hc_db_stats_temp.out
		echo '<pre>' >>$LOGDIR/hc_db_stats_temp.out
		cat $LOGDIR/hc_db_stats_new.out >>$LOGDIR/hc_db_stats_temp.out
		echo '</pre>' >>$LOGDIR/hc_db_stats_temp.out
		echo '</font>' >>$LOGDIR/hc_db_stats_temp.out
		echo '</td>' >>$LOGDIR/hc_db_stats_temp.out
		echo '</tr>' >>$LOGDIR/hc_db_stats_temp.out
	fi

	if [ "$GSTATS_CHK" != "GOOD" ]
	then
		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><b><u><a name="Section9">Gather Stats Details: </a></u></b></font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML
		cat $LOGDIR/hc_db_stats_temp.out >>$OUTPUT_FILE_HTML
		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML
	fi

	echo "GSTATS_CHK: " $GSTATS_CHK >>$OUTPUT_FILE_VAL
	rm $LOGDIR/hc_db_stats_temp.out
	rm $LOGDIR/hc_db_stats.out
	rm $LOGDIR/hc_db_stats_new.out

	# Invalid object Check

	typeset -i INVALID_OBJ_CNT=`cat $LOGDIR/hc_db_invalidobj.out|wc -l`

	if [ $INVALID_OBJ_CNT -gt 0 ]
	then
		echo " ">>$OUTPUT_FILE_ERR
		echo "=========================================================================================================">>$OUTPUT_FILE_ERR
		echo " Invalid object(s) found. Please check.">>$OUTPUT_FILE_ERR
		cat $LOGDIR/hc_db_invalidobj.out >>$OUTPUT_FILE_ERR
		echo " ">>$OUTPUT_FILE_ERR
		INVOBJ_CHK="ERRORS"

		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><b><u><a name="Section10">Invalid object Details: </a></b></u></font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML
		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="1" color="black">' >>$OUTPUT_FILE_HTML
		echo '<pre>' >>$OUTPUT_FILE_HTML
		cat $LOGDIR/hc_db_invalidobj.out >>$OUTPUT_FILE_HTML
		echo '</pre>' >>$OUTPUT_FILE_HTML
		echo '</font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML
		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML


	fi
	echo "INVOBJ_CHK: " $INVOBJ_CHK >>$OUTPUT_FILE_VAL
	rm $LOGDIR/hc_db_invalidobj.out


	# Unusable Index Check

	typeset -i INDEX_CNT=`cat $LOGDIR/hc_db_index.out|wc -l`

	if [ $INDEX_CNT -gt 0 ]
	then
		INDEX_CNT=$INDEX_CNT-1
		echo " ">>$OUTPUT_FILE_ERR
		echo "=========================================================================================================">>$OUTPUT_FILE_ERR
		echo "Total " $INDEX_CNT " number of index(s) are unusable in the db. Please check.">>$OUTPUT_FILE_ERR
		cat $LOGDIR/hc_db_index.out >>$OUTPUT_FILE_ERR
		echo " ">>$OUTPUT_FILE_ERR
		INDEX_CHK="ERRORS"

		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><b><u><a name="Section11">Unusable Index Details: </a></b></u></font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML
		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="1" color="black">' >>$OUTPUT_FILE_HTML
		echo '<pre>' >>$OUTPUT_FILE_HTML
		cat $LOGDIR/hc_db_index.out >>$OUTPUT_FILE_HTML
		echo '</pre>' >>$OUTPUT_FILE_HTML
		echo '</font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML
		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML



	fi
	echo "INDEX_CHK: " $INDEX_CHK >>$OUTPUT_FILE_VAL
	rm $LOGDIR/hc_db_index.out


	# Disabled Constraints Check

	typeset -i CONSTRAINTS_CNT=`cat $LOGDIR/hc_db_constraints.out|wc -l`

	if [ $CONSTRAINTS_CNT -gt 0 ]
	then

		echo " ">>$OUTPUT_FILE_ERR
		echo "=========================================================================================================">>$OUTPUT_FILE_ERR
		echo "Few Constraints are in DISABLED status. Please check.">>$OUTPUT_FILE_ERR
		cat $LOGDIR/hc_db_constraints.out >>$OUTPUT_FILE_ERR
		echo " ">>$OUTPUT_FILE_ERR
		CONSTRAINTS_CHK="ERRORS"

		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><b><u><a name="Section12">Disabled Constraints Details: </a></b></u></font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML
		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="1" color="black">' >>$OUTPUT_FILE_HTML
		echo '<pre>' >>$OUTPUT_FILE_HTML
		cat $LOGDIR/hc_db_constraints.out >>$OUTPUT_FILE_HTML
		echo '</pre>' >>$OUTPUT_FILE_HTML
		echo '</font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML
		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML
	fi
	echo "CONSTRAINTS_CHK: " $CONSTRAINTS_CHK >>$OUTPUT_FILE_VAL
	rm $LOGDIR/hc_db_constraints.out



	# Blocking session Check

	typeset -i BLOCKING_SESS_CNT=`cat $LOGDIR/hc_db_blockingsess.out|wc -l`
	if [ $BLOCKING_SESS_CNT -gt 0 ]
	then
		BLOCKING_SESS_CNT=$BLOCKING_SESS_CNT-1
		echo " ">>$OUTPUT_FILE_ERR
		echo "=========================================================================================================">>$OUTPUT_FILE_ERR
		echo "Total " $BLOCKING_SESS_CNT " number of blocking session(s) found in the db. Please check.">>$OUTPUT_FILE_ERR

		cat $LOGDIR/hc_db_blockingsess.out >>$OUTPUT_FILE_ERR
		echo " ">>$OUTPUT_FILE_ERR
		BLOCKINGSESS_CHK="ERRORS"

		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><b><u><a name="Section5">Blocking Session Details: </a></b></u></font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML
		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="1" color="black">' >>$OUTPUT_FILE_HTML
		echo '<pre>' >>$OUTPUT_FILE_HTML
		cat $LOGDIR/hc_db_blockingsess.out >>$OUTPUT_FILE_HTML
		echo '</pre>' >>$OUTPUT_FILE_HTML
		echo '</font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML
		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML

	fi
	echo "BLOCKINGSESS_CHK: " $BLOCKINGSESS_CHK >>$OUTPUT_FILE_VAL
	rm $LOGDIR/hc_db_blockingsess.out


	## Archive log destination space usage
	ARCH_STR=`grep -i "Archive Log Destination:LOCATION=" $LOGDIR/hc_sql.out |head -1`
	typeset -i DBRFD_Chk=0
	if [ "x$ARCH_STR" = "x" ]
	then
		ARCDEST_VAL="No Archive Mode"
		echo "ARCDEST_VAL: " $ARCDEST_VAL >>$OUTPUT_FILE_VAL
		ARCH_HTML_STR="Database is running in No Archive Log mode"
	else
		ARCH_DEST_TMP=`echo $ARCH_STR | awk '{print $3}' | sed -e 's/%//'`
		typeset -i ARCH_DEST_TMP_CNT=${#ARCH_DEST_TMP}
		ARCH_DEST=`echo ${ARCH_DEST_TMP} | cut -c22-$ARCH_DEST_TMP_CNT`


		if [ "$ARCH_DEST" == "USE_DB_RECOVERY_FILE_DEST" ]
		then

			sqlplus -s  "/ as sysdba" << ENDSQL31
			set echo off pages 3000 lines 800 feedb off time off timi off trimsp on
			whenever sqlerror exit 7 rollback
			spool  $LOGDIR/hc_arch_DRFD1.out
			set head off
			SELECT 'DBRecovery File Destination:'||RTRIM(value) FROM v\$parameter WHERE NAME LIKE 'db_recovery_file_dest' AND VALUE IS NOT NULL ;
			spool off

			spool  $LOGDIR/hc_arch_DRFD2.out
			SELECT 'DBRecovery File Destsize(b):'||RTRIM(value) FROM v\$parameter WHERE NAME LIKE 'db_recovery_file_dest_size' AND VALUE IS NOT NULL ;
			spool off
ENDSQL31

			DBRFD_Chk=1

			ARCH_STR_NEW=`grep -i "DBRecovery File Destination:" $LOGDIR/hc_arch_DRFD1.out |head -1`
			ARCH_DEST_TMP=`echo $ARCH_STR_NEW | awk '{print $3}' | sed -e 's/%//'`
			typeset -i ARCH_DEST_TMP_CNT=${#ARCH_DEST_TMP}
			ARCH_DEST=`echo ${ARCH_DEST_TMP} | cut -c13-$ARCH_DEST_TMP_CNT`
			ARCH_ASM_CHK=`echo ${ARCH_DEST_TMP} | cut -c13`

			DBRFD_SIZE_STR=`grep -i "DBRecovery File Destsize(b):" $LOGDIR/hc_arch_DRFD2.out |head -1`
			DBRF_DEST_SIZE_TMP=`echo $DBRFD_SIZE_STR | awk '{print $3}' | sed -e 's/%//'`
			typeset -i DBRF_DEST_TMP_CNT=${#DBRF_DEST_SIZE_TMP}
			typeset -i DBRF_DEST_SIZE=`echo ${DBRF_DEST_SIZE_TMP} | cut -c13-$DBRF_DEST_TMP_CNT`
			typeset -i DBRF_DEST_SIZE_MB=$DBRF_DEST_SIZE/1024/1024


		else
			ARCH_ASM_CHK=`echo ${ARCH_DEST_TMP} | cut -c22`
		fi


		if [ "$ARCH_ASM_CHK" = "+" ]
		then
			ASM_CHK=1
			typeset -i ARCH_DEST_CNT=${#ARCH_DEST}

			ARCH_ASM_DG=`echo ${ARCH_DEST} | cut -c2-$ARCH_DEST_CNT`


			if [ $DBRFD_Chk == 1 ]
			then

				sqlplus -s  "/ as sysdba" << ENDSQL3
			set echo off pages 3000 lines 800 feedb off time off timi off trimsp on
			whenever sqlerror exit 7 rollback
			col machine for a25
			col event for a35
			col username for a30
			col osuser for a25
			spool  $LOGDIR/asm_arch_DG1.out
			set head off

			select 'Archive Log Destination free space Status:',case count(*) when 0 then 'GOOD' else 'Failing'
			end
			from
			(SELECT name,state, total_mb,free_mb, round(100-(free_mb/total_mb*100),2) as "%used"
			FROM v\$asm_diskgroup
			where name like '$ARCH_ASM_DG' and round(100-(free_mb/total_mb*100),2)> $ArchDestspaceThreshold
			)
			/
			spool off
			spool  $LOGDIR/asm_arch_DG2.out
			set head on
			SELECT name,state, total_mb,free_mb, round(100-(free_mb/total_mb*100),2) as "%used"   FROM v\$asm_diskgroup where name like '$ARCH_ASM_DG' ;

			spool off

			spool  $LOGDIR/asm_arch_DG3.out
			set head on
			SELECT name,state, total_mb,free_mb, round(100-(free_mb/total_mb*100),2) as "%used"   FROM v\$asm_diskgroup;

			spool off
ENDSQL3


		else


			sqlplus -s  "/ as sysdba" << ENDSQL3
			set echo off pages 3000 lines 800 feedb off time off timi off trimsp on
			whenever sqlerror exit 7 rollback
			col machine for a25
			col event for a35
			col username for a30
			col osuser for a25
			spool  $LOGDIR/asm_arch_DG1.out
			set head off

			select 'Archive Log Destination free space Status:',case count(*) when 0 then 'GOOD' else 'Failing'
			end
			from
			(SELECT name,state, total_mb,free_mb, round(100-(free_mb/total_mb*100),2) as "%used"
			FROM v\$asm_diskgroup
			where name like '$ARCH_ASM_DG' and round(100-(free_mb/total_mb*100),2)> $ArchDestspaceThreshold
			)
			/
			spool off
			spool  $LOGDIR/asm_arch_DG2.out
			set head on
			SELECT name,state, total_mb,free_mb, round(100-(free_mb/total_mb*100),2) as "%used"   FROM v\$asm_diskgroup where name like '$ARCH_ASM_DG' ;

			spool off

			spool  $LOGDIR/asm_arch_DG3.out
			set head on
			SELECT name,state, total_mb,free_mb, round(100-(free_mb/total_mb*100),2) as "%used"   FROM v\$asm_diskgroup;

			spool off
ENDSQL3

		fi

		ARCDEST_STR=`grep -i "Archive Log Destination free space Status:" $LOGDIR/asm_arch_DG1.out |head -1`
			ARCDEST_VAL=`echo $ARCDEST_STR | awk '{print $7}' | sed -e 's/%//'`
			if [ "$ARCDEST_VAL" = "Failing" ]
			then
				echo " ">>$OUTPUT_FILE_ERR
				echo "Archive Log Destination Space Details">>$OUTPUT_FILE_ERR
				echo "=========================================================================================================">>$OUTPUT_FILE_ERR
				cat $LOGDIR/asm_arch_DG1.out >>$OUTPUT_FILE_ERR
				echo " ">>$OUTPUT_FILE_ERR
				cat $LOGDIR/asm_arch_DG2.out >>$OUTPUT_FILE_ERR
				echo " ">>$OUTPUT_FILE_ERR
				ARCDEST_VAL="ERROR"

				ARCH_HTML_STR="Archive Log Destination used space is greater than threshold ("$ArchDestspaceThreshold"%).Details below,"
			else
				echo " ">>$OUTPUT_FILE_TOTAL
				echo "Archive Log Destination Space Details">>$OUTPUT_FILE_TOTAL
				echo "=========================================================================================================">>$OUTPUT_FILE_TOTAL
				cat $LOGDIR/asm_arch_DG1.out >>$OUTPUT_FILE_TOTAL
				echo " ">>$OUTPUT_FILE_TOTAL
				cat $LOGDIR/asm_arch_DG2.out >>$OUTPUT_FILE_TOTAL
				echo " ">>$OUTPUT_FILE_TOTAL

				echo " ">>$OUTPUT_FILE_ERR
				echo "ASM Diskgroup Space Details">>$OUTPUT_FILE_ERR
				echo "=========================================================================================================">>$OUTPUT_FILE_ERR
				cat $LOGDIR/asm_arch_DG2.out >>$OUTPUT_FILE_ERR
				echo " ">>$OUTPUT_FILE_ERR
				ARCDEST_VAL="GOOD"
			fi
			echo "ARCDEST_VAL: " $ARCDEST_VAL >>$OUTPUT_FILE_VAL

		elif [ "$ARCH_ASM_CHK" == "/" ]
		then
			ASM_CHK=0
			if [ $(uname -s | cut -c1-5) = "HP-UX" ];then
				OSLevel=$(uname -a |awk -F"." '{print $2}')
				if [ ${OSLevel} = 10 ];then
						Pct=$(df -k $ARCH_DEST | grep -vi "^filesys" | grep "%" | \
						awk '{if(NF != 6) print $1; else print $5;}'|cut -c1-2)
						ARCH_FREE_PCT="${Pct%%[%]}"
				fi
				OSLevel=$(uname -a |awk '{print substr($3,3,7)}')
				if [ ${OSLevel} = 11.11 ];then
						Pct=$(df -k $ARCH_DEST | grep "%" |awk '{print $1}')
						ARCH_FREE_PCT="${Pct%%[%]}"
				else
						Pct=$(df -k $ARCH_DEST | grep -vi "^filesys" | grep "%" | \
						awk '{if(NF != 6) print $4; else print $5;}'|cut -c1-2)
						ARCH_FREE_PCT="${Pct%%[%]}"
				fi
			else
				Pct=$(df -k $ARCH_DEST | grep -vi "^filesys" | grep "%" | \
						awk '{if(NF != 6) print $4; else print $5;}'|cut -c1-2)
				ARCH_FREE_PCT="${Pct%%[%]}"
			fi
			ARCH_FREE_PCT=${ARCH_FREE_PCT:-0}

			if [[ ${ARCH_FREE_PCT} -ge ${ArchDestspaceThreshold} ]];then
				echo " ">>$OUTPUT_FILE_ERR
				echo "=========================================================================================================">>$OUTPUT_FILE_ERR
				echo "Archive Log Destination free space Status: FAILED" >>$OUTPUT_FILE_ERR
				echo " ">>$OUTPUT_FILE_ERR
				ARCDEST_VAL="ERROR"
				ARCH_HTML_STR="Archive Log Destination free space ("$ARCH_FREE_PCT") is greater than threshold ($ArchDestspaceThreshold)"
			else
				echo " ">>$OUTPUT_FILE_TOTAL
				echo "Archive Log Destination Space Details">>$OUTPUT_FILE_TOTAL
				echo "=========================================================================================================">>$OUTPUT_FILE_TOTAL
				echo "Archive Log Destination free space Status: Good" >>$OUTPUT_FILE_TOTAL
				echo " ">>$OUTPUT_FILE_TOTAL
				ARCDEST_VAL="GOOD"
			fi
			echo "ARCDEST_VAL: " $ARCDEST_VAL >>$OUTPUT_FILE_VAL
		else
			ARCDEST_VAL="No Archive Mode"
			echo "ARCDEST_VAL: " $ARCDEST_VAL >>$OUTPUT_FILE_VAL
			ARCH_HTML_STR="Database is running in No Archive Log mode"
		fi
	fi
	if [ "$ARCDEST_VAL" != "GOOD" ]
	then
		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><b><u><a name="Section6">Archive log Destination Details: </a></b></u></font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML
		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="2" color="black">' >>$OUTPUT_FILE_HTML
		echo $ARCH_HTML_STR >>$OUTPUT_FILE_HTML
		echo '</font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML

		if [ "$ARCH_ASM_CHK" == "+" ]
		then
			echo '<tr>' >>$OUTPUT_FILE_HTML
			echo '<td align="left">' >>$OUTPUT_FILE_HTML
			echo '<font face="Arial" size="2" color="black"><pre>' >>$OUTPUT_FILE_HTML
			cat $LOGDIR/asm_arch_DG2.out >>$OUTPUT_FILE_HTML
			echo '</pre></font>' >>$OUTPUT_FILE_HTML
			echo '</td>' >>$OUTPUT_FILE_HTML
			echo '</tr>' >>$OUTPUT_FILE_HTML

			rm $LOGDIR/asm_arch_DG1.out
			rm $LOGDIR/asm_arch_DG2.out
			rm $LOGDIR/asm_arch_DG3.out
		fi
		echo '<tr>' >>$OUTPUT_FILE_HTML
		echo '<td align="left">' >>$OUTPUT_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$OUTPUT_FILE_HTML
		echo '</td>' >>$OUTPUT_FILE_HTML
		echo '</tr>' >>$OUTPUT_FILE_HTML
	fi

	echo " ">>$OUTPUT_FILE_ERR
	cat $LOGDIR/Top_sql_details.out>>$OUTPUT_FILE_ERR
	echo " ">>$OUTPUT_FILE_ERR


fi #end of RAC_MNODE_CHK =1





	OUTPUT_FILE_HTML_ALERTLOG="$LOGDIR/hc_alertlog_$hostname.out"
	cat /dev/null > $OUTPUT_FILE_HTML_ALERTLOG

	# GG Check
	if [ $GGCHK == 1 ]
	then
		typeset -i GG_MGR_PRC_CHK=`ps -ef|grep -i "$GG_HOME_PATH" |grep -i "./mgr" |grep -i "PARAMFILE"|wc -l`

		OUTPUT_FILE_HTML_GG="$LOGDIR/hc_gg_$hostname.out"
		cat /dev/null > $OUTPUT_FILE_HTML_GG
		if [ $GG_MGR_PRC_CHK == 1 ]
		then
			GGSCI_PATH_STR="$GG_HOME_PATH/ggsci"
			echo $GGSCI_PATH_STR

			$GGSCI_PATH_STR << EOF > $LOGDIR/gg_infoall_temp.log
info all
exit
EOF
			typeset -i ggk=0
			cat /dev/null > $LOGDIR/gg_infoall.log
			cat /dev/null > $LOGDIR/gg_infoall_running.log

			echo " " >>$OUTPUT_FILE_TOTAL
			cat $LOGDIR/gg_infoall_temp.log >>$OUTPUT_FILE_TOTAL
			echo " " >>$OUTPUT_FILE_TOTAL

			grep -i manager $LOGDIR/gg_infoall_temp.log >> $LOGDIR/gg_infoall.log
			grep -i extract $LOGDIR/gg_infoall_temp.log >> $LOGDIR/gg_infoall.log
			grep -i replicat $LOGDIR/gg_infoall_temp.log >> $LOGDIR/gg_infoall.log

			typeset -i Program_CNT=`cat $LOGDIR/gg_infoall.log|wc -l`
			if [ $Program_CNT == 0 ]
			then
				echo "Program_CNT : " $Program_CNT
				echo "=========================================================================================================">>$OUTPUT_FILE_ERR
				echo "GG Proecess are not running.Please check" >> $OUTPUT_FILE_ERR
				cat $LOGDIR/gg_infoall.log >>$OUTPUT_FILE_ERR
				echo " ">>$OUTPUT_FILE_ERR
				GGCHK_STATUS="ERRORS"

				echo '<tr>' >>$OUTPUT_FILE_HTML_GG
				echo '<td align="left">' >>$OUTPUT_FILE_HTML_GG
				echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_GG
				echo "GG Proecess are not running in "$hostname".Please check">>$OUTPUT_FILE_HTML_GG
				echo '</p></font>' >>$OUTPUT_FILE_HTML_GG
				echo '</td>' >>$OUTPUT_FILE_HTML_GG
				echo '</tr>' >>$OUTPUT_FILE_HTML_GG
			else
				typeset -i NOTRUN_CNT=`cat $LOGDIR/gg_infoall.log|grep -v "RUNNING"|wc -l`
				echo "NOTRUN_CNT " $NOTRUN_CNT
				if [ $NOTRUN_CNT -gt 0 ]
				then
					echo "NOTRUN_CNT " $NOTRUN_CNT
					echo "=========================================================================================================">>$OUTPUT_FILE_ERR
					echo " The below process(es) are not in RUNNING status.Please check">>$OUTPUT_FILE_ERR
					echo " ">>$OUTPUT_FILE_ERR
					echo "Program     Status      Group       Lag at Chkpt  Time Since Chkpt">>$OUTPUT_FILE_ERR
					echo " ">>$OUTPUT_FILE_ERR
					ggk=1
					GGCHK_STATUS="ERRORS"
					cat $LOGDIR/gg_infoall.log|grep -v "RUNNING">>$OUTPUT_FILE_ERR
					echo " ">>$OUTPUT_FILE_ERR

					echo '<tr>' >>$OUTPUT_FILE_HTML_GG
					echo '<td align="left">' >>$OUTPUT_FILE_HTML_GG
					echo '<font face="Arial" size="2" color="blue"><p>' >>$OUTPUT_FILE_HTML_GG
					echo " The below GG process(es) is/are not in RUNNING status in "$hostname".Please check">>$OUTPUT_FILE_HTML_GG
					echo '</p></font>' >>$OUTPUT_FILE_HTML_GG
					echo '</td>' >>$OUTPUT_FILE_HTML_GG
					echo '</tr>' >>$OUTPUT_FILE_HTML_GG

					echo '<tr>' >>$OUTPUT_FILE_HTML_GG
					echo '<td align="left">' >>$OUTPUT_FILE_HTML_GG
					echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_GG
					echo "Program     Status      Group       Lag at Chkpt  Time Since Chkpt">>$OUTPUT_FILE_HTML_GG
					echo '</p></font>' >>$OUTPUT_FILE_HTML_GG
					echo '</td>' >>$OUTPUT_FILE_HTML_GG
					echo '</tr>' >>$OUTPUT_FILE_HTML_GG

					echo '<tr>' >>$OUTPUT_FILE_HTML_GG
					echo '<td align="left">' >>$OUTPUT_FILE_HTML_GG
					echo '<font face="Arial" size="2" color="black"><pre>' >>$OUTPUT_FILE_HTML_GG
					cat $LOGDIR/gg_infoall.log|grep -v "RUNNING">>$OUTPUT_FILE_HTML_GG
					echo '</pre></font>' >>$OUTPUT_FILE_HTML_GG
					echo '</td>' >>$OUTPUT_FILE_HTML_GG
					echo '</tr>' >>$OUTPUT_FILE_HTML_GG

				fi

				cat $LOGDIR/gg_infoall.log|grep -i "RUNNING" |grep -v "MANAGER" > $LOGDIR/gg_infoall_running_temp.log
				sed 's/:/ /g' $LOGDIR/gg_infoall_running_temp.log > $LOGDIR/gg_infoall_running.log
				while read ggline
				do
					lag1=`echo $ggline | awk '{print $4}' | sed -e 's/%//'`
					lag2=`echo $ggline | awk '{print $5}' | sed -e 's/%//'`

					clag1=`echo $ggline | awk '{print $7}' | sed -e 's/%//'`
					clag2=`echo $ggline | awk '{print $8}' | sed -e 's/%//'`

					if [ $lag1 == "00" ] && [ $lag2 == "00" ] && [ $clag1 == "00" ] && [ $clag2 == "00" ]
					then
						ggstatus=1
					else
						if [ $ggk != 1 ]
						then
							echo "=========================================================================================================">>$OUTPUT_FILE_ERR
							echo " GoldenGate latency found in below process(es).Please check">>$OUTPUT_FILE_ERR
							echo "Program     Status      Group       Lag at Chkpt  Time Since Chkpt">>$OUTPUT_FILE_ERR
							echo " ">>$OUTPUT_FILE_ERR
							echo "$ggline" >>$OUTPUT_FILE_ERR
							ggk=1
							#07042015 GGCHK_STATUS="GG LATENCY FOUND"
							GGCHK_STATUS="ERRORS"
							echo '<tr>' >>$OUTPUT_FILE_HTML_GG
							echo '<td align="left">' >>$OUTPUT_FILE_HTML_GG
							echo '<font face="Arial" size="2" color="blue"><p>' >>$OUTPUT_FILE_HTML_GG
							echo " GoldenGate latency found in below process(es).Please check">>$OUTPUT_FILE_HTML_GG
							echo '</p></font>' >>$OUTPUT_FILE_HTML_GG
							echo '</td>' >>$OUTPUT_FILE_HTML_GG
							echo '</tr>' >>$OUTPUT_FILE_HTML_GG
							echo '<tr>' >>$OUTPUT_FILE_HTML_GG
							echo '<td align="left">' >>$OUTPUT_FILE_HTML_GG
							echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_GG
							echo "Program     Status      Group       Lag at Chkpt  Time Since Chkpt">>$OUTPUT_FILE_HTML_GG
							echo '</p></font>' >>$OUTPUT_FILE_HTML_GG
							echo '</td>' >>$OUTPUT_FILE_HTML_GG
							echo '</tr>' >>$OUTPUT_FILE_HTML_GG

							echo '<tr>' >>$OUTPUT_FILE_HTML_GG
							echo '<td align="left">' >>$OUTPUT_FILE_HTML_GG
							echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_GG
							echo "$ggline">>$OUTPUT_FILE_HTML_GG
							echo '</p></font>' >>$OUTPUT_FILE_HTML_GG
							echo '</td>' >>$OUTPUT_FILE_HTML_GG
							echo '</tr>' >>$OUTPUT_FILE_HTML_GG

						else
							echo "$ggline" >>$OUTPUT_FILE_ERR
							#07042015 GGCHK_STATUS="GG LATENCY FOUND"
							GGCHK_STATUS="ERRORS"
							echo '<tr>' >>$OUTPUT_FILE_HTML_GG
							echo '<td align="left">' >>$OUTPUT_FILE_HTML_GG
							echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_GG
							echo "$ggline">>$OUTPUT_FILE_HTML_GG
							echo '</p></font>' >>$OUTPUT_FILE_HTML_GG
							echo '</td>' >>$OUTPUT_FILE_HTML_GG
							echo '</tr>' >>$OUTPUT_FILE_HTML_GG
						fi
					fi
				done <$LOGDIR/gg_infoall_running.log
				echo " " >>$OUTPUT_FILE_ERR
			fi
			rm $LOGDIR/gg_infoall.log
			rm $LOGDIR/gg_infoall_running.log
			rm $LOGDIR/gg_infoall_running_temp.log
		    rm $LOGDIR/gg_infoall_temp.log

			# GG alert log checking

			export GG_LOG_PATH=$GG_HOME_PATH/ggserr.log
			if [ -f "$GG_LOG_PATH" ]
			then
				typeset -i GG_FIRST_DNUM
				typeset -i GG_TOTAL_LINES
				typeset -i GG_STARTING_LINE
				typeset -i GG_ORA_ALERT_CNT

				typeset  GG_LOG_ERROR="GOOD"

                               #GG_DATE_STAMP=`TZ=EST+30 date +%Y-%m-%d`
                                GG_DATE_STAMP=`TZ=EST date +%Y-%m-%d`

				GG_FIRST_DSTR=`grep -n "$GG_DATE_STAMP" $GG_LOG_PATH|head -1`
				GG_FIRST_DNUM=${GG_FIRST_DSTR%%:*}

				GG_TOTAL_LINES=`cat $GG_LOG_PATH|wc -l`
				GG_STARTING_LINE=$GG_TOTAL_LINES-$GG_FIRST_DNUM

				if [ $GG_STARTING_LINE == $GG_TOTAL_LINES ]
				then
					echo "=========================================================================================================">>$OUTPUT_FILE_ERR
					echo "GG ERROR LOG HAS NO DETAILS FOR  " $GG_DATE_STAMP>>$OUTPUT_FILE_ERR
					echo " " >>$OUTPUT_FILE_ERR
					GG_LOG_ERROR="NO DATA FOUND"

					ALERT_LOG_ERROR="ERRORS"

					echo '<tr>' >>$OUTPUT_FILE_HTML_ALERTLOG
					echo '<td align="left">' >>$OUTPUT_FILE_HTML_ALERTLOG
					echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_ALERTLOG
					echo "GG error log has No Detail for  "$GG_DATE_STAMP" in "$hostname >>$OUTPUT_FILE_HTML_ALERTLOG
					echo '</p></font>' >>$OUTPUT_FILE_HTML_ALERTLOG
					echo '</td>' >>$OUTPUT_FILE_HTML_ALERTLOG
					echo '</tr>' >>$OUTPUT_FILE_HTML_ALERTLOG
				else
					GG_ERR_CNT=`tail -$GG_STARTING_LINE $GG_LOG_PATH |grep -i "ERROR"|wc -l`

					if [ $GG_ERR_CNT -gt 0 ]
					then
						echo "=========================================================================================================">>$OUTPUT_FILE_ERR
						echo "GG ERROR LOG HAS " $GG_ERR_CNT " ERRORS ">>$OUTPUT_FILE_ERR
						echo "=========================================================================================================">>$OUTPUT_FILE_ERR
						echo " " >>$OUTPUT_FILE_ERR

						tail -$GG_STARTING_LINE $GG_LOG_PATH |grep -i "ERROR">>$OUTPUT_FILE_ERR
						GG_LOG_ERROR="ERRORS"

						ALERT_LOG_ERROR="ERRORS"
						echo '<tr>' >>$OUTPUT_FILE_HTML_ALERTLOG
						echo '<td align="left">' >>$OUTPUT_FILE_HTML_ALERTLOG
						echo '<font face="Arial" size="2" color="Blue"><p>' >>$OUTPUT_FILE_HTML_ALERTLOG
						echo "GG error log has "$GG_ERR_CNT" errors in.Details below" $hostname >>$OUTPUT_FILE_HTML_ALERTLOG
						echo '</p></font>' >>$OUTPUT_FILE_HTML_ALERTLOG
						echo '</td>' >>$OUTPUT_FILE_HTML_ALERTLOG
						echo '</tr>' >>$OUTPUT_FILE_HTML_ALERTLOG

						echo '<tr>' >>$OUTPUT_FILE_HTML_ALERTLOG
						echo '<td align="left">' >>$OUTPUT_FILE_HTML_ALERTLOG
						echo '<font face="Arial" size="2" color="black">' >>$OUTPUT_FILE_HTML_ALERTLOG
						echo '<pre>' >>$OUTPUT_FILE_HTML_ALERTLOG
						tail -$GG_STARTING_LINE $GG_LOG_PATH |grep -i "ERROR" >>$OUTPUT_FILE_HTML_ALERTLOG
						echo '</pre>' >>$OUTPUT_FILE_HTML_ALERTLOG
						echo '</font>' >>$OUTPUT_FILE_HTML_ALERTLOG
						echo '</td>' >>$OUTPUT_FILE_HTML_ALERTLOG
						echo '</tr>' >>$OUTPUT_FILE_HTML_ALERTLOG

					else
						echo "=========================================================================================================">>$OUTPUT_FILE_TOTAL
						echo "GG ERROR LOG HAS NO ERRORS ">>$OUTPUT_FILE_TOTAL
						echo " " >>$OUTPUT_FILE_TOTAL
					fi
				fi

			else
				echo " ">>$OUTPUT_FILE_ERR
				echo "=========================================================================================================">>$OUTPUT_FILE_ERR
				echo "GG Error log not found in defined path $GG_HOME_PATH. Please check." >>$OUTPUT_FILE_ERR
				echo " ">>$OUTPUT_FILE_ERR
				GG_LOG_ERROR="NOT FOUND"

				ALERT_LOG_ERROR="ERRORS"
				echo '<tr>' >>$OUTPUT_FILE_HTML_ALERTLOG
				echo '<td align="left">' >>$OUTPUT_FILE_HTML_ALERTLOG
				echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_ALERTLOG
				echo "GG Error log not found in defined path "$GG_HOME_PATH" in" $hostname >>$OUTPUT_FILE_HTML_ALERTLOG
				echo '</p></font>' >>$OUTPUT_FILE_HTML_ALERTLOG
				echo '</td>' >>$OUTPUT_FILE_HTML_ALERTLOG
				echo '</tr>' >>$OUTPUT_FILE_HTML_ALERTLOG

			fi
			echo "GG_LOG_ERROR: " $GG_LOG_ERROR >>$OUTPUT_FILE_VAL

			# GG alert log check ends
		else
			GGCHK_STATUS="ERRORS"
		fi
	fi # GG check
	echo "GGCHK_STATUS: " $GGCHK_STATUS >>$OUTPUT_FILE_VAL



# CPU idle Check


OUTPUT_FILE_HTML_CPU="$LOGDIR/hc_cpu_$hostname.out"
cat /dev/null > $OUTPUT_FILE_HTML_CPU

#CPU_IDLE_STR=`sar -u|tail -3|tail -1`
CPU_IDLE_STR=`sar -u 1 1|tail -3|tail -1`

CPU_IDLE=${CPU_IDLE_STR##* }
CPU_IDLE_CHK="GOOD"

if [ $CpuFreeThreshold -gt 100 ]
then
	echo " CPU idle threshold value should not be greater than 100.Please check" >>$OUTPUT_FILE_ERR
	CPU_IDLE="ERROR"
	CPU_IDLE_CHK="ERROR"
	echo '<tr>' >>$OUTPUT_FILE_HTML_CPU
	echo '<td align="left">' >>$OUTPUT_FILE_HTML_CPU
	echo '<font face="Arial" size="2" color="black">' >>$OUTPUT_FILE_HTML_CPU
	echo "CPU idle threshold value should not be greater than 100 in "$hostname".Please check" >>$OUTPUT_FILE_HTML_CPU
	echo '</font>' >>$OUTPUT_FILE_HTML_CPU
	echo '</td>' >>$OUTPUT_FILE_HTML_CPU
	echo '</tr>' >>$OUTPUT_FILE_HTML_CPU
else
	typeset -i CPU_VAL=100-$CpuFreeThreshold
	if [ $CPU_IDLE -lt $CpuFreeThreshold ]
	then
	 echo "=========================================================================================================">>$OUTPUT_FILE_ERR
	  echo "CPU IDLE PERCENTAGE  " $CPU_IDLE " IS lESSER THAN $CPU_VAL% |  Failed">>$OUTPUT_FILE_ERR
	  CPU_IDLE_CHK="ERROR"

		echo '<tr>' >>$OUTPUT_FILE_HTML_CPU
		echo '<td align="left">' >>$OUTPUT_FILE_HTML_CPU
		echo '<font face="Arial" size="2" color="black">' >>$OUTPUT_FILE_HTML_CPU
		echo "CPU Idle percentage  "$CPU_IDLE" is lesser than threshold("$CpuFreeThreshold"%) in "$hostname".Please check." >>$OUTPUT_FILE_HTML_CPU
		echo '</font>' >>$OUTPUT_FILE_HTML_CPU
		echo '</td>' >>$OUTPUT_FILE_HTML_CPU
		echo '</tr>' >>$OUTPUT_FILE_HTML_CPU

	else
	  echo "CPU IDLE PERCENTAGE " $CPU_IDLE " IS GREATER THAN $CPU_VAL% | Good">>$OUTPUT_FILE_TOTAL
	  echo "CPU Idle percentage "$CPU_IDLE" IS GREATER THAN $CPU_VAL% Good"  # need to remove this
	  CPU_IDLE_CHK="GOOD"
	fi

fi
echo "CPU_IDLE_CHK: " $CPU_IDLE_CHK >>$OUTPUT_FILE_VAL
echo "CPU_IDLE: " $CPU_IDLE >>$OUTPUT_FILE_VAL





###Get ORA- Error in alert log

if VerChk=1
then
	export ALERT_LOG_PATH=$ORACLE_BASE/diag/rdbms/${DBNAME}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log
else
	export ALERT_LOG_PATH=$AlertLogFixedPath
fi


if [ -f "$ALERT_LOG_PATH" ]
then
	typeset -i FIRST_DNUM
	typeset -i TOTAL_LINES
	typeset -i STARTING_LINE
	typeset -i ORA_ALERT_CNT
	typeset -i DBA_ALERT_CNT

	typeset  ALERT_LOG_ERROR="GOOD"

       #DATE_STAMP=`TZ=EST+30 date +%a" "%b" "%d`
       #YEAR_STAMP=`TZ=EST+30 date +%Y`
        DATE_STAMP=`TZ=EST date "+%Y-%m-%d"`
        YEAR_STAMP=`TZ=EST date +%Y`

	FIRST_DSTR=`grep -n "$DATE_STAMP" $ALERT_LOG_PATH|grep "$YEAR_STAMP" |head -1`
	FIRST_DNUM=${FIRST_DSTR%%:*}

	TOTAL_LINES=`cat $ALERT_LOG_PATH|wc -l`
	STARTING_LINE=$TOTAL_LINES-$FIRST_DNUM


	if [ $STARTING_LINE == $TOTAL_LINES ]
	then
		echo "=========================================================================================================">>$OUTPUT_FILE_ERR
		echo "ALERT LOG HAS NO DETAILS FOR  "$DATE_STAMP" "$YEAR_STAMP>>$OUTPUT_FILE_ERR
		echo " " >>$OUTPUT_FILE_ERR
		ALERT_LOG_ERROR="NO DATA FOUND"

		echo '<tr>' >>$OUTPUT_FILE_HTML_ALERTLOG
		echo '<td align="left">' >>$OUTPUT_FILE_HTML_ALERTLOG
		echo '<font face="Arial" size="2" color="black">' >>$OUTPUT_FILE_HTML_ALERTLOG
		echo "Database Alert Log has NO details for  "$DATE_STAMP" "$YEAR_STAMP " in "$hostname".Please check" >>$OUTPUT_FILE_HTML_ALERTLOG
		echo '</font>' >>$OUTPUT_FILE_HTML_ALERTLOG
		echo '</td>' >>$OUTPUT_FILE_HTML_ALERTLOG
		echo '</tr>' >>$OUTPUT_FILE_HTML_ALERTLOG

		if [ "$BKP_METHOD" = "VSU" ]
		then
			BKP_CHK="ERRORS"
		fi
	else
		#ORA_ALERT_CNT=`tail -$STARTING_LINE $ALERT_LOG_PATH |grep -i "ORA-"|grep -vi 2068|grep -vi 3135|grep -vi 00060|wc -l`
		#DBA_ALERT_CNT=`tail -$STARTING_LINE $ALERT_LOG_PATH |grep -i "DBA-"|grep -vi 2068|grep -vi 3135|grep -vi 00060|wc -l`
		ORA_ALERT_CNT=`tail -$STARTING_LINE $ALERT_LOG_PATH |grep -i "ORA-"|wc -l`
		DBA_ALERT_CNT=`tail -$STARTING_LINE $ALERT_LOG_PATH |grep -i "DBA-"|wc -l`


		if [[ $ORA_ALERT_CNT -gt 0  || $DBA_ALERT_CNT -gt 0 ]]
		then
			echo "=========================================================================================================">>$OUTPUT_FILE_ERR
			echo "ALERT LOG HAS " $ORA_ALERT_CNT " ORA ERRORS ">>$OUTPUT_FILE_ERR
			#<27-May-2015>echo "ALERT LOG HAS " $DBA_ALERT_CNT " DBA ERRORS ">>$OUTPUT_FILE_ERR
			echo "=========================================================================================================">>$OUTPUT_FILE_ERR
			echo " " >>$OUTPUT_FILE_ERR

			#tail -$STARTING_LINE $ALERT_LOG_PATH |grep -i "ORA-"|grep -vi 2068|grep -vi 3135|grep -vi 00060>>$OUTPUT_FILE_ERR
			tail -$STARTING_LINE $ALERT_LOG_PATH |grep -i "ORA-">>$OUTPUT_FILE_ERR

			echo '<tr>' >>$OUTPUT_FILE_HTML_ALERTLOG
			echo '<td align="left">' >>$OUTPUT_FILE_HTML_ALERTLOG
			echo '<font face="Arial" size="2" color="Blue"><p>' >>$OUTPUT_FILE_HTML_ALERTLOG
			echo "Database Alert Log has "$ORA_ALERT_CNT" ORA- errors in "$hostname >>$OUTPUT_FILE_HTML_ALERTLOG
			echo '</p></font>' >>$OUTPUT_FILE_HTML_ALERTLOG
			echo '</td>' >>$OUTPUT_FILE_HTML_ALERTLOG
			echo '</tr>' >>$OUTPUT_FILE_HTML_ALERTLOG

			echo '<tr>' >>$OUTPUT_FILE_HTML_ALERTLOG
			echo '<td align="left">' >>$OUTPUT_FILE_HTML_ALERTLOG
			echo '<font face="Arial" size="2" color="black">' >>$OUTPUT_FILE_HTML_ALERTLOG
			echo '<pre>' >>$OUTPUT_FILE_HTML_ALERTLOG
			#tail -$STARTING_LINE $ALERT_LOG_PATH |grep -i "ORA-"|grep -vi 2068|grep -vi 3135|grep -vi 00060 >>$OUTPUT_FILE_HTML_ALERTLOG
			tail -$STARTING_LINE $ALERT_LOG_PATH |grep -i "ORA-" >>$OUTPUT_FILE_HTML_ALERTLOG
			echo '</pre>' >>$OUTPUT_FILE_HTML_ALERTLOG
			echo '</font>' >>$OUTPUT_FILE_HTML_ALERTLOG
			echo '</td>' >>$OUTPUT_FILE_HTML_ALERTLOG
			echo '</tr>' >>$OUTPUT_FILE_HTML_ALERTLOG



			ALERT_LOG_ERROR="ERRORS"
		else
			echo "=========================================================================================================">>$OUTPUT_FILE_TOTAL
			echo "ALERT LOG HAS NO ORA ERRORS ">>$OUTPUT_FILE_TOTAL
			echo " " >>$OUTPUT_FILE_TOTAL
		fi

		#VSU backup check , based on alert log
		if [ "$BKP_METHOD" = "VSU" ]
		then
			typeset -i BKP_BEGIN_CNT=`tail -$STARTING_LINE $ALERT_LOG_PATH |grep -i "begin"|grep -i "backup"|grep -i "completed"|wc -l`
			typeset -i BKP_END_CNT=`tail -$STARTING_LINE $ALERT_LOG_PATH |grep -i "end"|grep -i "backup"|grep -i "completed"|wc -l`



			if [ $BKP_BEGIN_CNT -gt 0 ] && [ $BKP_END_CNT -gt 0 ]
			then
				echo " ">>$OUTPUT_FILE_TOTAL
				echo "=========================================================================================================">>$OUTPUT_FILE_TOTAL
				echo "DB alert log has begin and end backup statements"
				echo "DB alert log has begin and end backup statements" >>$OUTPUT_FILE_TOTAL
				echo " ">>$OUTPUT_FILE_TOTAL
				BKP_CHK="GOOD"
			else
				echo " ">>$OUTPUT_FILE_ERR
				echo "=========================================================================================================">>$OUTPUT_FILE_ERR
				echo "DB alert log does not have backup information. Please check." >>$OUTPUT_FILE_ERR
				echo " ">>$OUTPUT_FILE_ERR
				BKP_CHK="ERRORS"
			fi
		fi
	fi
else
	echo " ">>$OUTPUT_FILE_ERR
	echo "=========================================================================================================">>$OUTPUT_FILE_ERR
	echo "DB alert log not found in defined path $ALERT_LOG_PATH in "$hostname". Please check." >>$OUTPUT_FILE_ERR
	echo " ">>$OUTPUT_FILE_ERR
	ALERT_LOG_ERROR="NOT FOUND"

	echo '<tr>' >>$OUTPUT_FILE_HTML_ALERTLOG
	echo '<td align="left">' >>$OUTPUT_FILE_HTML_ALERTLOG
	echo '<font face="Arial" size="2" color="black">' >>$OUTPUT_FILE_HTML_ALERTLOG
	echo "DB alert log not found in defined path $ALERT_LOG_PATH in "$hostname". Please check." >>$OUTPUT_FILE_HTML_ALERTLOG
	echo '</font>' >>$OUTPUT_FILE_HTML_ALERTLOG
	echo '</td>' >>$OUTPUT_FILE_HTML_ALERTLOG
	echo '</tr>' >>$OUTPUT_FILE_HTML_ALERTLOG


	if [ "$BKP_METHOD" = "VSU" ]
	then
		BKP_CHK="ERRORS"
	fi
fi
echo "BKP_CHK: " $BKP_CHK >>$OUTPUT_FILE_VAL
#07-03-2015 echo "ALERT_LOG_ERROR: " $ALERT_LOG_ERROR >>$OUTPUT_FILE_VAL


if [ "$BKP_CHK" != "GOOD" ] && [ "$BKP_METHOD" = "RMAN" ]
then
	echo '<tr>' >>$OUTPUT_FILE_HTML
	echo '<td align="left">' >>$OUTPUT_FILE_HTML
	echo '<font face="Arial" size="2"  color="blue"><b><u><a name="Section17">Backup Details: </a></b></u></font>' >>$OUTPUT_FILE_HTML
	echo '</td>' >>$OUTPUT_FILE_HTML
	echo '</tr>' >>$OUTPUT_FILE_HTML
	echo '<tr>' >>$OUTPUT_FILE_HTML
	echo '<td align="left">' >>$OUTPUT_FILE_HTML
	echo '<font face="Arial" size="1" color="black">' >>$OUTPUT_FILE_HTML
	echo '<pre>' >>$OUTPUT_FILE_HTML
	cat $LOGDIR/hc_backup_status.out >>$OUTPUT_FILE_HTML
	echo '</pre>' >>$OUTPUT_FILE_HTML
	echo '</font>' >>$OUTPUT_FILE_HTML
	echo '</td>' >>$OUTPUT_FILE_HTML
	echo '</tr>' >>$OUTPUT_FILE_HTML
	echo '<tr>' >>$OUTPUT_FILE_HTML
	echo '<td align="left">' >>$OUTPUT_FILE_HTML
	echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$OUTPUT_FILE_HTML
	echo '</td>' >>$OUTPUT_FILE_HTML
	echo '</tr>' >>$OUTPUT_FILE_HTML
fi




###Get DB Service status in Listener log


OUTPUT_FILE_HTML_LISTENER="$LOGDIR/hc_listener_$hostname.out"
cat /dev/null > $OUTPUT_FILE_HTML_LISTENER

OUTPUT_FILE_TXT_LISTENER="$LOGDIR/hc_listener_txt_$hostname.out"
cat /dev/null > $OUTPUT_FILE_TXT_LISTENER


typeset  LISTENER_CHECK="GOOD"
typeset -i listen_Cnt=0

listener_func()
{

typeset LISTENER=$1

echo " listener name is : " $LISTENER

 LISTENER_STATUS=`lsnrctl stat $LISTENER |grep -i $ORACLE_SID |wc -l`

 typeset -i LSNR_CHK=0

	if [ $LISTENER_STATUS -gt 0 ]
	then
		LSNR_LOG_FULLPATH=`lsnrctl status $LISTENER|grep -i "Listener Log File"`
		LSNR_LOG_PATH=`echo $LSNR_LOG_FULLPATH | awk '{print $4}' | sed -e 's/%//'`
		typeset -i LSNR_LOG_PATH_TOTAL_CNT=`echo $LSNR_LOG_PATH|wc -m`
		typeset -i LSNR_LOG_PATH_EXT_STARTPOS=$LSNR_LOG_PATH_TOTAL_CNT-4
		LSNR_LOG_EXTN=`echo ${LSNR_LOG_PATH} | cut -c$LSNR_LOG_PATH_EXT_STARTPOS-$LSNR_LOG_PATH_TOTAL_CNT`

		if [ "$LSNR_LOG_EXTN" == ".log" ]
		then
			LSNR_ACTUAL_LOG_PATH=$LSNR_LOG_PATH
			LSNR_CHK=1

		elif [ "$LSNR_LOG_EXTN" == ".xml" ]
		then

			typeset -i LSNR_ACTUAL_LOG_PATH_SPOS=$LSNR_LOG_PATH_TOTAL_CNT-14
			LSNR_ACTUAL_LOG_PATH_TMP=`echo ${LSNR_LOG_PATH} | cut -c1-$LSNR_ACTUAL_LOG_PATH_SPOS`
			#LISTENER_NAME=$(echo $LISTENER|tr "[:upper:]" "[:lower:]")
			LISTENER_NAME=$(echo $LISTENER|tr "[A-Z]" "[a-z]")
			LSNR_ACTUAL_LOG_PATH=`echo $LSNR_ACTUAL_LOG_PATH_TMP"trace/"$LISTENER_NAME".log"`
			LSNR_CHK=1
		else
			LSNR_CHK=0
			listen_Cnt=$listen_Cnt+1
			echo '<tr>' >>$OUTPUT_FILE_HTML_LISTENER
			echo '<td align="left">' >>$OUTPUT_FILE_HTML_LISTENER
			echo '<font face="Courier New" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_LISTENER
			echo "Listener ("$LISTENER") log("$LSNR_LOG_PATH") is not in defined format.Please check." >>$OUTPUT_FILE_HTML_LISTENER
			echo '</p></font>' >>$OUTPUT_FILE_HTML_LISTENER
			echo '</td>' >>$OUTPUT_FILE_HTML_LISTENER
			echo '</tr>' >>$OUTPUT_FILE_HTML_LISTENER

			echo '<tr>' >>$OUTPUT_FILE_TXT_LISTENER
			echo '<td align="left">' >>$OUTPUT_FILE_TXT_LISTENER
			echo '<font face="Courier New" size="2" color="black"><p>' >>$OUTPUT_FILE_TXT_LISTENER
			echo "Listener ("$LISTENER") log("$LSNR_LOG_PATH") is not in defined format.Please check." >>$OUTPUT_FILE_TXT_LISTENER
			echo '</p></font>' >>$OUTPUT_FILE_TXT_LISTENER
			echo '</td>' >>$OUTPUT_FILE_TXT_LISTENER
			echo '</tr>' >>$OUTPUT_FILE_TXT_LISTENER


		fi

		if [ $LSNR_CHK == 1 ]
		then

			if [ -f "$LSNR_ACTUAL_LOG_PATH" ]
			then

				echo "actual path " $LSNR_ACTUAL_LOG_PATH

				typeset -i LSNR_FILESIZE=0
				LSNR_FILESIZE=$(ls -ltr $LSNR_ACTUAL_LOG_PATH | tr -s ' ' | cut -d ' ' -f 5)

				if [ $LSNR_FILESIZE -gt 1073741824 ]
				then

					echo '<tr>' >>$OUTPUT_FILE_HTML_LISTENER
					echo '<td align="left">' >>$OUTPUT_FILE_HTML_LISTENER
					echo '<font face="Courier New" size="2" color="red"><p>' >>$OUTPUT_FILE_HTML_LISTENER
					echo "Listener ("$LISTENER") log("$LSNR_ACTUAL_LOG_PATH") size is greater then 1GB.Please purge the listener logs." >>$OUTPUT_FILE_HTML_LISTENER
					echo '</p></font>' >>$OUTPUT_FILE_HTML_LISTENER
					echo '</td>' >>$OUTPUT_FILE_HTML_LISTENER
					echo '</tr>' >>$OUTPUT_FILE_HTML_LISTENER

					echo '<tr>' >>$OUTPUT_FILE_TXT_LISTENER
					echo '<td align="left">' >>$OUTPUT_FILE_TXT_LISTENER
					echo '<font face="Courier New" size="2" color="red"><p>' >>$OUTPUT_FILE_TXT_LISTENER
					echo "Listener ("$LISTENER") log("$LSNR_ACTUAL_LOG_PATH") size is greater then 1GB.Please purge the listener logs." >>$OUTPUT_FILE_TXT_LISTENER
					echo '</p></font>' >>$OUTPUT_FILE_TXT_LISTENER
					echo '</td>' >>$OUTPUT_FILE_TXT_LISTENER
					echo '</tr>' >>$OUTPUT_FILE_TXT_LISTENER


				fi


				typeset -i LSNR_FIRST_DNUM
				typeset -i LSNR_TOTAL_LINES
				typeset -i LSNR_STARTING_LINE
				typeset -i LSNR_ORA_ALERT_CNT

                               #LSNR_DATE_STAMP=`TZ=EST+30 date +%d-%b-%Y`
                                LSNR_DATE_STAMP=`TZ=EST date +%d-%b-%Y`
				#LSNR_DATE_STAMP=$(echo $LSNR_DATE_STAMP|tr "[:lower:]" "[:upper:]")
				LSNR_DATE_STAMP=$(echo $LSNR_DATE_STAMP|tr "[a-z]" "[A-Z]")


				LSNR_FIRST_DSTR=`grep -n "$LSNR_DATE_STAMP" $LSNR_ACTUAL_LOG_PATH|head -1`
				LSNR_FIRST_DSTR_CHK="x$LSNR_FIRST_DSTR"
				if [ "x$LSNR_FIRST_DSTR_CHK" = "x" ]; then
					listen_Cnt=$listen_Cnt+1
					echo '<tr>' >>$OUTPUT_FILE_HTML_LISTENER
					echo '<td align="left">' >>$OUTPUT_FILE_HTML_LISTENER
					echo '<font face="Courier New" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_LISTENER
					echo "Listener ("$LISTENER") log("$LSNR_ACTUAL_LOG_PATH") does not have details for the date" $LSNR_DATE_STAMP".Please check." >>$OUTPUT_FILE_HTML_LISTENER
					echo '</p></font>' >>$OUTPUT_FILE_HTML_LISTENER
					echo '</td>' >>$OUTPUT_FILE_HTML_LISTENER
					echo '</tr>' >>$OUTPUT_FILE_HTML_LISTENER

					echo '<tr>' >>$OUTPUT_FILE_TXT_LISTENER
					echo '<td align="left">' >>$OUTPUT_FILE_TXT_LISTENER
					echo '<font face="Courier New" size="2" color="black"><p>' >>$OUTPUT_FILE_TXT_LISTENER
					echo "Listener ("$LISTENER") log("$LSNR_ACTUAL_LOG_PATH") does not have details for the date" $LSNR_DATE_STAMP".Please check." >>$OUTPUT_FILE_TXT_LISTENER
					echo '</p></font>' >>$OUTPUT_FILE_TXT_LISTENER
					echo '</td>' >>$OUTPUT_FILE_TXT_LISTENER
					echo '</tr>' >>$OUTPUT_FILE_TXT_LISTENER


				else
					LSNR_FIRST_DNUM=${LSNR_FIRST_DSTR%%:*}

					LSNR_TOTAL_LINES=`cat $LSNR_ACTUAL_LOG_PATH|wc -l`
					LSNR_STARTING_LINE=$LSNR_TOTAL_LINES-$LSNR_FIRST_DNUM

					#ORA_ALERT_CNT=`tail -$LSNR_STARTING_LINE $LSNR_ACTUAL_LOG_PATH |grep -i "ORA-"|grep -vi 2068|grep -vi 3135|grep -vi 00060|wc -l`
					OUTPUT_FILE_TEMP_LISTENER="$LOGDIR/hc_listener_temp_"$LISTENER"_"$hostname".out"

					##cat -n $LSNR_ACTUAL_LOG_PATH|tail -$LSNR_STARTING_LINE|grep -i "TNS-" > $OUTPUT_FILE_TEMP_LISTENER
					tail -$LSNR_STARTING_LINE  $LSNR_ACTUAL_LOG_PATH > $OUTPUT_FILE_TEMP_LISTENER

					#awk '/WARNING:/{nr[NR]; nr[NR-1]}; NR in nr' $OUTPUT_FILE_TEMP_LISTENER > $OUTPUT_FILE_HTML_LISTENER

					#x=`awk '/Linux/{print NR+2}' file`



					typeset -i OUTPUT_FILE_TEMP_LISTENER_CNT=`cat $OUTPUT_FILE_TEMP_LISTENER|grep -i "TNS-"|wc -l`
					if [ $OUTPUT_FILE_TEMP_LISTENER_CNT -gt 0 ]
					then
						listen_Cnt=$listen_Cnt+1

						echo '<tr>' >>$OUTPUT_FILE_HTML_LISTENER
						echo '<td align="left">' >>$OUTPUT_FILE_HTML_LISTENER
						echo '<font face="Courier New" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_LISTENER
						echo " Listener("$LISTENER") log error details below :" >> $OUTPUT_FILE_HTML_LISTENER
						echo '</p></font>' >>$OUTPUT_FILE_HTML_LISTENER
						echo '</td>' >>$OUTPUT_FILE_HTML_LISTENER
						echo '</tr>' >>$OUTPUT_FILE_HTML_LISTENER

						echo '<tr>' >>$OUTPUT_FILE_HTML_LISTENER
						echo '<td align="left">' >>$OUTPUT_FILE_HTML_LISTENER
						echo '<font face="Courier New" size="2" color="black">' >>$OUTPUT_FILE_HTML_LISTENER
						echo '<pre>' >>$OUTPUT_FILE_HTML_ALERTLOG
						sed -n -e '/TNS-/{x;1!p;g;$!N;p;D;}' -e h  $OUTPUT_FILE_TEMP_LISTENER >> $OUTPUT_FILE_HTML_LISTENER
						echo '</pre>' >>$OUTPUT_FILE_HTML_LISTENER
						echo '</font>' >>$OUTPUT_FILE_HTML_LISTENER
						echo '</td>' >>$OUTPUT_FILE_HTML_LISTENER
						echo '</tr>' >>$OUTPUT_FILE_HTML_LISTENER


						echo '<tr>' >>$OUTPUT_FILE_TXT_LISTENER
						echo '<td align="left">' >>$OUTPUT_FILE_TXT_LISTENER
						echo '<font face="Courier New" size="2" color="black"><p>' >>$OUTPUT_FILE_TXT_LISTENER
						echo " Listener("$LISTENER") log error details below :" >> $OUTPUT_FILE_TXT_LISTENER
						echo '</p></font>' >>$OUTPUT_FILE_TXT_LISTENER
						echo '</td>' >>$OUTPUT_FILE_TXT_LISTENER
						echo '</tr>' >>$OUTPUT_FILE_TXT_LISTENER

						echo '<tr>' >>$OUTPUT_FILE_TXT_LISTENER
						echo '<td align="left">' >>$OUTPUT_FILE_TXT_LISTENER
						echo '<font face="Courier New" size="2" color="black">' >>$OUTPUT_FILE_TXT_LISTENER
						echo '<pre>' >>$OUTPUT_FILE_TXT_LISTENER
						echo "Listener ("$LISTENER") log("$LSNR_ACTUAL_LOG_PATH")  has "$OUTPUT_FILE_TEMP_LISTENER_CNT" errors for timestamp("$LSNR_DATE_STAMP") in $hostname.Please check."  >> $OUTPUT_FILE_TXT_LISTENER
						echo '</pre>' >>$OUTPUT_FILE_TXT_LISTENER
						echo '</font>' >>$OUTPUT_FILE_TXT_LISTENER
						echo '</td>' >>$OUTPUT_FILE_TXT_LISTENER
						echo '</tr>' >>$OUTPUT_FILE_TXT_LISTENER

					fi

				fi

			else
				listen_Cnt=$listen_Cnt+1
				echo '<tr>' >>$OUTPUT_FILE_HTML_LISTENER
				echo '<td align="left">' >>$OUTPUT_FILE_HTML_LISTENER
				echo '<font face="Courier New" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_LISTENER
				echo "Listener ("$LISTENER") log("$LSNR_ACTUAL_LOG_PATH")  not found in $hostname.Please check." >>$OUTPUT_FILE_HTML_LISTENER
				echo '</p></font>' >>$OUTPUT_FILE_HTML_LISTENER
				echo '</td>' >>$OUTPUT_FILE_HTML_LISTENER
				echo '</tr>' >>$OUTPUT_FILE_HTML_LISTENER

				echo '<tr>' >>$OUTPUT_FILE_TXT_LISTENER
				echo '<td align="left">' >>$OUTPUT_FILE_TXT_LISTENER
				echo '<font face="Courier New" size="2" color="black"><p>' >>$OUTPUT_FILE_TXT_LISTENER
				echo "Listener ("$LISTENER") log("$LSNR_ACTUAL_LOG_PATH")  not found in $hostname.Please check." >>$OUTPUT_FILE_TXT_LISTENER
				echo '</p></font>' >>$OUTPUT_FILE_TXT_LISTENER
				echo '</td>' >>$OUTPUT_FILE_TXT_LISTENER
				echo '</tr>' >>$OUTPUT_FILE_TXT_LISTENER

			fi

		fi
	else

		listen_Cnt=$listen_Cnt+1
		echo '<tr>' >>$OUTPUT_FILE_HTML_LISTENER
		echo '<td align="left">' >>$OUTPUT_FILE_HTML_LISTENER
		echo '<font face="Courier New" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_LISTENER
		echo "Listener ( "$LISTENER") status is failed for ORACLE_SID($ORACLE_SID) in "$hostname".Please check." >>$OUTPUT_FILE_HTML_LISTENER
		echo '</p></font>' >>$OUTPUT_FILE_HTML_LISTENER
		echo '</td>' >>$OUTPUT_FILE_HTML_LISTENER
		echo '</tr>' >>$OUTPUT_FILE_HTML_LISTENER

		echo '<tr>' >>$OUTPUT_FILE_TXT_LISTENER
		echo '<td align="left">' >>$OUTPUT_FILE_TXT_LISTENER
		echo '<font face="Courier New" size="2" color="black"><p>' >>$OUTPUT_FILE_TXT_LISTENER
		echo "Listener ( "$LISTENER") status is failed for ORACLE_SID($ORACLE_SID) in "$hostname".Please check." >>$OUTPUT_FILE_TXT_LISTENER
		echo '</p></font>' >>$OUTPUT_FILE_TXT_LISTENER
		echo '</td>' >>$OUTPUT_FILE_TXT_LISTENER
		echo '</tr>' >>$OUTPUT_FILE_TXT_LISTENER

	fi



} #listener_func



if [ $RACChk == 1 ]
then
	listener_func "LISTENER"
else
	cat $ORACLE_HOME/network/admin/listener.ora | grep = | grep -i '^listener'|grep -vi report| awk -F" " '{print $1}' | while read LISTENER_NAME
	do
		listener_func $LISTENER_NAME

	done
fi


if [ $listen_Cnt == 0 ]
then

 echo " ">>$OUTPUT_FILE_TOTAL
 echo "=========================================================================================================">>$OUTPUT_FILE_TOTAL
 echo "Listener_Status  | Good" >>$OUTPUT_FILE_TOTAL
 echo " ">>$OUTPUT_FILE_TOTAL
else
  echo " ">>$OUTPUT_FILE_ERR
  echo "=========================================================================================================">>$OUTPUT_FILE_ERR
  echo "Listener_Status | Failing" >>$OUTPUT_FILE_ERR

  echo " ">>$OUTPUT_FILE_ERR


  LISTENER_CHECK="ERROR"
fi


###Filesystem check

OUTPUT_FILE_HTML_FILESYSTEM="$LOGDIR/hc_fs_$hostname.out"
cat /dev/null > $OUTPUT_FILE_HTML_FILESYSTEM
typeset FS_CHK="GOOD"


if [ $(uname -s | cut -c1-3) = "Sun" ];then


	df -h | grep -iv filesystem | while read LINE; do PERC=`echo $LINE | awk '{print $5}' | sed -e 's/%//'`
		FS_NAME=`echo $LINE | awk '{print $6}' | sed -e 's/%//'`
		FS_OWNER=`ls -ld  $FS_NAME | awk '{print $3}' | sed -e 's/%//'`


		if [ $PERC -gt $FilesystemusedThreshold ]; then
			if [[ "$FS_NAME" == "/tmp"   ||  "$FS_NAME" == "/var"  ||  "$FS_NAME" == "/home" ]]
			then
				if [ "$FS_CHK" == "GOOD" ]
				then
					echo "=========================================================================================================">>$OUTPUT_FILE_ERR
				fi

				echo "The Filesystem ${FS_NAME} on `hostname -s` is "$PERC"% used" >>$OUTPUT_FILE_ERR
				FS_CHK="ERRORS"
				echo '<tr>' >>$OUTPUT_FILE_HTML_FILESYSTEM
				echo '<td align="left">' >>$OUTPUT_FILE_HTML_FILESYSTEM
				echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_FILESYSTEM
				echo "The Filesystem '"${FS_NAME}"' on `hostname -s` is "$PERC"% used" >>$OUTPUT_FILE_HTML_FILESYSTEM
				echo '</p></font>' >>$OUTPUT_FILE_HTML_FILESYSTEM
				echo '</td>' >>$OUTPUT_FILE_HTML_FILESYSTEM
				echo '</tr>' >>$OUTPUT_FILE_HTML_FILESYSTEM

			fi

			if [ "$FS_OWNER" = "oracle" ]
			then
				if echo $EXCLUDE_FS_LIST |grep ":$FS_NAME:"; then
				  k=1
				else
					if [ "$FS_CHK" == "GOOD" ]
					then
						echo "=========================================================================================================">>$OUTPUT_FILE_ERR
					fi
					echo "The Filesystem ${FS_NAME} on `hostname -s` is " $PERC "% used" >>$OUTPUT_FILE_ERR
					FS_CHK="ERRORS"
					echo '<tr>' >>$OUTPUT_FILE_HTML_FILESYSTEM
					echo '<td align="left">' >>$OUTPUT_FILE_HTML_FILESYSTEM
					echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_FILESYSTEM
					echo "The Filesystem '"${FS_NAME}"' on `hostname -s` is " $PERC "% used" >>$OUTPUT_FILE_HTML_FILESYSTEM
					echo '</p></font>' >>$OUTPUT_FILE_HTML_FILESYSTEM
					echo '</td>' >>$OUTPUT_FILE_HTML_FILESYSTEM
					echo '</tr>' >>$OUTPUT_FILE_HTML_FILESYSTEM
				fi
			fi
		fi
	done


else

	df -h | grep -iv filesystem | while read LINE;
	   do
	   FILENAME_TENP=$LINE
		tt=`echo $LINE |grep -i "%" |wc -l`
	   ####if [[ "$LINE" =~ "%" ]]; then
	   if [ $tt -gt 0 ]
	   then
		  FS_NAME=`echo $LINE | awk '{if(NF != 6) print $5; else print $6;}' | sed -e 's/%//'`
		  PERC=`echo $LINE | awk '{if(NF != 6) print $4; else print $5;}' | sed -e 's/%//'`
		  FS_OWNER=`ls -ld  $FS_NAME | awk '{print $3}' | sed -e 's/%//'`
		  if [ $PERC -gt $FilesystemusedThreshold ]; then
			if [[ "$FS_NAME" == "/tmp"   ||  "$FS_NAME" == "/var"  ||  "$FS_NAME" == "/home" ]]
			then
				if [ "$FS_CHK" == "GOOD" ]
				then
					echo "=========================================================================================================">>$OUTPUT_FILE_ERR
				fi
				echo "The Filesystem ${FS_NAME} on `hostname -s` is " $PERC "% used" >>$OUTPUT_FILE_ERR
				FS_CHK="ERRORS"
				echo '<tr>' >>$OUTPUT_FILE_HTML_FILESYSTEM
				echo '<td align="left">' >>$OUTPUT_FILE_HTML_FILESYSTEM
				echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_FILESYSTEM
				echo "The Filesystem '"${FS_NAME}"' on `hostname -s` is " $PERC "% used" >>$OUTPUT_FILE_HTML_FILESYSTEM
				echo '</p></font>' >>$OUTPUT_FILE_HTML_FILESYSTEM
				echo '</td>' >>$OUTPUT_FILE_HTML_FILESYSTEM
				echo '</tr>' >>$OUTPUT_FILE_HTML_FILESYSTEM
			fi

			if [ "$FS_OWNER" = "oracle" ]
			then
				if echo $EXCLUDE_FS_LIST |grep ":$FS_NAME:"; then
				  k=1
				else
					if [ "$FS_CHK" == "GOOD" ]
					then
						echo "=========================================================================================================">>$OUTPUT_FILE_ERR
					fi
					echo "The Filesystem ${FS_NAME} on `hostname -s` is " $PERC "% used" >>$OUTPUT_FILE_ERR
					FS_CHK="ERRORS"
					echo '<tr>' >>$OUTPUT_FILE_HTML_FILESYSTEM
					echo '<td align="left">' >>$OUTPUT_FILE_HTML_FILESYSTEM
					echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_FILESYSTEM
					echo "The Filesystem '"${FS_NAME}"' on `hostname -s` is " $PERC "% used" >>$OUTPUT_FILE_HTML_FILESYSTEM
					echo '</p></font>' >>$OUTPUT_FILE_HTML_FILESYSTEM
					echo '</td>' >>$OUTPUT_FILE_HTML_FILESYSTEM
					echo '</tr>' >>$OUTPUT_FILE_HTML_FILESYSTEM
				fi
			fi
		  fi
		fi
	 done
fi

echo "FS_CHK: " $FS_CHK >>$OUTPUT_FILE_VAL




# ASM alert log checking

if [ $RACChk == 1 ]
then

			ASM_PS_STR=`ps -ef|grep pmon|grep -i "asm"`
			if [ $(uname -s | cut -c1-3) = "Sun" ];then
				ASM_INST_STR=`echo $ASM_PS_STR | awk '{print $9}' | sed -e 's/%//'`
			else
				ASM_INST_STR=`echo $ASM_PS_STR | awk '{print $8}' | sed -e 's/%//'`
			fi

			typeset -i ASM_INST_TMP_CNT=${#ASM_INST_STR}
			ASM_INST=`echo ${ASM_INST_STR} | cut -c10-$ASM_INST_TMP_CNT`

			export ASM_ALERTLOG_PATH=$ASM_BASE/diag/asm/+asm/${ASM_INST}/trace/alert_${ASM_INST}.log
			ASM_RUNNING="GOOD"
else

	typeset -i ALERTLOG_ASM_STR_CNT=`cat $LOGDIR/hc_asm_check.out|wc -l`
	if [ $ALERTLOG_ASM_STR_CNT -gt 0 ]
	then
		ALERTLOG_ASM_STR=`cat $LOGDIR/hc_asm_check.out|head -1`
		ALERTLOG_ASM_CHK=`echo ${ALERTLOG_ASM_STR} | cut -c1`

		if [ "$ALERTLOG_ASM_CHK" = "+" ]
		then

			ASM_PS_STR=`ps -ef|grep pmon|grep -i "asm"`

			if [ $(uname -s | cut -c1-3) = "Sun" ];then

				ASM_INST_STR=`echo $ASM_PS_STR | awk '{print $9}' | sed -e 's/%//'`
			else
				ASM_INST_STR=`echo $ASM_PS_STR | awk '{print $8}' | sed -e 's/%//'`
			fi

			typeset -i ASM_INST_TMP_CNT=${#ASM_INST_STR}
			ASM_INST=`echo ${ASM_INST_STR} | cut -c10-$ASM_INST_TMP_CNT`

			export ASM_ALERTLOG_PATH=$ASM_BASE/diag/asm/+asm/${ASM_INST}/trace/alert_${ASM_INST}.log
			ASM_RUNNING="GOOD"
		else
			ASM_RUNNING="ERROR"
		fi
	fi

fi

if [ "$ASM_RUNNING" == "GOOD" ]
then

	if [ -f "$ASM_ALERTLOG_PATH" ]
	then
		typeset -i ASM_FIRST_DNUM
		typeset -i ASM_TOTAL_LINES
		typeset -i ASM_STARTING_LINE
		typeset -i ASM_ORA_ALERT_CNT

		typeset  ASM_LOG_ERROR="GOOD"

               #ASM_DATE_STAMP=`TZ=EST+30 date +%Y-%m-%d`
                ASM_DATE_STAMP=`TZ=EST date +%Y-%m-%d`

		ASM_FIRST_DSTR=`grep -n "$ASM_DATE_STAMP" $ASM_ALERTLOG_PATH|head -1`
		ASM_FIRST_DNUM=${ASM_FIRST_DSTR%%:*}

		ASM_TOTAL_LINES=`cat $ASM_ALERTLOG_PATH|wc -l`
		ASM_STARTING_LINE=$ASM_TOTAL_LINES-$ASM_FIRST_DNUM


		if [ $ASM_STARTING_LINE == $ASM_TOTAL_LINES ]
		then
			echo "=========================================================================================================">>$OUTPUT_FILE_ERR
			echo "ASM ALERT LOG HAS NO DETAILS FOR  " $ASM_DATE_STAMP>>$OUTPUT_FILE_ERR
			echo " " >>$OUTPUT_FILE_ERR
			ASM_LOG_ERROR="NO DATA FOUND"

		else
			ASM_ERR_CNT=`tail -$ASM_STARTING_LINE $ASM_ALERTLOG_PATH |grep -i "ORA-"|wc -l`



			if [ $ASM_ERR_CNT -gt 0 ]
			then
				echo "=========================================================================================================">>$OUTPUT_FILE_ERR
				echo "ASM ALERT LOG HAS " $ASM_ERR_CNT " ERRORS ">>$OUTPUT_FILE_ERR
				echo "=========================================================================================================">>$OUTPUT_FILE_ERR
				echo " " >>$OUTPUT_FILE_ERR

				tail -$ASM_STARTING_LINE $ASM_ALERTLOG_PATH |grep -i "ORA-">>$OUTPUT_FILE_ERR
				ASM_LOG_ERROR="ERRORS"

				ALERT_LOG_ERROR="ERRORS"
				echo '<tr>' >>$OUTPUT_FILE_HTML_ALERTLOG
				echo '<td align="left">' >>$OUTPUT_FILE_HTML_ALERTLOG
				echo '<font face="Arial" size="2" color="Blue"><p>' >>$OUTPUT_FILE_HTML_ALERTLOG
				echo "ASM alert log has "$ASM_ERR_CNT" errors in "$hostname".Details below"  >>$OUTPUT_FILE_HTML_ALERTLOG
				echo '</p></font>' >>$OUTPUT_FILE_HTML_ALERTLOG
				echo '</td>' >>$OUTPUT_FILE_HTML_ALERTLOG
				echo '</tr>' >>$OUTPUT_FILE_HTML_ALERTLOG

				echo '<tr>' >>$OUTPUT_FILE_HTML_ALERTLOG
				echo '<td align="left">' >>$OUTPUT_FILE_HTML_ALERTLOG
				echo '<font face="Arial" size="2" color="black">' >>$OUTPUT_FILE_HTML_ALERTLOG
				echo '<pre>' >>$OUTPUT_FILE_HTML_ALERTLOG
				tail -$ASM_STARTING_LINE $ASM_ALERTLOG_PATH |grep -i "ORA-" >>$OUTPUT_FILE_HTML_ALERTLOG
				echo '</pre>' >>$OUTPUT_FILE_HTML_ALERTLOG
				echo '</font>' >>$OUTPUT_FILE_HTML_ALERTLOG
				echo '</td>' >>$OUTPUT_FILE_HTML_ALERTLOG
				echo '</tr>' >>$OUTPUT_FILE_HTML_ALERTLOG

			else
				echo "=========================================================================================================">>$OUTPUT_FILE_TOTAL
				echo "ASM ALERT LOG HAS NO ERRORS ">>$OUTPUT_FILE_TOTAL
				echo " " >>$OUTPUT_FILE_TOTAL
			fi
		fi

	else
		echo " ">>$OUTPUT_FILE_ERR
		echo "=========================================================================================================">>$OUTPUT_FILE_ERR
		echo "ASM alert log not found in defined path $ASM_ALERTLOG_PATH. Please check." >>$OUTPUT_FILE_ERR
		echo " ">>$OUTPUT_FILE_ERR
		ASM_LOG_ERROR="NOT FOUND"

		ALERT_LOG_ERROR="ERRORS"
		echo '<tr>' >>$OUTPUT_FILE_HTML_ALERTLOG
		echo '<td align="left">' >>$OUTPUT_FILE_HTML_ALERTLOG
		echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_ALERTLOG
		echo "ASM alert log not found in defined path "$ASM_ALERTLOG_PATH" in" $hostname >>$OUTPUT_FILE_HTML_ALERTLOG
		echo '</p></font>' >>$OUTPUT_FILE_HTML_ALERTLOG
		echo '</td>' >>$OUTPUT_FILE_HTML_ALERTLOG
		echo '</tr>' >>$OUTPUT_FILE_HTML_ALERTLOG

	fi
	echo "ASM_LOG_ERROR: " $ASM_LOG_ERROR >>$OUTPUT_FILE_VAL

fi




# Cluster Check



if [ $RACChk == 1 ]
then
	CRS_CHK_STATUS="GOOD"
	CRS_STATUS="GOOD"
	SVC_STATUS="GOOD"
	typeset -i Service_Failure_Chk=0

	OUTPUT_FILE_HTML_RAC="$LOGDIR/hc_rac_$hostname.out"
	cat /dev/null > $OUTPUT_FILE_HTML_RAC

	OUTPUT_FILE_HTML_SVC="$LOGDIR/hc_svc_$hostname.out"
	cat /dev/null > $OUTPUT_FILE_HTML_SVC


	CRS_RUNNING=`ps -ef|grep -i crsd.bin|grep -i reboot|wc -l`
	if [ $CRS_RUNNING == 0 ]
	then

		echo " CRS is Not running . Please check">>$OUTPUT_FILE_ERR
		CRS_STATUS="ERRORS"
		CRS_CHK_STATUS="ERRORS"

		echo '<tr>' >>$OUTPUT_FILE_HTML_RAC
		echo '<td align="left">' >>$OUTPUT_FILE_HTML_RAC
		echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_RAC
		echo "CRS is Not running in "$hostname".Please check.">>$OUTPUT_FILE_HTML_RAC
		echo '</p></font>' >>$OUTPUT_FILE_HTML_RAC
		echo '</td>' >>$OUTPUT_FILE_HTML_RAC
		echo '</tr>' >>$OUTPUT_FILE_HTML_RAC

	else

		CRS_STR=`ps -ef|grep -i crsd.bin|grep -i reboot`

		if [ $(uname -s | cut -c1-3) = "Sun" ];then

			CRS_HOME_STR=`echo $CRS_STR | awk '{print $9}' | sed -e 's/%//'`
		else
			CRS_HOME_STR=`echo $CRS_STR | awk '{print $8}' | sed -e 's/%//'`
		fi



		typeset -i CRS_HOME_STR_CNT=`echo $CRS_HOME_STR | wc -m`
		typeset -i CRS_HOME_STR_END_POS=$CRS_HOME_STR_CNT-14

		CRS_HOME=$(echo ${CRS_HOME_STR} | cut -c-$CRS_HOME_STR_END_POS)

		export CRS_HOME=$CRS_HOME
		export PATH=$PATH:$CRS_HOME/bin

		crsctl check crs > $LOGDIR/hc_crs.out
		cat $LOGDIR/hc_crs.out >>$OUTPUT_FILE_TOTAL

		CRS_HA_CHK=`cat $LOGDIR/hc_crs.out|grep -i "CRS-4638: Oracle High Availability Services is online" |wc -l `
		CRS_CRS_CHK=`cat $LOGDIR/hc_crs.out|grep -i "CRS-4537: Cluster Ready Services is online" |wc -l `
		CRS_CSS_CHK=`cat $LOGDIR/hc_crs.out|grep -i "CRS-4529: Cluster Synchronization Services is online" |wc -l `
		CRS_EM_CHK=`cat $LOGDIR/hc_crs.out|grep -i "CRS-4533: Event Manager is online" |wc -l `


		if [ $CRS_HA_CHK != 1 ]
		then
			CRS_STATUS="ERRORS"
			CRS_CHK_STATUS="ERRORS"
			echo "Oracle High Availability Services is not running in `hostname -s`" >>$OUTPUT_FILE_ERR

			echo '<tr>' >>$OUTPUT_FILE_HTML_RAC
			echo '<td align="left">' >>$OUTPUT_FILE_HTML_RAC
			echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_RAC
			echo "Oracle High Availability Services is not running in "$hostname".Please check.">>$OUTPUT_FILE_HTML_RAC
			echo '</p></font>' >>$OUTPUT_FILE_HTML_RAC
			echo '</td>' >>$OUTPUT_FILE_HTML_RAC
			echo '</tr>' >>$OUTPUT_FILE_HTML_RAC

		fi

		if [ $CRS_CRS_CHK != 1 ]
		then
			CRS_STATUS="ERRORS"
			CRS_CHK_STATUS="ERRORS"
			echo "Oracle High Cluster Ready Services is not running in `hostname -s`" >>$OUTPUT_FILE_ERR
			echo '<tr>' >>$OUTPUT_FILE_HTML_RAC
			echo '<td align="left">' >>$OUTPUT_FILE_HTML_RAC
			echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_RAC
			echo "Oracle High Cluster Ready Services is not running in "$hostname".Please check.">>$OUTPUT_FILE_HTML_RAC
			echo '</p></font>' >>$OUTPUT_FILE_HTML_RAC
			echo '</td>' >>$OUTPUT_FILE_HTML_RAC
			echo '</tr>' >>$OUTPUT_FILE_HTML_RAC
		fi
		if [ $CRS_CSS_CHK != 1 ]
		then
			CRS_STATUS="ERRORS"
			CRS_CHK_STATUS="ERRORS"
			echo "Oracle Cluster Synchronization Services is not running in `hostname -s`" >>$OUTPUT_FILE_ERR

			echo '<tr>' >>$OUTPUT_FILE_HTML_RAC
			echo '<td align="left">' >>$OUTPUT_FILE_HTML_RAC
			echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_RAC
			echo "Oracle Cluster Synchronization Services is not running in "$hostname".Please check.">>$OUTPUT_FILE_HTML_RAC
			echo '</p></font>' >>$OUTPUT_FILE_HTML_RAC
			echo '</td>' >>$OUTPUT_FILE_HTML_RAC
			echo '</tr>' >>$OUTPUT_FILE_HTML_RAC

		fi
		if [ $CRS_EM_CHK != 1 ]
		then
			CRS_STATUS="ERRORS"
			CRS_CHK_STATUS="ERRORS"
			echo "Oracle Event Manager is not running in `hostname -s`" >>$OUTPUT_FILE_ERR

			echo '<tr>' >>$OUTPUT_FILE_HTML_RAC
			echo '<td align="left">' >>$OUTPUT_FILE_HTML_RAC
			echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_RAC
			echo "Oracle Event Manager is not running in "$hostname".Please check.">>$OUTPUT_FILE_HTML_RAC
			echo '</p></font>' >>$OUTPUT_FILE_HTML_RAC
			echo '</td>' >>$OUTPUT_FILE_HTML_RAC
			echo '</tr>' >>$OUTPUT_FILE_HTML_RAC
		fi
		rm $LOGDIR/hc_crs.out



		# CRS alert log checking
		if [ $DBVersion -gt 11 ]
		then
			export CRS_LOG_PATH=$ORACLE_BASE/diag/crs/$hostname/crs/trace/alert.log
		else
			export CRS_LOG_PATH=$CRS_HOME/log/$hostname/"alert"$hostname.log
		fi




		if [ -f "$CRS_LOG_PATH" ]
		then
			typeset -i CRS_FIRST_DNUM
			typeset -i CRS_TOTAL_LINES
			typeset -i CRS_STARTING_LINE
			typeset -i CRS_ORA_ALERT_CNT

			typeset  CRS_LOG_ERROR="GOOD"

                       #CRS_DATE_STAMP=`TZ=EST+30 date +%Y-%m-%d`
                        CRS_DATE_STAMP=`TZ=EST date +%Y-%m-%d`

			CRS_FIRST_DSTR=`grep -n "$CRS_DATE_STAMP" $CRS_LOG_PATH|head -1`
			CRS_FIRST_DNUM=${CRS_FIRST_DSTR%%:*}

			CRS_TOTAL_LINES=`cat $CRS_LOG_PATH|wc -l`
			CRS_STARTING_LINE=$CRS_TOTAL_LINES-$CRS_FIRST_DNUM


			if [ $CRS_STARTING_LINE == $CRS_TOTAL_LINES ]
			then
				echo "=========================================================================================================">>$OUTPUT_FILE_ERR
				echo "CRS ALERT LOG HAS NO DETAILS FOR  " $CRS_DATE_STAMP>>$OUTPUT_FILE_ERR
				echo " " >>$OUTPUT_FILE_ERR
				CRS_LOG_ERROR="NO DATA FOUND"


			else
				CRS_ERR_CNT=`tail -$CRS_STARTING_LINE $CRS_LOG_PATH |grep -i "CRS-"|grep -v "CRS-2409"|wc -l`


				if [ $CRS_ERR_CNT -gt 0 ]
				then
					echo "=========================================================================================================">>$OUTPUT_FILE_ERR
					echo "CRS ALERT LOG HAS " $CRS_ERR_CNT " ERRORS ">>$OUTPUT_FILE_ERR
					echo "=========================================================================================================">>$OUTPUT_FILE_ERR
					echo " " >>$OUTPUT_FILE_ERR

					tail -$CRS_STARTING_LINE $CRS_LOG_PATH |grep -i "CRS-"|grep -v "CRS-2409">>$OUTPUT_FILE_ERR
					CRS_LOG_ERROR="ERRORS"
					ALERT_LOG_ERROR="ERRORS"

					echo '<tr>' >>$OUTPUT_FILE_HTML_ALERTLOG
					echo '<td align="left">' >>$OUTPUT_FILE_HTML_ALERTLOG
					echo '<font face="Arial" size="2" color="Blue"><p>' >>$OUTPUT_FILE_HTML_ALERTLOG
					echo "CRS Alert Log has "$CRS_ERR_CNT" errors in "$hostname >>$OUTPUT_FILE_HTML_ALERTLOG
					echo '</p></font>' >>$OUTPUT_FILE_HTML_ALERTLOG
					echo '</td>' >>$OUTPUT_FILE_HTML_ALERTLOG
					echo '</tr>' >>$OUTPUT_FILE_HTML_ALERTLOG

					echo '<tr>' >>$OUTPUT_FILE_HTML_ALERTLOG
					echo '<td align="left">' >>$OUTPUT_FILE_HTML_ALERTLOG
					echo '<font face="Arial" size="2" color="black">' >>$OUTPUT_FILE_HTML_ALERTLOG
					echo '<pre>' >>$OUTPUT_FILE_HTML_ALERTLOG
					tail -$CRS_STARTING_LINE $CRS_LOG_PATH |grep -i "CRS-"|grep -v "CRS-2409" >>$OUTPUT_FILE_HTML_ALERTLOG
					echo '</pre>' >>$OUTPUT_FILE_HTML_ALERTLOG
					echo '</font>' >>$OUTPUT_FILE_HTML_ALERTLOG
					echo '</td>' >>$OUTPUT_FILE_HTML_ALERTLOG
					echo '</tr>' >>$OUTPUT_FILE_HTML_ALERTLOG



				else
					echo "=========================================================================================================">>$OUTPUT_FILE_TOTAL
					echo "CRS ALERT LOG HAS NO ERRORS ">>$OUTPUT_FILE_TOTAL
					echo " " >>$OUTPUT_FILE_TOTAL
				fi
			fi

		else
			echo " ">>$OUTPUT_FILE_ERR
			echo "=========================================================================================================">>$OUTPUT_FILE_ERR
			echo "CRS Alert log not found in defined path $CRS_LOG_PATH. Please check." >>$OUTPUT_FILE_ERR
			echo " ">>$OUTPUT_FILE_ERR
			CRS_LOG_ERROR="NOT FOUND"
			ALERT_LOG_ERROR="ERRORS"
			echo '<tr>' >>$OUTPUT_FILE_HTML_ALERTLOG
			echo '<td align="left">' >>$OUTPUT_FILE_HTML_ALERTLOG
			echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_ALERTLOG
			echo "CRS Alert log not found in defined path "$CRS_LOG_PATH" in "$hostname". Please check." >>$OUTPUT_FILE_HTML_ALERTLOG
			echo '</p></font>' >>$OUTPUT_FILE_HTML_ALERTLOG
			echo '</td>' >>$OUTPUT_FILE_HTML_ALERTLOG
			echo '</tr>' >>$OUTPUT_FILE_HTML_ALERTLOG

		fi
		echo "CRS_LOG_ERROR: " $CRS_LOG_ERROR >>$OUTPUT_FILE_VAL
		echo "ALERT_LOG_ERROR: " $ALERT_LOG_ERROR >>$OUTPUT_FILE_VAL


		# CRS alert log check ends



		# SCAN Listener service Check starts

		export ORACLE_HOME_old=$ORACLE_HOME
		export ORACLE_HOME=$CRS_HOME
		export PATH=$ORACLE_HOME/bin:$PATH

		#srvctl config database -d $DBNAME|grep -i "services:" > $LOGDIR/DBservices.out
		srvctl config database -d $DBNAME|grep "Services:" > $LOGDIR/DBservices.out
		srvctl status scan_listener|grep -i "$hostname" >$LOGDIR/scanlistenerstatus.out

		echo " " >>$OUTPUT_FILE_TOTAL
		cat $LOGDIR/scanlistenerstatus.out>>$OUTPUT_FILE_TOTAL
		echo " ">>$OUTPUT_FILE_TOTAL

		typeset -i Service_Cnt=`cat $LOGDIR/DBservices.out|wc -l`
		typeset -i Scanlistener_Cnt=`cat $LOGDIR/scanlistenerstatus.out|wc -l`

		if [ $Service_Cnt == 1 ]
		then
			ACTUAL_SERVICE_STR=`cat $LOGDIR/DBservices.out`
			ACTUAL_SERVICE_CHK=`echo $ACTUAL_SERVICE_STR | awk '{print $2}' | sed -e 's/%//'`
			if [ "x$ACTUAL_SERVICE_CHK" = "x" ]; then
				echo "Service Not Running" >>$OUTPUT_FILE_ERR
				Service_Failure_Chk=1
			fi
		fi

		if [ $Service_Failure_Chk == 0 ]
		then
			echo " ">>$OUTPUT_FILE_ERR
			while read ScanListenerLine
			do



				Listener_Name=`echo $ScanListenerLine | awk '{print $3}' | sed -e 's/%//'`
				listener_func $Listener_Name

				lsnrctl status $Listener_Name>$LOGDIR/ListnerStatuslog$Listener_Name.out
				if [ $Service_Cnt -gt 0 ]
				then
					TotalServices_old=`cat $LOGDIR/DBservices.out`
					typeset -i TotSerCnt_old=`echo $TotalServices_old | wc -m`
					cut -c11-$TotSerCnt_old $LOGDIR/DBservices.out | sed -n 1'p' | tr ',' '\n' | while read ServiceName_old; do


						typeset -i ExactServiceChk_Cnt=`cat $LOGDIR/ListnerStatuslog$Listener_Name.out|grep -i "$ServiceName_old"|wc -l`

						if [ $ExactServiceChk_Cnt == 0 ]
						then
							echo " Service $ServiceName_old is not running in $Listener_Name. Please check" >>$OUTPUT_FILE_ERR
							LISTENER_CHECK="ERROR"
							echo '<tr>' >>$OUTPUT_FILE_HTML_LISTENER
							echo '<td align="left">' >>$OUTPUT_FILE_HTML_LISTENER
							echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_LISTENER
							echo "Service "$ServiceName_old" is not running in "$Listener_Name" in "$hostname". Please check" >>$OUTPUT_FILE_HTML_LISTENER
							echo '</p></font>' >>$OUTPUT_FILE_HTML_LISTENER
							echo '</td>' >>$OUTPUT_FILE_HTML_LISTENER
							echo '</tr>' >>$OUTPUT_FILE_HTML_LISTENER

							echo '<tr>' >>$OUTPUT_FILE_TXT_LISTENER
							echo '<td align="left">' >>$OUTPUT_FILE_TXT_LISTENER
							echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_TXT_LISTENER
							echo "Service "$ServiceName_old" is not running in "$Listener_Name" in "$hostname". Please check" >>$OUTPUT_FILE_TXT_LISTENER
							echo '</p></font>' >>$OUTPUT_FILE_TXT_LISTENER
							echo '</td>' >>$OUTPUT_FILE_TXT_LISTENER
							echo '</tr>' >>$OUTPUT_FILE_TXT_LISTENER



						fi

					done
				fi
				rm $LOGDIR/ListnerStatuslog$Listener_Name.out
			done <$LOGDIR/scanlistenerstatus.out
			rm $LOGDIR/scanlistenerstatus.out
		fi
		echo "LISTENER_CHECK: " $LISTENER_CHECK >>$OUTPUT_FILE_VAL

		#SCAN Listener service Check- ends


		export ORACLE_HOME=$ORACLE_HOME_old
		export PATH=$ORACLE_HOME/bin:$PATH
		export CRS_HOME=$CRS_HOME
		export PATH=$PATH:$CRS_HOME/bin
	fi

	if [ $RAC_MNODE_CHK == 1 ] && [ "$CRS_STATUS" == "GOOD" ]
	then
			if [ $(uname -s | cut -c1-3) = "Sun" ];then

				crsctl status res |grep -v "^$"|/usr/xpg4/bin/awk -F "=" 'BEGIN {print " "} {printf("%s",NR%4 ? $2"|" : $2"\n")}'|sed -e 's/ *, /,/g' -e 's/, /,/g'|\
				/usr/xpg4/bin/awk -F "|" 'BEGIN { printf "%-40s%-35s%-20s%-50s\n","Resource Name","Resource Type","Target ","State" }{ split ($3,trg,",") split ($4,st,",")}{for (i in trg) {printf "%-40s%-35s%-20s%-50s\n",$1,$2,trg[i],st[i]}}' > $LOGDIR/crsctlstatres.out

			else

				crsctl status res |grep -v "^$"|awk -F "=" 'BEGIN {print " "} {printf("%s",NR%4 ? $2"|" : $2"\n")}'|sed -e 's/ *, /,/g' -e 's/, /,/g'|\
				awk -F "|" 'BEGIN { printf "%-40s%-35s%-20s%-50s\n","Resource Name","Resource Type","Target ","State" }{ split ($3,trg,",") split ($4,st,",")}{for (i in trg) {printf "%-40s%-35s%-20s%-50s\n",$1,$2,trg[i],st[i]}}' > $LOGDIR/crsctlstatres.out

			fi
		cat $LOGDIR/crsctlstatres.out|grep -v "ONLINE              ONLINE"|grep -v "ora.gsd" > $LOGDIR/crsctlstatres_err_withhead.out
		cat $LOGDIR/crsctlstatres.out|grep -v "ONLINE              ONLINE"|grep -v "ora.gsd"|grep -v "Resource Name                           Resource Type" > $LOGDIR/crsctlstatres_err.out


		Crs_err_cnt=`cat $LOGDIR/crsctlstatres_err.out|wc -l`
		if [ Crs_err_cnt -gt 0 ]
		then
			CRS_STATUS="ERRORS"
			echo " ">>$OUTPUT_FILE_ERR
			cat $LOGDIR/crsctlstatres_err_withhead.out >>$OUTPUT_FILE_ERR
			echo " ">>$OUTPUT_FILE_ERR

			echo '<tr>' >>$OUTPUT_FILE_HTML_RAC
			echo '<td align="left">' >>$OUTPUT_FILE_HTML_RAC
			echo '<font face="Arial" size="2" color="black"><pre>' >>$OUTPUT_FILE_HTML_RAC
			cat $LOGDIR/crsctlstatres_err_withhead.out >>$OUTPUT_FILE_HTML_RAC
			echo '</pre></font>' >>$OUTPUT_FILE_HTML_RAC
			echo '</td>' >>$OUTPUT_FILE_HTML_RAC
			echo '</tr>' >>$OUTPUT_FILE_HTML_RAC
		fi

		rm $LOGDIR/crsctlstatres.out
		rm $LOGDIR/crsctlstatres_err.out
		rm $LOGDIR/crsctlstatres_err_withhead.out

		Service_Cnt=0
		Service_Cnt=`cat $LOGDIR/DBservices.out|wc -l`

		if [ $Service_Cnt == 0 ] || [ $Service_Failure_Chk == 1 ]
		then
			echo " Database Service is not defined for this database-"$DBNAME >>$OUTPUT_FILE_ERR
			SVC_STATUS="ERRORS"
			echo '<tr>' >>$OUTPUT_FILE_HTML_SVC
			echo '<td align="left">' >>$OUTPUT_FILE_HTML_SVC
			echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_SVC
			echo " Database Service is not defined for this database-"$DBNAME >>$OUTPUT_FILE_HTML_SVC
			echo '</p></font>' >>$OUTPUT_FILE_HTML_SVC
			echo '</td>' >>$OUTPUT_FILE_HTML_SVC
			echo '</tr>' >>$OUTPUT_FILE_HTML_SVC
		else
			if  [ $Service_Cnt == 1 ]
			then
				TotalServices=`cat $LOGDIR/DBservices.out`

				typeset -i TotSerCnt=`echo $TotalServices | wc -m`
				cut -c11-$TotSerCnt $LOGDIR/DBservices.out | sed -n 1'p' | tr ',' '\n' | while read ServiceName; do
					srvctl config service -d $DBNAME -s $ServiceName > $LOGDIR/serviceconfig_details.out
					srvctl status service -d $DBNAME -s $ServiceName > $LOGDIR/servicestatus_details.out
					typeset -i RunningSvc_Chk=`cat $LOGDIR/servicestatus_details.out|grep -i " is running"|wc -l`
					typeset -i Service_Status=`cat $LOGDIR/serviceconfig_details.out|grep -i "Service is enabled" |wc -l`

					if  [ $Service_Status == 0 ]
					then
						echo " Service " $ServiceName " is not enabled for this database-"$DBNAME >>$OUTPUT_FILE_ERR
						SVC_STATUS="ERRORS"

						echo '<tr>' >>$OUTPUT_FILE_HTML_SVC
						echo '<td align="left">' >>$OUTPUT_FILE_HTML_SVC
						echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_SVC
						echo " Service "$ServiceName" is not enabled for this database-"$DBNAME >>$OUTPUT_FILE_HTML_SVC
						echo '</p></font>' >>$OUTPUT_FILE_HTML_SVC
						echo '</td>' >>$OUTPUT_FILE_HTML_SVC
						echo '</tr>' >>$OUTPUT_FILE_HTML_SVC
					else
						if [ $RunningSvc_Chk == 1 ]
						then
							PreferredInst_list=`cat $LOGDIR/serviceconfig_details.out|grep -i "Preferred instances"`
							AvailableInst_list=`cat $LOGDIR/serviceconfig_details.out|grep -i "Available instances:"`

							RunningSvc_List=`cat $LOGDIR/servicestatus_details.out`
							cat $LOGDIR/serviceconfig_details.out|grep -i "Preferred instances" > $LOGDIR/PreferredInstance_list.out
							typeset -i TotPrefInstLen=`echo $PreferredInst_list |wc -m`
							typeset -i Psvc_chk=0
							typeset -i TotPinscnt=0
							cut -c22-$TotPrefInstLen $LOGDIR/PreferredInstance_list.out | sed -n 1'p' | tr ',' '\n' | while read PrefSvcInstName; do
								TotPinscnt=TotPinscnt+1
								if [[ "$RunningSvc_List" == *${PrefSvcInstName}* ]]
								then
									echo "=========================================================================================================">>$OUTPUT_FILE_TOTAL
									echo "Service " $ServiceName " is running in Preferred Instance " $PrefSvcInstName >> $OUTPUT_FILE_TOTAL
									Psvc_chk=Psvc_chk+1
								else
									echo "=========================================================================================================">>$OUTPUT_FILE_ERR
									echo "Service " $ServiceName " is not running in Preferred Instance " $PrefSvcInstName ".Please check." >>$OUTPUT_FILE_ERR
									echo " " >>$OUTPUT_FILE_ERR

									echo '<tr>' >>$OUTPUT_FILE_HTML_SVC
									echo '<td align="left">' >>$OUTPUT_FILE_HTML_SVC
									echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_SVC
									echo "Service " $ServiceName" is not running in Preferred Instance " $PrefSvcInstName ".Please check." >>$OUTPUT_FILE_HTML_SVC
									echo '</p></font>' >>$OUTPUT_FILE_HTML_SVC
									echo '</td>' >>$OUTPUT_FILE_HTML_SVC
									echo '</tr>' >>$OUTPUT_FILE_HTML_SVC
								fi

							done
							rm $LOGDIR/PreferredInstance_list.out

							if [ $TotPinscnt == $Psvc_chk ] && [ "$SVC_STATUS" = "GOOD" ]
							then
								SVC_STATUS="GOOD"
							else
								SVC_STATUS="ERRORS"
							fi
						else
							echo "=========================================================================================================">>$OUTPUT_FILE_ERR
							echo " Service " $ServiceName " is not running . Please check." >>$OUTPUT_FILE_ERR
							echo " " >>$OUTPUT_FILE_ERR
							echo "=========================================================================================================">>$OUTPUT_FILE_ERR

							SVC_STATUS="ERRORS"

							echo '<tr>' >>$OUTPUT_FILE_HTML_SVC
							echo '<td align="left">' >>$OUTPUT_FILE_HTML_SVC
							echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_SVC
							echo " Service "$ServiceName "is not running.Please check." >>$OUTPUT_FILE_HTML_SVC
							echo '</p></font>' >>$OUTPUT_FILE_HTML_SVC
							echo '</td>' >>$OUTPUT_FILE_HTML_SVC
							echo '</tr>' >>$OUTPUT_FILE_HTML_SVC
						fi
					fi

				done
				rm $LOGDIR/serviceconfig_details.out
				rm $LOGDIR/servicestatus_details.out
			else
				echo "=========================================================================================================">>$OUTPUT_FILE_ERR
				echo " Service details not fetched correctly using SRVCTL " >>$OUTPUT_FILE_ERR
				echo " " >>$OUTPUT_FILE_ERR
				SVC_STATUS="ERRORS"
				echo '<tr>' >>$OUTPUT_FILE_HTML_SVC
				echo '<td align="left">' >>$OUTPUT_FILE_HTML_SVC
				echo '<font face="Arial" size="2" color="black"><p>' >>$OUTPUT_FILE_HTML_SVC
				echo " Service detail is not fetched correctly using SRVCTL " >>$OUTPUT_FILE_HTML_SVC
				echo '</p></font>' >>$OUTPUT_FILE_HTML_SVC
				echo '</td>' >>$OUTPUT_FILE_HTML_SVC
				echo '</tr>' >>$OUTPUT_FILE_HTML_SVC
			fi

		fi
		rm $LOGDIR/DBservices.out


	fi
	echo "CRS_STATUS: " $CRS_STATUS >>$OUTPUT_FILE_VAL
	echo "SVC_STATUS: " $SVC_STATUS >>$OUTPUT_FILE_VAL

	if [ $RAC_MNODE_CHK == 1 ] && [ "$CRS_CHK_STATUS" == "GOOD" ]
	then

		#07-05-2015 olsnodes > $LOGDIR/node_list.out
		cat /dev/null > $LOGDIR/node_list.out
		olsnodes > $LOGDIR/node_list_old.out
		srvctl status database -d $DBNAME > $LOGDIR/DB_list.out
		while read hostname_line
		do
			typeset -i DB_RUNNING_CNT=`echo $hostname_line|grep -i "is running"|wc -l`
			if [ $DB_RUNNING_CNT == 1 ]
			then
				HOST=`echo $hostname_line | awk '{print $7}' | sed -e 's/%//'`
			else
				HOST=`echo $hostname_line | awk '{print $8}' | sed -e 's/%//'`
			fi

			echo "$HOST" >> $LOGDIR/node_list.out
		done <$LOGDIR/DB_list.out


		for HOST in $(cat $LOGDIR/node_list.out)
		do
			if [ "$HOST" == "$hostname" ]
			then
				y=1
			else
				DBLIST_STR=`cat $LOGDIR/DB_list.out|grep -i "$HOST"`
				DBINST_NAME=`echo $DBLIST_STR | awk '{print $2}' | sed -e 's/%//'`
				#07272015#scp $hostname:$RUNDIR/DB_Master_Health_Check.ksh $HOST:/tmp/DB_Master_Health_Check.ksh > /dev/null
				#07272015#scp $hostname:$RUNDIR/hc_input_$ORACLE_SID.prm $HOST:/tmp/hc_input_$DBINST_NAME.prm > /dev/null
				scp $RUNDIR/DB_Master_Health_Check.sh $user_name@$HOST:/tmp/DB_Master_Health_Check.sh > /dev/null

				scp $RUNDIR/hc_input_$ORACLE_SID.prm $user_name@$HOST:/tmp/hc_input_$DBINST_NAME.prm > /dev/null

				##echo "Remote host: " $HOST >> /tmp/Prabu/log/scp1.log
				##echo "Remote DBINST_NAME: " $DBINST_NAME >> /tmp/Prabu/log/scp2.log
				##scp -pq $hostname:$RUNDIR/DB_Master_Health_Check.ksh oracle@$HOST:/tmp/DB_Master_Health_Check.ksh >> /tmp/Prabu/log/scp1.log
				##scp -pq $hostname:$RUNDIR/hc_input_$ORACLE_SID.prm oracle@$HOST:/tmp/hc_input_$DBINST_NAME.prm >> /tmp/Prabu/log/scp2.log

				SSH_STR="ksh /tmp/DB_Master_Health_Check.sh $DBINST_NAME 2 $hostname $LOGDIR"


				ssh $user_name@$HOST $SSH_STR > /dev/null
			fi
		done
	fi

	if [ "$RAC_MNODE_NAME" == "$hostname" ]
	then
		echo " Not performing scp operation in the same node $RAC_MNODE_NAME" >>$OUTPUT_FILE_TOTAL
	else
		echo " I m doing scp from $hostname" >>$OUTPUT_FILE_TOTAL

		scp $OUTPUT_FILE_TOTAL $user_name@$RAC_MNODE_NAME:$SOURCE_HOST_LOGDIR/hc_total_$hostname.out
		scp $OUTPUT_FILE_ERR $user_name@$RAC_MNODE_NAME:$SOURCE_HOST_LOGDIR/hc_err_$hostname.out
		scp $OUTPUT_FILE_VAL $user_name@$RAC_MNODE_NAME:$SOURCE_HOST_LOGDIR/hc_val_$hostname.out


		scp $LOGDIR/hc_alertlog_$hostname.out $user_name@$RAC_MNODE_NAME:$SOURCE_HOST_LOGDIR/hc_alertlog_$hostname.out
		scp $LOGDIR/hc_cpu_$hostname.out $user_name@$RAC_MNODE_NAME:$SOURCE_HOST_LOGDIR/hc_cpu_$hostname.out
		scp $LOGDIR/hc_listener_$hostname.out $user_name@$RAC_MNODE_NAME:$SOURCE_HOST_LOGDIR/hc_listener_$hostname.out
		scp $LOGDIR/hc_listener_txt_$hostname.out $user_name@$RAC_MNODE_NAME:$SOURCE_HOST_LOGDIR/hc_listener_txt_$hostname.out
		scp $LOGDIR/hc_fs_$hostname.out $user_name@$RAC_MNODE_NAME:$SOURCE_HOST_LOGDIR/hc_fs_$hostname.out
		scp $LOGDIR/hc_rac_$hostname.out $user_name@$RAC_MNODE_NAME:$SOURCE_HOST_LOGDIR/hc_rac_$hostname.out
		scp $LOGDIR/hc_svc_$hostname.out $user_name@$RAC_MNODE_NAME:$SOURCE_HOST_LOGDIR/hc_svc_$hostname.out

		if [ $GGCHK == 1 ]
		then
			scp $LOGDIR/hc_gg_$hostname.out $user_name@$RAC_MNODE_NAME:$SOURCE_HOST_LOGDIR/hc_gg_$hostname.out
		fi

		rm $OUTPUT_FILE_TOTAL
		rm $OUTPUT_FILE_ERR
		rm $OUTPUT_FILE_VAL

	fi
else
	echo "LISTENER_CHECK: " $LISTENER_CHECK >>$OUTPUT_FILE_VAL
	echo "ALERT_LOG_ERROR: " $ALERT_LOG_ERROR >>$OUTPUT_FILE_VAL

fi


if [ $RAC_MNODE_CHK == 1 ]
then
	cat /dev/null > $LOGDIR/HCscript.html

	echo '<TABLE cellpadding="3" cellspacing="0" width='500%'>' >>$LOGDIR/HCscript.html
	echo '<td>' >>$LOGDIR/HCscript.html
	echo '<b><a name="main"><font face="Calibri" size="6" color="Navy"><b><u> Health Check Report</u> </a></u></b></font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html
	echo '</TABLE>' >>$LOGDIR/HCscript.html


	while read htmtag_line
	do
		HLINE_STR=$htmtag_line
		FIRST_TAG=`echo $HLINE_STR | awk '{print $1}' | sed -e 's/%//'`

		if [ "$FIRST_TAG" == "<table" ]
		then
			echo "<table border='1' width='50%' align='left' cellpadding='3' cellspacing='1'>" >>$LOGDIR/HCscript.html

		elif [ "$FIRST_TAG" == "<th" ]
		then
			echo "<th scope="col" align='center' bgcolor="blue"><font face='Calibri' size='8px' color='white'>" >>$LOGDIR/HCscript.html
		elif [ "$FIRST_TAG" == "</th>" ]
		then
			echo "</font></th>" >>$LOGDIR/HCscript.html
		elif [ "$FIRST_TAG" == "<td" ] || [ "$FIRST_TAG" == "<td>" ]
		then
			echo "<td align="center"><font face='Calibri' size='5px' >" >>$LOGDIR/HCscript.html
		elif [ "$FIRST_TAG" == "</td>" ]
		then
			echo "</font></td>" >>$LOGDIR/HCscript.html
		else
			echo $HLINE_STR >>$LOGDIR/HCscript.html
		fi

	done <$LOGDIR/hc_db_temp.html

	if [ -f $LOGDIR/node_list.out ]
	then
		typeset -i NODELIST_CNT=`cat $LOGDIR/node_list.out|wc -l`
		if [ $NODELIST_CNT -gt 1 ]
		then
			while read node_line
			do
				echo '<TABLE cellpadding="3" cellspacing="0" width='500%'>' >>$LOGDIR/HCscript.html
				echo '<tr><td><pre>' >>$LOGDIR/HCscript.html
				echo " " >>$LOGDIR/HCscript.html
				echo '</pre></td></tr>' >>$LOGDIR/HCscript.html
				echo '</TABLE>' >>$LOGDIR/HCscript.html

			done <$LOGDIR/node_list.out
		fi
	else
		echo '<TABLE cellpadding="3" cellspacing="0" width='500%'>' >>$LOGDIR/HCscript.html
		echo '<tr><td><pre>' >>$LOGDIR/HCscript.html
		echo " " >>$LOGDIR/HCscript.html
		echo '</pre></td></tr>' >>$LOGDIR/HCscript.html
		echo '</TABLE>' >>$LOGDIR/HCscript.html

		echo '<TABLE cellpadding="3" cellspacing="0" width='500%'>' >>$LOGDIR/HCscript.html
		echo '<tr><td><pre>' >>$LOGDIR/HCscript.html
		echo " " >>$LOGDIR/HCscript.html
		echo '</pre></td></tr>' >>$LOGDIR/HCscript.html
		echo '</TABLE>' >>$LOGDIR/HCscript.html

	fi
		echo '<TABLE cellpadding="3" cellspacing="0" width='500%'>' >>$LOGDIR/HCscript.html
		echo '<tr><td><pre>' >>$LOGDIR/HCscript.html
		echo " " >>$LOGDIR/HCscript.html
		echo '</pre></td></tr>' >>$LOGDIR/HCscript.html



	echo '<table border='1' width='35%' align='left' cellpadding='3' cellspacing='1'>' >>$LOGDIR/HCscript.html
	echo "<tr><th scope="col" align='center' bgcolor="blue"><font face='Calibri' size='4px' color='white'>Total Database Size</th>" >>$LOGDIR/HCscript.html
	echo "<th scope="col" align='center' bgcolor="blue"><font face='Calibri' size='4px' color='white'>Used space</th>" >>$LOGDIR/HCscript.html
	echo "<th scope="col" align='center' bgcolor="blue"><font face='Calibri' size='4px' color='white'>Free space</th></font></tr>" >>$LOGDIR/HCscript.html
	cat $LOGDIR/hc_db_size.out >>$LOGDIR/HCscript.html
	echo '</TABLE>' >>$LOGDIR/HCscript.html


	echo '<TABLE cellpadding="3" cellspacing="0" width='500%'>' >>$LOGDIR/HCscript.html
	echo '<td>' >>$LOGDIR/HCscript.html
	echo '<font face="Calibri" size="8" color="Navy">' >>$LOGDIR/HCscript.html
	echo '<pre>' >>$LOGDIR/HCscript.html
	echo " " >>$LOGDIR/HCscript.html
	echo '</pre>' >>$LOGDIR/HCscript.html
	echo '</font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html
	echo '</TABLE>' >>$LOGDIR/HCscript.html


	echo '<TABLE cellpadding="3" cellspacing="0" width='500%'>' >>$LOGDIR/HCscript.html
	echo '<td>' >>$LOGDIR/HCscript.html
	echo '<font face="Calibri" size="8" color="Navy">' >>$LOGDIR/HCscript.html
	echo '<pre>' >>$LOGDIR/HCscript.html
	echo " " >>$LOGDIR/HCscript.html
	echo '</pre>' >>$LOGDIR/HCscript.html
	echo '</font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html
	echo '</TABLE>' >>$LOGDIR/HCscript.html

	echo '<TABLE border="1" cellpadding="3" cellspacing="0" width="500">' >>$LOGDIR/HCscript.html
	echo '<tr>' >>$LOGDIR/HCscript.html


	echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
	echo '<font face="Calibri" size="3" color="Navy">Host Name</font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html
	echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
	echo '<font face="Calibri" size="3" color="Navy">Instance Name</font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html
	echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
	echo '<font face="Calibri" size="3" color="Navy">CPU Idle </font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html
	echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
	echo '<font face="Calibri" size="3" color="Navy">Connections (Active/Inactive) </font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html
	echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
	echo '<font face="Calibri" size="3" color="Navy">Blocker</font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html

	echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
	echo '<font face="Calibri" size="3" color="Navy">Arch Dest Space</font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html

	echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
	echo '<font face="Calibri" size="3" color="Navy">Tablespace Check</font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html



	echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
	echo '<font face="Calibri" size="3" color="Navy">LongRunning Sessions</font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html

	echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
	echo '<font face="Calibri" size="3" color="Navy">Avg File I/O Read Check</font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html

	echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
	echo '<font face="Calibri" size="3" color="Navy">Gather Stats Check</font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html

	echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
	echo '<font face="Calibri" size="3" color="Navy">Invalid Object</font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html

	echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
	echo '<font face="Calibri" size="3" color="Navy">Unusable Index</font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html

	echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
	echo '<font face="Calibri" size="3" color="Navy">Disabled Constraints</font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html

	echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
	echo '<font face="Calibri" size="3" color="Navy">Datafile Status</font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html

	echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
	echo '<font face="Calibri" size="3" color="Navy">Alert Log </font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html
	echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
	echo '<font face="Calibri" size="3" color="Navy">Space Issue </font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html
	echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
	echo '<font face="Calibri" size="3" color="Navy">Listener Status </font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html
	echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
	echo '<font face="Calibri" size="3" color="Navy">Backup Status </font>' >>$LOGDIR/HCscript.html
	echo '</td>' >>$LOGDIR/HCscript.html


	if [ $RACChk == 1 ]
	then

		echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
		echo '<font face="Calibri" size="3" color="Navy">DB Service status </font>' >>$LOGDIR/HCscript.html
		echo '</td>' >>$LOGDIR/HCscript.html


		echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
		echo '<font face="Calibri" size="3" color="Navy">Cluster Services </font>' >>$LOGDIR/HCscript.html
		echo '</td>' >>$LOGDIR/HCscript.html
	fi


	if [ $GGCHK == 1 ]
	then
		echo '<td width="25%" align="center" bgcolor="yellow">' >>$LOGDIR/HCscript.html
		echo '<font face="Calibri" size="3" color="Navy">GoldenGate Process </font>' >>$LOGDIR/HCscript.html
		echo '</td>' >>$LOGDIR/HCscript.html
	fi


	echo '</tr>' >>$LOGDIR/HCscript.html

	if [ $RACChk == 1 ] && [ "$CRS_CHK_STATUS" == "GOOD" ]
	then
		node_list=1

	elif [ "$CRS_CHK_STATUS" == "GOOD" ]
	then
		echo `hostname -s` > $LOGDIR/node_list.out
	fi

	if [ "$CRS_CHK_STATUS" == "GOOD" ]
	then

		export LOGFILENAME="HC_TOTAL_LOG_"${ORACLE_SID}_${CURRENT_DAY}_${DATE}.log
		export FINAL_FILE_TOTAL=${LOGDIR}/${LOGFILENAME}
		export ERRFILENAME="HC_ERR_"${ORACLE_SID}_${CURRENT_DAY}_${DATE}.err
		export FINAL_FILE_ERR=${LOGDIR}/${ERRFILENAME}

		export HTMLFILENAME="HC_HTML_"${ORACLE_SID}_${CURRENT_DAY}_${DATE}.html
		export FINAL_FILE_HTML=${LOGDIR}/${HTMLFILENAME}
		mv $OUTPUT_FILE_HTML $FINAL_FILE_HTML
		#07072015 FINAL_FILE_HTML=$OUTPUT_FILE_HTML

		TOTAL_CPU_FILE=$LOGDIR/hc_total_cpu_output.out


		TOTAL_ALERTLOG_FILE=$LOGDIR/hc_total_alertlog_output.out

		TOTAL_LISTENER_FILE=$LOGDIR/hc_total_listener_output.out

		TOTAL_LISTENER_TXTFILE=$LOGDIR/hc_total_listener_txtoutput.out


		TOTAL_FS_FILE=$LOGDIR/hc_total_fs_output.out

		TOTAL_RAC_FILE=$LOGDIR/hc_total_rac_output.out


		if [ $GGCHK == 1 ]
		then
			TOTAL_GG_FILE=$LOGDIR/hc_total_gg_output.out
			cat /dev/null > $TOTAL_GG_FILE

		fi

		cat /dev/null > $FINAL_FILE_TOTAL
		cat /dev/null > $FINAL_FILE_ERR
		cat /dev/null > $TOTAL_CPU_FILE
		cat /dev/null > $TOTAL_ALERTLOG_FILE
		cat /dev/null > $TOTAL_LISTENER_FILE
		cat /dev/null > $TOTAL_LISTENER_TXTFILE
		cat /dev/null > $TOTAL_FS_FILE
		cat /dev/null > $TOTAL_RAC_FILE

		FBKP_VAL="FAILED"
		if [ "$BKP_METHOD" == "RMAN" ]
		then
			FBKP_VAL=$BKP_CHK
		elif [ "$BKP_METHOD" == "VSU" ]
		then
			for HOST1 in $(cat $LOGDIR/node_list.out)
			do
				FINAL_OUTPUT_BKPFILE_VAL="$LOGDIR/hc_val_$HOST1.out"
				if [ -f $FINAL_OUTPUT_BKPFILE_VAL ]
				then
					FBKP_STR=`grep -i "BKP_CHK:" $FINAL_OUTPUT_BKPFILE_VAL |head -1`
					FBKP_VALUE=`echo $FBKP_STR | awk '{print $2}' | sed -e 's/%//'`

					#if [ "$FBKP_VALUE" == "GOOD" ]
					if [ "$FBKP_VALUE" = "GOOD" ] && [ "$FBKP_VAL" = "FAILED" ]
					then
						FBKP_VAL=$FBKP_VALUE
					fi
				fi
			done
		fi

		FGG_VAL="FAILED"

		for HOST2 in $(cat $LOGDIR/node_list.out)
		do
			FINAL_OUTPUT_GGSTATUS_VAL="$LOGDIR/hc_val_$HOST2.out"
			if [ -f $FINAL_OUTPUT_GGSTATUS_VAL ]
			then
				FGGSTATUS_STR=`grep -i "GGCHK_STATUS:" $FINAL_OUTPUT_GGSTATUS_VAL |head -1`
				FGGSTATUS_VALUE=`echo $FGGSTATUS_STR | awk '{print $2}' | sed -e 's/%//'`

				if [ "$FGGSTATUS_VALUE" != "ERRORS" ]
				then
					FGG_VAL=$FGGSTATUS_VALUE
				fi
			fi
		done


		typeset FGG_VAL_NEW=$FGG_VAL
		for HOST in $(cat $LOGDIR/node_list.out)
		do
			typeset HOST_CHK="GOOD"
			FINAL_OUTPUT_FILE_TOTAL="$LOGDIR/hc_total_$HOST.out"
			FINAL_OUTPUT_FILE_ERR="$LOGDIR/hc_err_$HOST.out"
			FINAL_OUTPUT_FILE_VAL="$LOGDIR/hc_val_$HOST.out"

			FINAL_OUTPUT_FILE_CPU="$LOGDIR/hc_cpu_$HOST.out"
			FINAL_OUTPUT_FILE_ALERTLOG="$LOGDIR/hc_alertlog_$HOST.out"
			FINAL_OUTPUT_FILE_LISTENER="$LOGDIR/hc_listener_$HOST.out"
			FINAL_OUTPUT_TXTFILE_LISTENER="$LOGDIR/hc_listener_txt_$HOST.out"
			FINAL_OUTPUT_FILE_FS="$LOGDIR/hc_fs_$HOST.out"
			FINAL_OUTPUT_FILE_GG="$LOGDIR/hc_gg_$HOST.out"
			FINAL_OUTPUT_FILE_RAC="$LOGDIR/hc_rac_$HOST.out"


			AICNT_STR=`grep -i "$HOST" $LOGDIR/hc_inst_sess_main.out |head -1`
			INST_VAL=`echo $AICNT_STR | awk '{print $2}' | sed -e 's/%//'`
			AICNT_VAL=`echo $AICNT_STR | awk '{print $4}' | sed -e 's/%//'`
			AICNT_ERR_VAL=`echo $AICNT_STR | awk '{print $5}' | sed -e 's/%//'`

			if [ -f $FINAL_OUTPUT_FILE_TOTAL ]
			then
				echo " ">>$FINAL_FILE_TOTAL
				echo "Complete Log details from the server : $HOST">>$FINAL_FILE_TOTAL
				echo "=========================================================================================================">>$FINAL_FILE_TOTAL
				cat $FINAL_OUTPUT_FILE_TOTAL >>$FINAL_FILE_TOTAL
				echo "=========================================================================================================">>$FINAL_FILE_TOTAL
				echo " ">>$FINAL_FILE_TOTAL
			else
				HOST_CHK="HOST NOT REACHABLE"
			fi

			if [ -f $FINAL_OUTPUT_FILE_ERR ]
			then
				echo " ">>$FINAL_FILE_ERR

				echo "=========================================================================================================">>$FINAL_FILE_ERR
				echo "Complete Log details from the server : $HOST">>$FINAL_FILE_ERR
				echo " " >>$FINAL_FILE_ERR
				cat $FINAL_OUTPUT_FILE_ERR >>$FINAL_FILE_ERR
				echo "=========================================================================================================">>$FINAL_FILE_ERR
				echo " ">>$FINAL_FILE_ERR
			else
				HOST_CHK="HOST NOT REACHABLE"
			fi

			if [ -f $FINAL_OUTPUT_FILE_CPU ]
			then
				typeset -i FINALOUTPUTFILECPU_CNT=`cat $FINAL_OUTPUT_FILE_CPU|wc -l`
				if [ $FINALOUTPUTFILECPU_CNT -gt 0 ]
				then
					cat $FINAL_OUTPUT_FILE_CPU >>$TOTAL_CPU_FILE
				fi
			else
				HOST_CHK="HOST NOT REACHABLE"
			fi

			if [ -f $FINAL_OUTPUT_FILE_ALERTLOG ]
			then

				typeset -i FINALOUTPUTFILEALERTLOG_CNT=`cat $FINAL_OUTPUT_FILE_ALERTLOG|wc -l`
				if [ $FINALOUTPUTFILEALERTLOG_CNT -gt 0 ]
				then
					cat $FINAL_OUTPUT_FILE_ALERTLOG >>$TOTAL_ALERTLOG_FILE
				fi
			else
				HOST_CHK="HOST NOT REACHABLE"
			fi

			if [ -f $FINAL_OUTPUT_FILE_LISTENER ]
			then
				typeset -i FINALOUTPUTFILELISTENER_CNT=`cat $FINAL_OUTPUT_FILE_LISTENER|wc -l`
				if [ $FINALOUTPUTFILELISTENER_CNT -gt 0 ]
				then
					cat $FINAL_OUTPUT_FILE_LISTENER >>$TOTAL_LISTENER_FILE
				fi
			else
				HOST_CHK="HOST NOT REACHABLE"
			fi

			if [ -f $FINAL_OUTPUT_TXTFILE_LISTENER ]
			then
				typeset -i FINALOUTPUTTXTFILELISTENER_CNT=`cat $FINAL_OUTPUT_TXTFILE_LISTENER|wc -l`
				if [ $FINALOUTPUTTXTFILELISTENER_CNT -gt 0 ]
				then
					cat $FINAL_OUTPUT_TXTFILE_LISTENER >>$TOTAL_LISTENER_TXTFILE
				fi
			else
				HOST_CHK="HOST NOT REACHABLE"
			fi


			if [ -f $FINAL_OUTPUT_FILE_FS ]
			then
				typeset -i FINALOUTPUTFILEFS_CNT=`cat $FINAL_OUTPUT_FILE_FS|wc -l`
				if [ $FINALOUTPUTFILEFS_CNT -gt 0 ]
				then
					cat $FINAL_OUTPUT_FILE_FS >>$TOTAL_FS_FILE
				fi
			else
				HOST_CHK="HOST NOT REACHABLE"
			fi

			if [ $RACChk == 1 ]
			then
				if [ -f $FINAL_OUTPUT_FILE_RAC ]
				then
					typeset -i FINALOUTPUTFILERAC_CNT=`cat $FINAL_OUTPUT_FILE_RAC|wc -l`
					if [ $FINALOUTPUTFILERAC_CNT -gt 0 ]
					then
						cat $FINAL_OUTPUT_FILE_RAC >>$TOTAL_RAC_FILE
					fi
				else
					HOST_CHK="HOST NOT REACHABLE"
				fi
			fi

			if [ $GGCHK == 1 ]
			then
				if [ -f $FINAL_OUTPUT_FILE_GG ]
				then
					typeset -i FINALOUTPUTFILEGG_CNT=`cat $FINAL_OUTPUT_FILE_GG|wc -l`
					if [ $FINALOUTPUTFILEGG_CNT -gt 0 ]
					then
						cat $FINAL_OUTPUT_FILE_GG >>$TOTAL_GG_FILE
					fi
				else
					HOST_CHK="HOST NOT REACHABLE"
				fi
			fi

			if [ -f $FINAL_OUTPUT_FILE_VAL ]
			then

				FCPU_STR=`grep -i "CPU_IDLE:" $FINAL_OUTPUT_FILE_VAL |head -1`
				FCPU_VAL=`echo $FCPU_STR | awk '{print $2}' | sed -e 's/%//'`

				FCPU_CHK_STR=`grep -i "CPU_IDLE_CHK:" $FINAL_OUTPUT_FILE_VAL |head -1`
				FCPU_CHK_VAL=`echo $FCPU_CHK_STR | awk '{print $2}' | sed -e 's/%//'`

				FALERT_STR=`grep -i "ALERT_LOG_ERROR:" $FINAL_OUTPUT_FILE_VAL |head -1`
				FALERT_VAL=`echo $FALERT_STR | awk '{print $2}' | sed -e 's/%//'`

				FFS_STR=`grep -i "FS_CHK:" $FINAL_OUTPUT_FILE_VAL |head -1`
				FFS_VAL=`echo $FFS_STR | awk '{print $2}' | sed -e 's/%//'`

				FLSNR_STR=`grep -i "LISTENER_CHECK:" $FINAL_OUTPUT_FILE_VAL |head -1`
				FLSNR_VAL=`echo $FLSNR_STR | awk '{print $2}' | sed -e 's/%//'`

				FCRS_STR=`grep -i "CRS_STATUS:" $FINAL_OUTPUT_FILE_VAL |head -1`
				FCRS_VAL=`echo $FCRS_STR | awk '{print $2}' | sed -e 's/%//'`


				##FALERTLOG_STR=`grep -i "ALERT_LOG_ERROR:" $FINAL_OUTPUT_FILE_VAL |head -1`
				##FALERTLOG_VAL=`echo $FALERTLOG_STR | awk '{print $2}' | sed -e 's/%//'`

				FDB_STR=`grep -i "INST_CHK:" $FINAL_OUTPUT_FILE_VAL |head -1`
				FDB_VAL=`echo $FDB_STR | awk '{print $2}' | sed -e 's/%//'`

			else
				HOST_CHK="HOST NOT REACHABLE"
			fi

			if [ "$FDB_VAL" == "GOOD" ] && [ "$HOST_CHK" != "HOST NOT REACHABLE" ]
			then
				BLO_VAL=$BLOCKINGSESS_CHK
				TAB_VAL=$TTS_VAL
				IO_VAL=$AFIOR_VAL
				LON_VAL=$LRT_VAL
				GAT_VAL=$GSTATS_CHK
				OBJ_VAL=$INVOBJ_CHK
				IND_VAL=$INDEX_CHK
				CONS_VAL=$CONSTRAINTS_CHK
				DF_VAL=$DBFILE_CHK
				ARC_VAL=$ARCDEST_VAL
				FBKP_VAL_NEW=$FBKP_VAL

			elif [ "$HOST_CHK" == "HOST NOT REACHABLE" ]
			then

				BLO_VAL="HOST NOT REACHABLE"
				TAB_VAL="HOST NOT REACHABLE"
				IO_VAL="HOST NOT REACHABLE"
				LON_VAL="HOST NOT REACHABLE"
				GAT_VAL="HOST NOT REACHABLE"
				OBJ_VAL="HOST NOT REACHABLE"
				IND_VAL="HOST NOT REACHABLE"
				CONS_VAL="HOST NOT REACHABLE"
				DF_VAL="HOST NOT REACHABLE"
				ARC_VAL="HOST NOT REACHABLE"
				FCPU_VAL="HOST NOT REACHABLE"
				FLSNR_VAL="HOST NOT REACHABLE"
				FALERT_VAL="HOST NOT REACHABLE"
				FFS_VAL="HOST NOT REACHABLE"
				FBKP_VAL_NEW="HOST NOT REACHABLE"
				if [ $GGCHK == 1 ]
				then
					FGG_VAL_NEW="HOST NOT REACHABLE"
				fi
				if [ $RACChk == 1 ]
				then
					FCRS_VAL="HOST NOT REACHABLE"
					SVC_STATUS="HOST NOT REACHABLE"
				fi

			else
				BLO_VAL="INSTANCE DOWN"
				TAB_VAL="INSTANCE DOWN"
				IO_VAL="INSTANCE DOWN"
				LON_VAL="INSTANCE DOWN"
				GAT_VAL="INSTANCE DOWN"
				OBJ_VAL="INSTANCE DOWN"
				IND_VAL="INSTANCE DOWN"
				CONS_VAL="INSTANCE DOWN"
				DF_VAL="INSTANCE DOWN"
				ARC_VAL="INSTANCE DOWN"
				FBKP_VAL_NEW="INSTANCE DOWN"
			fi

			echo '<tr>' >>$LOGDIR/HCscript.html
			echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
			echo '<font face="Calibri" size="3" color="Navy">'$HOST'</font>' >>$LOGDIR/HCscript.html
			echo '</td>' >>$LOGDIR/HCscript.html

			echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
			echo '<font face="Calibri" size="3" color="Navy">'$INST_VAL'</font>' >>$LOGDIR/HCscript.html
			echo '</td>' >>$LOGDIR/HCscript.html

			if [ "$FCPU_CHK_VAL" == "GOOD" ] || [ "$HOST_CHK" == "HOST NOT REACHABLE" ]
			then
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<font face="Calibri" size="3" color="Navy">'$FCPU_VAL'</font>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			else
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<a href="#Section3"> <font face="Calibri" size="3" color="Red">'$FCPU_VAL'</font></a>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			fi

			if [ "$AICNT_ERR_VAL" == "GOOD" ] || [ "$AICNT_ERR_VAL" == "INSTANCE DOWN" ] || [ "$HOST_CHK" == "HOST NOT REACHABLE" ]
			then
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<font face="Calibri" size="3" color="Navy">'$AICNT_VAL'</font>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			else
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<a href="#Section4"> <font face="Calibri" size="3" color="Red">'$AICNT_VAL'</font></a>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			fi



			if [ "$BLO_VAL" == "GOOD" ] || [ "$BLO_VAL" == "INSTANCE DOWN" ] || [ "$HOST_CHK" == "HOST NOT REACHABLE" ]
			then
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<font face="Calibri" size="3" color="Navy">'$BLO_VAL'</font>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			else
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<a href="#Section5"> <font face="Calibri" size="3" color="Red">'$BLO_VAL'</font></a>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			fi


			if [ "$ARC_VAL" == "GOOD" ] || [ "$ARC_VAL" == "INSTANCE DOWN" ] || [ "$HOST_CHK" == "HOST NOT REACHABLE" ]
			then

				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<font face="Calibri" size="3" color="Navy">'$ARC_VAL'</font>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			else
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<a href="#Section6"> <font face="Calibri" size="3" color="Red">'$ARC_VAL'</font></a>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html

			fi

			if [ "$TAB_VAL" == "GOOD" ] || [ "$TAB_VAL" == "INSTANCE DOWN" ] || [ "$HOST_CHK" == "HOST NOT REACHABLE" ]
			then
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<font face="Calibri" size="3" color="Navy">'$TAB_VAL'</font>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			else
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<a href="#Section7"> <font face="Calibri" size="3" color="Red">'$TAB_VAL'</font></a>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			fi



			if [ "$LON_VAL" == "GOOD" ] || [ "$LON_VAL" == "INSTANCE DOWN" ] || [ "$HOST_CHK" == "HOST NOT REACHABLE" ]
			then
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<font face="Calibri" size="3" color="Navy">'$LON_VAL'</font>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			else
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<a href="#Section8"> <font face="Calibri" size="3" color="Red">'$LON_VAL'</font></a>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			fi

			if [ "$IO_VAL" == "GOOD" ] || [ "$IO_VAL" == "INSTANCE DOWN" ] || [ "$IO_VAL" == "HOST NOT REACHABLE" ]
			then
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<font face="Calibri" size="3" color="Navy">'$IO_VAL'</font>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			else
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<a href="#Section8a"> <font face="Calibri" size="3" color="Red">'$IO_VAL'</font></a>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			fi

			if [ "$GAT_VAL" == "GOOD" ] || [ "$GAT_VAL" == "INSTANCE DOWN" ] || [ "$HOST_CHK" == "HOST NOT REACHABLE" ]
			then
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<font face="Calibri" size="3" color="Navy">'$GAT_VAL'</font>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			else
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<a href="#Section9"> <font face="Calibri" size="3" color="Red">'$GAT_VAL'</font></a>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			fi


			if [ "$OBJ_VAL" == "GOOD" ] || [ "$OBJ_VAL" == "INSTANCE DOWN" ] || [ "$HOST_CHK" == "HOST NOT REACHABLE" ]
			then
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<font face="Calibri" size="3" color="Navy">'$OBJ_VAL'</font>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			else
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<a href="#Section10"> <font face="Calibri" size="3" color="Red">'$OBJ_VAL'</font></a>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			fi


			if [ "$IND_VAL" == "GOOD" ] || [ "$IND_VAL" == "INSTANCE DOWN" ] || [ "$HOST_CHK" == "HOST NOT REACHABLE" ]
			then
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<font face="Calibri" size="3" color="Navy">'$IND_VAL'</font>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			else
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<a href="#Section11"> <font face="Calibri" size="3" color="Red">'$IND_VAL'</font></a>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			fi



			if [ "$CONS_VAL" == "GOOD" ] || [ "$CONS_VAL" == "INSTANCE DOWN" ] || [ "$HOST_CHK" == "HOST NOT REACHABLE" ]
			then
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<font face="Calibri" size="3" color="Navy">'$CONS_VAL'</font>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			else
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<a href="#Section12"> <font face="Calibri" size="3" color="Red">'$CONS_VAL'</font></a>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			fi

			if [ "$DF_VAL" == "GOOD" ] || [ "$DF_VAL" == "INSTANCE DOWN" ] || [ "$HOST_CHK" == "HOST NOT REACHABLE" ]
			then
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<font face="Calibri" size="3" color="Navy">'$DF_VAL'</font>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			else
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<a href="#Section13"> <font face="Calibri" size="3" color="Red">'$DF_VAL'</font></a>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			fi

			if [ "$FALERT_VAL" == "GOOD" ] || [ "$HOST_CHK" == "HOST NOT REACHABLE" ]
			then
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<font face="Calibri" size="3" color="Navy">'$FALERT_VAL'</font>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			else
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<a href="#Section14"> <font face="Calibri" size="3" color="Red">'$FALERT_VAL'</font></a>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			fi

			if [ "$FFS_VAL" == "GOOD" ] || [ "$HOST_CHK" == "HOST NOT REACHABLE" ]
			then
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<font face="Calibri" size="3" color="Navy">'$FFS_VAL'</font>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			else
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<a href="#Section15"> <font face="Calibri" size="3" color="Red">'$FFS_VAL'</font></a>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			fi

			if [ "$FLSNR_VAL" == "GOOD" ] || [ "$HOST_CHK" == "HOST NOT REACHABLE" ]
			then
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<font face="Calibri" size="3" color="Navy">'$FLSNR_VAL'</font>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			else
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<a href="#Section16"> <font face="Calibri" size="3" color="Red">'$FLSNR_VAL'</font></a>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			fi



			if [ "$FBKP_VAL_NEW" == "GOOD" ] || [ "$HOST_CHK" == "HOST NOT REACHABLE" ]
			then
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<font face="Calibri" size="3" color="Navy">'$FBKP_VAL_NEW'</font>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			else
				echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
				echo '<a href="#Section17"> <font face="Calibri" size="3" color="Red">'$FBKP_VAL_NEW'</font></a>' >>$LOGDIR/HCscript.html
				echo '</td>' >>$LOGDIR/HCscript.html
			fi


			if [ $RACChk == 1 ]
			then


				if [ "$SVC_STATUS" == "GOOD" ] || [ "$HOST_CHK" == "HOST NOT REACHABLE" ]
				then
					echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
					echo '<font face="Calibri" size="3" color="Navy">'$SVC_STATUS'</font>' >>$LOGDIR/HCscript.html
					echo '</td>' >>$LOGDIR/HCscript.html
				else
					echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
					echo '<a href="#Section20"> <font face="Calibri" size="3" color="Red">'$SVC_STATUS'</font></a>' >>$LOGDIR/HCscript.html
					echo '</td>' >>$LOGDIR/HCscript.html
				fi

				if [ "$FCRS_VAL" == "GOOD" ] || [ "$HOST_CHK" == "HOST NOT REACHABLE" ]
				then
					echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
					echo '<font face="Calibri" size="3" color="Navy">'$FCRS_VAL'</font>' >>$LOGDIR/HCscript.html
					echo '</td>' >>$LOGDIR/HCscript.html
				else
					echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
					echo '<a href="#Section19"> <font face="Calibri" size="3" color="Red">'$FCRS_VAL'</font></a>' >>$LOGDIR/HCscript.html
					echo '</td>' >>$LOGDIR/HCscript.html
				fi


			fi
			if [ $GGCHK == 1 ]
			then

				if [ "$FGG_VAL" == "GOOD" ] || [ "$HOST_CHK" == "HOST NOT REACHABLE" ]
				then
					echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
					echo '<font face="Calibri" size="3" color="Navy">'$FGG_VAL_NEW'</font>' >>$LOGDIR/HCscript.html
					echo '</td>' >>$LOGDIR/HCscript.html
				else
					echo '<td width="35%" align="center">' >>$LOGDIR/HCscript.html
					echo '<a href="#Section18"> <font face="Calibri" size="3" color="Red">'$FGG_VAL_NEW'</font></a>' >>$LOGDIR/HCscript.html
					echo '</td>' >>$LOGDIR/HCscript.html
				fi

			fi

			echo '</tr>' >>$LOGDIR/HCscript.html


		done
		#07-03-2015 rm $LOGDIR/hc_inst_sess_main.out



		typeset -i TOTAL_CPU_FILE_CNT=`cat $TOTAL_CPU_FILE|wc -l`
		if [ $TOTAL_CPU_FILE_CNT -gt 0 ]
		then

			echo '<tr>' >>$FINAL_FILE_HTML
			echo '<td align="left">' >>$FINAL_FILE_HTML
			echo '<font face="Arial" size="2"  color="blue"><b><u><a name="Section3">CPU Idle Details: </a></b></u></font>' >>$FINAL_FILE_HTML
			echo '</td>' >>$FINAL_FILE_HTML
			echo '</tr>' >>$FINAL_FILE_HTML
			echo '<tr>' >>$FINAL_FILE_HTML
			echo '<td align="left">' >>$FINAL_FILE_HTML
			echo '<font face="Arial" size="1" color="black">' >>$FINAL_FILE_HTML
			echo '<pre>' >>$FINAL_FILE_HTML
			cat $TOTAL_CPU_FILE >>$FINAL_FILE_HTML
			echo '</pre>' >>$FINAL_FILE_HTML
			echo '</font>' >>$FINAL_FILE_HTML
			echo '</td>' >>$FINAL_FILE_HTML
			echo '</tr>' >>$FINAL_FILE_HTML
			echo '<tr>' >>$FINAL_FILE_HTML
			echo '<td align="left">' >>$FINAL_FILE_HTML
			echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$FINAL_FILE_HTML
			echo '</td>' >>$FINAL_FILE_HTML
			echo '</tr>' >>$FINAL_FILE_HTML
		fi

		typeset -i TOTAL_ALERTLOG_FILE_CNT=`cat $TOTAL_ALERTLOG_FILE|wc -l`
		if [ $TOTAL_ALERTLOG_FILE_CNT -gt 0 ]
		then
			echo '<tr>' >>$FINAL_FILE_HTML
			echo '<td align="left">' >>$FINAL_FILE_HTML
			echo '<font face="Arial" size="2"  color="blue"><b><u><a name="Section14">Alert Log Details: </a></b></u></font>' >>$FINAL_FILE_HTML
			echo '</td>' >>$FINAL_FILE_HTML
			echo '</tr>' >>$FINAL_FILE_HTML
			echo '<tr>' >>$FINAL_FILE_HTML
			echo '<td align="left">' >>$FINAL_FILE_HTML
			echo '<font face="Arial" size="1" color="black">' >>$FINAL_FILE_HTML
			echo '<pre>' >>$FINAL_FILE_HTML
			cat $TOTAL_ALERTLOG_FILE >>$FINAL_FILE_HTML
			echo '</pre>' >>$FINAL_FILE_HTML
			echo '</font>' >>$FINAL_FILE_HTML
			echo '</td>' >>$FINAL_FILE_HTML
			echo '</tr>' >>$FINAL_FILE_HTML
			echo '<tr>' >>$FINAL_FILE_HTML
			echo '<td align="left">' >>$FINAL_FILE_HTML
			echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$FINAL_FILE_HTML
			echo '</td>' >>$FINAL_FILE_HTML
			echo '</tr>' >>$FINAL_FILE_HTML
		fi

		typeset -i TOTAL_FS_FILE_CNT=`cat $TOTAL_FS_FILE|wc -l`
		if [ $TOTAL_FS_FILE_CNT -gt 0 ]
		then
			echo '<tr>' >>$FINAL_FILE_HTML
			echo '<td align="left">' >>$FINAL_FILE_HTML
			echo '<font face="Arial" size="2"  color="blue"><b><u><a name="Section15">Space usage Details: </a></b></u></font>' >>$FINAL_FILE_HTML
			echo '</td>' >>$FINAL_FILE_HTML
			echo '</tr>' >>$FINAL_FILE_HTML
			echo '<tr>' >>$FINAL_FILE_HTML
			echo '<td align="left">' >>$FINAL_FILE_HTML
			echo '<font face="Arial" size="1" color="black">' >>$FINAL_FILE_HTML
			echo '<pre>' >>$FINAL_FILE_HTML
			cat $TOTAL_FS_FILE >>$FINAL_FILE_HTML
			echo '</pre>' >>$FINAL_FILE_HTML
			echo '</font>' >>$FINAL_FILE_HTML
			echo '</td>' >>$FINAL_FILE_HTML
			echo '</tr>' >>$FINAL_FILE_HTML
			echo '<tr>' >>$FINAL_FILE_HTML
			echo '<td align="left">' >>$FINAL_FILE_HTML
			echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$FINAL_FILE_HTML
			echo '</td>' >>$FINAL_FILE_HTML
			echo '</tr>' >>$FINAL_FILE_HTML
		fi


		typeset -i TOTAL_LISTENER_FILE_CNT=`cat $TOTAL_LISTENER_FILE|wc -l`
		if [ $TOTAL_LISTENER_FILE_CNT -gt 0 ]
		then

			echo '<tr>' >>$FINAL_FILE_HTML
			echo '<td align="left">' >>$FINAL_FILE_HTML
			echo '<font face="Arial" size="2"  color="blue"><b><u><a name="Section16">Listener Details: </a></b></u></font>' >>$FINAL_FILE_HTML
			echo '</td>' >>$FINAL_FILE_HTML
			echo '</tr>' >>$FINAL_FILE_HTML


			typeset -i TOTAL_LSNRFILESIZE=0
			TOTAL_LSNRFILESIZE=$(ls -ltr $TOTAL_LISTENER_FILE | tr -s ' ' | cut -d ' ' -f 5)

			if [ $TOTAL_LSNRFILESIZE -gt 2097152 ]
			then
				ACTUAL_LISTENER_FILE=$TOTAL_LISTENER_TXTFILE

				export LISTENER_ERRLOG_FILENAME="HC_LISTENER_ERRORLOG_"${ORACLE_SID}_${CURRENT_DAY}_${DATE}.html
				export LISTENER_ERRLOG_FILE=${LOGDIR}/${LISTENER_ERRLOG_FILENAME}

				mv $TOTAL_LISTENER_FILE $LISTENER_ERRLOG_FILE
				echo '<tr>' >>$FINAL_FILE_HTML
				echo '<td align="left">' >>$FINAL_FILE_HTML
				echo '<font face="Courier New" size="2"  color="red"><b>' >>$FINAL_FILE_HTML
				echo "Due to huge volumn (>2MB) of errors,unable to display all error details in the mail.Please check the listener error log $LISTENER_ERRLOG_FILE in $hostname" >>$FINAL_FILE_HTML
				echo '</b></font>' >>$FINAL_FILE_HTML
				echo '</td>' >>$FINAL_FILE_HTML
				echo '</tr>' >>$FINAL_FILE_HTML


			else
				ACTUAL_LISTENER_FILE=$TOTAL_LISTENER_FILE
			fi



			echo '<tr>' >>$FINAL_FILE_HTML
			echo '<td align="left">' >>$FINAL_FILE_HTML
			echo '<font face="Arial" size="1" color="black">' >>$FINAL_FILE_HTML
			echo '<pre>' >>$FINAL_FILE_HTML
			cat $ACTUAL_LISTENER_FILE >>$FINAL_FILE_HTML
			echo '</pre>' >>$FINAL_FILE_HTML
			echo '</font>' >>$FINAL_FILE_HTML
			echo '</td>' >>$FINAL_FILE_HTML
			echo '</tr>' >>$FINAL_FILE_HTML
			echo '<tr>' >>$FINAL_FILE_HTML
			echo '<td align="left">' >>$FINAL_FILE_HTML
			echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$FINAL_FILE_HTML
			echo '</td>' >>$FINAL_FILE_HTML
			echo '</tr>' >>$FINAL_FILE_HTML
		fi

		if [ "$BKP_METHOD" == "VSU" ] && [ "$FBKP_VAL_NEW" != "GOOD" ]
		then

			echo '<tr>' >>$FINAL_FILE_HTML
			echo '<td align="left">' >>$FINAL_FILE_HTML
			echo '<font face="Arial" size="2"  color="blue"><b><u><a name="Section17">Backup Details: </a></b></u></font>' >>$FINAL_FILE_HTML
			echo '</td>' >>$FINAL_FILE_HTML
			echo '</tr>' >>$FINAL_FILE_HTML
			echo '<tr>' >>$FINAL_FILE_HTML
			echo '<td align="left">' >>$FINAL_FILE_HTML
			echo '<font face="Arial" size="2" color="black">' >>$FINAL_FILE_HTML
			echo '<p>' >>$FINAL_FILE_HTML
			echo "DB alert log does not have any backup information. Please check"  >>$FINAL_FILE_HTML
			echo '</p>' >>$FINAL_FILE_HTML
			echo '</font>' >>$FINAL_FILE_HTML
			echo '</td>' >>$FINAL_FILE_HTML
			echo '</tr>' >>$FINAL_FILE_HTML
			echo '<tr>' >>$FINAL_FILE_HTML
			echo '<td align="left">' >>$FINAL_FILE_HTML
			echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$FINAL_FILE_HTML
			echo '</td>' >>$FINAL_FILE_HTML
			echo '</tr>' >>$FINAL_FILE_HTML
		fi



		if [ $RACChk == 1 ]
		then
			typeset -i TOTAL_SVC_FILE_CNT=`cat $OUTPUT_FILE_HTML_SVC|wc -l`
			if [ $TOTAL_SVC_FILE_CNT -gt 0 ]
			then

				echo '<tr>' >>$FINAL_FILE_HTML
				echo '<td align="left">' >>$FINAL_FILE_HTML
				echo '<font face="Arial" size="2"  color="blue"><b><u><a name="Section20">Database Service Details: </a></b></u></font>' >>$FINAL_FILE_HTML
				echo '</td>' >>$FINAL_FILE_HTML
				echo '</tr>' >>$FINAL_FILE_HTML
				echo '<tr>' >>$FINAL_FILE_HTML
				echo '<td align="left">' >>$FINAL_FILE_HTML
				echo '<font face="Arial" size="1" color="black">' >>$FINAL_FILE_HTML
				echo '<pre>' >>$FINAL_FILE_HTML
				cat $OUTPUT_FILE_HTML_SVC >>$FINAL_FILE_HTML
				echo '</pre>' >>$FINAL_FILE_HTML
				echo '</font>' >>$FINAL_FILE_HTML
				echo '</td>' >>$FINAL_FILE_HTML
				echo '</tr>' >>$FINAL_FILE_HTML
				echo '<tr>' >>$FINAL_FILE_HTML
				echo '<td align="left">' >>$FINAL_FILE_HTML
				echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$FINAL_FILE_HTML
				echo '</td>' >>$FINAL_FILE_HTML
				echo '</tr>' >>$FINAL_FILE_HTML
			fi


			typeset -i TOTAL_RAC_FILE_CNT=`cat $TOTAL_RAC_FILE|wc -l`
			if [ $TOTAL_RAC_FILE_CNT -gt 0 ]
			then

				echo '<tr>' >>$FINAL_FILE_HTML
				echo '<td align="left">' >>$FINAL_FILE_HTML
				echo '<font face="Arial" size="2"  color="blue"><b><u><a name="Section19">Cluster Details: </a></b></u></font>' >>$FINAL_FILE_HTML
				echo '</td>' >>$FINAL_FILE_HTML
				echo '</tr>' >>$FINAL_FILE_HTML
				echo '<tr>' >>$FINAL_FILE_HTML
				echo '<td align="left">' >>$FINAL_FILE_HTML
				echo '<font face="Arial" size="1" color="black">' >>$FINAL_FILE_HTML
				echo '<pre>' >>$FINAL_FILE_HTML
				cat $TOTAL_RAC_FILE >>$FINAL_FILE_HTML
				echo '</pre>' >>$FINAL_FILE_HTML
				echo '</font>' >>$FINAL_FILE_HTML
				echo '</td>' >>$FINAL_FILE_HTML
				echo '</tr>' >>$FINAL_FILE_HTML
				echo '<tr>' >>$FINAL_FILE_HTML
				echo '<td align="left">' >>$FINAL_FILE_HTML
				echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$FINAL_FILE_HTML
				echo '</td>' >>$FINAL_FILE_HTML
				echo '</tr>' >>$FINAL_FILE_HTML
			fi


		fi

		if [ $GGCHK == 1 ]
		then
			typeset -i TOTAL_GG_FILE_CNT=`cat $TOTAL_GG_FILE|wc -l`
			if [ $TOTAL_GG_FILE_CNT -gt 0 ]
			then

				echo '<tr>' >>$FINAL_FILE_HTML
				echo '<td align="left">' >>$FINAL_FILE_HTML
				echo '<font face="Arial" size="2"  color="blue"><b><u><a name="Section18">GoldenGate Details: </a></b></u></font>' >>$FINAL_FILE_HTML
				echo '</td>' >>$FINAL_FILE_HTML
				echo '</tr>' >>$FINAL_FILE_HTML
				echo '<tr>' >>$FINAL_FILE_HTML
				echo '<td align="left">' >>$FINAL_FILE_HTML
				echo '<font face="Arial" size="1" color="black">' >>$FINAL_FILE_HTML
				echo '<pre>' >>$FINAL_FILE_HTML
				cat $TOTAL_GG_FILE >>$FINAL_FILE_HTML
				echo '</pre>' >>$FINAL_FILE_HTML
				echo '</font>' >>$FINAL_FILE_HTML
				echo '</td>' >>$FINAL_FILE_HTML
				echo '</tr>' >>$FINAL_FILE_HTML
				echo '<tr>' >>$FINAL_FILE_HTML
				echo '<td align="left">' >>$FINAL_FILE_HTML
				echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$FINAL_FILE_HTML
				echo '</td>' >>$FINAL_FILE_HTML
				echo '</tr>' >>$FINAL_FILE_HTML
			fi

		fi

		echo '</TABLE>' >>$LOGDIR/HCscript.html

		echo '<TABLE cellpadding="3" cellspacing="0" width='500%'>' >>$LOGDIR/HCscript.html
		echo '<tr><td><pre>' >>$LOGDIR/HCscript.html
		echo " " >>$LOGDIR/HCscript.html
		echo '</pre></td></tr>' >>$LOGDIR/HCscript.html
		echo '</TABLE>' >>$LOGDIR/HCscript.html
	fi



	echo '</TABLE>' >>$FINAL_FILE_HTML
	hostvalue=`hostname -s`
	FILE_VAL_NAME="$LOGDIR/hc_val_$hostvalue.out"
	LDB_STR=`grep -i "INST_CHK:" $FILE_VAL_NAME |head -1`
	LDB_VAL=`echo $LDB_STR | awk '{print $2}' | sed -e 's/%//'`

	if [ "$ARC_VAL" != "No Archive Mode" ] && [ "$LDB_VAL" == "GOOD" ]
	then
		echo '<TABLE cellpadding="3" cellspacing="0">' >>$FINAL_FILE_HTML
		echo '<tr>' >>$FINAL_FILE_HTML
		echo '<td align="left">' >>$FINAL_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><b><u>Archive Log Generation Details: </b></u></font>' >>$FINAL_FILE_HTML
		echo '</td>' >>$FINAL_FILE_HTML
		echo '</tr>' >>$FINAL_FILE_HTML
		echo '</TABLE>' >>$FINAL_FILE_HTML
		cat $LOGDIR/hc_db_arch.out >>$FINAL_FILE_HTML
		echo '<TABLE cellpadding="3" cellspacing="0">' >>$FINAL_FILE_HTML
		echo '<tr>' >>$FINAL_FILE_HTML
		echo '<td align="left">' >>$FINAL_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$FINAL_FILE_HTML
		echo '</td>' >>$FINAL_FILE_HTML
		echo '</tr>' >>$FINAL_FILE_HTML
		echo '</TABLE>' >>$FINAL_FILE_HTML
	fi

	if [ "$LDB_VAL" == "GOOD" ]
	then
		echo '<tr>' >>$FINAL_FILE_HTML
		echo '<td align="left">' >>$FINAL_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><b><u>Top Query Details: </b></u></font>' >>$FINAL_FILE_HTML
		echo '</td>' >>$FINAL_FILE_HTML
		echo '</tr>' >>$FINAL_FILE_HTML
		echo '<tr>' >>$FINAL_FILE_HTML
		echo '<td align="left">' >>$FINAL_FILE_HTML
		echo '<font face="Arial" size="1" color="black"><pre>' >>$FINAL_FILE_HTML
		cat $LOGDIR/Top_sql_details.out >>$FINAL_FILE_HTML
		echo '</pre></font>' >>$FINAL_FILE_HTML
		echo '</td>' >>$FINAL_FILE_HTML
		echo '</tr>' >>$FINAL_FILE_HTML
		echo '<tr>' >>$FINAL_FILE_HTML
		echo '<td align="left">' >>$FINAL_FILE_HTML
		echo '<font face="Arial" size="2"  color="blue"><a href="#main">Back to Top</a></font>' >>$FINAL_FILE_HTML
		echo '</td>' >>$FINAL_FILE_HTML
		echo '</tr>' >>$FINAL_FILE_HTML
	fi


	HTML_FILE=$LOGDIR/sendm_final.html
	cat /dev/null > $LOGDIR/sendm_final.html



#st="prabu.s@one.example.com"
#CClist="prabu.s@one.example.com"

echo "To:$Tolist
Subject:Database Health Check report for $DBNAME from `hostname -s`
To:$TOlist
CC:$CClist
Content-Type: text/html" >  $HTML_FILE





cat $LOGDIR/HCscript.html >> $HTML_FILE

#cat $OUTPUT_FILE_HTML >> $HTML_FILE
cat $FINAL_FILE_HTML >> $HTML_FILE

cat $HTML_FILE | /usr/lib/sendmail -r donotreply@example.com -t


	rm $LOGDIR/*_list*.out
	rm $LOGDIR/asm_*.out
	rm $LOGDIR/Top_sql_details.out
	rm $LOGDIR/HCscript.html
	rm $LOGDIR/sendm_final.html
	rm $LOGDIR/hc_db_temp.html
	rm $LOGDIR/hc_fileiostat.html
	rm $LOGDIR/hc_*.out


fi

echo "done"


