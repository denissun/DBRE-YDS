/*
Copyright © 2023 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

// encryptCmd represents the encrypt command
var encryptCmd = &cobra.Command{
	Use:   "encrypt",
	Short: "Encrypt s clear text password, used internally",
	Long:  "Encrypt a clear text password, used internally",
	Run: func(cmd *cobra.Command, args []string) {

		// fmt.Println("encrypt called")
		EncryptSecret(args)
	},
}

func init() {
	rootCmd.AddCommand(encryptCmd)
	encryptCmd.Flags().StringVarP(&Password, "password", "p", "", "Password")

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// encryptCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// encryptCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}

func EncryptSecret(args []string) error {
	// fmt.Println("CreateSecret called")
	var err error
	//  fmt.Println(Password)
	encPassword, err := Encrypt(Password, APP_KEY)
	if err != nil {
		fmt.Printf("Problem to generate encrypted password: %v \n", curPassword)
		encPassword = ""
		return err
	}
	fmt.Println(encPassword)
	return nil
}
