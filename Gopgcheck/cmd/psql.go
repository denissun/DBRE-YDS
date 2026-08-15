/*
Copyright © 2022 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"fmt"
	"log"
	"os"
	"os/exec"

	"github.com/spf13/cobra"
	"gitlab.mycompany.com/username/gopgcheck/database"
)

var (
	Cmd     string
	cmdFile string
)

// psqlCmd represents the psql command
var psqlCmd = &cobra.Command{
	Use:   "psql",
	Short: "Using psql to execute commands with -c or -f options",
	Long:  `Using psql to execute commands with -c or -f options.`,
	Run: func(cmd *cobra.Command, args []string) {
		dowork(args)
	},
}

func init() {
	rootCmd.AddCommand(psqlCmd)
	psqlCmd.Flags().StringVarP(&Cmd, "cmd", "c", "", "Command")
	psqlCmd.Flags().StringVarP(&cmdFile, "file", "f", "", "File contains sql statements")

}

func dowork(args []string) {

	connInfo := database.DBConnInfoFromConfig(dbconfig)

	fmt.Println("-------------------------------------------------------------------\n")
	fmt.Println(connInfo)
	fmt.Println("-------------------------------------------------------------------\n")

	psqlConnStr := database.GetPsqlConnStringFromConfig(dbconfig)

	if Cmd == "" && cmdFile == "" {
		fmt.Println("missing -c or -f options, type -h for help!")
		os.Exit(1)
	}

	if Cmd != "" {
		fmt.Printf("Command: %s\n\n", Cmd)
		option_args := Cmd
		cmd := exec.Command("psql", psqlConnStr, "-c", option_args)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		err := cmd.Run()
		if err != nil {
			log.Fatalf("cmd.Run() failed with %s\n", err)
		}
	}

	if cmdFile != "" {
		fmt.Printf("Command File: %s\n\n", cmdFile)
		option_args := cmdFile
		cmd := exec.Command("psql", psqlConnStr, "-f", option_args)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		err := cmd.Run()
		if err != nil {
			log.Fatalf("cmd.Run() failed with %s\n", err)
		}
	}

}
