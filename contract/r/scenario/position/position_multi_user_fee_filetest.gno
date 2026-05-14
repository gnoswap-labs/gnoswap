// position multi user fee

// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"

	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/atone"
)

const (
	INT64_MAX int64 = 9223372036854775807

	MIN_PRICE string = "4295128740"                                        // MIN_SQRT_RATIO + 1
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1
)

var (
	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prbac.ROLE_ROUTER.String())
	routerRealm   = testing.NewUserRealm(routerAddr)

	user1Addr  = testutils.TestAddress("user1")
	user1Realm = testing.NewUserRealm(user1Addr)
	user2Addr  = testutils.TestAddress("user2")
	user2Realm = testing.NewUserRealm(user2Addr)

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize pool and users")
	initPoolAndUsers()
	println()

	ufmt.Println("[SCENARIO] 2. Mint position for user1")
	mintUser1Position()
	println()

	ufmt.Println("[SCENARIO] 3. Mint position for user2")
	mintUser2Position()
	println()

	ufmt.Println("[SCENARIO] 4. Execute swaps to generate fees")
	executeSwaps()
	println()

	ufmt.Println("[SCENARIO] 5. Check and collect fees for user1")
	collectUser1Fees()
	println()

	ufmt.Println("[SCENARIO] 6. Check and collect fees for user2")
	collectUser2Fees()
	println()

	ufmt.Println("[SCENARIO] 7. Compare collected fees between users")
	compareCollectedFees()
	println()
}

func initPoolAndUsers() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	ufmt.Println("[INFO] Creating pool at tick -23028")
	pool.CreatePool(
		cross,
		atomPath,
		atonePath,
		3000,
		"25054144837504793118641380156", // encodePriceSqrt(1, 10)
	)

	ufmt.Println("[INFO] Transfer initial tokens to users")
	atom.Transfer(cross, user1Addr, 100_000_000)
	atone.Transfer(cross, user1Addr, 100_000_000)
	atom.Transfer(cross, user2Addr, 100_000_000)
	atone.Transfer(cross, user2Addr, 100_000_000)
}

func mintUser1Position() {
	testing.SetRealm(user1Realm)
	atom.Approve(cross, poolAddr, INT64_MAX)
	atone.Approve(cross, poolAddr, INT64_MAX)
	atom.Approve(cross, routerAddr, INT64_MAX)
	atone.Approve(cross, routerAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting position for user1")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		atomPath,
		atonePath,
		3000,
		-43020,
		0,
		"10000000",
		"10000000",
		"0",
		"0",
		time.Now().Unix()+1000,
		user1Addr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
}

func mintUser2Position() {
	testing.SetRealm(user2Realm)
	atom.Approve(cross, poolAddr, INT64_MAX)
	atone.Approve(cross, poolAddr, INT64_MAX)
	atom.Approve(cross, routerAddr, INT64_MAX)
	atone.Approve(cross, routerAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting position for user2")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		atomPath,
		atonePath,
		3000,
		-43020,
		0,
		"10000000",
		"10000000",
		"0",
		"0",
		time.Now().Unix()+1000,
		user2Addr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
}

func executeSwaps() {
	testing.SetRealm(adminRealm)
	atom.Approve(cross, poolAddr, INT64_MAX)
	atone.Approve(cross, poolAddr, INT64_MAX)
	atom.Approve(cross, routerAddr, INT64_MAX)
	atone.Approve(cross, routerAddr, INT64_MAX)

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))

	ufmt.Println("[INFO] Executing swap ATOM -> ATONE")
	amount0, amount1 := pool.Swap(
		cross,
		atomPath,
		atonePath,
		3000,
		adminAddr,
		true,
		"10000000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(atomPath, atonePath, amount0Delta, amount1Delta, true)
		},
	)
	ufmt.Printf("[EXPECTED] Swap1 amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap1 amount1 should be %s\n", amount1)

	ufmt.Println("[INFO] Executing swap ATONE -> ATOM")
	amount0, amount1 = pool.Swap(
		cross,
		atomPath,
		atonePath,
		3000,
		adminAddr,
		false,
		"10000000",
		MAX_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(atomPath, atonePath, amount0Delta, amount1Delta, false)
		},
	)
	ufmt.Printf("[EXPECTED] Swap2 amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap2 amount1 should be %s\n", amount1)
}

