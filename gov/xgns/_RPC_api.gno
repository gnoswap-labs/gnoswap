package xgns

func TotalDelegated() uint64 {
	// same as xgns total supply
	return TotalSupply()
}

func TotalDelegatedFromAddress(from std.Address) uint64 {
	return sumDelegated(from)
}

func TotalDelegatedToAddress(to std.Address) uint64 {
	sum := uint64(0)
	for _, amount := range delegated {
		sum += amount[to.String()]
	}
	return sum
}`