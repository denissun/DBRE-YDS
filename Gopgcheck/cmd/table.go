/*
Copyright © 2022 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"context"
	"database/sql"
	"fmt"
	"os"

	"github.com/jackc/pgx/v4"
	"github.com/spf13/cobra"
	"gitlab.mycompany.com/username/gopgcheck/database"
)

var (
	AgingBool    bool
	SizeBool     bool
	HotBool      bool
	ColstatsBool bool
	IndexBool    bool
	Limit        int
	TableName    string
	Schema       string
)

// tableCmd represents the table command
var tableCmd = &cobra.Command{
	Use:   "table",
	Short: "Display Info About Tables",
	Long:  `Display Info About Tables`,
	Run: func(cmd *cobra.Command, args []string) {
		if AgingBool {
			showAgingTables()
		} else if SizeBool {
			showSizeTables()
		} else if HotBool {
			showHotTables()
		} else if IndexBool {
			if TableName == "" {
				fmt.Println("Table name is not provided")
				os.Exit(1)
			}
			showTableIndexes(Schema, TableName)
		} else if ColstatsBool {
			if TableName == "" {
				fmt.Println("Table name is not provided")
				os.Exit(1)
			}
			showColstats(Schema, TableName)
		} else {
			fmt.Println("No valid flags")
			fmt.Println("For help: gopgcheck table -h")
			os.Exit(1)
		}
	},
}

func init() {
	rootCmd.AddCommand(tableCmd)
	tableCmd.Flags().BoolVarP(&AgingBool, "aging", "", false, "Show top aging tables")
	tableCmd.Flags().BoolVarP(&SizeBool, "size", "", false, "Show top tables by size")
	tableCmd.Flags().BoolVarP(&HotBool, "hot", "", false, "Show top tables by dml activities")
	tableCmd.Flags().BoolVarP(&IndexBool, "index", "", false, "List all indexes of a table, --table-name and --schema required")
	tableCmd.Flags().BoolVarP(&ColstatsBool, "colstats", "", false, "Show column stats of a table used with flags --table-name and --schema")
	tableCmd.Flags().IntVarP(&Limit, "limit", "l", 20, "Limit number of rows returned")
	tableCmd.Flags().StringVarP(&TableName, "table-name", "t", "", "Table name")
	tableCmd.Flags().StringVarP(&Schema, "schema", "s", "public", "Schema Name")
}

func showAgingTables() {
	connInfo := database.DBConnInfoFromConfig(dbconfig)
	pgUrl := database.GetPgUrlFromConfig(dbconfig)
	conn, err := pgx.Connect(context.Background(), pgUrl)

	sqltext := `SELECT c.oid::regclass as table_name,
                     greatest(age(c.relfrozenxid),age(t.relfrozenxid)) as age,
                     pg_size_pretty(pg_table_size(c.oid)) as table_size
                FROM pg_class c
                LEFT JOIN pg_class t ON c.reltoastrelid = t.oid
                WHERE c.relkind = 'r'
                ORDER BY 2 DESC LIMIT $1`

	type Row struct {
		table_name string
		age        int
		table_size string
	}

	rows, err := conn.Query(context.Background(), sqltext, Limit)
	LogFatal(err)

	fmt.Println(connInfo)
	fmt.Println("-----------------------------")
	printSql(sqltext, outSql)

	fmt.Printf("\nTop %d aging tables\n\n", Limit)
	fmt.Printf("%-35s %-12s %-20s\n", "Table Name", "Age", "Table Size")
	fmt.Printf("%-35s %-12s %-20s\n", "-----------------------------------", "------------", "--------------------")

	for rows.Next() {
		var r Row
		err := rows.Scan(&r.table_name, &r.age, &r.table_size)
		LogFatal(err)
		fmt.Printf("%-35s %-12d %-20s\n", r.table_name, r.age, r.table_size)
	}
	fmt.Printf("%-35s %-12s %-20s\n", "-----------------------------------", "------------", "--------------------")
}

func showSizeTables() {
	connInfo := database.DBConnInfoFromConfig(dbconfig)
	pgUrl := database.GetPgUrlFromConfig(dbconfig)
	conn, err := pgx.Connect(context.Background(), pgUrl)
	LogFatal(err)

	sqltext := `SELECT n.nspname || '.' ||  relname AS tablename,
   reltuples::int AS "num_rows"
   ,relpages::bigint*8 AS size_kb
   , pg_size_pretty(relpages::bigint*8*1024) AS size
   FROM pg_class C
	 left join pg_namespace N on (N.oid = C.relnamespace)
   WHERE relpages >= 8
	 and relkind ='r'
   ORDER BY relpages DESC limit $1`

	rows, err := conn.Query(context.Background(), sqltext, Limit)
	LogFatal(err)

	type Row struct {
		tablename string
		num_rows  int
		size_kb   int
		size      string
	}

	fmt.Println(connInfo)
	fmt.Println("-----------------------------")
	printSql(sqltext, outSql)

	fmt.Printf("\nTop %d Tables by Size\n\n", Limit)
	fmt.Printf("%-35s %-12s %-12s %-16s\n", "Table Name", "Num Rows", "Size(KB)", "Size (Pretty)")
	fmt.Printf("%-35s %-12s %-12s %-16s\n", "-----------------------------------", "------------", "------------", "----------------")
	for rows.Next() {
		var r Row
		err := rows.Scan(&r.tablename, &r.num_rows, &r.size_kb, &r.size)
		LogFatal(err)
		fmt.Printf("%-35s %12d %12d %16s\n", r.tablename, r.num_rows, r.size_kb, r.size)
	}
	fmt.Printf("%-35s %-12s %-12s %-16s\n", "-----------------------------------", "------------", "------------", "----------------")
}

func showHotTables() {
	connInfo := database.DBConnInfoFromConfig(dbconfig)
	pgUrl := database.GetPgUrlFromConfig(dbconfig)
	conn, err := pgx.Connect(context.Background(), pgUrl)
	LogFatal(err)

	sqltext := ` select schemaname ||'.'|| relname tabname
, n_tup_ins +n_tup_upd + n_tup_upd as n_dml_ops
, n_tup_ins
, n_tup_upd
, n_tup_del
, n_live_tup
, n_dead_tup
, to_char(last_vacuum, 'YY-MM-DD HH24:MI') as last_vaccuum
, to_char(last_autovacuum, 'YY-MM-DD HH24:MI') as last_autovaccuum
, to_char(last_analyze, 'YY-MM-DD HH24:MI') as last_analyze
, to_char(last_autoanalyze, 'YY-MM-DD HH24:MI') as last_autoanalyze
 from pg_stat_user_tables
 order by n_dml_ops desc limit $1 `

	rows, err := conn.Query(context.Background(), sqltext, Limit)
	LogFatal(err)

	type Row struct {
		tabname          string
		n_dml_ops        int
		n_tup_ins        int
		n_tup_upd        int
		n_tup_del        int
		n_live_tup       int
		n_dead_tup       int
		last_vaccum      sql.NullString
		last_autovaccum  sql.NullString
		last_analyze     sql.NullString
		last_autoanalyze sql.NullString
	}

	fmt.Println(connInfo)
	fmt.Println("-----------------------------")
	printSql(sqltext, outSql)

	fmt.Printf("\nTop %d Tables by DML operations\n\n", Limit)
	fmt.Printf("%-35s %-12s %-12s %-12s %-12s %-12s %-12s %-16s %-16s %-16s %-16s\n", "Table Name", "#DML_OPS", "#TUP_INS", "#TUP_UPD", "#TUP_DEL", "#LIVE_TUP", "#DEAD_TUP", "Last Vaccum", "Last Autovaccum", "Last Analyze", "Last Autoanalyze")
	fmt.Printf("%-35s %-12s %-12s %-12s %-12s %-12s %-12s %-16s %-16s %-16s %-16s\n", "-----------------------------------", "------------", "------------", "------------", "------------", "------------", "------------", "----------------", "----------------", "----------------", "----------------")
	for rows.Next() {
		var r Row
		err := rows.Scan(&r.tabname, &r.n_dml_ops, &r.n_tup_ins, &r.n_tup_upd, &r.n_tup_del, &r.n_live_tup, &r.n_dead_tup, &r.last_vaccum, &r.last_autovaccum, &r.last_analyze, &r.last_autoanalyze)
		LogFatal(err)

		if !r.last_vaccum.Valid {
			r.last_vaccum.String = "NULL"
		}
		if !r.last_autovaccum.Valid {
			r.last_autovaccum.String = "NULL"
		}
		if !r.last_analyze.Valid {
			r.last_analyze.String = "NULL"
		}
		if !r.last_autoanalyze.Valid {
			r.last_autoanalyze.String = "NULL"
		}

		fmt.Printf("%-35s %12d %12d %12d %12d %12d %12d %16s %16s %16s %16s\n", r.tabname, r.n_dml_ops, r.n_tup_ins, r.n_tup_upd, r.n_tup_del, r.n_live_tup, r.n_dead_tup, r.last_vaccum.String, r.last_autovaccum.String, r.last_analyze.String, r.last_autoanalyze.String)
	}
	fmt.Printf("%-35s %-12s %-12s %-12s %-12s %-12s %-12s %-16s %-16s %-16s %-16s \n", "-----------------------------------", "------------", "------------", "------------", "------------", "------------", "------------", "----------------", "----------------", "----------------", "----------------")
}

func showColstats(Schema string, TableName string) {
	connInfo := database.DBConnInfoFromConfig(dbconfig)
	pgUrl := database.GetPgUrlFromConfig(dbconfig)
	conn, err := pgx.Connect(context.Background(), pgUrl)
	LogFatal(err)

	sqltext := `select ps.attname
		   , ps.inherited
		   ,ps.null_frac
		   , ps.n_distinct
		   ,ps.avg_width
		   , substr(ps.most_common_vals::text, 1,60) || '...' most_common_vals
		   , substr(ps.most_common_freqs::text, 1,60) || '...' most_common_freqs
		   ,correlation
		   ,to_char(t.last_analyze, 'YYYY-MM-DD HH24:MI') as last_analyze
		   ,to_char(t.last_autoanalyze, 'YYYY-MM-DD HH24:MI') as last_autoanalyze
		from pg_stats ps join  pg_stat_all_tables  t on (ps.schemaname= t.schemaname and ps.tablename=t.relname)
		where ps.schemaname=$1  and ps.tablename=$2 `

	rows, err := conn.Query(context.Background(), sqltext, Schema, TableName)
	LogFatal(err)

	type Row struct {
		column_name       string
		inherited         bool
		null_frac         float32
		n_distinct        float32
		avg_width         int
		most_common_vals  sql.NullString
		most_common_freqs sql.NullString
		correlation       float32
		last_analyze      sql.NullString
		last_autoanalyze  sql.NullString
	}

	fmt.Println(connInfo)
	fmt.Println("-----------------------------")
	printSql(sqltext, outSql)

	fmt.Printf(" ====================== Column Statistics for Table %s.%s =====================\n", Schema, TableName)

	for rows.Next() {
		var r Row
		err := rows.Scan(&r.column_name, &r.inherited, &r.null_frac, &r.n_distinct, &r.avg_width, &r.most_common_vals, &r.most_common_freqs, &r.correlation, &r.last_analyze, &r.last_autoanalyze)
		LogFatal(err)

		if !r.last_analyze.Valid {
			r.last_analyze.String = "NULL"
		}

		if !r.last_autoanalyze.Valid {
			r.last_autoanalyze.String = "NULL"
		}

		if !r.most_common_vals.Valid {
			r.most_common_vals.String = "NULL"
		}

		if !r.most_common_freqs.Valid {
			r.most_common_freqs.String = "NULL"
		}

		fmt.Printf("Column Nanme      | %s\n", r.column_name)
		fmt.Printf("Inherited         | %t\n", r.inherited)
		fmt.Printf("Null_Fra          | %f\n", r.null_frac)
		fmt.Printf("N_Distinct        | %f\n", r.n_distinct)
		fmt.Printf("Avg_Witdth        | %d\n", r.avg_width)
		fmt.Printf("Most Common vals  | %s\n", r.most_common_vals.String)
		fmt.Printf("Most Common freqs | %s\n", r.most_common_freqs.String)
		fmt.Printf("Correlation       | %f\n", r.correlation)
		fmt.Printf("Last_Analyze      | %s\n", r.last_analyze.String)
		fmt.Printf("Last_Autoanalyze  | %s\n", r.last_autoanalyze.String)
		fmt.Println("-----------------------------")
	}
}

func showTableIndexes(Schema string, TableName string) {
	connInfo := database.DBConnInfoFromConfig(dbconfig)
	pgUrl := database.GetPgUrlFromConfig(dbconfig)
	conn, err := pgx.Connect(context.Background(), pgUrl)
	LogFatal(err)

	sqltext := `SELECT c2.relname as index_name
		       , case i.indisprimary when 't' then 'primary,' else '' end ||
			     case i.indisunique when 't' then 'unique, ' end  ||
			     case i.indisclustered when 't' then 'clustered,' else '' end  ||
			     case  i.indisvalid  when 't' then '' else 'invalid' end as attributes
		       , pg_catalog.pg_get_indexdef(i.indexrelid, 0, true) as create_index_ddl
		FROM pg_catalog.pg_class c
		   , pg_catalog.pg_class c2
		   , pg_catalog.pg_index i
		     LEFT JOIN pg_catalog.pg_constraint con ON (conrelid = i.indrelid AND conindid = i.indexrelid AND contype IN ('p','u','x'))
		WHERE c.oid in  (
			SELECT c.oid
			FROM pg_catalog.pg_class c
			     LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
			WHERE c.relname = $1
                    AND n.nspname = $2
            )
		AND c.oid = i.indrelid AND i.indexrelid = c2.oid
		ORDER BY i.indisprimary DESC, i.indisunique DESC, c2.relname`

	rows, err := conn.Query(context.Background(), sqltext, TableName, Schema)
	LogFatal(err)

	type Row struct {
		index_name       string
		attributes       sql.NullString
		create_index_ddl string
	}

	fmt.Println(connInfo)
	fmt.Println("-----------------------------")
	printSql(sqltext, outSql)

	fmt.Printf("\n====================== Indexes for Table %s.%s =====================\n\n", Schema, TableName)
	fmt.Printf("%-24s %-20s %-70s\n", "Index_Name", "Attributes", "Create_Index_DDL")
	fmt.Printf("%-24s %-20s %-70s\n", "------------------------", "--------------------", "----------------------------------------------------------------")
	for rows.Next() {
		var r Row
		err := rows.Scan(&r.index_name, &r.attributes, &r.create_index_ddl)
		LogFatal(err)
		if !r.attributes.Valid {
			r.attributes.String = "NULL"
		}
		fmt.Printf("%-24s %-20s %-70s\n", r.index_name, r.attributes.String, r.create_index_ddl)
	}
	fmt.Printf("%-24s %-20s %-70s\n", "------------------------", "--------------------", "----------------------------------------------------------------")
}
