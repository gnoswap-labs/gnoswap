// PKGPATH: gno.land/r/gnoswap/v1/main
package main

import (
	"std"
	"strconv"

	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/access"
	en "gno.land/r/gnoswap/v1/emission"

	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/v1/rbac"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerRealm   = std.NewCodeRealm(consts.STAKER_PATH)

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	quxPath = "gno.land/r/onbloc/qux"

	fee3000 uint32 = 3000

	max_timeout      int64 = 9999999999
	depositGnsAmount int64 = 100000000000

	TIMESTAMP_365DAYS = int64(31536000)
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint 4 positions on bar:baz:3000")
	mintBarBaz3000_1_4()
	println()

	println("[SCENARIO] 4. Create external incentive with QUX for 365 days")
	createExternalIncentiveQux365()
	println()

	println("[SCENARIO] 5. Stake positions 1-4")
	stakeToken_1_4()
	println()

	println("[SCENARIO] 6. Prepare for active period")
	beforeActive()
	println()

	println("[SCENARIO] 7. Check rewards for 1 block of 365 days external")
	rewardFor1Block()
	println()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)

	sr.SetWarmUp(cross, 30, 150)
	sr.SetWarmUp(cross, 50, 300)
	sr.SetWarmUp(cross, 70, 900)
	sr.SetWarmUp(cross, 100, consts.INT64_MAX)

	testing.SetRealm(stakerRealm)
	en.RegisterGnsChangeCallback(cross)
	testing.SkipHeights(1)
}

func createPool() {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee()*3)

	pl.CreatePool(cross, barPath, bazPath, 3000, "79228162514264337593543950337")

	ufmt.Printf("[EXPECTED] bar:baz:3000 pool created successfully\n")
	testing.SkipHeights(1)
}

func mintBarBaz3000_1_4() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	baz.Approve(cross, poolAddr, consts.INT64_MAX)

	anoAdmin := adminUser

	pn.Mint(cross, barPath, bazPath, fee3000, int32(-1020), int32(1020), "13630", "13630", "0", "0", max_timeout, anoAdmin, anoAdmin, "")
	pn.Mint(cross, barPath, bazPath, fee3000, int32(-1020), int32(1020), "84360", "84360", "0", "0", max_timeout, anoAdmin, anoAdmin, "")
	pn.Mint(cross, barPath, bazPath, fee3000, int32(-1020), int32(1020), "1990", "1990", "0", "0", max_timeout, anoAdmin, anoAdmin, "")
	pn.Mint(cross, barPath, bazPath, fee3000, int32(-1020), int32(1020), "7", "7", "0", "0", max_timeout, anoAdmin, anoAdmin, "")
	testing.SkipHeights(1)

	t1Liq := pn.PositionGetPositionLiquidity(1).Clone()
	t2Liq := pn.PositionGetPositionLiquidity(2).Clone()
	t3Liq := pn.PositionGetPositionLiquidity(3).Clone()
	t4Liq := pn.PositionGetPositionLiquidity(4).Clone()

	all := u256.Zero()
	all.Add(all, t1Liq)
	all.Add(all, t2Liq)
	all.Add(all, t3Liq)
	all.Add(all, t4Liq)

	t1pct := t1Liq.Mul(t1Liq, u256.NewUint(100))
	t1pct.Div(t1pct, all) // 13.6317%
	t2pct := t2Liq.Mul(t2Liq, u256.NewUint(100))
	t2pct.Div(t2pct, all) // 84.3710%
	t3pct := t3Liq.Mul(t3Liq, u256.NewUint(100))
	t3pct.Div(t3pct, all) // 1.9902%
	t4pct := t4Liq.Mul(t4Liq, u256.NewUint(100))
	t4pct.Div(t4pct, all) // 0.0069%

	ufmt.Printf("[EXPECTED] positions minted with liquidity ratios - pos1: %s%%, pos2: %s%%, pos3: %s%%, pos4: %s%%\n",
		t1pct.ToString(), t2pct.ToString(), t3pct.ToString(), t4pct.ToString())
}

func createExternalIncentiveQux365() {
	testing.SetRealm(adminRealm)

	qux.Approve(cross, stakerAddr, consts.INT64_MAX)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	sr.AddToken(cross, quxPath)
	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000",
		quxPath,
		100_000_000_000_000,
		1234569600,
		1234569600+TIMESTAMP_365DAYS,
	)

	ufmt.Printf("[EXPECTED] external incentive QUX created for 365 days\n")
	testing.SkipHeights(1)
}

