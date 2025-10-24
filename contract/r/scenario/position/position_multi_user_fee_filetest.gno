// position multi user fee

// PKGPATH: gno.land/r/demo/main

package main

import (
	"chain"
	"strconv"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"

	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
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
	pool.SetPoolCreationFee(cross, 0)

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
	bar.Approve(cross, poolAddr, INT64_MAX)
	baz.Approve(cross, poolAddr, INT64_MAX)
	bar.Approve(cross, routerAddr, INT64_MAX)
	baz.Approve(cross, routerAddr, INT64_MAX)

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
	bar.Approve(cross, poolAddr, INT64_MAX)
	baz.Approve(cross, poolAddr, INT64_MAX)
	bar.Approve(cross, routerAddr, INT64_MAX)
	baz.Approve(cross, routerAddr, INT64_MAX)

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
	bar.Approve(cross, poolAddr, INT64_MAX)
	baz.Approve(cross, poolAddr, INT64_MAX)
	bar.Approve(cross, routerAddr, INT64_MAX)
	baz.Approve(cross, routerAddr, INT64_MAX)

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))

	ufmt.Println("[INFO] Executing swap BAR -> BAZ")
	amount0, amount1 := pool.Swap(
		cross,
		barPath,
		bazPath,
		3000,
		adminAddr,
		true,
		"10000000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta string) error {
			return mockSwapCallback(barPath, bazPath, amount0Delta, amount1Delta, true)
		},
	)
	ufmt.Printf("[EXPECTED] Swap1 amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap1 amount1 should be %s\n", amount1)

	ufmt.Println("[INFO] Executing swap BAZ -> BAR")
	amount0, amount1 = pool.Swap(
		cross,
		barPath,
		bazPath,
		3000,
		adminAddr,
		false,
		"10000000",
		MAX_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta string) error {
			return mockSwapCallback(barPath, bazPath, amount0Delta, amount1Delta, false)
		},
	)
	ufmt.Printf("[EXPECTED] Swap2 amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap2 amount1 should be %s\n", amount1)
}

func collectUser1Fees() {
	testing.SetRealm(user1Realm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	baz.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Collecting fees for user1")
	_, fee0, fee1, _, _, _ := position.CollectFee(cross, 1, false)
	ufmt.Printf("[EXPECTED] User1 collected fee0 should be %s\n", fee0)
	ufmt.Printf("[EXPECTED] User1 collected fee1 should be %s\n", fee1)
}

func collectUser2Fees() {
	testing.SetRealm(user2Realm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	baz.Approve(cross, poolAddr, INT64_MAX)

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

func mockSwapCallback(token0Path string, token1Path string, amount0Delta string, amount1Delta string, zeroForOne bool) error {
	testing.SetRealm(adminRealm)

	const wugnotPath = "gno.land/r/gnoland/wugnot"
	const ugnotDenom = "ugnot"

	amount0Int64, _ := strconv.ParseInt(amount0Delta, 10, 64)
	amount1Int64, _ := strconv.ParseInt(amount1Delta, 10, 64)

	if zeroForOne {
		if token0Path == wugnotPath {
			testing.SetOriginSend(chain.Coins{{ugnotDenom, amount0Int64}})
			wugnot.Deposit(cross)
		}

		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Int64)
	} else {
		if token1Path == wugnotPath {
			testing.SetOriginSend(chain.Coins{{ugnotDenom, amount1Int64}})
			wugnot.Deposit(cross)
		}

		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Int64)
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
