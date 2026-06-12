// wugnot gns 100 pool burn position with narrow range

// PKGPATH: gno.land/r/demo/main

package main

import (
	"gno.land/p/gnoswap/gnsmath"
	"chain"
	"chain/banker"
	"testing"

	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/gns"
)

const INT64_MAX int64 = 9223372036854775807

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(prbac.ROLE_POOL.String())

	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())

	wugnotPath = "gno.land/r/gnoland/wugnot"
	gnsPath    = "gno.land/r/gnoswap/gns"
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize Setup")

	testing.SetRealm(adminRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 100000000000000}})
	wugnot.Deposit(cross(cur))
	testing.SetOriginSend(chain.Coins{})
	initializeSetup(cur)
	println()

	println("[SCENARIO] 2. Create Pool (gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:100)")
	createPool(cur, wugnotPath, gnsPath, 100, 0)
	println()

	println("[SCENARIO] 3. Mint Position (-1 ~ 1)")
	mintPosition(cur, wugnotPath, gnsPath, 100, -1, 1, "1000000000", "1000000000", 1000000000)
	println()

	println("[SCENARIO] 4. Remove Position (-1 ~ 1)")
	removePosition(cur, 1)
	println()
}

func initializeSetup(cur realm) {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross(cur), 0)

	testing.IssueCoins(adminAddr, chain.Coins{{"ugnot", 1000000000000000}})

	banker_ := banker.NewBanker(banker.BankerTypeRealmIssue, cur)

	println("[INFO] GNS Balance of admin:", gns.BalanceOf(adminAddr))
	println("[INFO] WUGNOT Balance of admin:", wugnot.BalanceOf(adminAddr))
	println("[INFO] ugnot Balance of admin:", banker_.GetCoins(adminAddr))

	gns.Approve(cross(cur), poolAddr, INT64_MAX)
	wugnot.Approve(cross(cur), poolAddr, INT64_MAX)
	gns.Approve(cross(cur), positionAddr, INT64_MAX)
	wugnot.Approve(cross(cur), positionAddr, INT64_MAX)
}

func createPool(cur realm, token0Path string, token1Path string, fee uint32, startTick int32) {
	testing.SetRealm(adminRealm)
	pool.CreatePool(
		cross(cur),
		token0Path,
		token1Path,
		fee,
		gnsmath.TickMathGetSqrtRatioAtTick(startTick).ToString(),
	)

	ufmt.Printf("[EXPECTED] created %s:%s:%d pool at tick %d\n", token0Path, token1Path, fee, startTick)
}

func mintPosition(cur realm, token0Path string, token1Path string, fee uint32, minTick, maxTick int32, amount0 string, amount1 string, nativeCoinAmount int64) {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] Minting position")

	positionId, liquidity, amount0, amount1 := pn.Mint(
		cross(cur),
		token0Path,
		token1Path,
		fee,
		minTick,
		maxTick,
		amount0,
		amount1,
		"0",
		"0",
		9999999999,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] positionId: %d\n", positionId)
	ufmt.Printf("[EXPECTED] liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] amount0: %s\n", amount0)
	ufmt.Printf("[EXPECTED] amount1: %s\n", amount1)
}

func removePosition(cur realm, positionId uint64) {
	testing.SetRealm(adminRealm)

	_, liquidity, _, _, amount0, amount1, poolPath := pn.DecreaseLiquidity(
		cross(cur),
		positionId,
		"1000000000",
		"0",
		"0",
		9999999999,
	)

	ufmt.Printf("[EXPECTED] positionId: %d\n", positionId)
	ufmt.Printf("[EXPECTED] decreased liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] decreased amount0: %s\n", amount0)
	ufmt.Printf("[EXPECTED] decreased amount1: %s\n", amount1)
	ufmt.Printf("[EXPECTED] pool token0 balance: %d\n", pool.GetBalanceToken0(poolPath))
	ufmt.Printf("[EXPECTED] pool token1 balance: %d\n", pool.GetBalanceToken1(poolPath))
}

// Output:
// [SCENARIO] 1. Initialize Setup
// [INFO] GNS Balance of admin: 100000000000000
// [INFO] WUGNOT Balance of admin: 100000000000000
// [INFO] ugnot Balance of admin: 1000000000000000ugnot
//
// [SCENARIO] 2. Create Pool (gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:100)
// [EXPECTED] created gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:100 pool at tick 0
//
// [SCENARIO] 3. Mint Position (-1 ~ 1)
// [INFO] Minting position
// [EXPECTED] positionId: 1
// [EXPECTED] liquidity: 20001499987500
// [EXPECTED] amount0: 1000000000
// [EXPECTED] amount1: 1000000000
//
// [SCENARIO] 4. Remove Position (-1 ~ 1)
// [EXPECTED] positionId: 1
// [EXPECTED] decreased liquidity: 1000000000
// [EXPECTED] decreased amount0: 49996
// [EXPECTED] decreased amount1: 49996
// [EXPECTED] pool token0 balance: 999950004
// [EXPECTED] pool token1 balance: 999950004
