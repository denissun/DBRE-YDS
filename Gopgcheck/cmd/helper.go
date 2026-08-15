package cmd

import (
	"fmt"
	"log"
)

func LogFatal(err error) {
	if err != nil {
		log.Fatal(err)
	}
}

func printSql(sqltext string, outSql bool) {
	if outSql {
		fmt.Println("~~~~~~~~~~~~~~~~~~   The following SQL is used: ~~~~~~~~~~~~~~~~~~~~~~")
		fmt.Println(sqltext)
		fmt.Println("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")

	}
}
