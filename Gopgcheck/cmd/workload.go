/*
Copyright © 2022 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/jackc/pgx/v4"
	"github.com/spf13/cobra"
	"gitlab.mycompany.com/username/gopgcheck/database"
)

var (
	DbStat         bool
	DbStatRecent   bool
	SqlStat        bool
	TopSql         bool
	OrderBy        string
	DurationDbStat int
	WorkloadLimit  int
)

// workloadCmd represents the workload command
var workloadCmd = &cobra.Command{
	Use:   "workload",
	Short: "Show stats about workload",
	Long:  `Show stats about workload,e.g. transacntion per sec etc`,
	Run: func(cmd *cobra.Command, args []string) {
		if DbStat {
			getDatabaseStats()
		} else if DbStatRecent {
			getDatabaseStatsRecent(DurationDbStat)
		} else if SqlStat {
			getSqlStats(DurationDbStat)
		} else if TopSql {
			getTopSql(OrderBy)
		} else {
			fmt.Println("Invalid falgs")
			fmt.Println("For help: gopgcheck workload -h")
			os.Exit(1)
		}
	},
}

func init() {
	rootCmd.AddCommand(workloadCmd)
	workloadCmd.Flags().BoolVarP(&DbStat, "db-stats-hist", "", false, "Querying pg_stat_databases to get stats since last reset")
	workloadCmd.Flags().BoolVarP(&DbStatRecent, "db-stats", "", false, "Sampling pg_stat_databases to get stats in real time")
	workloadCmd.Flags().BoolVarP(&SqlStat, "sql-stats", "", false, "Sampling pg_stat_statements to get top SQLs in real time")
	workloadCmd.Flags().BoolVarP(&TopSql, "top-sql", "", false, "Querying pg_stat_statements to get top SQLs since last reset")
	workloadCmd.Flags().StringVarP(&OrderBy, "order", "", "ela", "Top SQLs order by ela, get, ela-ps, get-ps")
	workloadCmd.Flags().IntVarP(&DurationDbStat, "duration", "d", 10, "Duration in seconds - used with db-stats or sql-stats")
	workloadCmd.Flags().IntVarP(&WorkloadLimit, "limit", "l", 10, "Limit the number of rows")

}
func getDatabaseStatsRecent(Duration int) {
	// fmt.Println("call getDatabaseStatsRecent ...")
	connInfo := database.DBConnInfoFromConfig(dbconfig)
	pgUrl := database.GetPgUrlFromConfig(dbconfig)
	conn, err := pgx.Connect(context.Background(), pgUrl)
	if err != nil {
		log.Fatal(err)
	}

	sqltext := `select case when length(datname) > 25  then
                             concat('..' , right(datname,23))
                         else
                             coalesce (datname, '-')
                         end db
			,numbackends    
			,xact_commit    
			,xact_rollback  
			,blks_read      
			,blks_hit       
			,tup_returned   
			,tup_fetched    
			,tup_inserted   
			,tup_updated    
			,tup_deleted    
			,temp_files     
			,round(temp_bytes/1024/1024,0) as temp_bytes_mb     
            ,to_char(now()::timestamp(0), 'YYYY-MM-DD HH24:MI:SS') stime
			,deadlocks      
             from pg_stat_database order by datname`

	type Row struct {
		db            string
		numbackends   int
		xact_commit   int64
		xact_rollback int64
		blks_read     int64
		blks_hit      int64
		tup_returned  int64
		tup_fetched   int64
		tup_inserted  int64
		tup_updated   int64
		tup_deleted   int64
		temp_files    int64
		temp_bytes_mb int64
		stime         string
		deadlocks     int32
	}

	// rows, err := conn.Query(context.Background(), sqltext)
	rows, err := conn.Query(context.Background(), sqltext)

	if err != nil {
		log.Fatal(err)
	}

	snap1 := []Row{}

	for rows.Next() {
		var r Row
		err = rows.Scan(&r.db,
			&r.numbackends,
			&r.xact_commit,
			&r.xact_rollback,
			&r.blks_read,
			&r.blks_hit,
			&r.tup_returned,
			&r.tup_fetched,
			&r.tup_inserted,
			&r.tup_updated,
			&r.tup_deleted,
			&r.temp_files,
			&r.temp_bytes_mb,
			&r.stime,
			&r.deadlocks)

		if err != nil {
			log.Fatal(err)
		}
		snap1 = append(snap1, r)
	}

	fmt.Printf("Sampling, please wait for about %d seconds ... \n\n", Duration)

	time.Sleep(time.Duration(Duration) * time.Second)

	rows, err = conn.Query(context.Background(), sqltext)

	if err != nil {
		log.Fatal(err)
	}

	snap2 := []Row{}

	for rows.Next() {
		var r Row
		err = rows.Scan(&r.db,
			&r.numbackends,
			&r.xact_commit,
			&r.xact_rollback,
			&r.blks_read,
			&r.blks_hit,
			&r.tup_returned,
			&r.tup_fetched,
			&r.tup_inserted,
			&r.tup_updated,
			&r.tup_deleted,
			&r.temp_files,
			&r.temp_bytes_mb,
			&r.stime,
			&r.deadlocks)

		if err != nil {
			log.Fatal(err)
		}
		snap2 = append(snap2, r)
	}

	fmt.Println(connInfo)

	fmt.Println("============== Database Metrics Change Rate as Seen in PG_STAT_DATABASE  ===============")
	fmt.Printf("==============       beginning sample time: %s          ===============\n", snap1[0].stime)
	fmt.Printf("==============             sample duration: %d seconds                   ===============\n\n\n", Duration)

	fmt.Printf("%-25s %-8s %-8s %-8s %-10s %-10s %-10s %-8s %-8s %-8s %-10s %-12s %-9s\n", "datname", "#bcknds", "TPS", "blk_", "blk_", "tup_", "tup_", "tup_", "tup_", "tup_", "tmpfiles", "tmpbyts_M", "deadlck")
	// secondline header
	fmt.Printf("%-25s %-8s %-8s %-8s %-10s %-10s %-10s %-8s %-8s %-8s %-10s %-12s %-9s\n", "   ", "(delta)", "", "read/s", "hit/s", "rtrnd/s", "ftchd/s", "ins/s", "upd/s", "del/s", "(delta)", "(delta)", "(delta)")

	fmt.Printf("%-25s %-8s %-4s %-8s %-10s %-10s %-10s %-8s %-8s %-8s %-10s %-12s %-9s\n", "-------------------------", "--------", "--------", "--------", "----------", "----------", "----------", "--------", "--------", "--------", "----------", "------------", "---------")

	for i := 0; i < len(snap2); i++ {
		fmt.Printf("%-25s %-8s %-8.1f %-8.1f %-10.1f %-10.1f %-10.1f %-8.1f %-8.1f %-8.1f %-10s %-12s %-9s\n",
			snap2[i].db,
			fmt.Sprintf("%d (%d)", snap1[i].numbackends, snap2[i].numbackends-snap1[i].numbackends),
			float32(snap2[i].xact_commit+snap2[i].xact_rollback-snap1[i].xact_commit-snap1[i].xact_rollback)/float32(Duration),
			float32(snap2[i].blks_read-snap1[i].blks_read)/float32(Duration),
			float32(snap2[i].blks_hit-snap1[i].blks_hit)/float32(Duration),
			float32(snap2[i].tup_returned-snap1[i].tup_returned)/float32(Duration),
			float32(snap2[i].tup_fetched-snap1[i].tup_fetched)/float32(Duration),
			float32(snap2[i].tup_inserted-snap1[i].tup_inserted)/float32(Duration),
			float32(snap2[i].tup_updated-snap1[i].tup_updated)/float32(Duration),
			float32(snap2[i].tup_deleted-snap1[i].tup_deleted)/float32(Duration),
			fmt.Sprintf("%d (%d)", snap1[i].temp_files, snap2[i].temp_files-snap1[i].temp_files),
			fmt.Sprintf("%d (%d)", snap1[i].temp_bytes_mb, snap2[i].temp_bytes_mb-snap1[i].temp_bytes_mb),
			fmt.Sprintf("%d (%d)", snap1[i].deadlocks, snap2[i].deadlocks-snap1[i].deadlocks))
	}
}

func getDatabaseStats() {
	connInfo := database.DBConnInfoFromConfig(dbconfig)
	pgUrl := database.GetPgUrlFromConfig(dbconfig)
	conn, err := pgx.Connect(context.Background(), pgUrl)

	sqltext := ` select coalesce(datname,'-') as datname, to_char(stats_reset, 'YYYY-MM-DD HH24:MI:SS') as stats_reset ,round(((xact_commit + xact_rollback) /EXTRACT(EPOCH FROM (now() - stats_reset)))::numeric,1) as xtrans_per_sec
		,round((tup_returned /EXTRACT(EPOCH FROM (now() - stats_reset)))::numeric,1) as tup_returned_per_sec
		,round((tup_fetched /EXTRACT(EPOCH FROM (now() - stats_reset)))::numeric,1) as tup_fetched_per_sec
		,round((tup_inserted /EXTRACT(EPOCH FROM (now() - stats_reset)))::numeric,1) as tup_inserted_per_sec
		,round((tup_updated /EXTRACT(EPOCH FROM (now() - stats_reset)))::numeric,1) as tup_updated_per_sec
		,round((tup_deleted /EXTRACT(EPOCH FROM (now() - stats_reset)))::numeric,1) as tup_deleted_per_sec
		from pg_stat_database
		where stats_reset is not null
		order by 5 desc`

	type Row struct {
		datname              string
		stats_reset          string
		xtrans_per_sec       float32
		tup_returned_per_sec float32
		tup_fetched_per_sec  float32
		tup_inserted_per_sec float32
		tup_updated_per_sec  float32
		tup_deleted_per_sec  float32
	}

	rows, err := conn.Query(context.Background(), sqltext)
	LogFatal(err)

	fmt.Println(connInfo)
	fmt.Println("-----------------------------\n")

	fmt.Printf("%s %s %s %s %s %s %s %s\n", "Database                 ", "Stats_Reset        ", "Xtrans_Per_Sec", "Tup_Returned_Per_Sec", "Tup_Fetched_Per_Sec", "Tup_Inserted_Per_Sec", "Tup_Updated_Per_Secs", "Tup_Deleted_Per_Sec")
	fmt.Printf("%s %s %s %s %s %s %s %s\n", "-------------------------", "-------------------", "--------------", "--------------------", "-------------------", "--------------------", "--------------------", "-------------------")

	for rows.Next() {
		var r Row
		err := rows.Scan(&r.datname, &r.stats_reset, &r.xtrans_per_sec, &r.tup_returned_per_sec, &r.tup_fetched_per_sec, &r.tup_inserted_per_sec, &r.tup_updated_per_sec, &r.tup_deleted_per_sec)
		LogFatal(err)
		fmt.Printf("%-25s %-11s %14.1f %20.1f %19.1f %20.1f %20.1f %19.1f\n", r.datname, r.stats_reset, r.xtrans_per_sec, r.tup_returned_per_sec, r.tup_fetched_per_sec, r.tup_inserted_per_sec, r.tup_updated_per_sec, r.tup_deleted_per_sec)

	}

}

func getSqlStats(Duration int) {
	connInfo := database.DBConnInfoFromConfig(dbconfig)
	pgUrl := database.GetPgUrlFromConfig(dbconfig)
	conn, err := pgx.Connect(context.Background(), pgUrl)

	create_sql := `create temporary table temp_sqls as
select  1 as snap_id,  now() as mon_ts, b.queryid ,u.usename , d.datname
      , substr(b.query, 1,500) query_text
      , b.calls
       , b.rows
       , b.shared_blks_hit
       , b.shared_blks_read
       , b.total_time
from pg_stat_statements b join pg_user u on u.usesysid=b.userid join pg_database d on b.dbid = d.oid
`
	insert_sql := ` insert into temp_sqls
select  2 as snap_id,  now() as mon_ts, b.queryid ,u.usename , d.datname
      , substr(b.query, 1,500) query_text
      , b.calls
       , b.rows
       , b.shared_blks_hit
       , b.shared_blks_read
       , b.total_time
from pg_stat_statements b join pg_user u on u.usesysid=b.userid join pg_database d on b.dbid = d.oid`

	sqltext := ` select e.queryid, e.usename, e.datname, 
      e.calls - coalesce(s.calls,0) delta_calls,
      e.rows - coalesce(s.rows,0) delta_rows,
      e.shared_blks_hit - coalesce(s.shared_blks_hit,0) delta_bhits,
      e.shared_blks_read - coalesce(s.shared_blks_read,0) delta_bread,
      e.total_time - coalesce(s.total_time,0) delta_total_time,
      e.query_text,
	  EXTRACT(EPOCH FROM ( e.mon_ts - coalesce(s.mon_ts, e.mon_ts) )) interval_secs
from
(select * from temp_sqls where snap_id=2) e left outer join
(select * from temp_sqls where snap_id=1) s on (e.queryid = s.queryid and e.usename=s.usename and e.datname=s.datname)
where e.total_time - coalesce(s.total_time,0) > 0 
order by  e.total_time - coalesce(s.total_time,0)  desc
limit $1`

	type Row struct {
		queryid          int64
		usename          string
		datname          string
		delta_calls      int64
		delta_rows       int64
		delta_bhits      int64
		delta_bread      int64
		delta_total_time float64
		query_text       string
		interval_secs    float32
	}

	fmt.Printf("Sampling pg_stat_statment in progress wait about %d seconds ... \n\n", Duration)

	_, err = conn.Exec(context.Background(), create_sql)
	LogFatal(err)

	time.Sleep(time.Duration(Duration) * time.Second)

	_, err = conn.Exec(context.Background(), insert_sql)
	LogFatal(err)

	rows, err := conn.Query(context.Background(), sqltext, WorkloadLimit)
	LogFatal(err)

	fmt.Println(connInfo)
	fmt.Println("-----------------------------\n")

	for rows.Next() {
		var r Row
		err := rows.Scan(&r.queryid, &r.usename, &r.datname, &r.delta_calls, &r.delta_rows, &r.delta_bhits, &r.delta_bread, &r.delta_total_time, &r.query_text, &r.interval_secs)
		LogFatal(err)
		fmt.Printf("(queryid, usename, datname) | (%d, %s, %s)\n", r.queryid, r.usename, r.datname)
		fmt.Printf("total_time_ms               | %.1f\n", r.delta_total_time)
		fmt.Printf("calls                       | %d\n", r.delta_calls)
		fmt.Printf("rows                        | %d\n", r.delta_rows)
		fmt.Printf("logic reads                 | %d\n", r.delta_bhits+r.delta_bread)
		fmt.Printf("calls per secs              | %.1f\n", float32(r.delta_calls)/r.interval_secs)
		fmt.Printf("shared blocks hit           | %.1f\n", float32(r.delta_bhits))
		fmt.Printf("shared blocks read          | %.1f\n", float32(r.delta_bread))
		fmt.Printf("actual interval in secs     | %f\n", r.interval_secs)
		if r.delta_calls > 0 {
			fmt.Printf("time_ms_per_call            | %.1f\n", r.delta_total_time/float64(r.delta_calls))
			fmt.Printf("rows_per_call               | %.1f\n", float32(r.delta_rows)/float32(r.delta_calls))
			fmt.Printf("logical_read_per_call       | %.1f\n", float32(r.delta_bhits+r.delta_bread)/float32(r.delta_calls))
		}
		fmt.Printf("query text                  | %s\n", r.query_text)
		fmt.Println("-----------------------------------------------------------------------------------\n")
	}
}
func getTopSql(OrderBy string) {
	// fmt.Printf("get top sqls order by %s\n", OrderBy)
	connInfo := database.DBConnInfoFromConfig(dbconfig)
	pgUrl := database.GetPgUrlFromConfig(dbconfig)
	conn, err := pgx.Connect(context.Background(), pgUrl)

	sqltext := ` 
SELECT datname, 
       a.rolname,
       calls, 
       total_time, 
       rows, 
       shared_blks_hit + shared_blks_read as logic_reads,
       round(total_time/calls) as ms_per_call,  
       round((shared_blks_hit + shared_blks_read)/calls) logic_reads_per_call,
       query 
FROM pg_stat_statements as s inner join
    pg_database as d on d.oid =s.dbid
    inner join pg_roles as a on s.userid = a.oid
where datname not in ('rdsadmin')
`
	var message string
	if OrderBy == "get" {
		sqltext = sqltext + "  order by logic_reads  desc limit $1"
		message = "Logical Reads"
	} else if OrderBy == "get-ps" {
		sqltext = sqltext + "  order by logic_reads_per_call desc limit $1"
		message = "Logical Reads Per Call"
	} else if OrderBy == "ela-ps" {
		sqltext = sqltext + "  order by ms_per_call desc limit $1"
		message = "Elaspsed Time Per Call"
	} else {
		sqltext = sqltext + "  order by total_time desc limit $1 "
		message = "Total Elaspsed Time"
	}

	type Row struct {
		datname              string
		rolname              string
		calls                int64
		total_time           float64
		rows                 int64
		logic_reads          int64
		ms_per_call          float32
		logic_reads_per_call float32
		query                string
	}

	rows, err := conn.Query(context.Background(), sqltext, WorkloadLimit)
	LogFatal(err)

	fmt.Println(connInfo)
	fmt.Println("-----------------------------\n")

	printSql(sqltext, outSql)

	fmt.Printf("\n======= REPORT: Top %d SQLs Order By %s ======\n\n", WorkloadLimit, message)

	for rows.Next() {
		var r Row
		err := rows.Scan(&r.datname, &r.rolname, &r.calls, &r.total_time, &r.rows, &r.logic_reads, &r.ms_per_call, &r.logic_reads_per_call, &r.query)
		LogFatal(err)
		fmt.Printf("database                    | %s\n", r.datname)
		fmt.Printf("user                        | %s\n", r.rolname)
		fmt.Printf("calls                       | %d\n", r.calls)
		fmt.Printf("total_time                  | %.1f\n", r.total_time)
		fmt.Printf("rows                        | %d\n", r.rows)
		fmt.Printf("logic_reads                 | %d\n", r.logic_reads)
		fmt.Printf("ms per call                 | %.1f\n", r.ms_per_call)
		fmt.Printf("logic reads per call        | %.1f\n", r.logic_reads_per_call)
		fmt.Printf("query                       | %s\n", r.query)
		fmt.Println("--------------------------------------------------------------------\n")
	}
}
