package database

import (
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/joho/godotenv"
	"github.com/spf13/viper"
	"gitlab.mycompany.com/username/gopgcheck/decrypt"
)

func GetPsqlConnStringFromConfig(dbconfig string) string {
	//dbconfig is a yml file in the format config.yml
	var fname string
	var ftype string
	var err error

	ss := strings.Split(dbconfig, ".")
	if len(ss) < 2 {
		fname = ss[0]
		ftype = "yml"
	} else {
		fname = ss[0]
		ftype = ss[1]
	}

	// obtain app_key
	err = godotenv.Load(".env")
	if err != nil {
		log.Fatalf("Some error occured. Err: %s", err)
	}

	app_key := os.Getenv("APP_KEY")

	// viper settings and construct db connection url from config.yml file
	viper.SetConfigName(fname)
	viper.AddConfigPath(".")
	viper.AutomaticEnv()
	viper.SetConfigType(ftype)

	if err = viper.ReadInConfig(); err != nil {
		fmt.Printf("Error reading config file, %s", err)
	}

	// dbuser, err := decrypt.Decrypt(viper.GetString("database.dbuser"), app_key)
	dbpassword, err := decrypt.Decrypt(viper.GetString("database.dbpassword_encrypted"), app_key)

	// dbpassword := viper.GetString("database.dbpassword")
	dbname := viper.GetString("database.dbname")
	dbserver := viper.GetString("server.name")
	dbport := viper.GetInt("server.port")
	dbuser := viper.GetString("database.dbuser")

	db_connect_str := fmt.Sprintf("postgresql://%s:%s@%s:%d/%s", dbuser, dbpassword, dbserver, dbport, dbname)
	return db_connect_str
}

func GetPgUrlFromConfig(dbconfig string) string {
	//dbconfig is a yml file in the format config.yml
	var fname string
	var ftype string
	var err error

	ss := strings.Split(dbconfig, ".")
	if len(ss) < 2 {
		fname = ss[0]
		ftype = "yml"
	} else {
		fname = ss[0]
		ftype = ss[1]
	}

	// obtain app_key
	err = godotenv.Load(".env")
	if err != nil {
		log.Fatalf("Some error occured. Err: %s", err)
	}

	app_key := os.Getenv("APP_KEY")

	// viper settings and construct db connection url from config.yml file
	viper.SetConfigName(fname)
	viper.AddConfigPath(".")
	viper.AutomaticEnv()
	viper.SetConfigType(ftype)

	if err = viper.ReadInConfig(); err != nil {
		fmt.Printf("Error reading config file, %s", err)
	}

	// dbuser, err := decrypt.Decrypt(viper.GetString("database.dbuser"), app_key)
	dbpassword, err := decrypt.Decrypt(viper.GetString("database.dbpassword_encrypted"), app_key)

	// dbpassword := viper.GetString("database.dbpassword")
	dbname := viper.GetString("database.dbname")
	dbserver := viper.GetString("server.name")
	dbport := viper.GetInt("server.port")
	dbuser := viper.GetString("database.dbuser")

	// pgUrl := fmt.Sprintf("postgres://%s:%s@%s:%d/%s", dbuser, dbpassword, dbserver, dbport, dbname)
	pgUrl := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=disable", dbserver, dbport, dbuser, dbpassword, dbname)
	return pgUrl

}

func DBConnInfoFromConfig(dbconfig string) string {
	var fname string
	var ftype string

	ss := strings.Split(dbconfig, ".")
	if len(ss) < 2 {
		fname = ss[0]
		ftype = "yml"
	} else {
		fname = ss[0]
		ftype = ss[1]
	}

	// viper settings and construct db connection url from config.yml file
	viper.SetConfigName(fname)
	viper.AddConfigPath(".")
	viper.AutomaticEnv()
	viper.SetConfigType(ftype)

	if err := viper.ReadInConfig(); err != nil {
		fmt.Printf("Error reading config file, %s", err)
	}
	dbname := viper.GetString("database.dbname")
	dbserver := viper.GetString("server.name")
	dbport := viper.GetInt("server.port")
	dbuser := viper.GetString("database.dbuser")

	connInfo := fmt.Sprintf("Database: %s\nHost    : %s\nPort    : %d\nUser    : %s\n", dbname, dbserver, dbport, dbuser)
	return connInfo
}

func GetPgUrl() string {
	var err error

	// obtain app_key
	err = godotenv.Load(".env")
	if err != nil {
		log.Fatalf("Some error occured. Err: %s", err)
	}

	app_key := os.Getenv("APP_KEY")

	// viper settings and construct db connection url from config.yml file
	viper.SetConfigName("config")
	viper.AddConfigPath(".")
	viper.AutomaticEnv()
	viper.SetConfigType("yml")

	if err = viper.ReadInConfig(); err != nil {
		fmt.Printf("Error reading config file, %s", err)
	}

	// dbuser, err := decrypt.Decrypt(viper.GetString("database.dbuser"), app_key)
	dbpassword, err := decrypt.Decrypt(viper.GetString("database.dbpassword"), app_key)

	// dbpassword := viper.GetString("database.dbpassword")
	dbname := viper.GetString("database.dbname")
	dbserver := viper.GetString("server.name")
	dbport := viper.GetInt("server.port")
	dbuser := viper.GetString("database.dbuser")

	// pgUrl := fmt.Sprintf("postgres://%s:%s@%s:%d/%s", dbuser, dbpassword, dbserver, dbport, dbname)
	pgUrl := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=disable", dbserver, dbport, dbuser, dbpassword, dbname)
	return pgUrl
}

func DBConnInfo() string {
	// viper settings and construct db connection url from config.yml file
	viper.SetConfigName("config")
	viper.AddConfigPath(".")
	viper.AutomaticEnv()
	viper.SetConfigType("yml")

	if err := viper.ReadInConfig(); err != nil {
		fmt.Printf("Error reading config file, %s", err)
	}
	dbname := viper.GetString("database.dbname")
	dbserver := viper.GetString("server.name")
	dbport := viper.GetInt("server.port")
	dbuser := viper.GetString("database.dbuser")

	connInfo := fmt.Sprintf("Database: %s\nHost: %s\nPort: %d\nConnecting User:%s\n", dbname, dbserver, dbport, dbuser)
	return connInfo
}
