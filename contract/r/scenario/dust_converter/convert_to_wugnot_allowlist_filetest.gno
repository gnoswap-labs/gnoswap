// PKGPATH: gno.land/r/demo/main
package main

import (
	"chain"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	dc "gno.land/r/gnoswap/dust_converter"
	"gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	sr "gno.land/r/gnoswap/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/onbloc/bar"
)

var (
	adminAddr  = access.MustGetAddress(prabc.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)

	poolAddr = access.MustGetAddress(prabc.ROLE_POOL.String())

	userAddr  = testutils.TestAddress("dust-user")
	userRealm = testing.NewUserRealm(userAddr)

	dustConverterAddr = testing.NewCodeRealm("gno.land/r/gnoswap/dust_converter").Address()
)

const (
	barPath    = "gno.land/r/onbloc/bar"
	wugnotPath = "gno.land/r/gnoland/wugnot"

	feeTier uint32 = 500
)

func main() {
	println("[SCENARIO] Convert dust to allowlisted WUGNOT (GNOT)")
	println()

	println("[SCENARIO] 1. Allowlist WUGNOT as target asset")
	addTargetAsset()
	println()

	println("[SCENARIO] 2. Setup pool and liquidity")
	setupPool()
	println()

	println("[SCENARIO] 3. Convert bar dust to WUGNOT")
	convertDust()
	println()
}

func addTargetAsset() {
	testing.SetRealm(adminRealm)
	dc.AddTargetAsset(cross, wugnotPath)
	println("[EXPECTED] isTargetAsset(wugnot):", dc.IsTargetAsset(wugnotPath))
}

func setupPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	createPool(barPath, wugnotPath, feeTier)

	bar.Approve(cross, poolAddr, 1_000_000_000)
	mintWugnot(1_000_000_000)
	wugnot.Approve(cross, poolAddr, 1_000_000_000)

	mintPosition(barPath, wugnotPath, feeTier, "1000000", "1000000")
}

func mintWugnot(amount int64) {
	testing.SetRealm(adminRealm)
	testing.IssueCoins(adminAddr, chain.Coins{{"ugnot", amount}})
	testing.SetOriginSend(chain.Coins{{"ugnot", amount}})
	wugnot.Deposit(cross)
	testing.SetOriginSend(chain.Coins{})
}

func createPool(token0Path, token1Path string, fee uint32) {
	poolPath := pool.GetPoolPath(token0Path, token1Path, fee)
	if pool.ExistsPoolPath(poolPath) {
		return
	}

	pool.CreatePool(
		cross,
		token0Path,
		token1Path,
		fee,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)
	sr.SetPoolTier(cross, poolPath, 1)
	ufmt.Printf("[EXPECTED] created pool: %s\n", poolPath)
}

func mintPosition(token0Path, token1Path string, fee uint32, amount0, amount1 string) {
	_, liquidity, amt0, amt1 := pn.Mint(
		cross,
		token0Path,
		token1Path,
		fee,
		-6000,
		6000,
		amount0,
		amount1,
		"0",
		"0",
		9999999999,
		adminAddr,
		adminAddr,
		"",
	)
	ufmt.Printf("[EXPECTED] liquidity: %s amount0: %s amount1: %s\n", liquidity, amt0, amt1)
}

func convertDust() {
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, dustConverterAddr, 10)
	println("[EXPECTED] dust_converter bar balance:", bar.BalanceOf(dustConverterAddr))

	testing.SetRealm(userRealm)
	beforeWugnot := wugnot.BalanceOf(userAddr)
	totalOut := dc.ConvertDustToGns(
		cross,
		wugnotPath,
		barPath+":10",
		time.Now().Add(time.Hour).Unix(),
		userAddr,
	)

	println("[EXPECTED] totalOut:", totalOut)
	println("[EXPECTED] dust_converter bar balance after convert:", bar.BalanceOf(dustConverterAddr))
	println("[EXPECTED] user wugnot delta:", wugnot.BalanceOf(userAddr)-beforeWugnot)
}

// Output:
// [SCENARIO] Convert dust to allowlisted WUGNOT (GNOT)
//
// [SCENARIO] 1. Allowlist WUGNOT as target asset
// [EXPECTED] isTargetAsset(wugnot): true
//
// [SCENARIO] 2. Setup pool and liquidity
// [EXPECTED] created pool: gno.land/r/gnoland/wugnot:gno.land/r/onbloc/bar:500
// [EXPECTED] liquidity: 3858461 amount0: 1000000 amount1: 1000000
//
// [SCENARIO] 3. Convert bar dust to WUGNOT
// [EXPECTED] dust_converter bar balance: 10
// [EXPECTED] totalOut: 8
// [EXPECTED] dust_converter bar balance after convert: 0
// [EXPECTED] user wugnot delta: 8
