/*
Copyright © 2023 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/denissun/ezpass/database"
	"github.com/denissun/ezpass/model"
	"github.com/jmoiron/sqlx"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

// getCmd represents the get command
var getCmd = &cobra.Command{
	Use:   "get",
	Short: "Get passwords from repository",
	Long:  `Get passwords from repository`,
	Run: func(cmd *cobra.Command, args []string) {
		listPasswords(args)
	},
}

var (
	Name        string
	Type        string
	Username    string
	Level       int
	Password    string
	Note        string
	Clear       bool
	Expand      bool
	curPassword string
	EZUser      string
	EZPass      string
)

func init() {
	rootCmd.AddCommand(getCmd)

	getCmd.Flags().StringVarP(&Name, "name", "n", "", "Secret Object Target Name")
	getCmd.Flags().StringVarP(&Type, "type", "t", "", "Secret Object Target Type")
	getCmd.Flags().StringVarP(&Username, "username", "u", "", "User Name")
	getCmd.Flags().BoolVarP(&Clear, "clear", "c", false, "Whetehr showing clear-text password")
	getCmd.Flags().BoolVarP(&Expand, "Expand", "e", false, "List rows vertically with notes field")
}

func listPasswords(args []string) {

	viper.AddConfigPath("./")
	viper.SetConfigFile(".env")
	viper.SetConfigType("env")
	viper.ReadInConfig()

	db_host := viper.Get("DB_HOST").(string)
	db_port := viper.Get("DB_PORT").(string)
	db_service := viper.Get("DB_SERVICE").(string)

	my_username, my_password, err := ReadUsersInputs()
	exitOnErr(err)

	db, err := sqlx.Open("godror", database.GenerateConnectionString(my_username, my_password, db_host, db_port, db_service))
	exitOnErr(err)

	defer func() {
		if err := db.Close(); err != nil {
			log.Print("Failed to close database")
		}
	}()
	err = db.Ping()
	exitOnErr(err)

	sqltext := `select
       ID
	 , NAME                        
	 ,TYPE                        
	 ,USERNAME                    
	 ,PASSWORD                    
	 ,ACCESS_LEVEL                
	 ,NOTES
	 ,to_char(CREATED, 'YYYY-MM-DD HH24:MI:SS') CREATED                     
	 ,substr(standard_hash(concat(password, mod(id,100))),1,16) as PASSWORD_MASKED
	 from ezpass.secret_objects
	 where 1=1
	 `

	if Name != "" {
		sqltext = sqltext + " and  lower(name) like '%" + strings.ToLower(Name) + "%'"
	}

	if Type != "" {
		sqltext = sqltext + " and  lower(type) like '" + strings.ToLower(Type) + "%'"
	}

	if Username != "" {
		sqltext = sqltext + " and  lower(username) like '" + strings.ToLower(Username) + "%'"
	}

	sqltext = sqltext + " order by type, name, username, created desc"

	// fmt.Println(sqltext)

	rows, err := db.Queryx(sqltext)
	exitOnErr(err)

	if !Expand {
		fmt.Printf("\n\n%-60s %-10s %-14s %-20s %-4s %-20s\n", "Name", "Type", "UserName", "Password", "Lvl", "Created")
		fmt.Printf("%-60s %-10s %-14s %-20s %-4s %-20s\n",
			strings.Repeat("-", 60),
			strings.Repeat("-", 10),
			strings.Repeat("-", 14),
			strings.Repeat("-", 20),
			strings.Repeat("-", 4),
			strings.Repeat("-", 20))
	}
	for rows.Next() {
		var r model.SecretObjectRow
		err = rows.StructScan(&r)
		exitOnErr(err)
		if Expand {
			fmt.Printf("\n\n%+20s: %s\n", "Name", r.Name)
			fmt.Printf("%+20s: %s\n", "Type", r.Type)
			fmt.Printf("%+20s: %s\n", "Username", r.UserName)
			if Clear {
				curPassword, err = Decrypt(r.Password, APP_KEY)
				if err != nil {
					fmt.Printf("Problem to get decrypted password: %v \n", curPassword)
					curPassword = ""
				}
			} else {
				curPassword = r.PasswordMasked
			}
			fmt.Printf("%+20s: %s\n", "Password", curPassword)
			fmt.Printf("%+20s: %d\n", "AccessLevel", r.AccessLevel)
			fmt.Printf("%+20s: %s\n", "Notes", r.Notes)
			fmt.Printf("%+20s: %s\n", "Created", r.Created)
			fmt.Printf("------------------------------------------\n")
		} else {
			if Clear {
				curPassword, err = Decrypt(r.Password, APP_KEY)
				if err != nil {
					fmt.Printf("Problem to get decrypted password: %v \n", curPassword)
					curPassword = ""
				}
			} else {
				curPassword = r.PasswordMasked
			}
			fmt.Printf("%-60s %-10s %-14s %-20s %-4d %-20s\n", r.Name, r.Type, r.UserName, curPassword, r.AccessLevel, r.Created)
		}
	}
	if !Expand {
		fmt.Printf("%-60s %-10s %-14s %-20s %-4s %-20s\n",
			strings.Repeat("-", 60),
			strings.Repeat("-", 10),
			strings.Repeat("-", 14),
			strings.Repeat("-", 20),
			strings.Repeat("-", 4),
			strings.Repeat("-", 20))
	}

	// insert into activity log
	// who, action, name, type, username, level
	// Current User
	workdir, err := os.Getwd()
	exitOnErr(err)
	//fmt.Println(wd)
	hostName, err := os.Hostname()
	exitOnErr(err)

	insert_sql := `insert into ezpass.activity_log(who, action, workdir, hostname, name, type, username, access_level) values (:who, :action, :workdir,:hostname,:name, :type, :username, :access_level)`
	_, err = db.Exec(insert_sql, my_username, "GET", workdir, hostName, Name, Type, Username, Level)
	exitOnErr(err)
}
