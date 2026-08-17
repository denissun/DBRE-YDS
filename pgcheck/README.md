# pgcheck.py is a program to report various PostgreSQL database info for DBA


# binary version

A binary version (pgcheck) is provided under dist/

it can be run in Linux environment. No python software needed if you run binary version


## some python packages required:

      pip install psycopg2-binary
      pip install config
      pip install configparser

## tested with python 2.7.5

## Author:  Yu (Denis) Sun 



## program files:

pgcheck.py
database.ini  ( containing password,  readonly by owner : 600)

## to try out in this server:

   copy above *.py files to your directory. edit a database.ini file
   pgcheck.py is currently being updated frequently, check often to get lastest version


## content of database.ini - example

    put your own username and password !

        [username@123-456-7-89 pycheck]$ cat database.ini
        [postgresql]
        host=abcdeg.us-east-1.rds.amazonaws.com
        port=5432
        database=vvoprdtp
        user=username
        password=xxxx


      note: if password not in the int file, you will be prompted to enter password

## usage

        Specify  -h to get help message

	(venv) oracle@someip.mycom.com:/u01/app/postgres/pgcheck [etsdb] $ pgcheck.py  -h
	usage: pgcheck.py [-h] [-dbs] [-dbsps] [-sdd] [--delta DELTA] [-std]
			  [--schname SCHNAME] [--tabname TABNAME] [-ts]
			  [--tsorder TSORDER] [-pssst] [-psss] [-psast] [-psas] [-ad]
			  [-at] [-ds] [-dt] [-tsn] [--dbname DBNAME] [-df] [-bs] [-br]
			  [-cso] [-gf] [--funcname FUNCNAME] [-ht] [-htd] [-st] [-to]
			  [-ti] [-tcs] [-tnpu] [-a] [-bl] [-c] [-cus] [-sk] [-sl]
			  [--querytext QUERYTEXT] [--event EVENT] [--user USER]
			  [--pid PID] [-rq] [-we] [-dg] [--limit LIMIT] [-l] [-niit]
			  [-nsql] [-ps] [-v]
			  [DBConfigFile]

		     PGCHECK - Report Various Info Of A PostgreSQL Database for DBA
				 - Version 1.4 by Yu (Denis) Sun
					 created: 6-Mar-2019
					 updated: 08-Aug-2019


	positional arguments:
	  DBConfigFile          Specify a PostgreSQL instance connection configuration
				file. Default: database.ini

	optional arguments:
	  -h, --help            show this help message and exit

	Workload and Performance:
	  -dbs, --db_stats      Display Statistics for All Databases
	  -dbsps, --db_stats_per_sec
				Display Per-Sec Statistics Since Last Reset for All
				Databases,.e.g Trascation/s
	  -sdd, --stat_database_delta
				Display delta change rates from pg_stat_database (i.e.
				TPS etc) with --delta
	  --delta DELTA         n seconds
	  -std, --stat_table_delta
				Display delta changes and change rates from
				pg_stat_user_tables, with --schname --tabname and
				--delta
	  --schname SCHNAME     Specify a scheman name, default public; used with -st
				-std
	  --tabname TABNAME     Specify a tablename name; used with -st -std
	  -ts, --top_sql        Display top 20 SQL from pg_stat_statement
	  --tsorder TSORDER     Used with -ts option: tot - order by total execution
				time (default); avg - order by average execution time
	  -pssst, --pg_stat_statements_sampling_tt
				Sampling pg_stat_statements and report top queries -
				temp table (to be deprecated)
	  -psss, --pg_stat_statements_sampling
				Sampling pg_stat_statements and report top queries
	  -psast, --pg_stat_activity_sampling_tt
				Sampling pg_stat_activity and report top activities
				using temp table, write privilege required (to be
				deprecated)
	  -psas, --pg_stat_activity_sampling
				Sampling pg_stat_activity and report top activities
				using dataframe

	Objects:
	  Object (table, index, function) Related Info or Operations

	  -ad, --age_db         Which database is aging
	  -at, --age_table      Which tables are aging.
	  -ds, --db_size        Display db size, --dbname option required
	  -dt, --desc_tab       Describe Table used with --schname --tabname options
	  -tsn, --table_search_name
				Given table name, return table info
	  --dbname DBNAME       Specify a database name,used with -ds option
	  -df, --display_functions
				List Of Functions as in psql \df
	  -bs, --bloat_size     Display top 20 bloat tables by size
	  -br, --bloat_ratio    Display top 20 bloat tables by ratio
	  -cso, --count_schema_owner
				Table Counts By Schema And Owner
	  -gf, --get_function   Generate Function Definition Code, with --schname
				--funcname option
	  --funcname FUNCNAME   Specify a function name,used with -gf option
	  -ht, --hot_tables     Display top 20 hot tables for DML activities
	  -htd, --hot_tables_by_dead_tup
				Display top 20 hot tables sort by deat tup
	  -st, --stat_table     Display info from pg_stat_user_tables, with --schname
				--tabname
	  -to, --top_objects    Top 20 Objects by Size
	  -ti, --table_index    List Indexes of A Table, require --schname --tabname
				options
	  -tcs, --table_colstats
				Display Table Colume Statistics from pg_stats, require
				--schname --tabname options
	  -tnpu, --table_no_pkuk
				Display All Tables Without Primary Or Unique Keys

	Sessions:
	  Session (connection) Related Info or Operations

	  -a, --active_session  Display active session
	  -bl, --blockers       Display blockers
	  -c, --conn_info       Display current connecting session related info
	  -cus, --count_user_state
				Session Count by Username and State
	  -sk, --session_kill   kill sessions by pids: 123, '123,456' or 'select pid
				from ...'
	  -sl, --session_list   List sessions by different criteria default all
	  --querytext QUERYTEXT
				query text - used with -sl
	  --event EVENT         event - used with -sl
	  --user USER           user - used with -sl
	  --pid PID             pid - used with -sl -sk
	  -rq, --running_query  Display top 10 current running queries order by
				duration (excluding rdsadmin)
	  -we, --wait_event     Display Session wait event count

	General:
	  -dg, --display_roles  list of rolos as in psql \dg+
	  --limit LIMIT         Specify an INT value as limit to append to a query
	  -l, --list_db         List of databases as \l+ in psql
	  -niit, --no_idle_in_transaction
				exclude sessions with IDLE IN TRANCTION in some
				queries
	  -nsql, --no_sqltext   Don't print out sql text
	  -ps, --pg_settings    Display PG settings
	  -v, --version         Display PG version
	 
	 


