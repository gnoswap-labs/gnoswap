// wugnot gns 100 pool burn position with narrow range

// PKGPATH: gno.land/r/demo/main

package main

import (
	"chain"
	"chain/banker"
	"testing"

	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"

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

	gnotPath   = "gnot"
	wugnotPath = "gno.land/r/gnoland/wugnot"
	gnsPath    = "gno.land/r/gnoswap/gns"
)

func main() {
	println("[SCENARIO] 1. Initialize Setup")
	initializeSetup()
	println()

	println("[SCENARIO] 2. Create Pool (gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:100)")
	createPool(wugnotPath, gnsPath, 100, 0)
	println()

	println("[SCENARIO] 3. Mint Position (-1 ~ 1)")
	mintPosition(gnotPath, gnsPath, 100, -1, 1, "1000000000", "1000000000", 1000000000)
	println()

	println("[SCENARIO] 4. Remove Position (-1 ~ 1)")
	removePosition(1)
	println()
}

func initializeSetup() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	testing.IssueCoins(adminAddr, chain.Coins{{"ugnot", 1000000000000000}})
	testing.SetOriginSend(chain.Coins{{"ugnot", 100000000000000}})
	testing.SetRealm(adminRealm)
	wugnot.Deposit(cross)

	banker_ := banker.NewBanker(banker.BankerTypeRealmIssue)

	println("[INFO] GNS Balance of admin:", gns.BalanceOf(adminAddr))
	println("[INFO] WUGNOT Balance of admin:", wugnot.BalanceOf(adminAddr))
	println("[INFO] ugnot Balance of admin:", banker_.GetCoins(adminAddr))

	gns.Approve(cross, poolAddr, INT64_MAX)
	wugnot.Approve(cross, poolAddr, INT64_MAX)
	gns.Approve(cross, positionAddr, INT64_MAX)
	wugnot.Approve(cross, positionAddr, INT64_MAX)
}

func createPool(token0Path string, token1Path string, fee uint32, startTick int32) {
	testing.SetRealm(adminRealm)
	pool.CreatePool(
		cross,
		token0Path,
		token1Path,
		fee,
		common.TickMathGetSqrtRatioAtTick(startTick).ToString(),
	)

	ufmt.Printf("[EXPECTED] created %s:%s:%d pool at tick %d\n", token0Path, token1Path, fee, startTick)
}

func mintPosition(token0Path string, token1Path string, fee uint32, minTick, maxTick int32, amount0 string, amount1 string, nativeCoinAmount int64) {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] Minting position")

	if nativeCoinAmount > 0 {
		banker_ := banker.NewBanker(banker.BankerTypeRealmIssue)
		banker_.SendCoins(adminAddr, positionAddr, chain.Coins{{"ugnot", nativeCoinAmount}})
		testing.SetOriginSend(chain.Coins{{"ugnot", nativeCoinAmount}})
	}

	positionId, liquidity, amount0, amount1 := pn.Mint(
		cross,
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
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] positionId: %d\n", positionId)
	ufmt.Printf("[EXPECTED] liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] amount0: %s\n", amount0)
	ufmt.Printf("[EXPECTED] amount1: %s\n", amount1)
}

func removePosition(positionId uint64) {
	testing.SetRealm(adminRealm)

	_, liquidity, _, _, amount0, amount1, poolPath := pn.DecreaseLiquidity(
		cross,
		positionId,
		"1000000000",
		"0",
		"0",
		9999999999,
		true,
	)

	ufmt.Printf("[EXPECTED] positionId: %d\n", positionId)
	ufmt.Printf("[EXPECTED] decreased liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] decreased amount0: %s\n", amount0)
	ufmt.Printf("[EXPECTED] decreased amount1: %s\n", amount1)
	ufmt.Printf("[EXPECTED] pool token0 balance: %s\n", pool.GetBalanceToken0(poolPath))
	ufmt.Printf("[EXPECTED] pool token1 balance: %s\n", pool.GetBalanceToken1(poolPath))
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
