package pool

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/users"

	"gno.land/p/demo/ufmt"

	"gno.land/p/demo/u256"
)

func checkTicks(tickLower, tickUpper u256.Int) {
	require(tickLower.Lt(tickUpper), ufmt.Sprintf("[POOL] pool.gno__checkTicks() || tickLower(%d) < tickUpper(%d)", tickLower, tickUpper))
	require(tickLower.Gte(MIN_TICK), ufmt.Sprintf("[POOL] pool.gno__checkTicks() || tickLower(%d) >= MIN_TICK(%d)", tickLower, MIN_TICK))
	require(tickUpper.Lte(MAX_TICK), ufmt.Sprintf("[POOL] pool.gno__checkTicks() || tickUpper(%d) <= MAX_TICK(%d)", tickUpper, MAX_TICK))
}

func a2u(addr std.Address) users.AddressOrName {
	return users.AddressOrName(addr)
}

func min(num1, num2 bigint) bigint {
	if num1 < num2 {
		return num1
	}
	return num2
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

// REQUIREs
func require(cond bool, msg string) {
	if !(cond) {
		panic(msg)
	}
}

func requireUnsigned(x bigint, msg string) {
	if !(x >= 0) {
		panic(msg)
	}
}

func requirePositive(x bigint, msg string) {
	if !(x > 0) {
		panic(msg)
	}
}

func requireExist(exist bool, msg string) {
	if !exist {
		panic(msg)
	}
}

func requirePrevRealmPath(prevRealmPath, msg string) {
	if std.PrevRealm().PkgPath() != prevRealmPath {
		panic(msg)
	}
}
