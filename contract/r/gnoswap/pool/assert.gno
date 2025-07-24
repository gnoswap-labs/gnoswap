package pool

// assertIsValidTicks validates the tick range for a liquidity position.
func assertIsValidTicks(tickLower, tickUpper int32) {
	if err := validateTicks(tickLower, tickUpper); err != nil {
		panic(err)
	}
}