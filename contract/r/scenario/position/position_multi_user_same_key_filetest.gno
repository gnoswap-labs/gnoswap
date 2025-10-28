// position multi user same key

// PKGPATH: gno.land/r/demo/main

package main

import (
	"encoding/base64"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
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

	barPath  = "gno.land/r/onbloc/bar"
	bazPath  = "gno.land/r/onbloc/baz"
	poolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000"
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
}

func initPoolAndUsers() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	ufmt.Println("[INFO] Creating pool at tick 0")
	pool.CreatePool(
		cross,
		barPath,
		bazPath,
		3000,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
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

	ufmt.Println("[INFO] Minting position for user1 (minTick: -6960, maxTick: 6960)")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		barPath,
		bazPath,
		3000,
		-6960,
		6960,
		"10000000",
		"10000000",
		"0",
		"0",
		time.Now().Unix()+1000,
		user1Addr,
		user1Addr,
		"",
	)

	positionLiquidity := pool.GetPositionLiquidity(poolPath, computePositionKey(-6960, 6960))

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
	ufmt.Printf("[EXPECTED] Position liquidity should be %s\n", positionLiquidity.ToString())
}

func mintUser2Position() {
	testing.SetRealm(user2Realm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	baz.Approve(cross, poolAddr, INT64_MAX)
	bar.Approve(cross, routerAddr, INT64_MAX)
	baz.Approve(cross, routerAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting position for user2 (minTick: -6960, maxTick: 6960)")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		barPath,
		bazPath,
		3000,
		-6960,
		6960,
		"10000000",
		"10000000",
		"0",
		"0",
		time.Now().Unix()+1000,
		user2Addr,
		user2Addr,
		"",
	)

	positionLiquidity := pool.GetPositionLiquidity(poolPath, computePositionKey(-6960, 6960))

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
	ufmt.Printf("[EXPECTED] Position liquidity should be %s\n", positionLiquidity.ToString())
}

// computePositionKey generates a unique base64-encoded key for a liquidity position.
func computePositionKey(
	tickLower int32,
	tickUpper int32,
) string {
	positionPackagePath := "gno.land/r/gnoswap/position"
	key := ufmt.Sprintf("%s__%d__%d", positionPackagePath, tickLower, tickUpper)
	encoded := base64.StdEncoding.EncodeToString([]byte(key))
	return encoded
}

// Output:
// [SCENARIO] 1. Initialize pool and users
// [INFO] Creating pool at tick 0
// [INFO] Transfer initial tokens to users
//
// [SCENARIO] 2. Mint position for user1
// [INFO] Minting position for user1 (minTick: -6960, maxTick: 6960)
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 34026470
// [EXPECTED] Amount0 should be 10000000
// [EXPECTED] Amount1 should be 10000000
// [EXPECTED] Position liquidity should be 34026470
//
// [SCENARIO] 3. Mint position for user2
// [INFO] Minting position for user2 (minTick: -6960, maxTick: 6960)
// [EXPECTED] Position ID should be 2
// [EXPECTED] Liquidity should be 34026470
// [EXPECTED] Amount0 should be 10000000
// [EXPECTED] Amount1 should be 10000000
// [EXPECTED] Position liquidity should be 68052940
