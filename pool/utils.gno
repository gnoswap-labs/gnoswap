package pool

import (
	"std"

	"gno.land/r/demo/users"

	"gno.land/p/demo/ufmt"
)

func checkTicks(tickLower, tickUpper bigint) {
	require(tickLower < tickUpper, ufmt.Sprintf("[POOL] pool.gno__checkTicks() || tickLower(%s) < tickUpper(%s)", tickLower, tickUpper))
	require(tickLower >= MIN_TICK, ufmt.Sprintf("[POOL] pool.gno__checkTicks() || tickLower(%s) >= MIN_TICK(%s)", tickLower, MIN_TICK))
	require(tickUpper <= MAX_TICK, ufmt.Sprintf("[POOL] pool.gno__checkTicks() || tickUpper(%s) <= MAX_TICK(%s)", tickUpper, MAX_TICK))
}

func a2u(addr std.Address) users.AddressOrName {
	return users.AddressOrName(addr)
}

func requireUnsigned(x bigint, msg string) {
	if x < 0 {
		panic(msg)
	}
}

func min(num1, num2 bigint) bigint {
	if num1 < num2 {
		return num1
	}
	return num2
}

func require(cond bool, msg string) {
	if !cond {
		panic(msg)
	}
}

func abs(x bigint) bigint {
	if x < 0 {
		return -x
	}
	return x
}

func removeDuplicateString(strSlice []string) []string {
	// map to store unique keys
	keys := make(map[string]bool)
	returnSlice := []string{}
	for _, item := range strSlice {
		if _, value := keys[item]; !value {
			keys[item] = true
			returnSlice = append(returnSlice, item)
		}
	}
	return returnSlice
}

func remove(s []string, r string) []string {
	for i, v := range s {
		if v == r {
			return append(s[:i], s[i+1:]...)
		}
	}
	return s
}
