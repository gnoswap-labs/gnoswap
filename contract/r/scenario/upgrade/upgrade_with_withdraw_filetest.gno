// upgrade with filetest
package main

import (
	"std"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	sr "gno.land/r/gnoswap/v1/staker"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/rbac"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/pool"
	"gno.land/r/gnoswap/v1/position"
	"gno.land/r/gnoswap/v1/router"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

var t *testing.T

const (
	INT64_MAX int64 = 9223372036854775807

	MIN_PRICE string = "4295128740"                                        // MIN_SQRT_RATIO + 1
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = std.NewUserRealm(adminAddr)

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = std.NewUserRealm(aliceAddr)

	// current distribution targets
	stakerAddr, _        = access.GetAddress(prbac.ROLE_STAKER.String())
	govStakerAddr, _     = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	devOpsAddr, _        = access.GetAddress(prbac.ROLE_DEVOPS.String())
	communityPoolAddr, _ = access.GetAddress(prbac.ROLE_COMMUNITY_POOL.String())
	poolAddr, _          = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _        = access.GetAddress(prbac.ROLE_ROUTER.String())

	// v2 contract paths
	commonV2PackagePath        = "gno.land/r/gnoswap/v2/common"
	communityPoolV2PackagePath = "gno.land/r/gnoswap/v2/community_pool"
	gnftV2PackagePath          = "gno.land/r/gnoswap/v2/gnft"
	govGovernanceV2PackagePath = "gno.land/r/gnoswap/v2/gov/governance"
	govStakerV2PackagePath     = "gno.land/r/gnoswap/v2/gov/staker"
	govXgnsV2PackagePath       = "gno.land/r/gnoswap/v2/gov/xgns"
	launchpadV2PackagePath     = "gno.land/r/gnoswap/v2/launchpad"
	poolV2PackagePath          = "gno.land/r/gnoswap/v2/pool"
	positionV2PackagePath      = "gno.land/r/gnoswap/v2/position"
	protocolFeeV2PackagePath   = "gno.land/r/gnoswap/v2/protocol_fee"
	routerV2PackagePath        = "gno.land/r/gnoswap/v2/router"
	stakerV2PackagePath        = "gno.land/r/gnoswap/v2/staker"

	// v2 contract addresses
	commonV2Addr        = std.DerivePkgAddr(commonV2PackagePath)
	communityPoolV2Addr = std.DerivePkgAddr(communityPoolV2PackagePath)
	gnftV2Addr          = std.DerivePkgAddr(gnftV2PackagePath)
	govGovernanceV2Addr = std.DerivePkgAddr(govGovernanceV2PackagePath)
	govStakerV2Addr     = std.DerivePkgAddr(govStakerV2PackagePath)
	govXgnsV2Addr       = std.DerivePkgAddr(govXgnsV2PackagePath)
	launchpadV2Addr     = std.DerivePkgAddr(launchpadV2PackagePath)
	poolV2Addr          = std.DerivePkgAddr(poolV2PackagePath)
	positionV2Addr      = std.DerivePkgAddr(positionV2PackagePath)
	protocolFeeV2Addr   = std.DerivePkgAddr(protocolFeeV2PackagePath)
	routerV2Addr        = std.DerivePkgAddr(routerV2PackagePath)
	stakerV2Addr        = std.DerivePkgAddr(stakerV2PackagePath)

	devOpsV2Addr = testutils.TestAddress("devops2")

	// paths
	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
)

func main() {
	println("[SCENARIO] 1. Initialize emission")
	initEmission()
	println()

	ufmt.Println("[SCENARIO] 2. Mint to distribution target (before upgrade)")
	mintAndDistribute()
	println()

	println("[SCENARIO] 2. Mint position")
	createPool()
	mintPosition()
	println()

	println("[SCENARIO] 3. Swap for fee distribution")
	swap()
	println()

	println("[SCENARIO] 3. Upgrade role addresses")
	updateRoleAddresses()
	println()

	println("[SCENARIO] 4. Mint to distribution target (after upgrade)")
	mintAndDistribute()
	println()

	println("[SCENARIO] 5. Withdraw of previous contract")
	testing.SkipHeights(1)
	withdrawCollectFee()
	println()
}

func initEmission() {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	emission.MintAndDistributeGns(cross)

	defaultTokenAmount := int64(10000000000)

	bar.Transfer(cross, aliceAddr, defaultTokenAmount)
	foo.Transfer(cross, aliceAddr, defaultTokenAmount)
}

func mintAndDistribute() {
	testing.SetRealm(adminRealm)

	// clear previous distribution
	emission.MintAndDistributeGns(cross)

	println("[INFO] current block height", std.ChainHeight())
	testing.SkipHeights(1)

	testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/emission"))

	previousStakerBalance := gns.BalanceOf(stakerAddr)
	previousGovStakerBalance := gns.BalanceOf(govStakerAddr)
	previousDevOpsBalance := gns.BalanceOf(devOpsAddr)
	previousCommunityPoolBalance := gns.BalanceOf(communityPoolAddr)

	previousNewStakerBalance := gns.BalanceOf(stakerV2Addr)
	previousNewGovStakerBalance := gns.BalanceOf(govStakerV2Addr)
	previousNewDevOpsBalance := gns.BalanceOf(devOpsV2Addr)
	previousNewCommunityPoolBalance := gns.BalanceOf(communityPoolV2Addr)

	emission.MintAndDistributeGns(cross)

	stakerBalanceChange := gns.BalanceOf(stakerAddr) - previousStakerBalance
	govStakerBalanceChange := gns.BalanceOf(govStakerAddr) - previousGovStakerBalance
	devOpsBalanceChange := gns.BalanceOf(devOpsAddr) - previousDevOpsBalance
	communityPoolBalanceChange := gns.BalanceOf(communityPoolAddr) - previousCommunityPoolBalance

	newStakerBalanceChange := gns.BalanceOf(stakerV2Addr) - previousNewStakerBalance
	newGovStakerBalanceChange := gns.BalanceOf(govStakerV2Addr) - previousNewGovStakerBalance
	newDevOpsBalanceChange := gns.BalanceOf(devOpsV2Addr) - previousNewDevOpsBalance
	newCommunityPoolBalanceChange := gns.BalanceOf(communityPoolV2Addr) - previousNewCommunityPoolBalance

	totalMintedAmount := gns.MintedEmissionAmount()

	ufmt.Printf("[EXPECTED] total minted amount should be %d\n", totalMintedAmount)
	ufmt.Printf("[EXPECTED] (v1) staker balance change should be %d\n", stakerBalanceChange)
	ufmt.Printf("[EXPECTED] (v1) gov staker balance change should be %d\n", govStakerBalanceChange)
	ufmt.Printf("[EXPECTED] (v1) dev ops balance change should be %d\n", devOpsBalanceChange)
	ufmt.Printf("[EXPECTED] (v1) community pool balance change should be %d\n", communityPoolBalanceChange)

	ufmt.Printf("[EXPECTED] (v2) staker balance change should be %d\n", newStakerBalanceChange)
	ufmt.Printf("[EXPECTED] (v2) gov staker balance change should be %d\n", newGovStakerBalanceChange)
	ufmt.Printf("[EXPECTED] (v2) dev ops balance change should be %d\n", newDevOpsBalanceChange)
	ufmt.Printf("[EXPECTED] (v2) community pool balance change should be %d\n", newCommunityPoolBalanceChange)
}

func createPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Creating pool")
	pool.CreatePool(
		cross,
		barPath,
		fooPath,
		uint32(3000),
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	poolPath := pool.GetPoolPath(barPath, fooPath, uint32(3000))
	ufmt.Printf("[INFO] Pool created: %s\n", poolPath)

	testing.SetRealm(adminRealm)

	tier1 := uint64(1)
	sr.SetPoolTier(cross, poolPath, tier1)
	ufmt.Printf("[INFO]  %s pool tier set: Tier%d\n", poolPath, tier1)
}

func mintPosition() {
	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting position")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		barPath,
		fooPath,
		uint32(3000),
		-960,
		960,
		"50000000",
		"50000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		aliceAddr,
		aliceAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
}

func swap() {
	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	testing.SetOriginSend(std.Coins{})
	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		barPath,
		fooPath,
		"10000000",
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000",
		"100",
		"1",
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	ufmt.Printf("[EXPECTED] AmountIn should be %s\n", amountIn)
	ufmt.Printf("[EXPECTED] AmountOut should be %s\n", amountOut)
}

func updateRoleAddresses() {
	testing.SetOriginCaller(adminAddr)

	previousCommunityPoolAddr, _ := access.GetAddress(prbac.ROLE_COMMUNITY_POOL.String())
	previousGovGovernanceAddr, _ := access.GetAddress(prbac.ROLE_GOVERNANCE.String())
	previousGovStakerAddr, _ := access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	previousGovXgnsAddr, _ := access.GetAddress(prbac.ROLE_XGNS.String())
	previousLaunchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	previousPoolAddr, _ := access.GetAddress(prbac.ROLE_POOL.String())
	previousPositionAddr, _ := access.GetAddress(prbac.ROLE_POSITION.String())
	previousProtocolFeeAddr, _ := access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	previousRouterAddr, _ := access.GetAddress(prbac.ROLE_ROUTER.String())
	previousStakerAddr, _ := access.GetAddress(prbac.ROLE_STAKER.String())
	previousDevOpsAddr, _ := access.GetAddress(prbac.ROLE_DEVOPS.String())

	rbac.UpdateRoleAddress(cross, prbac.ROLE_COMMUNITY_POOL.String(), communityPoolV2Addr)
	rbac.UpdateRoleAddress(cross, prbac.ROLE_GOVERNANCE.String(), govGovernanceV2Addr)
	rbac.UpdateRoleAddress(cross, prbac.ROLE_GOV_STAKER.String(), govStakerV2Addr)
	rbac.UpdateRoleAddress(cross, prbac.ROLE_XGNS.String(), govXgnsV2Addr)
	rbac.UpdateRoleAddress(cross, prbac.ROLE_LAUNCHPAD.String(), launchpadV2Addr)
	rbac.UpdateRoleAddress(cross, prbac.ROLE_POOL.String(), poolV2Addr)
	rbac.UpdateRoleAddress(cross, prbac.ROLE_POSITION.String(), positionV2Addr)
	rbac.UpdateRoleAddress(cross, prbac.ROLE_PROTOCOL_FEE.String(), protocolFeeV2Addr)
	rbac.UpdateRoleAddress(cross, prbac.ROLE_ROUTER.String(), routerV2Addr)
	rbac.UpdateRoleAddress(cross, prbac.ROLE_STAKER.String(), stakerV2Addr)
	rbac.UpdateRoleAddress(cross, prbac.ROLE_DEVOPS.String(), devOpsV2Addr)

	updatedCommunityPoolAddr, _ := access.GetAddress(prbac.ROLE_COMMUNITY_POOL.String())
	updatedGovGovernanceAddr, _ := access.GetAddress(prbac.ROLE_GOVERNANCE.String())
	updatedGovStakerAddr, _ := access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	updatedGovXgnsAddr, _ := access.GetAddress(prbac.ROLE_XGNS.String())
	updatedLaunchpadAddr, _ := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	updatedPoolAddr, _ := access.GetAddress(prbac.ROLE_POOL.String())
	updatedPositionAddr, _ := access.GetAddress(prbac.ROLE_POSITION.String())
	updatedProtocolFeeAddr, _ := access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	updatedRouterAddr, _ := access.GetAddress(prbac.ROLE_ROUTER.String())
	updatedStakerAddr, _ := access.GetAddress(prbac.ROLE_STAKER.String())
	updatedDevOpsAddr, _ := access.GetAddress(prbac.ROLE_DEVOPS.String())

	ufmt.Printf("[EXPECTED] community_pool should be changed %s to %s\n", previousCommunityPoolAddr, updatedCommunityPoolAddr)
	ufmt.Printf("[EXPECTED] gov_governance should be changed %s to %s\n", previousGovGovernanceAddr, updatedGovGovernanceAddr)
	ufmt.Printf("[EXPECTED] gov_staker should be changed %s to %s\n", previousGovStakerAddr, updatedGovStakerAddr)
	ufmt.Printf("[EXPECTED] gov_xgns should be changed %s to %s\n", previousGovXgnsAddr, updatedGovXgnsAddr)
	ufmt.Printf("[EXPECTED] launchpad should be changed %s to %s\n", previousLaunchpadAddr, updatedLaunchpadAddr)
	ufmt.Printf("[EXPECTED] pool should be changed %s to %s\n", previousPoolAddr, updatedPoolAddr)
	ufmt.Printf("[EXPECTED] position should be changed %s to %s\n", previousPositionAddr, updatedPositionAddr)
	ufmt.Printf("[EXPECTED] protocol_fee should be changed %s to %s\n", previousProtocolFeeAddr, updatedProtocolFeeAddr)
	ufmt.Printf("[EXPECTED] router should be changed %s to %s\n", previousRouterAddr, updatedRouterAddr)
	ufmt.Printf("[EXPECTED] staker should be changed %s to %s\n", previousStakerAddr, updatedStakerAddr)
	ufmt.Printf("[EXPECTED] dev ops should be changed %s to %s\n", previousDevOpsAddr, updatedDevOpsAddr)
}

func withdrawCollectFee() {
	testing.SetRealm(aliceRealm)

	position.CollectFee(cross, uint64(1), false)
}

// Output:
// [SCENARIO] 1. Initialize emission
//
// [SCENARIO] 2. Mint to distribution target (before upgrade)
// [INFO] current block height 124
// [EXPECTED] total minted amount should be 35673515
// [EXPECTED] (v1) staker balance change should be 26755136
// [EXPECTED] (v1) gov staker balance change should be 0
// [EXPECTED] (v1) dev ops balance change should be 7134703
// [EXPECTED] (v1) community pool balance change should be 1783675
// [EXPECTED] (new) staker balance change should be 0
// [EXPECTED] (new) gov staker balance change should be 0
// [EXPECTED] (new) dev ops balance change should be 0
// [EXPECTED] (new) community pool balance change should be 0
//
// [SCENARIO] 3. Change distribution target for upgrade
// [EXPECTED] staker address should be changed g1cceshmzzlmrh7rr3z30j2t5mrvsq9yccysw9nu to g1dejhw5m5v94k2ujpv3j8yh6lta047h6ly4ras8
// [EXPECTED] gov staker address should be changed g17e3ykyqk9jmqe2y9wxe9zhep3p7cw56davjqwa to g1dejhw3m0wefhgcttv4eyzerywf047h6ldvhvcq
// [EXPECTED] dev ops address should be changed g1mjvd83nnjee3z2g7683er55me9f09688pd4mj9 to g1dejhw3r9we8hqu6pv3j8yh6lta047h6lguneqv
// [EXPECTED] community pool address should be changed g100fnnlz5eh87p5hvwt8pf279lxaelm8k8md049 to g1dejhwsm0d4kh2mnfw3u4qmm0d3qkgerj7zt4z6
//
// [SCENARIO] 4. Mint to distribution target (after upgrade)
// [INFO] current block height 125
// [EXPECTED] total minted amount should be 71347030
// [EXPECTED] (v1) staker balance change should be 0
// [EXPECTED] (v1) gov staker balance change should be 0
// [EXPECTED] (v1) dev ops balance change should be 0
// [EXPECTED] (v1) community pool balance change should be 0
// [EXPECTED] (new) staker balance change should be 26755137
// [EXPECTED] (new) gov staker balance change should be 0
// [EXPECTED] (new) dev ops balance change should be 7134703
// [EXPECTED] (new) community pool balance change should be 1783675
