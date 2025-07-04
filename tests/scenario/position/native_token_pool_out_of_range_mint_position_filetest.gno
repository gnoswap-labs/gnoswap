// native token pool out of range mint position

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"

	"gno.land/r/demo/wugnot"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(access.ROLE_POOL)

	positionAddr, _ = access.GetAddress(access.ROLE_POSITION)

	gnotPath   = "gnot"
	wugnotPath = "gno.land/r/demo/wugnot"
	gnsPath    = "gno.land/r/gnoswap/v1/gns"
)

func main() {
	println("[SCENARIO] 1. Initialize Setup")
	initializeSetup()
	println()

	println("[SCENARIO] 2. Create Pool (gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000)")
	createPool(wugnotPath, gnsPath, 3000, 0)
	println()

	println("[SCENARIO] 3. Mint InRange Position (-6960 ~ 6960)")
	mintPosition(gnotPath, gnsPath, 3000, -6960, 6960, "1000000000", "1000000000", 1000000000)
	println()

	println("[SCENARIO] 4. Mint OutOfRange Position (only token0, -10140 ~ -8100)")
	mintPosition(gnotPath, gnsPath, 3000, -10140, -8100, "0", "50000000", 0)
	println()

	println("[SCENARIO] 5. Mint OutOfRange Position (only token1, 8100 ~ 10140)")
	mintPosition(gnotPath, gnsPath, 3000, 8100, 10140, "50000000", "0", 50000000)
	println()
}

func initializeSetup() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFeeByAdmin(cross, 0)

	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 1000000000000000}})
	testing.SetOriginSend(std.Coins{{"ugnot", 100000000000000}})
	testing.SetRealm(adminRealm)
	wugnot.Deposit(cross)

	banker := std.NewBanker(std.BankerTypeRealmIssue)

	println("[INFO] GNS Balance of admin:", gns.BalanceOf(adminAddr))
	println("[INFO] WUGNOT Balance of admin:", wugnot.BalanceOf(adminAddr))
	println("[INFO] ugnot Balance of admin:", banker.GetCoins(adminAddr))

	gns.Approve(cross, poolAddr, consts.INT64_MAX)
	wugnot.Approve(cross, poolAddr, consts.INT64_MAX)
	gns.Approve(cross, positionAddr, consts.INT64_MAX)
	wugnot.Approve(cross, positionAddr, consts.INT64_MAX)
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
		banker := std.NewBanker(std.BankerTypeRealmIssue)
		banker.SendCoins(adminAddr, positionAddr, std.Coins{{"ugnot", nativeCoinAmount}})
		testing.SetOriginSend(std.Coins{{"ugnot", nativeCoinAmount}})
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

// Output:
// [SCENARIO] 1. Initialize Setup
// [INFO] GNS Balance of admin: 100000000000000
// [INFO] WUGNOT Balance of admin: 100000000000000
// [INFO] ugnot Balance of admin: 1000000000000000ugnot
//
// [SCENARIO] 2. Create Pool (gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000)
// [EXPECTED] created gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000 pool at tick 0
//
// [SCENARIO] 3. Mint InRange Position (-6960 ~ 6960)
// [INFO] Minting position
// [EXPECTED] positionId: 1
// [EXPECTED] liquidity: 3402647087
// [EXPECTED] amount0: 1000000000
// [EXPECTED] amount1: 1000000000
//
// [SCENARIO] 4. Mint OutOfRange Position (only token0, -10140 ~ -8100)
// [INFO] Minting position
// [EXPECTED] positionId: 2
// [EXPECTED] liquidity: 773092922
// [EXPECTED] amount0: 0
// [EXPECTED] amount1: 50000000
//
// [SCENARIO] 5. Mint OutOfRange Position (only token1, 8100 ~ 10140)
// [INFO] Minting position
// [EXPECTED] positionId: 3
// [EXPECTED] liquidity: 773092922
// [EXPECTED] amount0: 50000000
// [EXPECTED] amount1: 0