func collectUser1Fees() {
	testing.SetRealm(user1Realm)
	atom.Approve(cross, poolAddr, INT64_MAX)
	atone.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Collecting fees for user1")
	_, fee0, fee1, _, _, _ := position.CollectFee(cross, 1)
	ufmt.Printf("[EXPECTED] User1 collected fee0 should be %s\n", fee0)
	ufmt.Printf("[EXPECTED] User1 collected fee1 should be %s\n", fee1)
}

func collectUser2Fees() {
	testing.SetRealm(user2Realm)
	atom.Approve(cross, poolAddr, INT64_MAX)
	atone.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Collecting fees for user2")
	_, fee0, fee1, _, _, _ := position.CollectFee(cross, 2)
	ufmt.Printf("[EXPECTED] User2 collected fee0 should be %s\n", fee0)
	ufmt.Printf("[EXPECTED] User2 collected fee1 should be %s\n", fee1)
}

func compareCollectedFees() {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] Comparing collected fees between users")
	user1AtomBalance := atom.BalanceOf(user1Addr)
	user1AtoneBalance := atone.BalanceOf(user1Addr)
	user2AtomBalance := atom.BalanceOf(user2Addr)
	user2AtoneBalance := atone.BalanceOf(user2Addr)

	ufmt.Printf("[EXPECTED] User1 final ATOM balance should be %d\n", user1AtomBalance)
	ufmt.Printf("[EXPECTED] User1 final ATONE balance should be %d\n", user1AtoneBalance)
	ufmt.Printf("[EXPECTED] User2 final ATOM balance should be %d\n", user2AtomBalance)
	ufmt.Printf("[EXPECTED] User2 final ATONE balance should be %d\n", user2AtoneBalance)
	ufmt.Printf("[EXPECTED] Users should have equal fee distribution\n")
}

func mockSwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64, zeroForOne bool) error {
	testing.SetRealm(adminRealm)

	if amount0Delta > 0 {
		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Delta)
	}

	if amount1Delta > 0 {
		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Delta)
	}

	return nil
}

// Output:
// [SCENARIO] 1. Initialize pool and users
// [INFO] Creating pool at tick -23028
// [INFO] Transfer initial tokens to users
//
// [SCENARIO] 2. Mint position for user1
// [INFO] Minting position for user1
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 4624752
// [EXPECTED] Amount0 should be 9999998
// [EXPECTED] Amount1 should be 924246
//
// [SCENARIO] 3. Mint position for user2
// [INFO] Minting position for user2
// [EXPECTED] Position ID should be 2
// [EXPECTED] Liquidity should be 4624752
// [EXPECTED] Amount0 should be 9999998
// [EXPECTED] Amount1 should be 924246
//
// [SCENARIO] 4. Execute swaps to generate fees
// [INFO] Executing swap ATOM -> ATONE
// [EXPECTED] Swap1 amount0 should be 10000000
// [EXPECTED] Swap1 amount1 should be -743552
// [INFO] Executing swap ATONE -> ATOM
// [EXPECTED] Swap2 amount0 should be -29969994
// [EXPECTED] Swap2 amount1 should be 7089378
//
// [SCENARIO] 5. Check and collect fees for user1
// [INFO] Collecting fees for user1
// [EXPECTED] User1 collected fee0 should be 14850
// [EXPECTED] User1 collected fee1 should be 10528
//
// [SCENARIO] 6. Check and collect fees for user2
// [INFO] Collecting fees for user2
// [EXPECTED] User2 collected fee0 should be 14850
// [EXPECTED] User2 collected fee1 should be 10528
//
// [SCENARIO] 7. Compare collected fees between users
// [INFO] Comparing collected fees between users
// [EXPECTED] User1 final ATOM balance should be 90014852
// [EXPECTED] User1 final ATONE balance should be 99086282
// [EXPECTED] User2 final ATOM balance should be 90014852
// [EXPECTED] User2 final ATONE balance should be 99086282
// [EXPECTED] Users should have equal fee distribution
