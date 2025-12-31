package xgns

// checkErr panics if an error occurs.
func checkErr(err error) {
	if err != nil {
		panic(err.Error())
	}
}
