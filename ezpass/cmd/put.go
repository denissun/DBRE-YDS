/*
Copyright © 2023 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"fmt"
	"log"
	"os"

	"github.com/denissun/ezpass/database"
	"github.com/jmoiron/sqlx"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

// putCmd represents the put command
var putCmd = &cobra.Command{
	Use:   "put",
	Short: "Put password in repository",
	Long:  `Put password in repository with name, type, username and acccess_level info.`,
	Run: func(cmd *cobra.Command, args []string) {
		CreateSecret(args)
	},
}

func init() {
	rootCmd.AddCommand(putCmd)
	putCmd.Flags().StringVarP(&Name, "name", "n", "", "Secret Object Target Name")
	putCmd.Flags().StringVarP(&Type, "type", "t", "", "Secret Object Target Type")
	putCmd.Flags().StringVarP(&Username, "username", "u", "", "User Name")
	putCmd.Flags().StringVarP(&Password, "password", "p", "", "Password")
	putCmd.Flags().StringVarP(&EZUser, "ez_user", "", "", "EZPass App User Name")
	putCmd.Flags().StringVarP(&EZPass, "ez_pass", "", "", "EZPass App Password")
	putCmd.Flags().IntVarP(&Level, "level", "l", 2, "access control level (1,2,10) ")
	putCmd.Flags().StringVarP(&Note, "note", "d", "", "Shot notes (max 250 chars)")
}

func CreateSecret(args []string) error {
	// fmt.Println("CreateSecret called")

	viper.AddConfigPath("./")
	viper.SetConfigFile(".env")
	viper.SetConfigType("env")
	viper.ReadInConfig()

	db_host := viper.Get("DB_HOST").(string)
	db_port := viper.Get("DB_PORT").(string)
	db_service := viper.Get("DB_SERVICE").(string)

	var encPassword string
	var err error
	var my_username string
	var my_password string

	if Name == "" {
		err = fmt.Errorf("Secret target name can't be empty %v, using --name, -n option is required", Name)
		exitOnErr(err)
	}

	if Username == "" {
		err = fmt.Errorf("Username can't be empty %v, using --username, -u option is required", Username)
		exitOnErr(err)
	}

	if Level != 10 && Level != 1 && Level != 2 {
		err = fmt.Errorf("Level should be 1, 2, or 10 You entered:  %v", Level)
		exitOnErr(err)
	}

	if EZPass == "" && EZUser == "" {
		my_username, my_password, err = ReadUsersInputs()
		exitOnErr(err)
	} else {
		my_username = EZUser
		my_password = EZPass
	}

	// db, err := sqlx.Open("godror", database.GetConnectionStringFromInput(my_username, my_password))

	db, err := sqlx.Open("godror", database.GenerateConnectionString(my_username, my_password, db_host, db_port, db_service))
	exitOnErr(err)

	defer func() {
		if err := db.Close(); err != nil {
			log.Print("Failed to close database")
		}
	}()
	err = db.Ping()
	exitOnErr(err)

	if Password == "" {
		secPass, err := ReadSecretPassword()
		exitOnErr(err)
		encPassword, err = Encrypt(secPass, APP_KEY)
		exitOnErr(err)
	} else {
		encPassword, err = Encrypt(Password, APP_KEY)
		exitOnErr(err)
	}

	insertSql := ` insert into ezpass.secret_objects(name, type, username, password, access_level, notes, ols_col) values (:name, :type,:username, :password,:access_level,:notes, `

	if Level == 10 {
		insertSql = insertSql + `char_to_label('EZPASS_OLS_POL','HS') )`
	} else if Level == 2 {
		insertSql = insertSql + `char_to_label('EZPASS_OLS_POL','S') )`
	} else {
		insertSql = insertSql + `char_to_label('EZPASS_OLS_POL','C') )`
	}

	_, err = db.Exec(insertSql, Name, Type, Username, encPassword, Level, Note)
	exitOnErr(err)
	fmt.Println("\n\nput a password is done!")

	// insert into activity log
	// who, action, name, type, username, level
	// Current User
	workdir, err := os.Getwd()
	exitOnErr(err)
	//fmt.Println(wd)
	hostName, err := os.Hostname()
	exitOnErr(err)

	insert_sql := `insert into ezpass.activity_log(who, action, workdir, hostname, name, type, username, access_level) values (:who, :action, :workdir,:hostname,:name, :type, :username, :access_level)`
	_, err = db.Exec(insert_sql, my_username, "PUT", workdir, hostName, Name, Type, Username, Level)
	exitOnErr(err)
	return nil
}
