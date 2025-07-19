// position multi user fee

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/pool"
	"gno.land/r/gnoswap/v1/position"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _  = access.GetAddress(access.ROLE_ADMIN)
	adminRealm    = std.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(access.ROLE_POOL)
	routerAddr, _ = access.GetAddress(access.ROLE_ROUTER)
	routerRealm   = std.NewUserRealm(routerAddr)

	user1Addr  = testutils.TestAddress("user1")
	user1Realm = std.NewUserRealm(user1Addr)
	user2Addr  = testutils.TestAddress("user2")
	user2Realm = std.NewUserRealm(user2Addr)

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
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
	pool.SetPoolCreationFeeByAdmin(cross, 0)

	ufmt.Println("[INFO] Creating pool at tick -23028")
	pool.CreatePool(
		cross,
		barPath,
		bazPath,
		3000,
		"25054144837504793118641380156", // encodePriceSqrt(1, 10)
	)

	ufmt.Println("[INFO] Transfer initial tokens to users")
	bar.Transfer(cross, user1Addr, 100_000_000)
	baz.Transfer(cross, user1Addr, 100_000_000)
	bar.Transfer(cross, user2Addr, 100_000_000)
	baz.Transfer(cross, user2Addr, 100_000_000)
}

func mintUser1Position() {
	testing.SetRealm(user1Realm)
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	baz.Approve(cross, poolAddr, consts.INT64_MAX)
	bar.Approve(cross, routerAddr, consts.INT64_MAX)
	baz.Approve(cross, routerAddr, consts.INT64_MAX)

	ufmt.Println("[INFO] Minting position for user1")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		barPath,
		bazPath,
		3000,
		-43020,
		0,
		"10000000",
		"10000000",
		"0",
		"0",
		time.Now().Unix()+1000,
		user1Addr,
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
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	baz.Approve(cross, poolAddr, consts.INT64_MAX)
	bar.Approve(cross, routerAddr, consts.INT64_MAX)
	baz.Approve(cross, routerAddr, consts.INT64_MAX)

	ufmt.Println("[INFO] Minting position for user2")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		barPath,
		bazPath,
		3000,
		-43020,
		0,
		"10000000",
		"10000000",
		"0",
		"0",
		time.Now().Unix()+1000,
		user2Addr,
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
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	baz.Approve(cross, poolAddr, consts.INT64_MAX)
	bar.Approve(cross, routerAddr, consts.INT64_MAX)
	baz.Approve(cross, routerAddr, consts.INT64_MAX)

	testing.SetRealm(routerRealm)

	ufmt.Println("[INFO] Executing swap BAR -> BAZ")
	amount0, amount1 := pool.Swap(
		cross,
		barPath,
		bazPath,
		3000,
		adminAddr,
		true,
		"10000000",
		consts.MIN_PRICE,
		adminAddr,
	)
	ufmt.Printf("[EXPECTED] Swap1 amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap1 amount1 should be %s\n", amount1)

	ufmt.Println("[INFO] Executing swap BAZ -> BAR")
	amount0, amount1 = pool.Swap(
		cross,
		bazPath,
		barPath,
		3000,
		adminAddr,
		false,
		"10000000",
		consts.MAX_PRICE,
		adminAddr,
	)
	ufmt.Printf("[EXPECTED] Swap2 amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap2 amount1 should be %s\n", amount1)
}

func collectUser1Fees() {
	testing.SetRealm(user1Realm)
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	baz.Approve(cross, poolAddr, consts.INT64_MAX)

	ufmt.Println("[INFO] Collecting fees for user1")
	_, fee0, fee1, _, _, _ := position.CollectFee(cross, 1, false)
	ufmt.Printf("[EXPECTED] User1 collected fee0 should be %s\n", fee0)
	ufmt.Printf("[EXPECTED] User1 collected fee1 should be %s\n", fee1)
}

func collectUser2Fees() {
	testing.SetRealm(user2Realm)
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	baz.Approve(cross, poolAddr, consts.INT64_MAX)

	ufmt.Println("[INFO] Collecting fees for user2")
	_, fee0, fee1, _, _, _ := position.CollectFee(cross, 2, false)
	ufmt.Printf("[EXPECTED] User2 collected fee0 should be %s\n", fee0)
	ufmt.Printf("[EXPECTED] User2 collected fee1 should be %s\n", fee1)
}

func compareCollectedFees() {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] Comparing collected fees between users")
	user1BarBalance := bar.BalanceOf(user1Addr)
	user1BazBalance := baz.BalanceOf(user1Addr)
	user2BarBalance := bar.BalanceOf(user2Addr)
	user2BazBalance := baz.BalanceOf(user2Addr)

	ufmt.Printf("[EXPECTED] User1 final BAR balance should be %d\n", user1BarBalance)
	ufmt.Printf("[EXPECTED] User1 final BAZ balance should be %d\n", user1BazBalance)
	ufmt.Printf("[EXPECTED] User2 final BAR balance should be %d\n", user2BarBalance)
	ufmt.Printf("[EXPECTED] User2 final BAZ balance should be %d\n", user2BazBalance)
	ufmt.Printf("[EXPECTED] Users should have equal fee distribution\n")
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
// [INFO] Executing swap BAR -> BAZ
// [EXPECTED] Swap1 amount0 should be 10000000
// [EXPECTED] Swap1 amount1 should be -743552
// [INFO] Executing swap BAZ -> BAR
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
// [EXPECTED] User1 final BAR balance should be 90014852
// [EXPECTED] User1 final BAZ balance should be 99086282
// [EXPECTED] User2 final BAR balance should be 90014852
// [EXPECTED] User2 final BAZ balance should be 99086282
// [EXPECTED] Users should have equal fee distribution
