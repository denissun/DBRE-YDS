/*
Copyright © 2022 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"crypto/aes"
	"crypto/cipher"
	"encoding/base64"
	"fmt"
	"log"
	"os"

	"github.com/joho/godotenv"
	"github.com/spf13/cobra"
)

var bytes = []byte{35, 46, 57, 24, 85, 35, 24, 74, 87, 35, 88, 98, 66, 32, 14, 05}

// encryptCmd represents the encrypt command
var encryptCmd = &cobra.Command{
	Use:   "encrypt <clear_text_password>",
	Short: "A helper command to generate encrypted password that is used in the config yaml file",
	Long: `A helper command to generate encrypt password that is used in the config yaml file,
using the encryption key saved in the .env file.`,

	Run: func(cmd *cobra.Command, args []string) {
		if len(args) != 1 {
			fmt.Println("Wrong number of arguments")
			fmt.Println("Usage: gopgcheck encrypt <clear_text_password>")
			os.Exit(1)
		}
		// fmt.Println("encrypt called")
		StringToEncrypt := args[0]
		// fmt.Println(StringToEncrypt)
		// read app_key from .env
		err := godotenv.Load(".env")
		if err != nil {
			log.Fatalf("Some error occured. Err: %s", err)
		}
		app_key := os.Getenv("APP_KEY")
		// fmt.Println(app_key)

		// To encrypt the StringToEncrypt
		encText, err := Encrypt(StringToEncrypt, app_key)
		if err != nil {
			fmt.Println("error encrypting your classified text: ", err)
		}
		fmt.Println(encText)

	},
}

func init() {
	rootCmd.AddCommand(encryptCmd)

}

func Encode(b []byte) string {
	return base64.StdEncoding.EncodeToString(b)
}

// Encrypt method is to encrypt or hide any classified text
func Encrypt(text, MySecret string) (string, error) {
	block, err := aes.NewCipher([]byte(MySecret))
	if err != nil {
		return "", err
	}
	plainText := []byte(text)
	cfb := cipher.NewCFBEncrypter(block, bytes)
	cipherText := make([]byte, len(plainText))
	cfb.XORKeyStream(cipherText, plainText)
	return Encode(cipherText), nil
}
