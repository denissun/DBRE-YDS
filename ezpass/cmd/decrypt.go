/*
Copyright © 2023 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

// decryptCmd represents the decrypt command
var decryptCmd = &cobra.Command{
	Use:   "decrypt",
	Short: "Decrypt a encrypted text, used internally",
	Long:  "Decrypt a encrypted text, used internally",
	Run: func(cmd *cobra.Command, args []string) {

		// fmt.Println("decrypt called")
		GetSecret(args)
	},
}

func init() {
	rootCmd.AddCommand(decryptCmd)
	decryptCmd.Flags().StringVarP(&Password, "password", "p", "", "Password")

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// decryptCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// decryptCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}

func GetSecret(args []string) error {
	// fmt.Println("CreateSecret called")
	var err error
	//  fmt.Println(Password)
	curPassword, err = Decrypt(Password, APP_KEY)
	if err != nil {
		fmt.Printf("Problem to get decrypted password: %v \n", curPassword)
		curPassword = ""
		return err
	}
	fmt.Println(curPassword)
	return nil
}
