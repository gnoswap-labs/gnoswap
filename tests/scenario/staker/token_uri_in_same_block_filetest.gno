// token URI in same block scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/v1/rbac"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = std.NewCodeRealm("gno.land/r/gnoswap/v1/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"

	fee500 uint32 = 500

	maxTimeout int64 = 9999999999
	maxApprove int64 = 9223372036854775807
)

func main() {
	println("[SCENARIO] 1. Initialize and create pool")
	initializeAndCreatePool()
	println()

	println("[SCENARIO] 2. Mint multiple positions and check URI uniqueness")
	mintPositionsAndCheckURI()
}

func initializeAndCreatePool() {
	testing.SetRealm(adminRealm)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)

	testing.SetRealm(adminRealm)

	println("[INFO] approve GNS for pool creation")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())

	println("[INFO] create bar:foo:500 pool")
	pl.CreatePool(cross, barPath, fooPath, fee500, "130621891405341611593710811006") // tick = 10000
	sr.SetPoolTierByAdmin(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", 1)

	ufmt.Printf("[EXPECTED] pool created and set to tier 1\n")
	testing.SkipHeights(1)
}

func mintPositionsAndCheckURI() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	bar.Approve(cross, poolAddr, maxApprove)
	foo.Approve(cross, poolAddr, maxApprove)

	println("[INFO] mint and stake position 01")
	positionId1, liquidity1, _, _, _ := sr.MintAndStake(
		cross,
		barPath,
		fooPath,
		fee500,
		8000,
		12000,
		"50000000",
		"50000000",
		"0",
		"0",
		maxTimeout,
		"",
	)

	println("[INFO] mint and stake position 02")
	positionId2, liquidity2, _, _, _ := sr.MintAndStake(
		cross,
		barPath,
		fooPath,
		fee500,
		9000,
		13000,
		"50000000",
		"50000000",
		"0",
		"0",
		maxTimeout,
		"",
	)

	ufmt.Printf("[EXPECTED] position 01 minted and staked: ID=%d, liquidity=%s\n", positionId1, liquidity1)
	ufmt.Printf("[EXPECTED] position 02 minted and staked: ID=%d, liquidity=%s\n", positionId2, liquidity2)

	println("[INFO] verify position IDs are different")
	tid1 := grc721.TokenID(ufmt.Sprintf("%d", positionId1))
	tid2 := grc721.TokenID(ufmt.Sprintf("%d", positionId2))

	if tid1 == tid2 {
		panic("token IDs should be different")
	}

	ufmt.Printf("[EXPECTED] token ID 1: %s\n", string(tid1))
	ufmt.Printf("[EXPECTED] token ID 2: %s\n", string(tid2))

	println("[INFO] get token URIs")
	tokenURI1, _ := gnft.TokenURI(tid1)
	tokenURI2, _ := gnft.TokenURI(tid2)

	ufmt.Printf("[EXPECTED] token URI 1: %s\n", tokenURI1)
	ufmt.Printf("[EXPECTED] token URI 2: %s\n", tokenURI2)

	println("[INFO] verify token URIs are different")
	if tokenURI1 == tokenURI2 {
		panic("token URIs should be different")
	}

	println("[INFO] token URI test completed successfully")
	println("[INFO] confirmed: different positions have different token IDs and URIs")
}

func positionIdFrom(positionId any) grc721.TokenID {
	if positionId == nil {
		panic("positionId is nil")
	}

	switch positionId.(type) {
	case string:
		return grc721.TokenID(positionId.(string))
	case int:
		return grc721.TokenID(strconv.Itoa(positionId.(int)))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(positionId.(uint64))))
	case grc721.TokenID:
		return positionId.(grc721.TokenID)
	default:
		panic("unsupported positionId type")
	}
}

