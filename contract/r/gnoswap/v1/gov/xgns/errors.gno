package xgns

import (
	"errors"
)

var errNoPermission = errors.New("[GNOSWAP-XGNS-001] caller has no permission")

// checkErr panics if an error occurs.
func checkErr(err error) {
	if err != nil {
		panic(err.Error())
	}
}