## python environment

  You may need to set up your python location at the first line of pgcheck.py file

  e.g.
	#!/misc/PythonVirtualEnv/bin/python


## pgconn.sh and pgconn2.sh

  They are convenient shell scripts to connect to pg database that can use same .ini files as input



## Example  -sdd

	someip.mycomp.com:/misc/denis/pgcheck [] $ pgcheck.py ini/appb-pr001.ini -sdd -nsql
	Trying to obtain connection info from ini/appb-pr001.ini ...
	Trying to obtain connection info from ini/appb-pr001.ini ...
	waiting for 10 seconds ...
	============== Database Metrics Change Rate as Seen in PG_STAT_DATABASE  ===============
	==============       beginning sample time: 2019-07-19 22:25:25          ===============
	==============             sample duration: 10 seconds                   ===============

			  datname  #bcknds  TPS     blk_       blk_       tup_       tup_  tup_  tup_  tup_   tmpfiles    tmpbyts_M   deadlck
				   (delta)        read/s      hit/s    rtrnd/s    ftchd/s ins/s upd/s del/s    (delta)      (delta)   (delta)
	------------------------- -------- ---- -------- ---------- ---------- ---------- ----- ----- ----- ---------- ------------ ---------
		accountservicesvc     2(0)    0        0         31        695          2     0     0     0       0(0)         0(0)      0(0)
	       acverificationhold     0(0)    0        0          6        108          1     0     0     0       0(0)         0(0)      0(0)
		addressservicesvc     2(0)    0        0         35        678          2     0     0     0       0(0)         0(0)      0(0)
		  agentservicesvc     2(0)    0        0         30        684          2     0     0     0       0(0)         0(0)      0(0)
		      aspsessions     0(0)    0        0         13        195          2     0     0     0       0(0)         0(0)      0(0)
			   bdvsvc     0(0)    0        0         24        292          2     0     0     0       0(0)         0(0)      0(0)
		   callmanagersvc     2(0)    0        0         22        305          2     0     0     0       0(0)         0(0)      0(0)
	   checkoutapplicationsvc     0(0)    0        0         20        269          2     0     0     0       0(0)         0(0)      0(0)
			configsvc     0(0)    0        0         13        198          2     0     0     0       0(0)         0(0)      0(0)
			      dba     0(0)    0        0         17        240          2     0     0     0       0(0)         0(0)      0(0)
		  fiosproductssvc     0(0)    0        0         25        309          2     0     0     0       0(0)         0(0)      0(0)
		    guidedflowsvc     2(0)    0        0         26        604          2     0     0     0       0(0)         0(0)      0(0)
			   hsisvc     0(0)    0        0         21        306          2     0     0     0       0(0)         0(0)      0(0)
			 offersvc     0(0)    0        0         23        299          2     0     0     0       0(0)         0(0)      0(0)
			 ordersvc     2(0)    0        0         30        674          2     0     0     0       0(0)         0(0)      0(0)
			 postgres     2(0)    0        0         13        195          2     0     0     0       0(0)         0(0)      0(0)
	      pqaccountservicesvc     0(0)    0        0         25        312          2     0     0     0       0(0)         0(0)      0(0)
	      pqaddressservicesvc     0(0)    0        0         24        305          2     0     0     0       0(0)         0(0)      0(0)
			 pqbdvsvc     0(0)    0        0         23        285          2     0     0     0       0(0)         0(0)      0(0)
		    pqfiosdatasvc     0(0)    0        0         23        296          2     0     0     0       0(0)         0(0)      0(0)
		 pqfiosproductsvc     0(0)    0        0         21        296          2     0     0     0       0(0)         0(0)      0(0)
			 pqhsisvc     0(0)    0        0         23        299          2     0     0     0       0(0)         0(0)      0(0)
			 pqlecsvc     0(0)    0        0         23        295          2     0     0     0       0(0)         0(0)      0(0)
		       pqoffersvc     0(0)    0        0         21        296          2     0     0     0       0(0)         0(0)      0(0)
		       pqordersvc     0(0)    0        0         23        296          2     0     0     0       0(0)         0(0)      0(0)
		  pqpricequotesvc     0(0)    0        0         21        301          2     0     0     0       0(0)         0(0)      0(0)
	  pqproductsaggregatorsvc     0(0)    0        0         23        296          2     0     0     0       0(0)         0(0)      0(0)
		     pqsessionsvc     0(0)    0        0         23        296          2     0     0     0       0(0)         0(0)      0(0)
	     pqtelephonenumbersvc     0(0)    0        0         23        297          2     0     0     0       0(0)         0(0)      0(0)
		pricequotecentral     0(0)    0        0         16        244          2     0     0     0       0(0)         0(0)      0(0)
		    pricequotesvc     0(0)    0        0         24        301          2     0     0     0       0(0)         0(0)      0(0)
	    productsaggregatorsvc     0(0)    0        0         23        299          2     0     0     0       0(0)         0(0)      0(0)
		       productsvc     2(0)    0        0         31        671          2     0     0     0       0(0)         0(0)      0(0)
			 rdsadmin     4(0)    2        0         14        197          2     0     0     0       0(0)         0(0)      0(0)
			      rpc     2(0)    0        0         24        502          2     0     0     0       0(0)         0(0)      0(0)
			searchsvc     2(0)    0        0         34        795          2     0     0     0       0(0)         0(0)      0(0)
		       sessionsvc     2(0)    0        0         31        671          2     0     0     0       0(0)         0(0)      0(0)
	       telephonenumbersvc     0(0)    0        0         29        671          2     0     0     0       0(0)         0(0)      0(0)
			template0     0(0)    0        0          0          0          0     0     0     0       0(0)         0(0)      0(0)
			template1     0(0)    0        0         13        195          2     0     0     0       0(0)         0(0)      0(0)


## pyinstaller pgcheck.py -F

create a one-file bundled executable