// Output:
// [SCENARIO] 1. Initialize and create pool
// [INFO] register gns change callback
// [INFO] approve GNS for pool creation
// [INFO] create bar:foo:500 pool
// [EXPECTED] pool created and set to tier 1
//
// [SCENARIO] 2. Mint multiple positions and check URI uniqueness
// [INFO] approve tokens for minting
// [INFO] mint and stake position 01
// [INFO] mint and stake position 02
// [EXPECTED] position 01 minted and staked: ID=1, liquidity=318704392
// [EXPECTED] position 02 minted and staked: ID=2, liquidity=591834484
// [INFO] verify position IDs are different
// [EXPECTED] token ID 1: 1
// [EXPECTED] token ID 2: 2
// [INFO] get token URIs
// [EXPECTED] token URI 1: data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTM1IiBoZWlnaHQ9IjEzNSIgdmlld0JveD0iMCAwIDEzNSAxMzUiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxnIGNsaXAtcGF0aD0idXJsKCNjbGlwMF83Njk4XzU2ODQ2KSI+CjxjaXJjbGUgY3g9IjY3LjUiIGN5PSI2Ny41IiByPSI2Ny41IiBmaWxsPSJ1cmwoI3BhaW50MF9saW5lYXJfNzY5OF81Njg0NikiLz4KPHBhdGggZD0iTTUxLjI5MDUgNDIuOTQ0OUw2Ni40ODk1IDMzTDk3IDUyLjgwNjFMODEuODI0MSA2Mi43NDI1TDUxLjI5MDUgNDIuOTQ0OVoiIGZpbGw9IndoaXRlIi8+CjxwYXRoIGQ9Ik01MS42MDU1IDY3LjUwNTlMNjYuODA0NCA1Ny41NjFMOTcgNzcuMDY1N0w4Mi4xMDQ2IDg3LjE3OTNMNTEuNjA1NSA2Ny41MDU5WiIgZmlsbD0id2hpdGUiIGZpbGwtb3BhY2l0eT0iMC40Ii8+CjxwYXRoIGQ9Ik0zNi4wNDY0IDgxLjc1NTlMNTEuMjkwNSA3MS44MTFMODEuNzMzNiA5MS42NTQ3TDY2LjQ4OTUgMTAxLjUwOEwzNi4wNDY0IDgxLjc1NTlaIiBmaWxsPSJ3aGl0ZSIgZmlsbC1vcGFjaXR5PSIwLjYiLz4KPHBhdGggZD0iTTM2LjAwMSA1Mi44MDU1TDUxLjI4ODQgNDIuOTE3N0w1MS4yODg0IDcxLjgxNDVMMzYuMDAxIDgxLjc3OUwzNi4wMDEgNTIuODA1NVoiIGZpbGw9IndoaXRlIi8+CjxwYXRoIGQ9Ik04Mi4xMDUxIDg3LjE3OTdMOTcuMDAxNiA3Ny4wNjYyTDk3LjAwMTYgODEuNzAyOUw4MS43ODk2IDkxLjYyOUw4Mi4xMDUxIDg3LjE3OTdaIiBmaWxsPSJ3aGl0ZSIgZmlsbC1vcGFjaXR5PSIwLjUiLz4KPHBhdGggZD0iTTUxLjI5MDUgNDIuOTQ0OUw2Ni40ODk1IDMzTDk3IDUyLjgwNjFMODEuODI0MSA2Mi43NDI1TDUxLjI5MDUgNDIuOTQ0OVoiIGZpbGw9IndoaXRlIi8+CjxwYXRoIGQ9Ik01MS42MDU1IDY3LjUwNTlMNjYuODA0NCA1Ny41NjFMOTcgNzcuMDY1N0w4Mi4xMDQ2IDg3LjE3OTNMNTEuNjA1NSA2Ny41MDU5WiIgZmlsbD0id2hpdGUiIGZpbGwtb3BhY2l0eT0iMC40Ii8+CjxwYXRoIGQ9Ik0zNi4wNDY0IDgxLjc1NTlMNTEuMjkwNSA3MS44MTFMODEuNzMzNiA5MS42NTQ3TDY2LjQ4OTUgMTAxLjUwOEwzNi4wNDY0IDgxLjc1NTlaIiBmaWxsPSJ3aGl0ZSIgZmlsbC1vcGFjaXR5PSIwLjYiLz4KPHBhdGggZD0iTTM2LjAwMSA1Mi44MDU1TDUxLjI4ODQgNDIuOTE3N0w1MS4yODg0IDcxLjgxNDVMMzYuMDAxIDgxLjc3OUwzNi4wMDEgNTIuODA1NVoiIGZpbGw9IndoaXRlIi8+CjxwYXRoIGQ9Ik04Mi4xMDUxIDg3LjE3OTdMOTcuMDAxNiA3Ny4wNjYyTDk3LjAwMTYgODEuNzAyOUw4MS43ODk2IDkxLjYyOUw4Mi4xMDUxIDg3LjE3OTdaIiBmaWxsPSJ3aGl0ZSIgZmlsbC1vcGFjaXR5PSIwLjUiLz4KPC9nPgo8ZGVmcz4KPGxpbmVhckdyYWRpZW50IGlkPSJwYWludDBfbGluZWFyXzc2OThfNTY4NDYiIHgxPSIxMSIgeTE9IjEyIiB4Mj0iMTI1IiB5Mj0iMTIzIiBncmFkaWVudFVuaXRzPSJ1c2VyU3BhY2VPblVzZSI+CjxzdG9wIHN0b3AtY29sb3I9IiNGREE1NEUiLz4KPHN0b3Agb2Zmc2V0PSIxIiBzdG9wLWNvbG9yPSIjQ0YzQTI2Ii8+CjwvbGluZWFyR3JhZGllbnQ+CjxjbGlwUGF0aCBpZD0iY2xpcDBfNzY5OF81Njg0NiI+CjxyZWN0IHdpZHRoPSIxMzUiIGhlaWdodD0iMTM1IiBmaWxsPSJ3aGl0ZSIvPgo8L2NsaXBQYXRoPgo8L2RlZnM+Cjwvc3ZnPgo=
// [EXPECTED] token URI 2: data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTM1IiBoZWlnaHQ9IjEzNSIgdmlld0JveD0iMCAwIDEzNSAxMzUiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxnIGNsaXAtcGF0aD0idXJsKCNjbGlwMF83Njk4XzU2ODQ2KSI+CjxjaXJjbGUgY3g9IjY3LjUiIGN5PSI2Ny41IiByPSI2Ny41IiBmaWxsPSJ1cmwoI3BhaW50MF9saW5lYXJfNzY5OF81Njg0NikiLz4KPHBhdGggZD0iTTUxLjI5MDUgNDIuOTQ0OUw2Ni40ODk1IDMzTDk3IDUyLjgwNjFMODEuODI0MSA2Mi43NDI1TDUxLjI5MDUgNDIuOTQ0OVoiIGZpbGw9IndoaXRlIi8+CjxwYXRoIGQ9Ik01MS42MDU1IDY3LjUwNTlMNjYuODA0NCA1Ny41NjFMOTcgNzcuMDY1N0w4Mi4xMDQ2IDg3LjE3OTNMNTEuNjA1NSA2Ny41MDU5WiIgZmlsbD0id2hpdGUiIGZpbGwtb3BhY2l0eT0iMC40Ii8+CjxwYXRoIGQ9Ik0zNi4wNDY0IDgxLjc1NTlMNTEuMjkwNSA3MS44MTFMODEuNzMzNiA5MS42NTQ3TDY2LjQ4OTUgMTAxLjUwOEwzNi4wNDY0IDgxLjc1NTlaIiBmaWxsPSJ3aGl0ZSIgZmlsbC1vcGFjaXR5PSIwLjYiLz4KPHBhdGggZD0iTTM2LjAwMSA1Mi44MDU1TDUxLjI4ODQgNDIuOTE3N0w1MS4yODg0IDcxLjgxNDVMMzYuMDAxIDgxLjc3OUwzNi4wMDEgNTIuODA1NVoiIGZpbGw9IndoaXRlIi8+CjxwYXRoIGQ9Ik04Mi4xMDUxIDg3LjE3OTdMOTcuMDAxNiA3Ny4wNjYyTDk3LjAwMTYgODEuNzAyOUw4MS43ODk2IDkxLjYyOUw4Mi4xMDUxIDg3LjE3OTdaIiBmaWxsPSJ3aGl0ZSIgZmlsbC1vcGFjaXR5PSIwLjUiLz4KPHBhdGggZD0iTTUxLjI5MDUgNDIuOTQ0OUw2Ni40ODk1IDMzTDk3IDUyLjgwNjFMODEuODI0MSA2Mi43NDI1TDUxLjI5MDUgNDIuOTQ0OVoiIGZpbGw9IndoaXRlIi8+CjxwYXRoIGQ9Ik01MS42MDU1IDY3LjUwNTlMNjYuODA0NCA1Ny41NjFMOTcgNzcuMDY1N0w4Mi4xMDQ2IDg3LjE3OTNMNTEuNjA1NSA2Ny41MDU5WiIgZmlsbD0id2hpdGUiIGZpbGwtb3BhY2l0eT0iMC40Ii8+CjxwYXRoIGQ9Ik0zNi4wNDY0IDgxLjc1NTlMNTEuMjkwNSA3MS44MTFMODEuNzMzNiA5MS42NTQ3TDY2LjQ4OTUgMTAxLjUwOEwzNi4wNDY0IDgxLjc1NTlaIiBmaWxsPSJ3aGl0ZSIgZmlsbC1vcGFjaXR5PSIwLjYiLz4KPHBhdGggZD0iTTM2LjAwMSA1Mi44MDU1TDUxLjI4ODQgNDIuOTE3N0w1MS4yODg0IDcxLjgxNDVMMzYuMDAxIDgxLjc3OUwzNi4wMDEgNTIuODA1NVoiIGZpbGw9IndoaXRlIi8+CjxwYXRoIGQ9Ik04Mi4xMDUxIDg3LjE3OTdMOTcuMDAxNiA3Ny4wNjYyTDk3LjAwMTYgODEuNzAyOUw4MS43ODk2IDkxLjYyOUw4Mi4xMDUxIDg3LjE3OTdaIiBmaWxsPSJ3aGl0ZSIgZmlsbC1vcGFjaXR5PSIwLjUiLz4KPC9nPgo8ZGVmcz4KPGxpbmVhckdyYWRpZW50IGlkPSJwYWludDBfbGluZWFyXzc2OThfNTY4NDYiIHgxPSI3IiB5MT0iMTEiIHgyPSIxMjQiIHkyPSIxMjMiIGdyYWRpZW50VW5pdHM9InVzZXJTcGFjZU9uVXNlIj4KPHN0b3Agc3RvcC1jb2xvcj0iI0JCMTc4RiIvPgo8c3RvcCBvZmZzZXQ9IjEiIHN0b3AtY29sb3I9IiNFMjA5OTgiLz4KPC9saW5lYXJHcmFkaWVudD4KPGNsaXBQYXRoIGlkPSJjbGlwMF83Njk4XzU2ODQ2Ij4KPHJlY3Qgd2lkdGg9IjEzNSIgaGVpZ2h0PSIxMzUiIGZpbGw9IndoaXRlIi8+CjwvY2xpcFBhdGg+CjwvZGVmcz4KPC9zdmc+Cg==
// [INFO] verify token URIs are different
// [INFO] token URI test completed successfully
// [INFO] confirmed: different positions have different token IDs and URIs
