package database

import (
	"fmt"
	"time"

	"github.com/godror/godror"
	"github.com/godror/godror/dsn"
)

func GenerateConnectionString(p_username string, p_password string, p_host string, p_port string, p_service string) string {
	var connString string
	connString = fmt.Sprintf("%s:%s/%s", p_host, p_port, p_service)

	tz, _ := time.LoadLocation("America/New_York")

	return godror.ConnectionParams{
		StandaloneConnection: true,
		CommonParams: dsn.CommonParams{
			Username:      p_username,
			Password:      dsn.NewPassword(p_password),
			ConnectString: connString,
			Timezone:      tz,
		},
		PoolParams: dsn.PoolParams{
			MinSessions:      0,
			MaxSessions:      5,
			SessionIncrement: 1,
		},
		ConnParams: dsn.ConnParams{
			IsSysDBA:  false,
			IsSysOper: false,
		},
	}.StringWithPassword()
}
