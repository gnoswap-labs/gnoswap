// reward for user collect change by collecting reward external

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/demo/wugnot"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(access.ROLE_STAKER)
	stakerUser    = stakerAddr
	stakerRealm   = std.NewCodeRealm(consts.STAKER_PATH)

	poolAddr, _ = access.GetAddress(access.ROLE_POOL)
	wugnotAddr  = consts.WUGNOT_ADDR

	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"

	fee100 uint32 = 100

	max_timeout int64 = 9999999999

	// external incentive deposit fee
	depositGnsAmount int64 = 1_000_000_000 // 1_000 GNS

	TIMESTAMP_90DAYS int64 = 90 * 24 * 60 * 60
)

func main() {
	println("[SCENARIO] 1. Initialize account and emission")
	initAccountAndEmission()
	println()

	println("[SCENARIO] 2. Create bar:qux:100 pool")
	createPool()
	println()

	println("[SCENARIO] 3. Create external incentive for bar token")
	createExternalIncentiveBar()
	println()

	println("[SCENARIO] 4. Create external incentive for qux token")
	createExternalIncentiveQux()
	println()

	println("[SCENARIO] 5. Mint and stake bar qux position 01")
	mintAndStakePosition01()
	println()

	println("[SCENARIO] 6. Mint and stake bar qux position 02")
	mintAndStakePosition02()
	println()

	println("[SCENARIO] 7. Wait for external bar and qux to start")
	waitForExternalBarAndQuxStart()
	println()

	println("[SCENARIO] 8. Collect reward for position 01")
	collectReward(1)
	println()

	println("[SCENARIO] 9. Collect reward for position 02")
	collectReward(2)
}

func initAccountAndEmission() {
	println("[INFO] send coins to admin")
	testing.SetRealm(adminRealm)
	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 100_000_000_000_000}})

	testing.SetRealm(adminRealm)
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(adminAddr, wugnotAddr, std.Coins{{"ugnot", 50_000_000_000_000}})
	testing.SetOriginSend(std.Coins{{"ugnot", 50_000_000_000_000}})

	println("[INFO] wrap gnot to wugnot")
	wugnot.Deposit(cross)
	testing.SetOriginSend(nil)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
	emission.RegisterGnsChangeCallback(cross)
}

func createPool() {
	println("[INFO] set pool creation fee to 0")
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFeeByAdmin(cross, 0)

	println("[INFO] create pool gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100 at tick 0")
	pl.CreatePool(
		cross,
		barPath,
		quxPath,
		fee100,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)
}

func createExternalIncentiveBar() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, stakerAddr, consts.INT64_MAX)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	println("[INFO] create external incentive for bar token")
	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		barPath,
		9000000000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)
}

func createExternalIncentiveQux() {
	testing.SetRealm(adminRealm)

	qux.Approve(cross, stakerAddr, consts.INT64_MAX)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	println("[INFO] create external incentive for qux token")
	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		quxPath,
		18000000000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)
}

func mintAndStakePosition01() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	qux.Approve(cross, poolAddr, consts.INT64_MAX)

	println("[INFO] mint in-range position 01 (tick range: -50 ~ 50, requested amount: 100, 100)")
	pn.Mint(
		cross,
		barPath,
		quxPath,
		fee100,
		int32(-50),
		int32(50),
		"100",
		"100",
		"0",
		"0",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)

	println("[INFO] stake position 01")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")
}

func mintAndStakePosition02() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	qux.Approve(cross, poolAddr, consts.INT64_MAX)

	println("[INFO] mint in-range position 02 (tick range: -50 ~ 50, requested amount: 100, 100)")
	pn.Mint(
		cross,
		barPath,
		quxPath,
		fee100,
		int32(-50),
		int32(50),
		"100",
		"100",
		"0",
		"0",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)

	println("[INFO] stake position 02")
	gnft.Approve(cross, stakerAddr, positionIdFrom(2))
	sr.StakeToken(cross, 2, "")
}

func waitForExternalBarAndQuxStart() {
	externalStartTime := int64(1234569600)
	nowTime := time.Now().Unix()
	timeLeft := externalStartTime - nowTime

	blockAvgTime := int64(2)
	blockLeft := timeLeft / blockAvgTime

	println("[INFO] skip blocks until external bar and qux start")
	testing.SkipHeights(int64(blockLeft)) // skip until external bar starts
	testing.SkipHeights(10)               // skip bit more to see reward calculation

	println("[EXPECTED] external bar and qux incentive started")
}

func collectReward(positionId uint64) {
	testing.SetRealm(adminRealm)

	sr.CollectReward(cross, positionId, false)

	println("[INFO] collect reward for position", positionId)
	oldBar := bar.BalanceOf(adminUser)
	oldQux := qux.BalanceOf(adminUser)

	testing.SkipHeights(1)

	sr.CollectReward(cross, positionId, false)

	newBar := bar.BalanceOf(adminUser)
	newQux := qux.BalanceOf(adminUser)

	diffBar := newBar - oldBar
	diffQux := newQux - oldQux

	ufmt.Printf("[EXPECTED] position %d reward collected: BAR=%d, QUX=%d\n", positionId, diffBar, diffQux)
}

func milliToSec(milliseconds int64) int64 {
	return milliseconds / 1000
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
// [SCENARIO] 1. Initialize account and emission
// [INFO] send coins to admin
// [INFO] wrap gnot to wugnot
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create bar:qux:100 pool
// [INFO] set pool creation fee to 0
// [INFO] create pool gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100 at tick 0
//
// [SCENARIO] 3. Create external incentive for bar token
// [INFO] create external incentive for bar token
//
// [SCENARIO] 4. Create external incentive for qux token
// [INFO] create external incentive for qux token
//
// [SCENARIO] 5. Mint and stake bar qux position 01
// [INFO] mint in-range position 01 (tick range: -50 ~ 50, requested amount: 100, 100)
// [INFO] stake position 01
//
// [SCENARIO] 6. Mint and stake bar qux position 02
// [INFO] mint in-range position 02 (tick range: -50 ~ 50, requested amount: 100, 100)
// [INFO] stake position 02
//
// [SCENARIO] 7. Wait for external bar and qux to start
// [INFO] skip blocks until external bar and qux start
// [EXPECTED] external bar and qux incentive started
//
// [SCENARIO] 8. Collect reward for position 01
// [INFO] collect reward for position 1
// [EXPECTED] position 1 reward collected: BAR=343, QUX=688
//
// [SCENARIO] 9. Collect reward for position 02
// [INFO] collect reward for position 2
// [EXPECTED] position 2 reward collected: BAR=344, QUX=688
