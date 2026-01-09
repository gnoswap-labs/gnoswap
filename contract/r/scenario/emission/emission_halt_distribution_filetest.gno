// emission halt distribution
//
// Scenario:
//   1. Collect emission reward before halt
//   2. Halt emission
//   3. Collect emission reward after halt
//   4. Resume emission
//   5. Collect emission reward after resume

// PKGPATH: gno.land/r/demo/main

package main

import (
	"chain"
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	_ "gno.land/r/gnoswap/rbac"
	"gno.land/r/gnoswap/staker"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"

	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
)

const (
	INT64_MAX int64 = 9223372036854775807

	MIN_PRICE string = "4295128740"                                        // MIN_SQRT_RATIO + 1
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1
)

var (
	adminAddr, _       = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm         = testing.NewUserRealm(adminAddr)
	poolAddr, _        = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _      = access.GetAddress(prbac.ROLE_ROUTER.String())
	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	stakerAddr, _      = access.GetAddress(prbac.ROLE_STAKER.String())
	emissionAddr, _    = access.GetAddress(prbac.ROLE_EMISSION.String())
	routerRealm        = testing.NewUserRealm(routerAddr)

	wugnotPath        = "gno.land/r/gnoland/wugnot"
	gnsPath           = "gno.land/r/gnoswap/gns"
	fee3000    uint32 = 3000

	wugnotGnsPoolPath = ufmt.Sprintf("%s:%s:%d", wugnotPath, gnsPath, fee3000)
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize emission state and pool")
	initEmissionState()
	initPool()
	testing.SkipHeights(1)
	println()

	ufmt.Println("[SCENARIO] 2. Mint position and stake")
	mintPositionAndStake()
	testing.SkipHeights(1)
	println()

	ufmt.Println("[SCENARIO] 3. Collect rewards before halt")
	collectRewards(1)
	testing.SkipHeights(1)
	println()

	ufmt.Println("[SCENARIO] 4. Set emission halt")
	setEmissionHaltState(true)
	println()

	ufmt.Println("[SCENARIO] 5. Collect rewards after halt")
	testing.SkipHeights(1)
	println()

	ufmt.Println("[SCENARIO] 6. Resume emission")
	setEmissionHaltState(false)
	println()

	ufmt.Println("[SCENARIO] 7. Collect rewards after resume")
	collectRewards(1)
	testing.SkipHeights(1)
	println()
}

func initEmissionState() {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)

	ufmt.Println("[INFO] Initializing emission state")
}

func initPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	testing.SetRealm(adminRealm)

	pool.CreatePool(
		cross,
		wugnotPath,
		gnsPath,
		fee3000,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	ufmt.Println("[INFO] Pool created: %s (tier: 1)", wugnotGnsPoolPath)
}

func mintPositionAndStake() {
	testing.SetRealm(adminRealm)
	testing.SetOriginSend(chain.Coins{{"ugnot", 100000000000000}})
	wugnot.Deposit(cross)

	wugnot.Approve(cross, poolAddr, INT64_MAX)
	gns.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting and staking position")
	testing.SetOriginSend(chain.Coins{{}})
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		wugnotPath,
		gnsPath,
		fee3000,
		-6960,
		6960,
		"50000000",
		"50000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		adminAddr,
		adminAddr,
		"",
	)

	gnft.Approve(cross, stakerAddr, grc721.TokenID(strconv.Itoa(int(positionId))))
	staker.StakeToken(cross, positionId, "")

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
}

func setEmissionHaltState(halted bool) {
	testing.SetRealm(adminRealm)
	halt.SetOperationStatus(cross, halt.OpTypeEmission, halted)

	ufmt.Printf("[INFO] Emission halt state set to %t\n", halted)
}

func collectRewards(positionId uint64) {
	testing.SetRealm(adminRealm)

	var totalAdminRewards int64
	var totalStakerBalanceChanges int64

	checkEmissionDistributionChangesFn(func() {
		stakerBalanceBeforeMint := gns.BalanceOf(stakerAddr)
		beforeGns := gns.BalanceOf(adminAddr)

		emission.MintAndDistributeGns(cross)
		totalStakerBalanceChanges = totalStakerBalanceChanges + gns.BalanceOf(stakerAddr) - stakerBalanceBeforeMint

		staker.CollectReward(cross, positionId, false)
		totalAdminRewards = gns.BalanceOf(adminAddr) - beforeGns
	})

	ufmt.Printf("[EXPECTED] total staker balance changes: %d\n", totalStakerBalanceChanges)
	ufmt.Printf("[EXPECTED] total reward: %d\n", totalAdminRewards)
}

func checkEmissionDistributionChangesFn(fn func()) {
	beforeEmissionDistributionBalance := emission.GetDistributedToStaker()
	fn()
	afterEmissionDistributionBalance := emission.GetDistributedToStaker()
	lastDistributedTimestamp := emission.GetLastExecutedTimestamp()
	ufmt.Printf("[INFO] Check emission distribution amount to staker (last distributed: %d)\n", lastDistributedTimestamp)
	ufmt.Printf("[INFO] Emission distribution balance changed: %d\n", afterEmissionDistributionBalance-beforeEmissionDistributionBalance)
}

// Output:
// [SCENARIO] 1. Initialize emission state and pool
// [INFO] Initializing emission state
// [INFO] Pool created: %s (tier: 1) gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000
//
// [SCENARIO] 2. Mint position and stake
// [INFO] Minting and staking position
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 170132354
// [EXPECTED] Amount0 should be 50000000
// [EXPECTED] Amount1 should be 50000000
//
// [SCENARIO] 3. Collect rewards before halt
// [INFO] Check emission distribution amount to staker (last distributed: 1234567900)
// [INFO] Emission distribution balance changed: 26755137
// [EXPECTED] total staker balance changes: 26755137
// [EXPECTED] total reward: 7946275
//
// [SCENARIO] 4. Set emission halt
// [INFO] Emission halt state set to true
//
// [SCENARIO] 5. Collect rewards after halt
//
// [SCENARIO] 6. Resume emission
// [INFO] Emission halt state set to false
//
// [SCENARIO] 7. Collect rewards after resume
// [INFO] Check emission distribution amount to staker (last distributed: 1234567910)
// [INFO] Emission distribution balance changed: 53510273
// [EXPECTED] total staker balance changes: 53510273
// [EXPECTED] total reward: 15892550

