/*
Copyright © 2023 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"fmt"
	"log"
	"os"
	"os/user"

	"github.com/denissun/ezpass/database"
	"github.com/denissun/ezpass/model"
	"github.com/jmoiron/sqlx"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

// getByKeyCmd represents the getByKey command
var getByKeyCmd = &cobra.Command{
	Use:   "getByKey",
	Short: `Get a password by access key`,
	Long:  `Get a password by access key `,
	Run: func(cmd *cobra.Command, args []string) {
		getPasswordByKey(args)
	},
}

func init() {
	rootCmd.AddCommand(getByKeyCmd)
	getByKeyCmd.Flags().StringVarP(&Name, "name", "n", "", "Secret Object Target Name")
	getByKeyCmd.Flags().StringVarP(&Type, "type", "t", "", "Secret Object Target Type")
	getByKeyCmd.Flags().StringVarP(&Username, "username", "u", "", "User Name")

}

func getPasswordByKey(args []string) {
	viper.AddConfigPath("./")
	viper.SetConfigFile(".env")
	viper.SetConfigType("env")
	viper.ReadInConfig()

	accessKey := viper.Get("ACCESS_KEY")
	ACCESS_BY_KEY_USER := viper.Get("ACCESS_BY_KEY_USER").(string)
	ACCESS_BY_KEY_USER_PASS := viper.Get("ACCESS_BY_KEY_USER_PASS").(string)
	db_host := viper.Get("DB_HOST").(string)
	db_port := viper.Get("DB_PORT").(string)
	db_service := viper.Get("DB_SERVICE").(string)

	// Current User
	user, err := user.Current()
	if err != nil {
		panic(err)
	}
	wd, err := os.Getwd()
	exitOnErr(err)
	//fmt.Println(wd)
	hostName, err := os.Hostname()
	exitOnErr(err)

	insertSql := `insert into ezpass.access_by_key_log(username, workdir, hostname, status) values (:username,:workdir,:hostname,:status)`

	db, err := sqlx.Open("godror", database.GenerateConnectionString(ACCESS_BY_KEY_USER, ACCESS_BY_KEY_USER_PASS, db_host, db_port, db_service))
	exitOnErr(err)

	defer func() {
		if err := db.Close(); err != nil {
			log.Print("Failed to close database")
		}
	}()
	err = db.Ping()
	exitOnErr(err)

	// read access key from a db table
	sql_stmt := `select count(*) as count from ezpass.access_keys where is_active='Y' and key = :key`
	//var kye_count int

	rows, err := db.Queryx(sql_stmt, accessKey)
	if err != nil {
		db.Exec(insertSql, user.Username, wd, hostName, "Failed - db.Queryx")
		exitOnErr(err)
	}
	var activeKeyCount model.Counter
	rows.Next()
	err = rows.StructScan(&activeKeyCount)
	if err != nil {
		db.Exec(insertSql, user.Username, wd, hostName, "Failed - StructScan")
		exitOnErr(err)
	}

	if activeKeyCount.Value != 1 {
		err := fmt.Errorf("ERROR: Access Key is not acceptable")
		db.Exec(insertSql, user.Username, wd, hostName, "Failed - Mismatch")
		exitOnErr(err)
	}

	sqltext := `select username, password from (select username, PASSWORD from ezpass.secret_objects where name =:name and type=:type and username =:username order by created desc) where rownum =1`

	if Name == "" {
		err := fmt.Errorf("Secret target name can't be empty %v, using --name, -n option is required", Name)
		exitOnErr(err)
	}

	if Type == "" {
		err := fmt.Errorf("Secret target type can't be empty %v, using --type, -t option is required", Name)
		exitOnErr(err)
	}

	if Username == "" {
		err := fmt.Errorf("Secret target username can't be empty %v, using --username, -u option is required", Name)
		exitOnErr(err)
	}

	rows, err = db.Queryx(sqltext, Name, Type, Username)
	exitOnErr(err)

	for rows.Next() {
		var r model.UserPass
		err = rows.StructScan(&r)
		exitOnErr(err)
		curPassword, err = Decrypt(r.Password, APP_KEY)
		exitOnErr(err)
		fmt.Println(curPassword)
	}
	db.Exec(insertSql, user.Username, wd, hostName, "Succeeded")
}
