package cmd

// Utility functions

import (
	"bufio"
	"crypto/aes"
	"crypto/cipher"
	"encoding/base64"
	"fmt"
	"log"
	"os"
	"strings"
	"syscall"

	"golang.org/x/term"
)

var (
	bytes = []byte{35, 46, 57, 24, 85, 35, 24, 74, 87, 35, 88, 98, 66, 32, 14, 05}
)

func Encode(b []byte) string {
	return base64.StdEncoding.EncodeToString(b)
}

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

func Decode(s string) []byte {
	data, err := base64.StdEncoding.DecodeString(s)
	if err != nil {
		panic(err)
	}
	return data
}

// Decrypt method is to extract back the encrypted text
func Decrypt(text, MySecret string) (string, error) {
	block, err := aes.NewCipher([]byte(MySecret))
	if err != nil {
		return "", err
	}
	cipherText := Decode(text)
	cfb := cipher.NewCFBDecrypter(block, bytes)
	plainText := make([]byte, len(cipherText))
	cfb.XORKeyStream(plainText, cipherText)
	return string(plainText), nil
}

func ReadUsersInputs() (string, string, error) {
	reader := bufio.NewReader(os.Stdin)
	fmt.Println("You need an account to use EZPass, if you don't have, CTRL-C and contact admins")
	fmt.Print("Enter EZPASS Account Username: ")
	userName, err := reader.ReadString('\n')
	if len(strings.TrimSpace(userName)) == 0 {
		err = fmt.Errorf("Your UserName can't be empty %v", userName)
		fmt.Println(err.Error())
		os.Exit(1)
	}
	if err != nil {
		return "", "", err
	}
	fmt.Print("Enter EZPASS Account Password: ")
	bytePassword, err := term.ReadPassword(syscall.Stdin)
	if err != nil {
		return "", "", err
	}
	password := string(bytePassword)
	return strings.TrimSpace(userName), strings.TrimSpace(password), nil
}

func ReadSecretPassword() (string, error) {
	fmt.Print("\nEnter the secret password you want to put:  ")
	byteSecPass, err := term.ReadPassword(syscall.Stdin)
	if len(strings.TrimSpace(string(byteSecPass))) == 0 {
		err = fmt.Errorf("Your password can't be empty %v", string(byteSecPass))
		fmt.Println(err.Error())
		os.Exit(1)
	}
	if err != nil {
		return "", err
	}

	fmt.Print("\nEnter again the secret password you want to put:  ")
	byteSecPass2, err := term.ReadPassword(syscall.Stdin)
	if err != nil {
		return "", err
	}

	if string(byteSecPass) != string(byteSecPass2) {
		return "", fmt.Errorf("Entered passwords do not match\n")
	}

	secPass := string(byteSecPass)
	return strings.TrimSpace(secPass), nil
}

func exitOnErr(err error) {
	if err != nil {
		log.Fatalf("\n\n------------------------\n%s", err.Error())
	}
}
