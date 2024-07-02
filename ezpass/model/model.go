package model

type SecretObjectRow struct {
	Id             string `db:"ID"`
	Name           string `db:"NAME"`
	Type           string `db:"TYPE"`
	UserName       string `db:"USERNAME"`
	Password       string `db:"PASSWORD"`
	Notes          string `db:"NOTES"`
	AccessLevel    int    `db:"ACCESS_LEVEL"`
	Created        string `db:"CREATED"`
	PasswordMasked string `db:"PASSWORD_MASKED"`
}

type UserPass struct {
	UserName string `db:"USERNAME"`
	Password string `db:"PASSWORD"`
}

type Counter struct {
	Value int `db:"COUNT"`
}