func stakeToken_1_4() {
	testing.SetRealm(adminRealm)

	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	gnft.Approve(cross, stakerAddr, positionIdFrom(2))
	sr.StakeToken(cross, 2, "")

	gnft.Approve(cross, stakerAddr, positionIdFrom(3))
	sr.StakeToken(cross, 3, "")

	gnft.Approve(cross, stakerAddr, positionIdFrom(4))
	sr.StakeToken(cross, 4, "")

	ufmt.Printf("[EXPECTED] all 4 positions staked successfully\n")
	testing.SkipHeights(1)
}

func beforeActive() {
	testing.SetRealm(adminRealm)
	en.MintAndDistributeGns(cross)
	testing.SkipHeights(1)
}

func rewardFor1Block() {
	testing.SkipHeights(849) // in active
	testing.SkipHeights(1)   // active // but no block passed since active
	testing.SetRealm(adminRealm)

	sr.CollectReward(cross, 1, false)
	sr.CollectReward(cross, 2, false)
	sr.CollectReward(cross, 3, false)
	sr.CollectReward(cross, 4, false)

	println("[INFO] skipping 1 block to check rewards")
	testing.SkipHeights(1)
	testing.SetRealm(adminRealm)

	/*
		- each staked position's liquidity ratio
		> position01: 13.6317%
		> position02: 84.3710%
		> position03: 1.9902%
		> position04: 0.0069%

		- block per reward 634195
	*/

	println("[INFO] collecting reward for position 01")
	testing.SetRealm(adminRealm)

	oldQux := qux.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	newQux := qux.BalanceOf(adminUser)
	diff := newQux - oldQux
	ufmt.Printf("[EXPECTED] position 01 reward: %d QUX\n", diff)
	// reward 59911
	// penalty 25936
	// total 85847
	// 634195 * 13.6317% = 86451.559815

	println("[INFO] collecting reward for position 02")
	testing.SetRealm(adminRealm)

	oldQux = qux.BalanceOf(adminUser)
	sr.CollectReward(cross, 2, false)
	newQux = qux.BalanceOf(adminUser)
	diff = newQux - oldQux
	ufmt.Printf("[EXPECTED] position 02 reward: %d QUX\n", diff)
	// reward 370808
	// penalty 160523
	// total 531331
	// 634195 * 84.3710% = 535076.66345

	println("[INFO] collecting reward for position 03")
	testing.SetRealm(adminRealm)

	oldQux = qux.BalanceOf(adminUser)
	sr.CollectReward(cross, 3, false)
	newQux = qux.BalanceOf(adminUser)
	diff = newQux - oldQux
	ufmt.Printf("[EXPECTED] position 03 reward: %d QUX\n", diff)
	// reward 8747
	// penalty 3787
	// total 12534
	// 634195 * 1.9902% = 12621.74889

	println("[INFO] collecting reward for position 04")
	testing.SetRealm(adminRealm)

	oldQux = qux.BalanceOf(adminUser)
	sr.CollectReward(cross, 4, false)
	newQux = qux.BalanceOf(adminUser)
	diff = newQux - oldQux
	ufmt.Printf("[EXPECTED] position 04 reward: %d QUX\n", diff)
	// reward 30
	// penalty 14
	// total 44
	// 634195 * 0.0069% = 43.759455
}

func positionIdFrom(positionId any) grc721.TokenID {
	switch positionId := positionId.(type) {
	case string:
		return grc721.TokenID(positionId)
	case int:
		return grc721.TokenID(strconv.Itoa(positionId))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(positionId)))
	case grc721.TokenID:
		return positionId
	default:
		panic("unsupported positionId type")
	}
}

// Output:
// [SCENARIO] 1. Initialize and setup
//
// [SCENARIO] 2. Create pool
// [EXPECTED] bar:baz:3000 pool created successfully
//
// [SCENARIO] 3. Mint 4 positions on bar:baz:3000
// [EXPECTED] positions minted with liquidity ratios - pos1: 13%, pos2: 84%, pos3: 1%, pos4: 0%
//
// [SCENARIO] 4. Create external incentive with QUX for 365 days
// [EXPECTED] external incentive QUX created for 365 days
//
// [SCENARIO] 5. Stake positions 1-4
// [EXPECTED] all 4 positions staked successfully
//
// [SCENARIO] 6. Prepare for active period
//
// [SCENARIO] 7. Check rewards for 1 block of 365 days external
// [INFO] skipping 1 block to check rewards
// [INFO] collecting reward for position 01
// [EXPECTED] position 01 reward: 599113 QUX
// [INFO] collecting reward for position 02
// [EXPECTED] position 02 reward: 3708086 QUX
// [INFO] collecting reward for position 03
// [EXPECTED] position 03 reward: 87471 QUX
// [INFO] collecting reward for position 04
// [EXPECTED] position 04 reward: 305 QUX
