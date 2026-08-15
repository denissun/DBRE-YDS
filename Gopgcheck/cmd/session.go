/*
Copyright © 2022 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"context"
	"fmt"
	"log"
	"os"
	"regexp"
	"time"

	"github.com/jackc/pgx/v4"
	"github.com/spf13/cobra"
	"gitlab.mycompany.com/username/gopgcheck/database"
)

var (
	Username    string
	Event       string
	State       string
	Query       string
	Appname     string
	Aas         bool
	KillBool    bool
	BlockerBool bool
	Duration    int
	Pidlist     string
	Expand      bool
)

// sessionCmd represents the session command
var sessionCmd = &cobra.Command{
	Use:   "session",
	Short: "Get info about sessions, kill sessions and average active session sampling",
	Long:  `Get info about sessions - filtered by username, event, state, query and app name optionally. Kill session and AAS stats`,
	Run: func(cmd *cobra.Command, args []string) {
		// fmt.Println("session called")
		if Aas {
			fmt.Printf("Sampling active session every 1 second is going on, please wait for %d seconds  ... \n", Duration)
			getStatsActiveSession()
		} else if KillBool {
			fmt.Println("Going to kill sessions ...\n")
			killSessions(Pidlist)
		} else if BlockerBool {
			fmt.Println("Find blocker/waiter sessions if any ...\n")
			listBlockers()
		} else {
			listSessions(args)
		}
	},
}

func init() {
	rootCmd.AddCommand(sessionCmd)
	sessionCmd.Flags().StringVarP(&Username, "username", "u", "", "User Name")
	sessionCmd.Flags().StringVarP(&Event, "event", "e", "", "Wait Event")
	sessionCmd.Flags().StringVarP(&State, "state", "s", "", "State")
	sessionCmd.Flags().StringVarP(&Query, "query", "q", "", "Query Text")
	sessionCmd.Flags().StringVarP(&Appname, "app", "a", "", "Application Name")
	sessionCmd.Flags().BoolVarP(&Aas, "aas", "", false, "Sampling Average Active Sessions")
	sessionCmd.Flags().StringVarP(&Pidlist, "pid", "p", "", "pid list  e.g. 123 or 123,456,789 or \"select pid from ...\"")
	sessionCmd.Flags().BoolVarP(&KillBool, "kill", "k", false, "kill sessions (pid flag required)")
	sessionCmd.Flags().BoolVarP(&BlockerBool, "blocker", "b", false, "Show blocker/waiter sessions if any")
	sessionCmd.Flags().BoolVarP(&Expand, "expand", "x", false, "Expanded output - row as column if applicable")
	sessionCmd.Flags().IntVarP(&Duration, "duration", "d", 10, "Sampling interval in seconds - used with aas ")
	//sessionCmd.MarkFlagsRequiredTogether("aas", "duration")
	//sessionCmd.Flags().MarkFlagsMutuallyExclusive("kill", "aas")
}

func listBlockers() {
	connInfo := database.DBConnInfoFromConfig(dbconfig)
	pgUrl := database.GetPgUrlFromConfig(dbconfig)

	conn, err := pgx.Connect(context.Background(), pgUrl)
	LogFatal(err)

	sqltext := `
		SELECT blocked_locks.pid                AS blocked_pid,
			 blocked_activity.usename           AS blocked_user,
			 blocking_locks.pid                 AS blocking_pid,
			 blocking_activity.usename          AS blocking_user,
			 blocked_activity.query             AS blocked_statement,
			 blocking_activity.query            AS current_statement_in_blocking_process,
			 blocked_activity.application_name  AS blocked_application,
			 blocking_activity.application_name AS blocking_application,
	    	 round(EXTRACT(EPOCH FROM  ( now() - blocked_activity.query_start  )))  as blocking_in_seconds,
			 blocking_activity.state AS blocking__state,
			 blocking_activity.wait_event AS blocking_wait_event
		FROM  pg_catalog.pg_locks         blocked_locks
		JOIN pg_catalog.pg_stat_activity blocked_activity  ON blocked_activity.pid = blocked_locks.pid
		JOIN pg_catalog.pg_locks         blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
			AND blocking_locks.DATABASE IS NOT DISTINCT FROM blocked_locks.DATABASE
			AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
			AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
			AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
			AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
			AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
			AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
			AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
			AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
			AND blocking_locks.pid != blocked_locks.pid
		JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
			WHERE NOT blocked_locks.GRANTED
	`

	type Row struct {
		blocked_pid                           int
		blocked_user                          string
		blocking_pid                          int
		blocking_user                         string
		blocked_statement                     string
		current_statement_in_blocking_process string
		blocked_application                   string
		blocking_application                  string
		blocking_in_seconds                   int
		blocking_state                        string
		blocking_wait_event                   string
	}

	rows, err := conn.Query(context.Background(), sqltext)

	LogFatal(err)

	fmt.Println(connInfo)
	fmt.Println("-----------------------------")
	printSql(sqltext, outSql)

	rowCount := 0
	for rows.Next() {
		rowCount++
		var r Row
		err := rows.Scan(&r.blocked_pid, &r.blocked_user, &r.blocking_pid, &r.blocking_user, &r.blocked_statement, &r.current_statement_in_blocking_process, &r.blocked_application, &r.blocking_application, &r.blocking_in_seconds, &r.blocking_state, &r.blocking_wait_event)
		if err != nil {
			log.Fatal(err)
		}

		fmt.Println("## waiter info ")
		fmt.Printf("%-30s :   %d\n", "Blocked Pid", r.blocked_pid)
		fmt.Printf("%-30s :   %s\n", "Blocked User", r.blocked_user)
		fmt.Printf("%-30s :   %s\n", "Blocked App", r.blocked_application)
		fmt.Printf("%-30s :   %s\n", "Blocked Statment", r.blocked_statement)
		fmt.Println("## blocker info ")
		fmt.Printf("%-30s :   %d\n", "Blocking Pid", r.blocking_pid)
		fmt.Printf("%-30s :   %s\n", "Blocking User", r.blocking_user)
		fmt.Printf("%-30s :   %s\n", "Blocking App", r.blocking_application)
		fmt.Printf("%-30s :   %s\n", "Blocking State", r.blocking_state)
		fmt.Printf("%-30s :   %s\n", "Blocking Wait Event", r.blocking_wait_event)
		fmt.Printf("%-30s :   %d\n", "Block in Secs", r.blocking_in_seconds)
		fmt.Printf("%-30s :   %s\n", "Curr Stmt in Blking Process", r.blocked_statement)
		fmt.Println("------------------------------------------------------------------------------------------")
	}

	if rowCount == 0 {
		fmt.Printf("\nNOTE: There are no blockers and waiters at the time of checking: %s\n", time.Now())
	}

}

func killSessions(Pidlist string) {
	if Pidlist == "" {
		fmt.Println("--pid flag is not set")
		fmt.Println("You can use three kinds of values:")
		fmt.Println("1. A single pid, e.g 123")
		fmt.Println("2. A corma separed pid list, e.g 123,456,789")
		fmt.Println("3. A query returns pid list, e.g \"select pid from ...\"")
		os.Exit(1)
	}

	sql := ` SELECT pg_terminate_backend(pid) 
			FROM pg_stat_activity 
			WHERE pid <> pg_backend_pid()
			and pid in ( ` + Pidlist + `)`

	connInfo := database.DBConnInfoFromConfig(dbconfig)
	pgUrl := database.GetPgUrlFromConfig(dbconfig)

	conn, err := pgx.Connect(context.Background(), pgUrl)

	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to connect to database: %v\n", err)
		os.Exit(1)
	}

	defer conn.Close(context.Background())

	fmt.Println(connInfo)
	fmt.Println("-----------------------------")

	printSql(sql, outSql)

	_, err = conn.Exec(context.Background(), sql)
	if err != nil {
		log.Fatal(err)
	}
}

func listSessions(args []string) {
	connInfo := database.DBConnInfoFromConfig(dbconfig)
	pgUrl := database.GetPgUrlFromConfig(dbconfig)

	conn, err := pgx.Connect(context.Background(), pgUrl)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to connect to database: %v\n", err)
		os.Exit(1)
	}

	defer conn.Close(context.Background())

	var sqltext string

	if Expand {
		sqltext = `SELECT COALESCE(datname,'') as datname,
       COALESCE(usename,'') as usename,
       pid,
       COALESCE(state,'') as state,
       COALESCE(wait_event,'') as wait_event,
       query,
       COALESCE(application_name, '') as application_name,
       to_char(COALESCE(current_timestamp - coalesce(xact_start, query_start), interval '0 seconds'), 'HH24:MI:SS') AS xact_runtime
FROM pg_stat_activity
WHERE 1=1  and usename is not null
and pid !=pg_backend_pid() `

	} else {

		sqltext = `SELECT COALESCE(datname,'') as datname,
       COALESCE(usename,'') as usename,
       pid,
       COALESCE(state,'') as state,
       COALESCE(wait_event,'') as wait_event,
       COALESCE(substr(query,1,50),'') as query,
       COALESCE(application_name, '') as application_name,
       to_char(COALESCE(current_timestamp - coalesce(xact_start, query_start), interval '0 seconds'), 'HH24:MI:SS') AS xact_runtime
FROM pg_stat_activity
WHERE 1=1  and usename is not null
and pid !=pg_backend_pid() `
	}

	if Event != "" {
		sqltext = sqltext + " and wait_event like '%" + Event + "%'"
	}

	if Username != "" {
		sqltext = sqltext + " and  usename like '%" + Username + "%'"
	}

	if State != "" {
		sqltext = sqltext + " and  state like '%" + State + "%'"
	}

	if Query != "" {
		sqltext = sqltext + " and  query like '%" + Query + "%'"
	}

	if Appname != "" {
		sqltext = sqltext + " and  application_name like '%" + Appname + "%'"
	}

	if Pidlist != "" {
		sqltext = sqltext + " and pid in (" + Pidlist + ")"
	}

	sqltext = sqltext + " ORDER BY xact_runtime "

	type Row struct {
		datname          string
		usename          string
		pid              int
		state            string
		wait_event       string
		query            string
		application_name string
		xact_runtime     string
	}

	rows, err := conn.Query(context.Background(), sqltext)
	if err != nil {
		log.Fatal(err)
	}

	re := regexp.MustCompile(`\r?\n`)

	fmt.Println(connInfo)
	fmt.Println("-----------------------------")
	printSql(sqltext, outSql)

	if !Expand {
		fmt.Printf("%-15s %-15s %-10s %-10s %-20s %-15s %-15s %-50s\n", "DB", "Username", "PID", "State", "Wait_Event", "App_Name", "Runtime", "Query")
		fmt.Printf("%s %s %s %s %s %s %s %s\n",
			"---------------",
			"---------------",
			"----------",
			"-----------",
			"--------------------",
			"---------------",
			"---------------",
			"---------------------------------------------------")
	}
	for rows.Next() {
		var r Row
		err := rows.Scan(&r.datname, &r.usename, &r.pid, &r.state, &r.wait_event, &r.query, &r.application_name, &r.xact_runtime)
		if err != nil {
			log.Fatal(err)
		}
		if Expand {

			fmt.Printf(" Database Name    : %s\n", r.datname)
			fmt.Printf(" User Name        : %s\n", r.usename)
			fmt.Printf(" PID              : %d\n", r.pid)
			fmt.Printf(" State            : %s\n", r.state)
			fmt.Printf(" Wait Event       : %s\n", r.wait_event)
			fmt.Printf(" Application Name : %s\n", r.application_name)
			fmt.Printf(" Runtime          : %s\n", r.xact_runtime)
			fmt.Printf(" Query            : %s\n", r.query)
			fmt.Printf("--------------------------\n")
		} else {
			fmt.Printf("%-15s %-15s %-10d %-10s %-20s %-15s %-15s %-50s\n", r.datname, r.usename, r.pid, r.state, r.wait_event, r.application_name,
				r.xact_runtime, re.ReplaceAllString(r.query, " "))
		}
	}
}

func getStatsActiveSession() {

	connInfo := database.DBConnInfoFromConfig(dbconfig)
	pgUrl := database.GetPgUrlFromConfig(dbconfig)

	conn, err := pgx.Connect(context.Background(), pgUrl)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to connect to database: %v\n", err)
		os.Exit(1)
	}
	defer conn.Close(context.Background())

	create_sql := `create temporary table tmp_sessions as select * from pg_stat_activity where 1=0`
	insert_sql := `insert into tmp_sessions select * from pg_stat_activity  where state='active' and pid != pg_backend_pid() `

	_, err = conn.Exec(context.Background(), create_sql)
	if err != nil {
		log.Fatal(err)
	}

	// default 10 seconds
	duration := Duration
	start_ts := time.Now()
	sample_start_ts := start_ts.UnixMilli()
	var sleep int64
	sleep = 1000
	for i := 0; i < duration; i++ {
		// t := time.Now().UnixMilli()
		// sleep = 1000 - t%1000
		time.Sleep(time.Duration(sleep) * time.Millisecond)

		_, err = conn.Exec(context.Background(), insert_sql)
		if err != nil {
			log.Fatal(err)
		}
	}
	sample_end_ts := time.Now().UnixMilli()

	fmt.Println("-------------------------------------------------------------------\n")
	fmt.Println(connInfo)
	fmt.Printf("Starting time : %s\n", start_ts)
	fmt.Printf("Actual sample duration : %d millisecond\n", sample_end_ts-sample_start_ts)
	fmt.Println("-------------------------------------------------------------------\n")

	// AAS total
	total_sessions_sql := `SELECT count(*) as total_sessions from tmp_sessions`
	var total_sessions int64
	err = conn.QueryRow(context.Background(), total_sessions_sql).Scan(&total_sessions)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("============== AAS in %d seconds interval: %.1f\n", duration, float32(total_sessions)/float32(duration))

	// AAS by wait event
	fmt.Println("\n============== AAS by Wait Event ==============")
	event_sql := `SELECT COALESCE(wait_event_type, 'N/A') || ' - ' ||  COALESCE(wait_event, 'N/A') as event, count(*) as count from tmp_sessions group by wait_event_type, wait_event order by 2 desc`

	var event string
	var count int

	rows, err := conn.Query(context.Background(), event_sql)
	if err != nil {
		log.Fatal(err)
	}

	for rows.Next() {
		err := rows.Scan(&event, &count)
		if err != nil {
			log.Fatal(err)
		}
		fmt.Printf("%-35s  %.1f\n", event, float32(count)/float32(duration))
	}

	// AAS by User
	fmt.Println("\n============== AAS by Username ================")
	usename_sql := `SELECT COALESCE(usename, 'N/A') as username, count(*) as count from tmp_sessions group by usename order by 2 desc`

	var username string

	rows, err = conn.Query(context.Background(), usename_sql)
	if err != nil {
		log.Fatal(err)
	}

	for rows.Next() {
		err := rows.Scan(&username, &count)
		if err != nil {
			log.Fatal(err)
		}
		fmt.Printf("%-35s  %.1f\n", username, float32(count)/float32(duration))
	}

	// AAS by Application Name
	fmt.Println("\n============== AAS by Application =============")
	application_sql := `SELECT COALESCE(application_name, 'N/A') as application, count(*) as count from tmp_sessions group by application_name order by 2 desc`

	var application_name string

	rows, err = conn.Query(context.Background(), application_sql)
	if err != nil {
		log.Fatal(err)
	}

	for rows.Next() {
		err := rows.Scan(&application_name, &count)
		if err != nil {
			log.Fatal(err)
		}
		fmt.Printf("%-35s  %.1f\n", application_name, float32(count)/float32(duration))
	}

	// AAS by Backend Type
	fmt.Println("\n============== AAS by Backend Type ============")
	backend_type_sql := `SELECT COALESCE(backend_type, 'N/A') as backend_type, count(*) as count from tmp_sessions group by backend_type order by 2 desc`

	var backend_type string

	rows, err = conn.Query(context.Background(), backend_type_sql)
	if err != nil {
		log.Fatal(err)
	}

	for rows.Next() {
		err := rows.Scan(&backend_type, &count)
		if err != nil {
			log.Fatal(err)
		}
		fmt.Printf("%-35s  %.1f\n", backend_type, float32(count)/float32(duration))
	}

	// AAS by Client_Addr_Host
	fmt.Println("\n============== AAS by Client Addr Host ========")
	client_sql := `SELECT COALESCE(client_addr, '0.0.0.0') ||  ' - ' ||  COALESCE(client_hostname, 'N/A') as addr_host , count(*) as count
                             from tmp_sessions group by client_addr, client_hostname order by 2 desc`

	var addr_host string

	rows, err = conn.Query(context.Background(), client_sql)
	if err != nil {
		log.Fatal(err)
	}

	for rows.Next() {
		err := rows.Scan(&addr_host, &count)
		if err != nil {
			log.Fatal(err)
		}
		fmt.Printf("%-35s  %.1f\n", addr_host, float32(count)/float32(duration))
	}

	// AAS by Query
	fmt.Println("\n============== AAS by Query - Top 10 ==========")
	query_sql := `SELECT COALESCE(substr(query,1,80), 'N/A') as username, count(*) as count from tmp_sessions group by substr(query,1,80) order by 2 desc limit 10`

	var query string
	rows, err = conn.Query(context.Background(), query_sql)
	if err != nil {
		log.Fatal(err)
	}

	for rows.Next() {
		err := rows.Scan(&query, &count)
		if err != nil {
			log.Fatal(err)
		}
		fmt.Printf("%-80s  %.1f\n", query, float32(count)/float32(duration))
	}
}
