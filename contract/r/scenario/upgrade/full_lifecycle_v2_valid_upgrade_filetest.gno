// PKGPATH: gno.land/r/gnoswap/v1/main

// Full-lifecycle upgrade scenario across every upgradeable GnoSwap contract.
//
// Goal: drive every cross (crossing) entry point of the eight upgradeable
// contracts through a realistic, time-advancing transaction sequence, verify
// the observable state with the public getters after each step, upgrade all
// eight implementations to v2_valid, prove the v1-created data survives the
// upgrade byte-for-byte, and then re-run the same operations through v2_valid
// to prove the behaviour is unchanged.
//
// Upgradeable contracts (proxy -> implementation):
//
//	pool, position, router, staker, launchpad, protocol_fee,
//	gov/governance, gov/staker
//
// Entry points reached directly:
//
//	pool:          CreatePool, IncreaseObservationCardinalityNext, CollectProtocol,
//	               SetPoolCreationFee, SetWithdrawalFee, SetFeeProtocol, UpgradeImpl
//	position:      Mint, IncreaseLiquidity, DecreaseLiquidity, CollectFee,
//	               Reposition, UpgradeImpl
//	router:        ExactInSwapRoute, ExactInSingleSwapRoute, ExactOutSwapRoute,
//	               ExactOutSingleSwapRoute, SetSwapFee, UpgradeImpl
//	staker:        SetPoolTier, ChangePoolTier, RemovePoolTier, AddToken,
//	               RemoveToken, SetWarmUp, SetDepositGnsAmount,
//	               SetMinimumRewardAmount, SetTokenMinimumRewardAmount,
//	               SetUnStakingFee, CreateExternalIncentive, StakeToken,
//	               CollectReward, UnStakeToken, EndExternalIncentive,
//	               CollectExternalIncentivePenalty, UpgradeImpl
//	launchpad:     CreateProject, DepositGns, CollectRewardByDepositId,
//	               CollectDepositGns, CollectProtocolFee, CollectEmissionReward,
//	               CollectProtocolFeeReward, TransferLeftFromProjectByAdmin,
//	               UpgradeImpl
//	protocol_fee:  SetDevOpsPct, SetGovStakerPct, DistributeProtocolFeeByTokenPath,
//	               DistributeProtocolFee, UpgradeImpl
//	gov/governance ProposeText, ProposeCommunityPoolSpend, ProposeParameterChange,
//	               Vote, Execute, Cancel, Reconfigure, UpgradeImpl
//	gov/staker:    Delegate, Redelegate, Undelegate, CollectUndelegatedGns,
//	               CollectReward, CollectEmissionReward, CollectProtocolFeeReward,
//	               CleanStakerDelegationSnapshotByAdmin,
//	               SetUnDelegationLockupPeriodByAdmin, UpgradeImpl
//
// Entry points reached indirectly (they are role-gated and unreachable from an
// EOA, so they are covered through their only legitimate caller):
//
//	pool.Mint / Burn / Collect / HandleWithdrawalFee   <- position
//	pool.Swap                                          <- router
//	pool.SetSwapStartHook / SetSwapEndHook /
//	    SetTickCrossHook                               <- staker initializer
//	router.SwapCallback                                <- pool
//	position.SetPositionOperator                       <- staker (StakeToken)
//	protocol_fee.AddToProtocolFee                      <- pool / position / router / staker
//	gov/staker.SetAmountByProjectWallet                <- launchpad (DepositGns)
//	gov/staker.CollectRewardFromLaunchPad /
//	    CollectEmissionRewardFromLaunchPad /
//	    CollectProtocolFeeRewardFromLaunchPad          <- launchpad (project recipient)
//	*.RegisterInitializer                              <- each version's init()
package main

import (
	"math"
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"
	govGovernance "gno.land/r/gnoswap/gov/governance"
	govStaker "gno.land/r/gnoswap/gov/staker"
	"gno.land/r/gnoswap/launchpad"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	protocolFee "gno.land/r/gnoswap/protocol_fee"
	"gno.land/r/gnoswap/router"
	"gno.land/r/gnoswap/scenarioutils"
	"gno.land/r/gnoswap/staker"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/obl"

	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/gov/governance/v1"
	_ "gno.land/r/gnoswap/gov/staker/v1"
	_ "gno.land/r/gnoswap/launchpad/v1"
	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	_ "gno.land/r/gnoswap/gov/governance/v2_valid"
	_ "gno.land/r/gnoswap/gov/staker/v2_valid"
	_ "gno.land/r/gnoswap/launchpad/v2_valid"
	_ "gno.land/r/gnoswap/pool/v2_valid"
	_ "gno.land/r/gnoswap/position/v2_valid"
	_ "gno.land/r/gnoswap/protocol_fee/v2_valid"
	_ "gno.land/r/gnoswap/router/v2_valid"
	_ "gno.land/r/gnoswap/staker/v2_valid"
)

var t *testing.T

const (
	poolV1Path          = "gno.land/r/gnoswap/pool/v1"
	positionV1Path      = "gno.land/r/gnoswap/position/v1"
	routerV1Path        = "gno.land/r/gnoswap/router/v1"
	stakerV1Path        = "gno.land/r/gnoswap/staker/v1"
	launchpadV1Path     = "gno.land/r/gnoswap/launchpad/v1"
	protocolFeeV1Path   = "gno.land/r/gnoswap/protocol_fee/v1"
	governanceV1Path    = "gno.land/r/gnoswap/gov/governance/v1"
	govStakerV1Path     = "gno.land/r/gnoswap/gov/staker/v1"
	poolV2Path          = "gno.land/r/gnoswap/pool/v2_valid"
	positionV2Path      = "gno.land/r/gnoswap/position/v2_valid"
	routerV2Path        = "gno.land/r/gnoswap/router/v2_valid"
	stakerV2Path        = "gno.land/r/gnoswap/staker/v2_valid"
	launchpadV2Path     = "gno.land/r/gnoswap/launchpad/v2_valid"
	protocolFeeV2Path   = "gno.land/r/gnoswap/protocol_fee/v2_valid"
	governanceV2Path    = "gno.land/r/gnoswap/gov/governance/v2_valid"
	govStakerV2Path     = "gno.land/r/gnoswap/gov/staker/v2_valid"
	blockTimeSeconds    = int64(5)
	secondsPerDay       = int64(86400)
	incentiveDuration   = 90 * secondsPerDay
	incentiveReward     = int64(1_500_000_000)
	launchpadTierWaitID = int64(30)
)

var (
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)

	poolAddr      = access.MustGetAddress(prbac.ROLE_POOL.String())
	routerAddr    = access.MustGetAddress(prbac.ROLE_ROUTER.String())
	stakerAddr    = access.MustGetAddress(prbac.ROLE_STAKER.String())
	govStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	launchpadAddr = access.MustGetAddress(prbac.ROLE_LAUNCHPAD.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	projectAddr  = testutils.TestAddress("project-owner")
	projectRealm = testing.NewUserRealm(projectAddr)

	barPath = "gno.land/r/onbloc/bar.BAR"
	fooPath = "gno.land/r/onbloc/foo.FOO"
	gnsPath = "gno.land/r/gnoswap/gns.GNS"
	oblPath = "gno.land/r/onbloc/obl.OBL"

	fee500 = uint32(500)

	zeroAddress = address("")

	barFoo500PoolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500"
	barFooRoute       = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500"
	fooBarRoute       = "gno.land/r/onbloc/foo.FOO:gno.land/r/onbloc/bar.BAR:500"

	externalIncentiveId  string
	launchpadProjectId   string
	launchpadTier30Id    string
	launchpadDepositId   string
	textProposalId       int64
	spendProposalId      int64
	paramProposalId      int64
	aliceDelegatedAmount int64

	// snapshot captured right before the v2_valid upgrade
	snap upgradeSnapshot
)

// upgradeSnapshot holds the state observed through the public getters right
// before the upgrade. Every field must be identical after the upgrade: the KV
// store is shared across implementations, so a data-layout regression in the
// new implementation shows up here.
type upgradeSnapshot struct {
	poolLiquidity      string
	poolSqrtPriceX96   string
	poolTick           int32
	poolFeeGrowth0     string
	poolFeeGrowth1     string
	poolProtocolFee0   int64
	poolProtocolFee1   int64
	poolCreationFee    int64
	withdrawalFee      uint64
	swapFee            uint64
	positionCount      int
	positionLiquidity  string
	positionTickLower  int32
	positionTickUpper  int32
	positionOwner      address
	positionOperator   address
	positionFeeGrowth0 string
	positionFeeGrowth1 string
	positionOwed0      int64
	positionOwed1      int64
	positionUnclaimed0 string
	positionUnclaimed1 string
	positionBurned     bool
	positionInRange    bool
	stakerPoolTier     uint64
	stakerPoolTierRat  uint64
	stakerUnstakingFee uint64
	stakerDepositGns   int64
	stakerAllowedToken int
	stakerAllowedList  []string
	depositLiquidity   string
	depositStakeTime   int64
	depositTickLower   int32
	depositTickUpper   int32
	depositWarmupCount int
	depositWarmups     []staker.Warmup
	depositCollected   int64
	totalEmissionSent  int64
	incentiveTotal     int64
	incentiveDistrib   int64
	incentiveRefunded  bool
	devOpsPct          int64
	govStakerPct       int64
	accuGovStakerBar   int64
	accuDevOpsBar      int64
	reservedTokens     []string
	totalDelegated     int64
	totalXGnsSupply    int64
	totalLocked        int64
	delegationCount    int
	delegationIDs      []int64
	proposalCount      int
	proposalIDs        []int64
	paramProposalYea   int64
	paramProposalNay   int64
	paramProposalState string
	spendProposalState string
	textProposalState  string
	adminVoteWeight    int64
	configVersion      int64
	configVotingPeriod int64
	projectCount       int
	projectActive      bool
	projectRecipient   address
	projectTier30Total int64
	launchpadDeposits  int64
	launchpadDepositID int64
	depositAmount      int64
}

func main(cur realm) {
	println("[SCENARIO] 1. Activate v1 implementations for every upgradeable contract")
	activateV1Implementations(cur)
	println()

	println("[SCENARIO] 2. Bootstrap emission and the canonical GNS/WUGNOT pool")
	bootstrapEmission(cur)
	println()

	println("[SCENARIO] 3. Configure protocol parameters through the admin setters")
	configureProtocolParameters(cur)
	println()

	println("[SCENARIO] 4. Create the BAR/FOO pool and grow its observation cardinality")
	createTargetPool(cur)
	println()

	println("[SCENARIO] 5. Position lifecycle: mint, increase, decrease, collect fee")
	positionLifecycle(cur)
	println()

	println("[SCENARIO] 6. Router: exact-in / exact-out, single and multi-hop")
	routerSwaps(cur)
	println()

	println("[SCENARIO] 7. Collect position fees generated by the swaps")
	collectPositionFee(cur, 1)
	println()

	println("[SCENARIO] 8. Reposition the second position into a new tick range")
	repositionPosition(cur, 2)
	println()

	println("[SCENARIO] 9. Staker: tier setup, external incentive, stake position 1")
	stakerSetup(cur)
	println()

	println("[SCENARIO] 10. Accumulate 10 days of rewards and collect them")
	accumulateAndCollectStakingReward(cur)
	println()

	println("[SCENARIO] 11. Protocol fee distribution to devops / gov staker")
	distributeProtocolFee(cur)
	println()

	println("[SCENARIO] 12. Gov staker: delegate, redelegate, undelegate, collect")
	govStakerLifecycle(cur)
	println()

	println("[SCENARIO] 13. Governance: propose, vote, execute, cancel, reconfigure")
	governanceLifecycle(cur)
	println()

	println("[SCENARIO] 14. Launchpad: project, deposit, reward collection")
	launchpadLifecycle(cur)
	println()

	println("[SCENARIO] 15. Capture the pre-upgrade snapshot through the getters")
	snap = captureSnapshot()
	printSnapshot(snap)
	println()

	println("[SCENARIO] 16. Upgrade all eight implementations to v2_valid")
	upgradeAllToV2Valid(cur)
	println()

	println("[SCENARIO] 17. Validate that every v1 value survived the upgrade")
	validateSnapshotUnchanged()
	println()

	println("[SCENARIO] 18. Re-run the same operations through v2_valid")
	rerunAfterUpgrade(cur)
	println()

	println("[SCENARIO] 19. Wind down: end incentive, unstake, remove tier")
	windDown(cur)
	println()

	println("[SCENARIO] 20. Final invariants")
	finalInvariants(cur)
	println()
}

// ---------------------------------------------------------------------------
// 1. implementation activation
// ---------------------------------------------------------------------------

func activateV1Implementations(cur realm) {
	testing.SetRealm(adminRealm)

	protocolFee.UpgradeImpl(cross(cur), protocolFeeV1Path)
	pool.UpgradeImpl(cross(cur), poolV1Path)
	position.UpgradeImpl(cross(cur), positionV1Path)
	router.UpgradeImpl(cross(cur), routerV1Path)
	staker.UpgradeImpl(cross(cur), stakerV1Path)
	launchpad.UpgradeImpl(cross(cur), launchpadV1Path)
	govStaker.UpgradeImpl(cross(cur), govStakerV1Path)
	govGovernance.UpgradeImpl(cross(cur), governanceV1Path)

	printImplementations()

	uassert.Equal(t, poolV1Path, pool.GetImplementationPackagePath())
	uassert.Equal(t, positionV1Path, position.GetImplementationPackagePath())
	uassert.Equal(t, routerV1Path, router.GetImplementationPackagePath())
	uassert.Equal(t, stakerV1Path, staker.GetImplementationPackagePath())
	uassert.Equal(t, launchpadV1Path, launchpad.GetImplementationPackagePath())
	uassert.Equal(t, protocolFeeV1Path, protocolFee.GetImplementationPackagePath())
	uassert.Equal(t, governanceV1Path, govGovernance.GetImplementationPackagePath())
	uassert.Equal(t, govStakerV1Path, govStaker.GetImplementationPackagePath())
}

func printImplementations() {
	println("[EXPECTED] pool impl:", pool.GetImplementationPackagePath())
	println("[EXPECTED] position impl:", position.GetImplementationPackagePath())
	println("[EXPECTED] router impl:", router.GetImplementationPackagePath())
	println("[EXPECTED] staker impl:", staker.GetImplementationPackagePath())
	println("[EXPECTED] launchpad impl:", launchpad.GetImplementationPackagePath())
	println("[EXPECTED] protocol_fee impl:", protocolFee.GetImplementationPackagePath())
	println("[EXPECTED] governance impl:", govGovernance.GetImplementationPackagePath())
	println("[EXPECTED] gov staker impl:", govStaker.GetImplementationPackagePath())
}

// ---------------------------------------------------------------------------
// 2. emission bootstrap
// ---------------------------------------------------------------------------

func bootstrapEmission(cur realm) {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross(cur), 0)
	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))

	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+blockTimeSeconds)
	testing.SkipHeights(1)

	println("[EXPECTED] canonical pool exists:", pool.ExistsPoolPath("gno.land/r/gnoland/wugnot.wugnot:gno.land/r/gnoswap/gns.GNS:3000"))
	println("[EXPECTED] pool count:", pool.GetPools().Size())
}

// ---------------------------------------------------------------------------
// 3. protocol parameters
// ---------------------------------------------------------------------------

func configureProtocolParameters(cur realm) {
	testing.SetRealm(adminRealm)

	// pool
	pool.SetPoolCreationFee(cross(cur), 100_000_000)
	pool.SetWithdrawalFee(cross(cur), 100) // 1%
	println("[EXPECTED] pool creation fee:", pool.GetPoolCreationFee())
	println("[EXPECTED] withdrawal fee bps:", pool.GetWithdrawalFee())

	// router
	router.SetSwapFee(cross(cur), 100) // 1%
	println("[EXPECTED] router swap fee bps:", router.GetSwapFee())

	// protocol fee split
	protocolFee.SetDevOpsPct(cross(cur), 4000) // 40%
	protocolFee.SetGovStakerPct(cross(cur), 6000)
	println("[EXPECTED] devops pct:", protocolFee.GetDevOpsPct())
	println("[EXPECTED] gov staker pct:", protocolFee.GetGovStakerPct())

	// staker
	staker.SetUnStakingFee(cross(cur), 100) // 1%
	staker.SetDepositGnsAmount(cross(cur), 1_000_000_000)
	staker.SetMinimumRewardAmount(cross(cur), 1_000_000_000)
	staker.SetTokenMinimumRewardAmount(cross(cur), ufmt.Sprintf("%s:%d", barPath, int64(1_000_000)))
	staker.AddToken(cross(cur), barPath)
	println("[EXPECTED] unstaking fee bps:", staker.GetUnstakingFee())
	println("[EXPECTED] deposit gns amount:", staker.GetDepositGnsAmount())
	println("[EXPECTED] minimum reward amount:", staker.GetMinimumRewardAmount())
	barMinimum, barMinimumFound := staker.GetSpecificTokenMinimumRewardAmount(barPath)
	println("[EXPECTED] bar minimum reward amount:", barMinimum, "found:", barMinimumFound)
	println("[EXPECTED] allowed token count:", len(staker.GetAllowedTokens()))
	println("[EXPECTED] warmup tiers:", len(staker.GetWarmupTemplate()))

	// gov staker
	govStaker.SetUnDelegationLockupPeriodByAdmin(cross(cur), 100)
	println("[EXPECTED] undelegation lockup period:", govStaker.GetUnDelegationLockupPeriod())

	uassert.Equal(t, int64(100_000_000), pool.GetPoolCreationFee())
	uassert.Equal(t, uint64(100), pool.GetWithdrawalFee())
	uassert.Equal(t, uint64(100), router.GetSwapFee())
	uassert.Equal(t, int64(4000), protocolFee.GetDevOpsPct())
	uassert.Equal(t, int64(6000), protocolFee.GetGovStakerPct())
	uassert.Equal(t, uint64(100), staker.GetUnstakingFee())
	uassert.Equal(t, int64(100), govStaker.GetUnDelegationLockupPeriod())
}

// ---------------------------------------------------------------------------
// 4. pool creation
// ---------------------------------------------------------------------------

func createTargetPool(cur realm) {
	testing.SetRealm(adminRealm)

	// The 100 GNS creation fee is routed to the protocol fee contract, which
	// exercises protocol_fee.AddToProtocolFee through the pool implementation.
	beforeGnsAccu := protocolFee.GetAccuTransferToGovStakerByTokenPath(gnsPath) +
		protocolFee.GetAccuTransferToDevOpsByTokenPath(gnsPath)

	gns.Approve(cross(cur), poolAddr, math.MaxInt64)
	pool.CreatePool(cross(cur), barPath, fooPath, fee500, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	testing.SkipHeights(1)

	afterGnsAccu := protocolFee.GetAccuTransferToGovStakerByTokenPath(gnsPath) +
		protocolFee.GetAccuTransferToDevOpsByTokenPath(gnsPath)

	println("[EXPECTED] created pool:", pool.GetPoolPath(barPath, fooPath, fee500))
	println("[EXPECTED] pool exists:", pool.ExistsPoolPath(barFoo500PoolPath))
	token0, err := pool.GetToken0Path(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	token1, err := pool.GetToken1Path(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	poolFee, err := pool.GetFee(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	tickSpacing, err := pool.GetTickSpacing(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	slot0Tick, err := pool.GetSlot0Tick(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	slot0SqrtPriceX96, err := pool.GetSlot0SqrtPriceX96(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	slot0Unlocked, err := pool.GetSlot0Unlocked(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] token0:", token0)
	println("[EXPECTED] token1:", token1)
	println("[EXPECTED] fee:", poolFee)
	println("[EXPECTED] tick spacing:", tickSpacing)
	println("[EXPECTED] slot0 tick:", slot0Tick)
	println("[EXPECTED] slot0 sqrtPriceX96:", slot0SqrtPriceX96)
	println("[EXPECTED] slot0 unlocked:", slot0Unlocked)
	println("[EXPECTED] creation fee accrued to protocol fee:", afterGnsAccu-beforeGnsAccu)

	// protocol fee split for token0/token1 is exercised by the swaps below.
	testing.SetRealm(adminRealm)
	pool.SetFeeProtocol(cross(cur), 4, 4)
	feeProtocol, err := pool.GetSlot0FeeProtocol(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] slot0 fee protocol:", feeProtocol)

	pool.IncreaseObservationCardinalityNext(cross(cur), barPath, fooPath, fee500, 10)
	observation, err := pool.GetObservationState(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] observation cardinality next:", observation.CardinalityNext())

	uassert.Equal(t, int64(100_000_000), afterGnsAccu-beforeGnsAccu)
	uassert.Equal(t, uint8(68), feeProtocol) // 4 + 4<<4
	uassert.True(t, pool.ExistsPoolPath(barFoo500PoolPath))

	// keep the remaining pools free to create
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross(cur), 0)
}

// ---------------------------------------------------------------------------
// 5. position lifecycle
// ---------------------------------------------------------------------------

func positionLifecycle(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), poolAddr, math.MaxInt64)
	foo.Approve(cross(cur), poolAddr, math.MaxInt64)

	positionId, liquidity, amount0, amount1 := position.Mint(
		cross(cur), barPath, fooPath, fee500, -960, 960,
		"50000000", "50000000", "0", "0", time.Now().Unix()+3600, adminAddr, "",
	)
	testing.SkipHeights(1)
	println("[EXPECTED] minted position:", positionId, "liquidity:", liquidity, "amount0:", amount0, "amount1:", amount1)
	positionOwner, err := position.GetPositionOwner(positionId)
	if err != nil {
		panic(err)
	}
	positionPoolKey, err := position.GetPositionPoolKey(positionId)
	if err != nil {
		panic(err)
	}
	positionTickLower, err := position.GetPositionTickLower(positionId)
	if err != nil {
		panic(err)
	}
	positionTickUpper, err := position.GetPositionTickUpper(positionId)
	if err != nil {
		panic(err)
	}
	positionInRange, err := position.IsInRange(positionId)
	if err != nil {
		panic(err)
	}
	positionBurned, err := position.IsBurned(positionId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] position owner:", positionOwner)
	println("[EXPECTED] position pool key:", positionPoolKey)
	println("[EXPECTED] position ticks:", positionTickLower, positionTickUpper)
	println("[EXPECTED] position in range:", positionInRange)
	println("[EXPECTED] position burned:", positionBurned)

	// second position with a wider range, used for Reposition later
	secondId, secondLiquidity, _, _ := position.Mint(
		cross(cur), barPath, fooPath, fee500, -1920, 1920,
		"30000000", "30000000", "0", "0", time.Now().Unix()+3600, adminAddr, "",
	)
	testing.SkipHeights(1)
	println("[EXPECTED] minted position:", secondId, "liquidity:", secondLiquidity)

	// increase liquidity on position 1
	_, increasedLiquidity, increased0, increased1, _ := position.IncreaseLiquidity(
		cross(cur), positionId, "10000000", "10000000", "0", "0", time.Now().Unix()+3600,
	)
	testing.SkipHeights(1)
	println("[EXPECTED] increased liquidity:", increasedLiquidity, "amount0:", increased0, "amount1:", increased1)
	positionLiquidity, err := position.GetPositionLiquidity(positionId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] position liquidity now:", positionLiquidity)

	// Trade both ways so the position actually accrues swap fees. Without this
	// the DecreaseLiquidity below would collect a zero fee and the withdrawal
	// fee it charges would be invisible.
	swapBothWays(cur)

	// DecreaseLiquidity collects the accrued fees first, so the gross fee is
	// what the position holds right before the call.
	grossFee0, grossFee1, err := position.GetUnclaimedFee(positionId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] fees accrued before decrease (gross):", grossFee0, grossFee1)

	// decrease half of the liquidity; the withdrawal fee is routed to protocol fee
	decreaseAmount, err := position.GetPositionLiquidity(positionId)
	if err != nil {
		panic(err)
	}
	beforeBarAccu := protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath) +
		protocolFee.GetAccuTransferToDevOpsByTokenPath(barPath)
	beforeFooAccu := protocolFee.GetAccuTransferToGovStakerByTokenPath(fooPath) +
		protocolFee.GetAccuTransferToDevOpsByTokenPath(fooPath)

	// returns: positionId, liquidity, fee0, fee1, amount0, amount1, poolPath
	_, removedLiquidity, fee0, fee1, removed0, removed1, removedPoolPath := position.DecreaseLiquidity(
		cross(cur), positionId, halfOf(decreaseAmount), "0", "0", time.Now().Unix()+3600,
	)
	testing.SkipHeights(1)

	afterBarAccu := protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath) +
		protocolFee.GetAccuTransferToDevOpsByTokenPath(barPath)
	afterFooAccu := protocolFee.GetAccuTransferToGovStakerByTokenPath(fooPath) +
		protocolFee.GetAccuTransferToDevOpsByTokenPath(fooPath)

	withdrawalFee0 := afterBarAccu - beforeBarAccu
	withdrawalFee1 := afterFooAccu - beforeFooAccu

	println("[EXPECTED] removed liquidity:", removedLiquidity, "from pool:", removedPoolPath)
	println("[EXPECTED] principal returned:", removed0, removed1)
	println("[EXPECTED] fees returned with the principal (net):", fee0, fee1)
	println("[EXPECTED] withdrawal fee accrued (BAR / FOO):", withdrawalFee0, withdrawalFee1)
	positionLiquidityAfterDecrease, err := position.GetPositionLiquidity(positionId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] position liquidity after decrease:", positionLiquidityAfterDecrease)
	println("[EXPECTED] position count:", position.GetPositions().Size())

	// withdrawal fee is withdrawalFeeBPS of the gross fee, and the caller keeps
	// the rest; the principal is not charged
	expectedWithdrawalFee0 := parseInt64(grossFee0) * int64(pool.GetWithdrawalFee()) / 10000
	expectedWithdrawalFee1 := parseInt64(grossFee1) * int64(pool.GetWithdrawalFee()) / 10000
	println("[EXPECTED] withdrawal fee expected from the gross fee:", expectedWithdrawalFee0, expectedWithdrawalFee1)

	uassert.True(t, parseInt64(grossFee0) > 0)
	uassert.True(t, parseInt64(grossFee1) > 0)
	uassert.Equal(t, expectedWithdrawalFee0, withdrawalFee0)
	uassert.Equal(t, expectedWithdrawalFee1, withdrawalFee1)
	uassert.Equal(t, parseInt64(grossFee0)-expectedWithdrawalFee0, parseInt64(fee0))
	uassert.Equal(t, parseInt64(grossFee1)-expectedWithdrawalFee1, parseInt64(fee1))

	positionOwner, err = position.GetPositionOwner(positionId)
	if err != nil {
		panic(err)
	}
	positionPoolKey, err = position.GetPositionPoolKey(positionId)
	if err != nil {
		panic(err)
	}
	positionInRange, err = position.IsInRange(positionId)
	if err != nil {
		panic(err)
	}
	positionBurned, err = position.IsBurned(positionId)
	if err != nil {
		panic(err)
	}
	uassert.Equal(t, adminAddr, positionOwner)
	uassert.Equal(t, barFoo500PoolPath, positionPoolKey)
	uassert.True(t, positionInRange)
	uassert.False(t, positionBurned)
	uassert.Equal(t, 2, position.GetPositions().Size())
}

// swapBothWays trades a small amount in each direction so both sides of the
// position accrue swap fees while the price ends up back inside the range.
func swapBothWays(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), routerAddr, math.MaxInt64)
	foo.Approve(cross(cur), routerAddr, math.MaxInt64)
	bar.Approve(cross(cur), poolAddr, math.MaxInt64)
	foo.Approve(cross(cur), poolAddr, math.MaxInt64)

	inBar, outFoo := router.ExactInSingleSwapRoute(
		cross(cur), barPath, fooPath, "2000000", barFooRoute, "1", "0", time.Now().Unix()+3600, "",
	)
	testing.SkipHeights(1)
	inFoo, outBar := router.ExactInSingleSwapRoute(
		cross(cur), fooPath, barPath, "2000000", fooBarRoute, "1", "0", time.Now().Unix()+3600, "",
	)
	testing.SkipHeights(1)

	println("[EXPECTED] fee-accrual swap bar->foo in/out:", inBar, outFoo)
	println("[EXPECTED] fee-accrual swap foo->bar in/out:", inFoo, outBar)
	poolTick, err := pool.GetSlot0Tick(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] pool tick after the fee-accrual swaps:", poolTick)
}

// parseInt64 parses a decimal amount string; every value it is used on is
// produced by the contracts themselves and fits into int64.
func parseInt64(value string) int64 {
	parsed, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		panic(err)
	}
	return parsed
}

// halfOf divides a decimal string by two. The liquidity values used here always
// fit into int64, so a plain parse is enough.
func halfOf(value string) string {
	return strconv.FormatInt(parseInt64(value)/2, 10)
}

// ---------------------------------------------------------------------------
// 6. router swaps
// ---------------------------------------------------------------------------

func routerSwaps(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), routerAddr, math.MaxInt64)
	foo.Approve(cross(cur), routerAddr, math.MaxInt64)
	bar.Approve(cross(cur), poolAddr, math.MaxInt64)
	foo.Approve(cross(cur), poolAddr, math.MaxInt64)

	in1, out1 := router.ExactInSingleSwapRoute(
		cross(cur), barPath, fooPath, "1000000", barFooRoute, "1", "0", time.Now().Unix()+3600, "",
	)
	testing.SkipHeights(1)
	println("[EXPECTED] exact-in-single in/out:", in1, out1)

	in2, out2 := router.ExactInSwapRoute(
		cross(cur), fooPath, barPath, "1000000", fooBarRoute, "100", "1", time.Now().Unix()+3600, "",
	)
	testing.SkipHeights(1)
	println("[EXPECTED] exact-in in/out:", in2, out2)

	in3, out3 := router.ExactOutSingleSwapRoute(
		cross(cur), barPath, fooPath, "500000", barFooRoute, "10000000", "0", time.Now().Unix()+3600, "",
	)
	testing.SkipHeights(1)
	println("[EXPECTED] exact-out-single in/out:", in3, out3)

	in4, out4 := router.ExactOutSwapRoute(
		cross(cur), fooPath, barPath, "500000", fooBarRoute, "100", "10000000", time.Now().Unix()+3600, "",
	)
	testing.SkipHeights(1)
	println("[EXPECTED] exact-out in/out:", in4, out4)

	poolTick, err := pool.GetSlot0Tick(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	poolLiquidity, err := pool.GetLiquidity(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	feeGrowth0, feeGrowth1, err := pool.GetFeeGrowthGlobalX128(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] pool tick after swaps:", poolTick)
	println("[EXPECTED] pool liquidity:", poolLiquidity)
	println("[EXPECTED] fee growth global:", feeGrowth0, feeGrowth1)
	protocolFee0, protocolFee1, err := pool.GetProtocolFeesTokens(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] pool protocol fees:", protocolFee0, protocolFee1)
	println("[EXPECTED] router fee accrued (FOO):", protocolFee.GetAccuTransferToGovStakerByTokenPath(fooPath)+
		protocolFee.GetAccuTransferToDevOpsByTokenPath(fooPath))

	uassert.True(t, protocolFee0 > 0)
	uassert.True(t, protocolFee1 > 0)
}

// ---------------------------------------------------------------------------
// 7-8. fee collection and reposition
// ---------------------------------------------------------------------------

func collectPositionFee(cur realm, positionId uint64) {
	testing.SetRealm(adminRealm)

	unclaimed0, unclaimed1, err := position.GetUnclaimedFee(positionId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] unclaimed fee before collect:", unclaimed0, unclaimed1)

	_, collected0, collected1, poolPath, token0, token1 := position.CollectFee(cross(cur), positionId)
	testing.SkipHeights(1)
	println("[EXPECTED] collected fee:", collected0, collected1, "pool:", poolPath)
	println("[EXPECTED] fee tokens:", token0, token1)

	after0, after1, err := position.GetUnclaimedFee(positionId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] unclaimed fee after collect:", after0, after1)

	uassert.Equal(t, barFoo500PoolPath, poolPath)
}

func repositionPosition(cur realm, positionId uint64) {
	testing.SetRealm(adminRealm)

	liquidity, err := position.GetPositionLiquidity(positionId)
	if err != nil {
		panic(err)
	}
	_, _, _, _, _, _, _ = position.DecreaseLiquidity(
		cross(cur), positionId, liquidity, "0", "0", time.Now().Unix()+3600,
	)
	testing.SkipHeights(1)
	positionLiquidity, err := position.GetPositionLiquidity(positionId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] liquidity before reposition:", positionLiquidity)

	_, newLiquidity, tickLower, tickUpper, used0, used1 := position.Reposition(
		cross(cur), positionId, -600, 600, "20000000", "20000000", "0", "0", time.Now().Unix()+3600,
	)
	testing.SkipHeights(1)
	println("[EXPECTED] repositioned liquidity:", newLiquidity, "ticks:", tickLower, tickUpper)
	println("[EXPECTED] amounts used:", used0, used1)
	positionTickLower, err := position.GetPositionTickLower(positionId)
	if err != nil {
		panic(err)
	}
	positionTickUpper, err := position.GetPositionTickUpper(positionId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] position ticks from getter:", positionTickLower, positionTickUpper)

	uassert.Equal(t, int32(-600), positionTickLower)
	uassert.Equal(t, int32(600), positionTickUpper)
}

// ---------------------------------------------------------------------------
// 9-10. staker
// ---------------------------------------------------------------------------

func stakerSetup(cur realm) {
	testing.SetRealm(adminRealm)

	staker.SetPoolTier(cross(cur), barFoo500PoolPath, 2)
	println("[EXPECTED] pool tier after SetPoolTier:", staker.GetPoolTier(barFoo500PoolPath))
	staker.ChangePoolTier(cross(cur), barFoo500PoolPath, 1)
	println("[EXPECTED] pool tier after ChangePoolTier:", staker.GetPoolTier(barFoo500PoolPath))
	println("[EXPECTED] tier1 pool count:", staker.GetPoolTierCount(1))

	// external incentive funded with GNS
	gns.Approve(cross(cur), stakerAddr, math.MaxInt64)
	createTimestamp := time.Now().Unix()
	startTime := ((createTimestamp / secondsPerDay) + 2) * secondsPerDay
	endTime := startTime + incentiveDuration
	externalIncentiveId = ufmt.Sprintf("%s:%d:%d", adminAddr.String(), createTimestamp, 1)

	staker.CreateExternalIncentive(cross(cur), barFoo500PoolPath, gnsPath, incentiveReward, startTime, endTime)
	testing.SkipHeights(1)

	incentiveRewardToken, err := staker.GetIncentiveRewardToken(barFoo500PoolPath, externalIncentiveId)
	if err != nil {
		panic(err)
	}
	incentiveTotalReward, err := staker.GetIncentiveTotalRewardAmount(barFoo500PoolPath, externalIncentiveId)
	if err != nil {
		panic(err)
	}
	incentiveCreator, err := staker.GetIncentiveCreator(barFoo500PoolPath, externalIncentiveId)
	if err != nil {
		panic(err)
	}
	incentiveDepositGns, err := staker.GetIncentiveDepositGnsAmount(barFoo500PoolPath, externalIncentiveId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] incentive id:", externalIncentiveId)
	println("[EXPECTED] incentive reward token:", incentiveRewardToken)
	println("[EXPECTED] incentive total reward:", incentiveTotalReward)
	println("[EXPECTED] incentive creator:", incentiveCreator)
	println("[EXPECTED] incentive deposit gns:", incentiveDepositGns)

	// stake position 1; staker takes NFT custody and becomes the position operator
	gnft.Approve(cross(cur), stakerAddr, grc721.TokenID("1"))
	lpTokenId := staker.StakeToken(cross(cur), 1, "")
	testing.SkipHeights(1)

	depositOwner, err := staker.GetDepositOwner(1)
	if err != nil {
		panic(err)
	}
	depositLiquidity, err := staker.GetDepositLiquidityAsString(1)
	if err != nil {
		panic(err)
	}
	depositTargetPool, err := staker.GetDepositTargetPoolPath(1)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] staked position 1 into:", lpTokenId)
	println("[EXPECTED] is staked:", staker.IsStaked(1))
	println("[EXPECTED] deposit owner:", depositOwner)
	println("[EXPECTED] deposit liquidity:", depositLiquidity)
	println("[EXPECTED] deposit target pool:", depositTargetPool)
	// StakeToken routes position.SetPositionOperator (staker-only entry point)
	// and records the staking caller as the position operator.
	positionOperator, err := position.GetPositionOperator(1)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] position operator after stake is the staker caller:", positionOperator == adminAddr)
	poolStakedLiquidity, err := staker.GetPoolStakedLiquidity(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] pool staked liquidity:", poolStakedLiquidity)

	uassert.Equal(t, uint64(1), staker.GetPoolTier(barFoo500PoolPath))
	uassert.True(t, staker.IsStaked(1))
	uassert.Equal(t, adminAddr, depositOwner)
	uassert.Equal(t, adminAddr, positionOperator)
	uassert.Equal(t, incentiveReward, incentiveTotalReward)
}

func accumulateAndCollectStakingReward(cur realm) {
	// 10 days: the first warm-up tier ends after 5 days, so the collected
	// amount reflects two different warm-up ratios.
	testing.SkipHeights(10 * secondsPerDay / blockTimeSeconds)

	collectableEmission, err := staker.CollectableEmissionReward(1)
	if err != nil {
		panic(err)
	}
	collectableExternal, err := staker.CollectableExternalIncentiveReward(1, externalIncentiveId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] collectable emission reward:", collectableEmission)
	println("[EXPECTED] collectable external reward:", collectableExternal)

	testing.SetRealm(adminRealm)
	rewardToUser, rewardPenalty, externalToUser, externalPenalty := staker.CollectReward(cross(cur), 1)
	testing.SkipHeights(1)

	println("[EXPECTED] internal reward to user:", rewardToUser, "penalty:", rewardPenalty)
	for tokenPath, amount := range externalToUser {
		println("[EXPECTED] external reward to user:", tokenPath, amount)
	}
	for tokenPath, amount := range externalPenalty {
		println("[EXPECTED] external reward penalty:", tokenPath, amount)
	}
	collectedInternalReward, err := staker.GetDepositCollectedInternalReward(1)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] collected internal reward total:", collectedInternalReward)
	println("[EXPECTED] total emission sent:", staker.GetTotalEmissionSent())

	toUser, _ := strconv.ParseInt(rewardToUser, 10, 64)
	penalty, _ := strconv.ParseInt(rewardPenalty, 10, 64)
	uassert.True(t, toUser > 0)
	uassert.True(t, penalty > 0)
	// the collected-reward ledger also accounts for the penalty share and for
	// the block mined between the getter read and the collect transaction
	uassert.True(t, collectedInternalReward >= toUser)
}

// ---------------------------------------------------------------------------
// 11. protocol fee
// ---------------------------------------------------------------------------

func distributeProtocolFee(cur realm) {
	testing.SetRealm(adminRealm)

	accuGovStakerBar := protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath)
	accuDevOpsBar := protocolFee.GetAccuTransferToDevOpsByTokenPath(barPath)
	println("[EXPECTED] accumulated BAR (gov staker / devops):", accuGovStakerBar, accuDevOpsBar)

	protocolFee.DistributeProtocolFeeByTokenPath(cross(cur), barPath)
	testing.SkipHeights(1)
	println("[EXPECTED] distributed BAR to gov staker:", protocolFee.GetActualDistributedToGovStakerByTokenPath(barPath))
	println("[EXPECTED] distributed BAR to devops:", protocolFee.GetActualDistributedToDevOpsByTokenPath(barPath))

	protocolFee.DistributeProtocolFee(cross(cur))
	testing.SkipHeights(1)
	println("[EXPECTED] reserved token count:", len(protocolFee.GetReservedTokens()))
	println("[EXPECTED] distributed FOO to gov staker:", protocolFee.GetActualDistributedToGovStakerByTokenPath(fooPath))
	println("[EXPECTED] distributed GNS to gov staker:", protocolFee.GetActualDistributedToGovStakerByTokenPath(gnsPath))

	// 40 / 60 split must hold for every distributed token
	distributedGovStaker := protocolFee.GetActualDistributedToGovStakerByTokenPath(barPath)
	distributedDevOps := protocolFee.GetActualDistributedToDevOpsByTokenPath(barPath)
	uassert.Equal(t, accuGovStakerBar, distributedGovStaker)
	uassert.Equal(t, accuDevOpsBar, distributedDevOps)
}

// ---------------------------------------------------------------------------
// 12. gov staker
// ---------------------------------------------------------------------------

func govStakerLifecycle(cur realm) {
	// alice delegates to admin
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), aliceAddr, 5_000_000_000)

	testing.SetRealm(aliceRealm)
	gns.Approve(cross(cur), govStakerAddr, 5_000_000_000)
	// Delegate returns the delegated amount, not a delegation id
	aliceDelegatedAmount = govStaker.Delegate(cross(cur), adminAddr, 2_000_000_000, "")
	testing.SkipHeights(1)
	println("[EXPECTED] alice delegated amount:", aliceDelegatedAmount)
	println("[EXPECTED] total delegated:", govStaker.GetTotalDelegated())
	println("[EXPECTED] total xGNS supply:", govStaker.GetTotalxGnsSupply())
	println("[EXPECTED] delegation count:", govStaker.GetDelegations().Size())

	// admin delegates to itself; needed later to pass the proposal threshold
	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), govStakerAddr, 5_000_000_000)
	adminDelegatedAmount := govStaker.Delegate(cross(cur), adminAddr, 5_000_000_000, "")
	testing.SkipHeights(1)
	println("[EXPECTED] admin delegated amount:", adminDelegatedAmount)
	println("[EXPECTED] total delegated after admin:", govStaker.GetTotalDelegated())

	// redelegate part of alice's stake to herself
	testing.SetRealm(aliceRealm)
	redelegated := govStaker.Redelegate(cross(cur), adminAddr, aliceAddr, 500_000_000)
	testing.SkipHeights(1)
	println("[EXPECTED] redelegated:", redelegated)
	println("[EXPECTED] alice->alice delegation count:", len(govStaker.GetUserDelegationIDs(aliceAddr, aliceAddr)))

	// undelegate and collect after the lockup period
	govStaker.Undelegate(cross(cur), aliceAddr, 200_000_000)
	testing.SkipHeights(1)
	println("[EXPECTED] total locked amount:", govStaker.GetTotalLockedAmount())

	testing.SkipHeights(100 / blockTimeSeconds)
	collected := govStaker.CollectUndelegatedGns(cross(cur))
	testing.SkipHeights(1)
	println("[EXPECTED] collected undelegated gns:", collected)
	println("[EXPECTED] total locked amount after collect:", govStaker.GetTotalLockedAmount())

	// rewards accrue from emission and from the distributed protocol fee
	testing.SkipHeights(secondsPerDay / blockTimeSeconds)
	emissionReward, protocolFeeRewards, err := govStaker.GetClaimableRewardByAddress(aliceAddr)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] alice claimable emission reward:", emissionReward)
	println("[EXPECTED] alice claimable protocol fee token count:", len(protocolFeeRewards))

	testing.SetRealm(aliceRealm)
	govStaker.CollectEmissionReward(cross(cur))
	govStaker.CollectProtocolFeeReward(cross(cur), barPath)
	govStaker.CollectReward(cross(cur))
	testing.SkipHeights(1)
	println("[EXPECTED] emission distributed amount:", govStaker.GetEmissionDistributedAmount())
	println("[EXPECTED] protocol fee amount (BAR):", govStaker.GetProtocolFeeAmount(barPath))

	// snapshot cleanup keeps the delegation history bounded
	testing.SetRealm(adminRealm)
	// snapshots may only be pruned once they are older than the maximum
	// smoothing period (30 days)
	govStaker.CleanStakerDelegationSnapshotByAdmin(cross(cur), time.Now().Unix()-31*secondsPerDay, aliceAddr)
	testing.SkipHeights(1)
	println("[EXPECTED] delegation snapshots present:", govStaker.HasDelegationSnapshotsKey())

	uassert.Equal(t, int64(6_800_000_000), govStaker.GetTotalDelegated())
	uassert.Equal(t, int64(6_800_000_000), govStaker.GetTotalLockedAmount())
	uassert.Equal(t, int64(2_000_000_000), aliceDelegatedAmount)
}

// ---------------------------------------------------------------------------
// 13. governance
// ---------------------------------------------------------------------------

func governanceLifecycle(cur realm) {
	config, err := govGovernance.GetLatestConfig()
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] governance config version:", govGovernance.GetLatestConfigVersion())
	println("[EXPECTED] voting period:", config.VotingPeriod, "quorum:", config.Quorum)

	// voting weight is averaged over the smoothing duration, so the delegation
	// made in the previous scenario must age before a proposal can be created
	testing.SkipHeights(config.VotingWeightSmoothingDuration / blockTimeSeconds)

	// A proposer may only hold one active proposal at a time, so each proposal
	// is driven to a terminal state before the next one is created.

	// --- text proposal: created, then canceled ---
	testing.SetRealm(adminRealm)
	textProposalId = govGovernance.ProposeText(cross(cur), "text proposal", "signal only")
	testing.SkipHeights(1)
	println("[EXPECTED] text proposal id:", textProposalId)
	textTitle, _ := govGovernance.GetTitleByProposalId(textProposalId)
	println("[EXPECTED] text proposal title:", textTitle)
	textProposer, _ := govGovernance.GetProposerByProposalId(textProposalId)
	println("[EXPECTED] text proposal proposer is admin:", textProposer == adminAddr)

	canceledId := govGovernance.Cancel(cross(cur), textProposalId)
	testing.SkipHeights(1)
	canceledStatus, _ := govGovernance.GetProposalStatusByProposalId(canceledId)
	println("[EXPECTED] text proposal status after cancel:", canceledStatus)

	// --- community pool spend proposal: voted and executed ---
	testing.SetRealm(adminRealm)
	spendProposalId = govGovernance.ProposeCommunityPoolSpend(
		cross(cur), "community pool spend", "spend 1000 GNS", aliceAddr, gnsPath, 1_000,
	)
	testing.SkipHeights(1)
	println("[EXPECTED] spend proposal id:", spendProposalId)
	spendType, _ := govGovernance.GetProposalTypeByProposalId(spendProposalId)
	println("[EXPECTED] spend proposal type:", spendType.String())

	aliceGnsBefore := gns.BalanceOf(aliceAddr)
	voteAndExecute(cur, config, spendProposalId)
	aliceGnsAfter := gns.BalanceOf(aliceAddr)
	spendStatus, _ := govGovernance.GetProposalStatusByProposalId(spendProposalId)
	println("[EXPECTED] spend proposal status after execute:", spendStatus)
	println("[EXPECTED] community pool spend received by alice:", aliceGnsAfter-aliceGnsBefore)

	// --- parameter change proposal: governance drives the staker setter ---
	testing.SetRealm(adminRealm)
	paramProposalId = govGovernance.ProposeParameterChange(
		cross(cur), "parameter change", "raise the unstaking fee", 1,
		"gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*150",
	)
	testing.SkipHeights(1)
	println("[EXPECTED] param proposal id:", paramProposalId)
	println("[EXPECTED] proposal count:", govGovernance.GetProposals().Size())

	unstakingFeeBefore := staker.GetUnstakingFee()
	voteAndExecute(cur, config, paramProposalId)
	println("[EXPECTED] unstaking fee before/after governance execution:", unstakingFeeBefore, staker.GetUnstakingFee())

	// --- reconfigure produces a new config version ---
	testing.SetRealm(adminRealm)
	newVersion := govGovernance.Reconfigure(
		cross(cur),
		config.VotingStartDelay,
		config.VotingPeriod,
		config.VotingWeightSmoothingDuration,
		config.Quorum,
		config.ProposalCreationThreshold,
		config.ExecutionDelay,
		config.ExecutionWindow,
	)
	testing.SkipHeights(1)
	println("[EXPECTED] governance config version after reconfigure:", newVersion)

	uassert.Equal(t, uint64(150), staker.GetUnstakingFee())
	uassert.Equal(t, int64(2), newVersion)
	uassert.Equal(t, 3, govGovernance.GetProposals().Size())
	uassert.Equal(t, int64(1_000), aliceGnsAfter-aliceGnsBefore)
}

// voteAndExecute drives a proposal through the full voting schedule:
// votingStartDelay -> Vote -> votingPeriod + executionDelay -> Execute.
func voteAndExecute(cur realm, config govGovernance.Config, proposalId int64) {
	testing.SkipHeights(config.VotingStartDelay / blockTimeSeconds)

	testing.SetRealm(adminRealm)
	govGovernance.Vote(cross(cur), proposalId, true)
	testing.SkipHeights(1)

	yea, _ := govGovernance.GetYeaByProposalId(proposalId)
	nay, _ := govGovernance.GetNayByProposalId(proposalId)
	println("[EXPECTED] proposal", proposalId, "yea/nay:", yea, nay)
	voteWeight, _ := govGovernance.GetVoteWeight(proposalId, adminAddr)
	println("[EXPECTED] admin vote weight:", voteWeight)
	quorum, maxVotingWeight, yesWeight, noWeight, _ := govGovernance.GetVoteStatus(proposalId)
	println("[EXPECTED] vote status quorum/max/yes/no:", quorum, maxVotingWeight, yesWeight, noWeight)

	testing.SkipHeights((config.VotingPeriod + config.ExecutionDelay) / blockTimeSeconds)
	testing.SetRealm(adminRealm)
	govGovernance.Execute(cross(cur), proposalId)
	testing.SkipHeights(1)
}

// ---------------------------------------------------------------------------
// 14. launchpad
// ---------------------------------------------------------------------------

func launchpadLifecycle(cur realm) {
	testing.SetRealm(adminRealm)

	rewardAmount := int64(1_000_000_000)
	startTime := time.Now().Unix() + 7*secondsPerDay

	obl.Approve(cross(cur), launchpadAddr, rewardAmount)
	launchpadProjectId = launchpad.CreateProject(
		cross(cur),
		"OBL launchpad project",
		oblPath,
		projectAddr,
		rewardAmount,
		"",
		"",
		10, // tier30 ratio
		20, // tier90 ratio
		70, // tier180 ratio
		startTime,
	)
	testing.SkipHeights(1)
	launchpadTier30Id = ufmt.Sprintf("%s:%d", launchpadProjectId, launchpadTierWaitID)

	println("[EXPECTED] project id:", launchpadProjectId)
	println("[EXPECTED] project count:", launchpad.GetProjects().Size())
	projectName, _ := launchpad.GetProjectName(launchpadProjectId)
	println("[EXPECTED] project name:", projectName)
	projectRecipient, _ := launchpad.GetProjectRecipient(launchpadProjectId)
	println("[EXPECTED] project recipient is project owner:", projectRecipient == projectAddr)
	tier30Total, _ := launchpad.GetProjectTierTotalDistributeAmount(launchpadProjectId, 30)
	tier90Total, _ := launchpad.GetProjectTierTotalDistributeAmount(launchpadProjectId, 90)
	tier180Total, _ := launchpad.GetProjectTierTotalDistributeAmount(launchpadProjectId, 180)
	println("[EXPECTED] tier distribute amounts:", tier30Total, tier90Total, tier180Total)

	// wait for the tier to open, then deposit GNS
	testing.SkipHeights(7 * secondsPerDay / blockTimeSeconds)

	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), aliceAddr, 1_000_000)

	testing.SetRealm(aliceRealm)
	gns.Approve(cross(cur), launchpadAddr, 1_000_000)
	launchpadDepositId = launchpad.DepositGns(cross(cur), launchpadTier30Id, 1_000_000, "")
	testing.SkipHeights(1)

	println("[EXPECTED] deposit id:", launchpadDepositId)
	println("[EXPECTED] deposit count:", launchpad.GetDepositCount())
	println("[EXPECTED] total GNS staked in launchpad:", launchpad.GetTotalGNSStakedAmount())
	depositAmount, _ := launchpad.GetDepositAmount(launchpadDepositId)
	println("[EXPECTED] deposit amount:", depositAmount)
	projectWalletAmount, projectWalletFound := govStaker.GetLaunchpadProjectDeposit(projectAddr.String())
	println("[EXPECTED] launchpad project wallet xGNS:", projectWalletAmount, "found:", projectWalletFound)

	// reward becomes claimable after the tier's collect-wait duration (3 days)
	testing.SkipHeights(4 * secondsPerDay / blockTimeSeconds)

	testing.SetRealm(aliceRealm)
	claimed := launchpad.CollectRewardByDepositId(cross(cur), launchpadDepositId)
	testing.SkipHeights(1)
	println("[EXPECTED] launchpad reward claimed:", claimed)

	// the project recipient collects the gov-staker side rewards
	testing.SetRealm(projectRealm)
	launchpad.CollectEmissionReward(cross(cur))
	launchpad.CollectProtocolFeeReward(cross(cur), barPath)
	launchpad.CollectProtocolFee(cross(cur))
	testing.SkipHeights(1)
	println("[EXPECTED] project recipient collected launchpad rewards")

	uassert.Equal(t, 1, launchpad.GetProjects().Size())
	uassert.Equal(t, int64(1_000_000), depositAmount)
	uassert.True(t, projectWalletFound)
	uassert.True(t, claimed > 0)
}

// ---------------------------------------------------------------------------
// 15. snapshot
// ---------------------------------------------------------------------------

func captureSnapshot() upgradeSnapshot {
	feeGrowth0, feeGrowth1, err := pool.GetFeeGrowthGlobalX128(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	protocolFee0, protocolFee1, err := pool.GetProtocolFeesTokens(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	poolLiquidity, err := pool.GetLiquidity(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	poolSqrtPriceX96, err := pool.GetSlot0SqrtPriceX96(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	poolTick, err := pool.GetSlot0Tick(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	positionFeeGrowth0, positionFeeGrowth1, err := position.GetPositionFeeGrowthInsideLastX128(1)
	if err != nil {
		panic(err)
	}
	positionOwed0, positionOwed1, err := position.GetPositionTokensOwed(1)
	if err != nil {
		panic(err)
	}
	positionUnclaimed0, positionUnclaimed1, err := position.GetUnclaimedFee(1)
	if err != nil {
		panic(err)
	}
	positionLiquidity, err := position.GetPositionLiquidity(1)
	if err != nil {
		panic(err)
	}
	positionTickLower, err := position.GetPositionTickLower(1)
	if err != nil {
		panic(err)
	}
	positionTickUpper, err := position.GetPositionTickUpper(1)
	if err != nil {
		panic(err)
	}
	positionOwner, err := position.GetPositionOwner(1)
	if err != nil {
		panic(err)
	}
	positionOperator, err := position.GetPositionOperator(1)
	if err != nil {
		panic(err)
	}
	positionBurned, err := position.IsBurned(1)
	if err != nil {
		panic(err)
	}
	positionInRange, err := position.IsInRange(1)
	if err != nil {
		panic(err)
	}
	stakerPoolTierRatio, err := staker.GetPoolTierRatio(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	depositLiquidity, err := staker.GetDepositLiquidityAsString(1)
	if err != nil {
		panic(err)
	}
	depositStakeTime, err := staker.GetDepositStakeTime(1)
	if err != nil {
		panic(err)
	}
	depositTickLower, err := staker.GetDepositTickLower(1)
	if err != nil {
		panic(err)
	}
	depositTickUpper, err := staker.GetDepositTickUpper(1)
	if err != nil {
		panic(err)
	}
	depositWarmups, err := staker.GetDepositWarmUp(1)
	if err != nil {
		panic(err)
	}
	depositCollected, err := staker.GetDepositCollectedInternalReward(1)
	if err != nil {
		panic(err)
	}
	incentiveTotal, err := staker.GetIncentiveTotalRewardAmount(barFoo500PoolPath, externalIncentiveId)
	if err != nil {
		panic(err)
	}
	incentiveDistributed, err := staker.GetIncentiveDistributedRewardAmount(barFoo500PoolPath, externalIncentiveId)
	if err != nil {
		panic(err)
	}
	incentiveRefunded, err := staker.GetIncentiveRefunded(barFoo500PoolPath, externalIncentiveId)
	if err != nil {
		panic(err)
	}
	paramStatus, _ := govGovernance.GetProposalStatusByProposalId(paramProposalId)
	spendStatus, _ := govGovernance.GetProposalStatusByProposalId(spendProposalId)
	textStatus, _ := govGovernance.GetProposalStatusByProposalId(textProposalId)
	paramYea, _ := govGovernance.GetYeaByProposalId(paramProposalId)
	paramNay, _ := govGovernance.GetNayByProposalId(paramProposalId)
	adminVoteWeight, _ := govGovernance.GetVoteWeight(paramProposalId, adminAddr)
	projectActive, _ := launchpad.GetProjectActiveStatus(launchpadProjectId)
	projectRecipient, _ := launchpad.GetProjectRecipient(launchpadProjectId)
	projectTier30Total, _ := launchpad.GetProjectTierTotalDistributeAmount(launchpadProjectId, 30)
	launchpadDepositAmount, _ := launchpad.GetDepositAmount(launchpadDepositId)
	config, err := govGovernance.GetLatestConfig()
	if err != nil {
		panic(err)
	}

	return upgradeSnapshot{
		poolLiquidity:      poolLiquidity,
		poolSqrtPriceX96:   poolSqrtPriceX96,
		poolTick:           poolTick,
		poolFeeGrowth0:     feeGrowth0,
		poolFeeGrowth1:     feeGrowth1,
		poolProtocolFee0:   protocolFee0,
		poolProtocolFee1:   protocolFee1,
		poolCreationFee:    pool.GetPoolCreationFee(),
		withdrawalFee:      pool.GetWithdrawalFee(),
		swapFee:            router.GetSwapFee(),
		positionCount:      position.GetPositions().Size(),
		positionLiquidity:  positionLiquidity,
		positionTickLower:  positionTickLower,
		positionTickUpper:  positionTickUpper,
		positionOwner:      positionOwner,
		positionOperator:   positionOperator,
		positionFeeGrowth0: positionFeeGrowth0,
		positionFeeGrowth1: positionFeeGrowth1,
		positionOwed0:      positionOwed0,
		positionOwed1:      positionOwed1,
		positionUnclaimed0: positionUnclaimed0,
		positionUnclaimed1: positionUnclaimed1,
		positionBurned:     positionBurned,
		positionInRange:    positionInRange,
		stakerPoolTier:     staker.GetPoolTier(barFoo500PoolPath),
		stakerPoolTierRat:  stakerPoolTierRatio,
		stakerUnstakingFee: staker.GetUnstakingFee(),
		stakerDepositGns:   staker.GetDepositGnsAmount(),
		stakerAllowedToken: len(staker.GetAllowedTokens()),
		stakerAllowedList:  staker.GetAllowedTokens(),
		depositLiquidity:   depositLiquidity,
		depositStakeTime:   depositStakeTime,
		depositTickLower:   depositTickLower,
		depositTickUpper:   depositTickUpper,
		depositWarmupCount: len(depositWarmups),
		depositWarmups:     depositWarmups,
		depositCollected:   depositCollected,
		totalEmissionSent:  staker.GetTotalEmissionSent(),
		incentiveTotal:     incentiveTotal,
		incentiveDistrib:   incentiveDistributed,
		incentiveRefunded:  incentiveRefunded,
		devOpsPct:          protocolFee.GetDevOpsPct(),
		govStakerPct:       protocolFee.GetGovStakerPct(),
		accuGovStakerBar:   protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath),
		accuDevOpsBar:      protocolFee.GetAccuTransferToDevOpsByTokenPath(barPath),
		reservedTokens:     protocolFee.GetReservedTokens(),
		totalDelegated:     govStaker.GetTotalDelegated(),
		totalXGnsSupply:    govStaker.GetTotalxGnsSupply(),
		totalLocked:        govStaker.GetTotalLockedAmount(),
		delegationCount:    govStaker.GetDelegations().Size(),
		delegationIDs:      collectDelegationIDs(0, 10),
		proposalCount:      govGovernance.GetProposals().Size(),
		proposalIDs:        collectProposalIDs(0, 10),
		paramProposalYea:   paramYea,
		paramProposalNay:   paramNay,
		paramProposalState: paramStatus,
		spendProposalState: spendStatus,
		textProposalState:  textStatus,
		adminVoteWeight:    adminVoteWeight,
		configVersion:      govGovernance.GetLatestConfigVersion(),
		configVotingPeriod: config.VotingPeriod,
		projectCount:       launchpad.GetProjects().Size(),
		projectActive:      projectActive,
		projectRecipient:   projectRecipient,
		projectTier30Total: projectTier30Total,
		launchpadDeposits:  launchpad.GetTotalGNSStakedAmount(),
		launchpadDepositID: launchpad.GetCurrentDepositId(),
		depositAmount:      launchpadDepositAmount,
	}
}

func printSnapshot(s upgradeSnapshot) {
	println("[EXPECTED] pool liquidity:", s.poolLiquidity)
	println("[EXPECTED] pool tick:", s.poolTick)
	println("[EXPECTED] pool protocol fees:", s.poolProtocolFee0, s.poolProtocolFee1)
	println("[EXPECTED] position 1 liquidity:", s.positionLiquidity)
	println("[EXPECTED] staker pool tier:", s.stakerPoolTier)
	println("[EXPECTED] staked deposit liquidity:", s.depositLiquidity)
	println("[EXPECTED] protocol fee split:", s.devOpsPct, s.govStakerPct)
	println("[EXPECTED] total delegated:", s.totalDelegated)
	println("[EXPECTED] proposal count:", s.proposalCount)
	println("[EXPECTED] project count:", s.projectCount)
	println("[EXPECTED] launchpad deposits:", s.launchpadDeposits)
	println("[EXPECTED] position fee growth inside last:", s.positionFeeGrowth0, s.positionFeeGrowth1)
	println("[EXPECTED] position unclaimed fee:", s.positionUnclaimed0, s.positionUnclaimed1)
	println("[EXPECTED] staker collected internal reward:", s.depositCollected)
	println("[EXPECTED] total emission sent:", s.totalEmissionSent)
	println("[EXPECTED] external incentive total / distributed:", s.incentiveTotal, s.incentiveDistrib)
	println("[EXPECTED] proposal ids:", len(s.proposalIDs), "delegation ids:", len(s.delegationIDs))
	println("[EXPECTED] param proposal yea / nay / status:", s.paramProposalYea, s.paramProposalNay, s.paramProposalState)
	println("[EXPECTED] launchpad project active:", s.projectActive)
	for _, tokenPath := range s.stakerAllowedList {
		println("[EXPECTED] staker allowed token:", tokenPath)
	}
	for i, warmup := range s.depositWarmups {
		println("[EXPECTED] deposit warmup", i, "duration / nextWarmupTime / ratio:",
			warmup.TimeDuration, warmup.NextWarmupTime, warmup.WarmupRatio)
	}
}

// ---------------------------------------------------------------------------
// 16-17. upgrade and validation
// ---------------------------------------------------------------------------

func upgradeAllToV2Valid(cur realm) {
	testing.SetRealm(adminRealm)

	protocolFee.UpgradeImpl(cross(cur), protocolFeeV2Path)
	pool.UpgradeImpl(cross(cur), poolV2Path)
	position.UpgradeImpl(cross(cur), positionV2Path)
	router.UpgradeImpl(cross(cur), routerV2Path)
	// The staker upgrade re-registers the pool swap hooks
	// (SetSwapStartHook / SetSwapEndHook / SetTickCrossHook) from the new
	// implementation, which is what keeps tick-cross reward accounting alive
	// after a pool upgrade.
	staker.UpgradeImpl(cross(cur), stakerV2Path)
	launchpad.UpgradeImpl(cross(cur), launchpadV2Path)
	govStaker.UpgradeImpl(cross(cur), govStakerV2Path)
	govGovernance.UpgradeImpl(cross(cur), governanceV2Path)
	testing.SkipHeights(1)

	printImplementations()

	uassert.Equal(t, poolV2Path, pool.GetImplementationPackagePath())
	uassert.Equal(t, positionV2Path, position.GetImplementationPackagePath())
	uassert.Equal(t, routerV2Path, router.GetImplementationPackagePath())
	uassert.Equal(t, stakerV2Path, staker.GetImplementationPackagePath())
	uassert.Equal(t, launchpadV2Path, launchpad.GetImplementationPackagePath())
	uassert.Equal(t, protocolFeeV2Path, protocolFee.GetImplementationPackagePath())
	uassert.Equal(t, governanceV2Path, govGovernance.GetImplementationPackagePath())
	uassert.Equal(t, govStakerV2Path, govStaker.GetImplementationPackagePath())
}

func validateSnapshotUnchanged() {
	after := captureSnapshot()

	uassert.Equal(t, snap.poolLiquidity, after.poolLiquidity)
	uassert.Equal(t, snap.poolSqrtPriceX96, after.poolSqrtPriceX96)
	uassert.Equal(t, snap.poolTick, after.poolTick)
	uassert.Equal(t, snap.poolFeeGrowth0, after.poolFeeGrowth0)
	uassert.Equal(t, snap.poolFeeGrowth1, after.poolFeeGrowth1)
	uassert.Equal(t, snap.poolProtocolFee0, after.poolProtocolFee0)
	uassert.Equal(t, snap.poolProtocolFee1, after.poolProtocolFee1)
	uassert.Equal(t, snap.poolCreationFee, after.poolCreationFee)
	uassert.Equal(t, snap.withdrawalFee, after.withdrawalFee)
	uassert.Equal(t, snap.swapFee, after.swapFee)
	uassert.Equal(t, snap.positionCount, after.positionCount)
	uassert.Equal(t, snap.positionLiquidity, after.positionLiquidity)
	uassert.Equal(t, snap.positionTickLower, after.positionTickLower)
	uassert.Equal(t, snap.positionTickUpper, after.positionTickUpper)
	uassert.Equal(t, snap.positionOwner, after.positionOwner)
	uassert.Equal(t, snap.positionOperator, after.positionOperator)
	uassert.Equal(t, snap.positionFeeGrowth0, after.positionFeeGrowth0)
	uassert.Equal(t, snap.positionFeeGrowth1, after.positionFeeGrowth1)
	uassert.Equal(t, snap.positionOwed0, after.positionOwed0)
	uassert.Equal(t, snap.positionOwed1, after.positionOwed1)
	uassert.Equal(t, snap.positionUnclaimed0, after.positionUnclaimed0)
	uassert.Equal(t, snap.positionUnclaimed1, after.positionUnclaimed1)
	uassert.Equal(t, snap.positionBurned, after.positionBurned)
	uassert.Equal(t, snap.positionInRange, after.positionInRange)
	uassert.Equal(t, snap.stakerPoolTier, after.stakerPoolTier)
	uassert.Equal(t, snap.stakerPoolTierRat, after.stakerPoolTierRat)
	uassert.Equal(t, snap.stakerUnstakingFee, after.stakerUnstakingFee)
	uassert.Equal(t, snap.stakerDepositGns, after.stakerDepositGns)
	uassert.Equal(t, snap.stakerAllowedToken, after.stakerAllowedToken)
	uassert.Equal(t, snap.depositLiquidity, after.depositLiquidity)
	uassert.Equal(t, snap.depositStakeTime, after.depositStakeTime)
	uassert.Equal(t, snap.depositTickLower, after.depositTickLower)
	uassert.Equal(t, snap.depositTickUpper, after.depositTickUpper)
	uassert.Equal(t, snap.depositWarmupCount, after.depositWarmupCount)
	uassert.Equal(t, snap.depositCollected, after.depositCollected)
	uassert.Equal(t, snap.totalEmissionSent, after.totalEmissionSent)
	uassert.Equal(t, snap.incentiveTotal, after.incentiveTotal)
	uassert.Equal(t, snap.incentiveDistrib, after.incentiveDistrib)
	uassert.Equal(t, snap.incentiveRefunded, after.incentiveRefunded)
	uassert.Equal(t, snap.devOpsPct, after.devOpsPct)
	uassert.Equal(t, snap.govStakerPct, after.govStakerPct)
	uassert.Equal(t, snap.accuGovStakerBar, after.accuGovStakerBar)
	uassert.Equal(t, snap.accuDevOpsBar, after.accuDevOpsBar)
	uassert.Equal(t, snap.totalDelegated, after.totalDelegated)
	uassert.Equal(t, snap.totalXGnsSupply, after.totalXGnsSupply)
	uassert.Equal(t, snap.totalLocked, after.totalLocked)
	uassert.Equal(t, snap.delegationCount, after.delegationCount)
	uassert.Equal(t, snap.proposalCount, after.proposalCount)
	uassert.Equal(t, snap.paramProposalYea, after.paramProposalYea)
	uassert.Equal(t, snap.paramProposalNay, after.paramProposalNay)
	uassert.Equal(t, snap.paramProposalState, after.paramProposalState)
	uassert.Equal(t, snap.spendProposalState, after.spendProposalState)
	uassert.Equal(t, snap.textProposalState, after.textProposalState)
	uassert.Equal(t, snap.adminVoteWeight, after.adminVoteWeight)
	uassert.Equal(t, snap.configVersion, after.configVersion)
	uassert.Equal(t, snap.configVotingPeriod, after.configVotingPeriod)
	uassert.Equal(t, snap.projectCount, after.projectCount)
	uassert.Equal(t, snap.projectActive, after.projectActive)
	uassert.Equal(t, snap.projectRecipient, after.projectRecipient)
	uassert.Equal(t, snap.projectTier30Total, after.projectTier30Total)
	uassert.Equal(t, snap.launchpadDeposits, after.launchpadDeposits)
	uassert.Equal(t, snap.launchpadDepositID, after.launchpadDepositID)
	uassert.Equal(t, snap.depositAmount, after.depositAmount)

	// list-valued getters are compared element by element: a list of the same
	// length holding different ids would otherwise pass
	uassert.Equal(t, len(snap.reservedTokens), len(after.reservedTokens))
	for i, tokenPath := range snap.reservedTokens {
		uassert.Equal(t, tokenPath, after.reservedTokens[i])
	}
	uassert.Equal(t, len(snap.delegationIDs), len(after.delegationIDs))
	for i, id := range snap.delegationIDs {
		uassert.Equal(t, id, after.delegationIDs[i])
	}
	uassert.Equal(t, len(snap.proposalIDs), len(after.proposalIDs))
	for i, id := range snap.proposalIDs {
		uassert.Equal(t, id, after.proposalIDs[i])
	}
	uassert.Equal(t, len(snap.stakerAllowedList), len(after.stakerAllowedList))
	for i, tokenPath := range snap.stakerAllowedList {
		uassert.Equal(t, tokenPath, after.stakerAllowedList[i])
	}
	// warm-up records carry the reward ratio schedule, so every field of every
	// tier is compared, not just how many tiers there are
	uassert.Equal(t, len(snap.depositWarmups), len(after.depositWarmups))
	for i, warmup := range snap.depositWarmups {
		uassert.Equal(t, warmup.TimeDuration, after.depositWarmups[i].TimeDuration)
		uassert.Equal(t, warmup.NextWarmupTime, after.depositWarmups[i].NextWarmupTime)
		uassert.Equal(t, warmup.WarmupRatio, after.depositWarmups[i].WarmupRatio)
	}

	println("[EXPECTED] every snapshot field is identical after the upgrade")
}

// ---------------------------------------------------------------------------
// 18. post-upgrade rerun
// ---------------------------------------------------------------------------

func rerunAfterUpgrade(cur realm) {
	testing.SetRealm(adminRealm)

	// pool + position through v2_valid
	bar.Approve(cross(cur), poolAddr, math.MaxInt64)
	foo.Approve(cross(cur), poolAddr, math.MaxInt64)
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross(cur), barPath, fooPath, fee500, -960, 960,
		"50000000", "50000000", "0", "0", time.Now().Unix()+3600, adminAddr, "",
	)
	testing.SkipHeights(1)
	println("[EXPECTED] v2_valid minted position:", positionId, "liquidity:", liquidity)
	println("[EXPECTED] v2_valid mint amounts:", amount0, amount1)

	// router through v2_valid
	bar.Approve(cross(cur), routerAddr, math.MaxInt64)
	foo.Approve(cross(cur), routerAddr, math.MaxInt64)
	in, out := router.ExactInSingleSwapRoute(
		cross(cur), barPath, fooPath, "1000000", barFooRoute, "1", "0", time.Now().Unix()+3600, "",
	)
	testing.SkipHeights(1)
	println("[EXPECTED] v2_valid swap in/out:", in, out)

	// staker through v2_valid: stake the freshly minted position
	gnft.Approve(cross(cur), stakerAddr, grc721.TokenID(strconv.FormatUint(positionId, 10)))
	staker.StakeToken(cross(cur), positionId, "")
	testing.SkipHeights(secondsPerDay / blockTimeSeconds)
	rewardToUser, rewardPenalty, _, _ := staker.CollectReward(cross(cur), positionId)
	testing.SkipHeights(1)
	println("[EXPECTED] v2_valid staking reward to user/penalty:", rewardToUser, rewardPenalty)

	// protocol fee through v2_valid
	testing.SetRealm(adminRealm)
	protocolFee.DistributeProtocolFee(cross(cur))
	testing.SkipHeights(1)
	println("[EXPECTED] v2_valid distributed FOO to gov staker:", protocolFee.GetActualDistributedToGovStakerByTokenPath(fooPath))

	// gov staker through v2_valid
	testing.SetRealm(aliceRealm)
	gns.Approve(cross(cur), govStakerAddr, 1_000_000_000)
	delegationCountBefore := govStaker.GetDelegations().Size()
	newDelegatedAmount := govStaker.Delegate(cross(cur), adminAddr, 1_000_000_000, "")
	testing.SkipHeights(1)
	println("[EXPECTED] v2_valid delegated amount:", newDelegatedAmount)
	println("[EXPECTED] v2_valid delegation count:", govStaker.GetDelegations().Size())
	println("[EXPECTED] v2_valid total delegated:", govStaker.GetTotalDelegated())

	// launchpad through v2_valid: collect the remaining deposit principal
	testing.SkipHeights(30 * secondsPerDay / blockTimeSeconds)
	testing.SetRealm(aliceRealm)
	principal, err := launchpad.CollectDepositGns(cross(cur), launchpadDepositId)
	if err != nil {
		panic(err)
	}
	testing.SkipHeights(1)
	println("[EXPECTED] v2_valid collected deposit principal:", principal)

	// governance through v2_valid
	testing.SetRealm(adminRealm)
	newProposalId := govGovernance.ProposeText(cross(cur), "post upgrade text", "created through v2_valid")
	testing.SkipHeights(1)
	println("[EXPECTED] v2_valid proposal id:", newProposalId)
	println("[EXPECTED] v2_valid proposal count:", govGovernance.GetProposals().Size())

	uassert.Equal(t, int64(1_000_000), principal)
	uassert.Equal(t, 4, govGovernance.GetProposals().Size())
	uassert.Equal(t, int64(1_000_000_000), newDelegatedAmount)
	uassert.Equal(t, delegationCountBefore+1, govStaker.GetDelegations().Size())
}

// ---------------------------------------------------------------------------
// 19. wind down
// ---------------------------------------------------------------------------

func windDown(cur realm) {
	// jump past the 90-day incentive window plus one day of buffer
	testing.SkipHeights((incentiveDuration + 2*secondsPerDay) / blockTimeSeconds)

	testing.SetRealm(adminRealm)
	staker.EndExternalIncentive(cross(cur), barFoo500PoolPath, externalIncentiveId, adminAddr)
	testing.SkipHeights(1)
	incentiveRefunded, err := staker.GetIncentiveRefunded(barFoo500PoolPath, externalIncentiveId)
	if err != nil {
		panic(err)
	}
	incentiveDistributed, err := staker.GetIncentiveDistributedRewardAmount(barFoo500PoolPath, externalIncentiveId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] incentive refunded:", incentiveRefunded)
	println("[EXPECTED] incentive distributed:", incentiveDistributed)

	penalty := staker.CollectExternalIncentivePenalty(cross(cur), barFoo500PoolPath, externalIncentiveId, adminAddr)
	testing.SkipHeights(1)
	println("[EXPECTED] collected incentive penalty:", penalty)

	staker.UnStakeToken(cross(cur), 1)
	testing.SkipHeights(1)
	println("[EXPECTED] position 1 staked after unstake:", staker.IsStaked(1))
	positionOwner, err := position.GetPositionOwner(1)
	if err != nil {
		panic(err)
	}
	positionOperator, err := position.GetPositionOperator(1)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] position 1 owner after unstake:", positionOwner)
	println("[EXPECTED] position 1 operator cleared:", positionOperator == zeroAddress)

	staker.RemoveToken(cross(cur), barPath)
	println("[EXPECTED] allowed token count after removal:", len(staker.GetAllowedTokens()))

	staker.RemovePoolTier(cross(cur), barFoo500PoolPath)
	println("[EXPECTED] pool tier after removal:", staker.GetPoolTier(barFoo500PoolPath))

	// admin sweeps the pool protocol fees
	before0, before1, err := pool.GetProtocolFeesTokens(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	collected0, collected1 := pool.CollectProtocol(
		cross(cur), barPath, fooPath, fee500, adminAddr, "1000000000", "1000000000",
	)
	testing.SkipHeights(1)
	after0, after1, err := pool.GetProtocolFeesTokens(barFoo500PoolPath)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] pool protocol fees before:", before0, before1)
	println("[EXPECTED] collected protocol fees:", collected0, collected1)
	println("[EXPECTED] pool protocol fees after:", after0, after1)

	// the admin may only reclaim the leftovers once the last tier has ended
	tier180End, err := launchpad.GetProjectTierEndTime(launchpadProjectId, 180)
	if err != nil {
		panic(err)
	}
	if remaining := tier180End - time.Now().Unix(); remaining > 0 {
		testing.SkipHeights(remaining/blockTimeSeconds + 1)
	}
	println("[EXPECTED] launchpad project ended:", time.Now().Unix() >= tier180End)

	left := launchpad.TransferLeftFromProjectByAdmin(cross(cur), launchpadProjectId, projectAddr)
	testing.SkipHeights(1)
	println("[EXPECTED] launchpad leftover transferred:", left)

	uassert.False(t, staker.IsStaked(1))
	uassert.Equal(t, adminAddr, positionOwner)
	uassert.Equal(t, uint64(0), staker.GetPoolTier(barFoo500PoolPath))
	uassert.Equal(t, int64(0), after0)
	uassert.Equal(t, int64(0), after1)
}

// ---------------------------------------------------------------------------
// 20. final invariants
// ---------------------------------------------------------------------------

func finalInvariants(cur realm) {
	println("[EXPECTED] pool count:", pool.GetPools().Size())
	println("[EXPECTED] position count:", position.GetPositions().Size())
	println("[EXPECTED] total emission sent:", staker.GetTotalEmissionSent())
	println("[EXPECTED] gov staker total delegated:", govStaker.GetTotalDelegated())
	println("[EXPECTED] governance proposal count:", govGovernance.GetProposals().Size())
	println("[EXPECTED] launchpad project count:", launchpad.GetProjects().Size())

	// external incentive ledger: the amount handed out (rewards + the refund
	// booked at EndExternalIncentive) can never exceed the funded total, and
	// the incentive must be marked refunded once it has been ended.
	total, err := staker.GetIncentiveTotalRewardAmount(barFoo500PoolPath, externalIncentiveId)
	if err != nil {
		panic(err)
	}
	distributed, err := staker.GetIncentiveDistributedRewardAmount(barFoo500PoolPath, externalIncentiveId)
	if err != nil {
		panic(err)
	}
	remaining, err := staker.GetIncentiveRemainingRewardAmount(barFoo500PoolPath, externalIncentiveId)
	if err != nil {
		panic(err)
	}
	penalty, err := staker.GetIncentiveAccumulatedPenaltyAmount(barFoo500PoolPath, externalIncentiveId)
	if err != nil {
		panic(err)
	}
	incentiveRefunded, err := staker.GetIncentiveRefunded(barFoo500PoolPath, externalIncentiveId)
	if err != nil {
		panic(err)
	}
	incentiveActive, err := staker.IsIncentiveActive(barFoo500PoolPath, externalIncentiveId)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] incentive total/distributed/remaining/penalty:", total, distributed, remaining, penalty)
	uassert.True(t, distributed > 0)
	uassert.True(t, distributed <= total)
	uassert.True(t, incentiveRefunded)
	uassert.False(t, incentiveActive)

	printImplementations()
}

// Output:
// [SCENARIO] 1. Activate v1 implementations for every upgradeable contract
// [EXPECTED] pool impl: gno.land/r/gnoswap/pool/v1
// [EXPECTED] position impl: gno.land/r/gnoswap/position/v1
// [EXPECTED] router impl: gno.land/r/gnoswap/router/v1
// [EXPECTED] staker impl: gno.land/r/gnoswap/staker/v1
// [EXPECTED] launchpad impl: gno.land/r/gnoswap/launchpad/v1
// [EXPECTED] protocol_fee impl: gno.land/r/gnoswap/protocol_fee/v1
// [EXPECTED] governance impl: gno.land/r/gnoswap/gov/governance/v1
// [EXPECTED] gov staker impl: gno.land/r/gnoswap/gov/staker/v1
//
// [SCENARIO] 2. Bootstrap emission and the canonical GNS/WUGNOT pool
// [EXPECTED] canonical pool exists: true
// [EXPECTED] pool count: 1
//
// [SCENARIO] 3. Configure protocol parameters through the admin setters
// [EXPECTED] pool creation fee: 100000000
// [EXPECTED] withdrawal fee bps: 100
// [EXPECTED] router swap fee bps: 100
// [EXPECTED] devops pct: 4000
// [EXPECTED] gov staker pct: 6000
// [EXPECTED] unstaking fee bps: 100
// [EXPECTED] deposit gns amount: 1000000000
// [EXPECTED] minimum reward amount: 1000000000
// [EXPECTED] bar minimum reward amount: 1000000 found: true
// [EXPECTED] allowed token count: 3
// [EXPECTED] warmup tiers: 4
// [EXPECTED] undelegation lockup period: 100
//
// [SCENARIO] 4. Create the BAR/FOO pool and grow its observation cardinality
// [EXPECTED] created pool: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [EXPECTED] pool exists: true
// [EXPECTED] token0: gno.land/r/onbloc/bar.BAR
// [EXPECTED] token1: gno.land/r/onbloc/foo.FOO
// [EXPECTED] fee: 500
// [EXPECTED] tick spacing: 10
// [EXPECTED] slot0 tick: 0
// [EXPECTED] slot0 sqrtPriceX96: 79228162514264337593543950336
// [EXPECTED] slot0 unlocked: true
// [EXPECTED] creation fee accrued to protocol fee: 100000000
// [EXPECTED] slot0 fee protocol: 68
// [EXPECTED] observation cardinality next: 10
//
// [SCENARIO] 5. Position lifecycle: mint, increase, decrease, collect fee
// [EXPECTED] minted position: 1 liquidity: 1066918731 amount0: 50000000 amount1: 50000000
// [EXPECTED] position owner: g10n6fcxm0zr3pl9gz0q4nacwvlfkjzya97rlxxz
// [EXPECTED] position pool key: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [EXPECTED] position ticks: -960 960
// [EXPECTED] position in range: true
// [EXPECTED] position burned: false
// [EXPECTED] minted position: 2 liquidity: 327755575
// [EXPECTED] increased liquidity: 213383746 amount0: 10000000 amount1: 10000000
// [EXPECTED] position liquidity now: 1280302477
// [EXPECTED] fee-accrual swap bar->foo in/out: 2000000 -1976553
// [EXPECTED] fee-accrual swap foo->bar in/out: 2000000 -1981465
// [EXPECTED] pool tick after the fee-accrual swaps: 0
// [EXPECTED] fees accrued before decrease (gross): 597 597
// [EXPECTED] removed liquidity: 640151238 from pool: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [EXPECTED] principal returned: 29999012 30000987
// [EXPECTED] fees returned with the principal (net): 592 592
// [EXPECTED] withdrawal fee accrued (BAR / FOO): 5 5
// [EXPECTED] position liquidity after decrease: 640151239
// [EXPECTED] position count: 2
// [EXPECTED] withdrawal fee expected from the gross fee: 5 5
//
// [SCENARIO] 6. Router: exact-in / exact-out, single and multi-hop
// [EXPECTED] exact-in-single in/out: 1000000 -988486
// [EXPECTED] exact-in in/out: 1000000 -990520
// [EXPECTED] exact-out-single in/out: 505567 -500000
// [EXPECTED] exact-out in/out: 505045 -500000
// [EXPECTED] pool tick after swaps: 0
// [EXPECTED] pool liquidity: 967906814
// [EXPECTED] fee growth global: 358045537627336065200174822438606 358257148375155596322091915147789
// [EXPECTED] pool protocol fees: 438 438
// [EXPECTED] router fee accrued (FOO): 35004
//
// [SCENARIO] 7. Collect position fees generated by the swaps
// [EXPECTED] unclaimed fee before collect: 375 375
// [EXPECTED] collected fee: 372 372 pool: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [EXPECTED] fee tokens: 375 375
// [EXPECTED] unclaimed fee after collect: 0 0
//
// [SCENARIO] 8. Reposition the second position into a new tick range
// [EXPECTED] liquidity before reposition: 0
// [EXPECTED] repositioned liquidity: 676696536 ticks: -600 600
// [EXPECTED] amounts used: 19996841 20000000
// [EXPECTED] position ticks from getter: -600 600
//
// [SCENARIO] 9. Staker: tier setup, external incentive, stake position 1
// [EXPECTED] pool tier after SetPoolTier: 2
// [EXPECTED] pool tier after ChangePoolTier: 1
// [EXPECTED] tier1 pool count: 2
// [EXPECTED] incentive id: g10n6fcxm0zr3pl9gz0q4nacwvlfkjzya97rlxxz:1234567965:1
// [EXPECTED] incentive reward token: gno.land/r/gnoswap/gns.GNS
// [EXPECTED] incentive total reward: 1500000000
// [EXPECTED] incentive creator: g10n6fcxm0zr3pl9gz0q4nacwvlfkjzya97rlxxz
// [EXPECTED] incentive deposit gns: 1000000000
// [EXPECTED] staked position 1 into: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [EXPECTED] is staked: true
// [EXPECTED] deposit owner: g10n6fcxm0zr3pl9gz0q4nacwvlfkjzya97rlxxz
// [EXPECTED] deposit liquidity: 640151239
// [EXPECTED] deposit target pool: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500
// [EXPECTED] position operator after stake is the staker caller: true
// [EXPECTED] pool staked liquidity: 640151239
//
// [SCENARIO] 10. Accumulate 10 days of rewards and collect them
// [EXPECTED] collectable emission reward: 924663981581
// [EXPECTED] collectable external reward: 61572819
// [EXPECTED] internal reward to user: 915417341766 penalty: 1386992627983
// [EXPECTED] external reward to user: gno.land/r/gnoswap/gns.GNS 61572819
// [EXPECTED] external reward penalty: gno.land/r/gnoswap/gns.GNS 88113715
// [EXPECTED] collected internal reward total: 2311656609564
// [EXPECTED] total emission sent: 2302423347314
//
// [SCENARIO] 11. Protocol fee distribution to devops / gov staker
// [EXPECTED] accumulated BAR (gov staker / devops): 21049 14031
// [EXPECTED] distributed BAR to gov staker: 21049
// [EXPECTED] distributed BAR to devops: 14031
// [EXPECTED] reserved token count: 0
// [EXPECTED] distributed FOO to gov staker: 21007
// [EXPECTED] distributed GNS to gov staker: 5608353326
//
// [SCENARIO] 12. Gov staker: delegate, redelegate, undelegate, collect
// [EXPECTED] alice delegated amount: 2000000000
// [EXPECTED] total delegated: 2000000000
// [EXPECTED] total xGNS supply: 2000000000
// [EXPECTED] delegation count: 1
// [EXPECTED] admin delegated amount: 5000000000
// [EXPECTED] total delegated after admin: 7000000000
// [EXPECTED] redelegated: 500000000
// [EXPECTED] alice->alice delegation count: 1
// [EXPECTED] total locked amount: 7000000000
// [EXPECTED] collected undelegated gns: 200000000
// [EXPECTED] total locked amount after collect: 6800000000
// [EXPECTED] alice claimable emission reward: 0
// [EXPECTED] alice claimable protocol fee token count: 3
// [EXPECTED] emission distributed amount: 0
// [EXPECTED] protocol fee amount (BAR): 21049
// [EXPECTED] delegation snapshots present: true
//
// [SCENARIO] 13. Governance: propose, vote, execute, cancel, reconfigure
// [EXPECTED] governance config version: 1
// [EXPECTED] voting period: 604800 quorum: 50
// [EXPECTED] text proposal id: 1
// [EXPECTED] text proposal title: text proposal
// [EXPECTED] text proposal proposer is admin: true
// [EXPECTED] text proposal status after cancel: canceled
// [EXPECTED] spend proposal id: 2
// [EXPECTED] spend proposal type: CommunityPoolSpend
// [EXPECTED] proposal 2 yea/nay: 6500000000 0
// [EXPECTED] admin vote weight: 6500000000
// [EXPECTED] vote status quorum/max/yes/no: 3400000000 6800000000 6500000000 0
// [EXPECTED] spend proposal status after execute: executed
// [EXPECTED] community pool spend received by alice: 1000
// [EXPECTED] param proposal id: 3
// [EXPECTED] proposal count: 3
// [EXPECTED] proposal 3 yea/nay: 6500000000 0
// [EXPECTED] admin vote weight: 6500000000
// [EXPECTED] vote status quorum/max/yes/no: 3400000000 6800000000 6500000000 0
// [EXPECTED] unstaking fee before/after governance execution: 100 150
// [EXPECTED] governance config version after reconfigure: 2
//
// [SCENARIO] 14. Launchpad: project, deposit, reward collection
// [EXPECTED] project id: gno.land/r/onbloc/obl.OBL:518579
// [EXPECTED] project count: 1
// [EXPECTED] project name: OBL launchpad project
// [EXPECTED] project recipient is project owner: true
// [EXPECTED] tier distribute amounts: 100000000 200000000 700000000
// [EXPECTED] deposit id: 1
// [EXPECTED] deposit count: 1
// [EXPECTED] total GNS staked in launchpad: 1000000
// [EXPECTED] deposit amount: 1000000
// [EXPECTED] launchpad project wallet xGNS: 1000000 found: true
// [EXPECTED] launchpad reward claimed: 13333719
// [EXPECTED] project recipient collected launchpad rewards
//
// [SCENARIO] 15. Capture the pre-upgrade snapshot through the getters
// [EXPECTED] pool liquidity: 1316847775
// [EXPECTED] pool tick: 0
// [EXPECTED] pool protocol fees: 438 438
// [EXPECTED] position 1 liquidity: 640151239
// [EXPECTED] staker pool tier: 1
// [EXPECTED] staked deposit liquidity: 640151239
// [EXPECTED] protocol fee split: 4000 6000
// [EXPECTED] total delegated: 6800000000
// [EXPECTED] proposal count: 3
// [EXPECTED] project count: 1
// [EXPECTED] launchpad deposits: 1000000
// [EXPECTED] position fee growth inside last: 358045537627336065200174822438606 358257148375155596322091915147789
// [EXPECTED] position unclaimed fee: 0 0
// [EXPECTED] staker collected internal reward: 2311656609564
// [EXPECTED] total emission sent: 2302423347314
// [EXPECTED] external incentive total / distributed: 1500000000 61572819
// [EXPECTED] proposal ids: 3 delegation ids: 3
// [EXPECTED] param proposal yea / nay / status: 6500000000 0 executed
// [EXPECTED] launchpad project active: true
// [EXPECTED] staker allowed token: gno.land/r/gnoswap/gns.GNS
// [EXPECTED] staker allowed token: gno.land/r/gnoland/wugnot.wugnot
// [EXPECTED] staker allowed token: gno.land/r/onbloc/bar.BAR
// [EXPECTED] deposit warmup 0 duration / nextWarmupTime / ratio: 432000 1234999970 30
// [EXPECTED] deposit warmup 1 duration / nextWarmupTime / ratio: 864000 1235863970 50
// [EXPECTED] deposit warmup 2 duration / nextWarmupTime / ratio: 2592000 1238455970 70
// [EXPECTED] deposit warmup 3 duration / nextWarmupTime / ratio: 9223372036854775807 9223372036854775807 100
//
// [SCENARIO] 16. Upgrade all eight implementations to v2_valid
// [EXPECTED] pool impl: gno.land/r/gnoswap/pool/v2_valid
// [EXPECTED] position impl: gno.land/r/gnoswap/position/v2_valid
// [EXPECTED] router impl: gno.land/r/gnoswap/router/v2_valid
// [EXPECTED] staker impl: gno.land/r/gnoswap/staker/v2_valid
// [EXPECTED] launchpad impl: gno.land/r/gnoswap/launchpad/v2_valid
// [EXPECTED] protocol_fee impl: gno.land/r/gnoswap/protocol_fee/v2_valid
// [EXPECTED] governance impl: gno.land/r/gnoswap/gov/governance/v2_valid
// [EXPECTED] gov staker impl: gno.land/r/gnoswap/gov/staker/v2_valid
//
// [SCENARIO] 17. Validate that every v1 value survived the upgrade
// [EXPECTED] every snapshot field is identical after the upgrade
//
// [SCENARIO] 18. Re-run the same operations through v2_valid
// [EXPECTED] v2_valid minted position: 3 liquidity: 1066865580
// [EXPECTED] v2_valid mint amounts: 49995019 50000000
// [EXPECTED] v2_valid swap in/out: 1000000 -989093
// [EXPECTED] v2_valid staking reward to user/penalty: 42692363335 101132501977
// [EXPECTED] v2_valid distributed FOO to gov staker: 27001
// [EXPECTED] v2_valid delegated amount: 1000000000
// [EXPECTED] v2_valid delegation count: 4
// [EXPECTED] v2_valid total delegated: 7800000000
// [EXPECTED] v2_valid collected deposit principal: 1000000
// [EXPECTED] v2_valid proposal id: 4
// [EXPECTED] v2_valid proposal count: 4
//
// [SCENARIO] 19. Wind down: end incentive, unstake, remove tier
// [EXPECTED] incentive refunded: true
// [EXPECTED] incentive distributed: 64697761
// [EXPECTED] collected incentive penalty: 95405246
// [EXPECTED] position 1 staked after unstake: false
// [EXPECTED] position 1 owner after unstake: g10n6fcxm0zr3pl9gz0q4nacwvlfkjzya97rlxxz
// [EXPECTED] position 1 operator cleared: true
// [EXPECTED] allowed token count after removal: 2
// [EXPECTED] pool tier after removal: 0
// [EXPECTED] pool protocol fees before: 562 438
// [EXPECTED] collected protocol fees: 562 438
// [EXPECTED] pool protocol fees after: 0 0
// [EXPECTED] launchpad project ended: true
// [EXPECTED] launchpad leftover transferred: 900000001
//
// [SCENARIO] 20. Final invariants
// [EXPECTED] pool count: 2
// [EXPECTED] position count: 3
// [EXPECTED] total emission sent: 20045613123257
// [EXPECTED] gov staker total delegated: 7800000000
// [EXPECTED] governance proposal count: 4
// [EXPECTED] launchpad project count: 1
// [EXPECTED] incentive total/distributed/remaining/penalty: 1500000000 714844521 510575316 179174917
// [EXPECTED] pool impl: gno.land/r/gnoswap/pool/v2_valid
// [EXPECTED] position impl: gno.land/r/gnoswap/position/v2_valid
// [EXPECTED] router impl: gno.land/r/gnoswap/router/v2_valid
// [EXPECTED] staker impl: gno.land/r/gnoswap/staker/v2_valid
// [EXPECTED] launchpad impl: gno.land/r/gnoswap/launchpad/v2_valid
// [EXPECTED] protocol_fee impl: gno.land/r/gnoswap/protocol_fee/v2_valid
// [EXPECTED] governance impl: gno.land/r/gnoswap/gov/governance/v2_valid
// [EXPECTED] gov staker impl: gno.land/r/gnoswap/gov/staker/v2_valid

// collectDelegationIDs pages the read-only delegation view and returns the IDs
// its keys encode.
func collectDelegationIDs(offset, count int) []int64 {
	ids := []int64{}
	govStaker.GetDelegations().IterateByOffset(offset, count, func(key string, _ any) bool {
		id, err := strconv.ParseInt(key, 10, 64)
		if err != nil {
			return false
		}

		ids = append(ids, id)

		return false
	})

	return ids
}

// collectProposalIDs pages the read-only proposal view and returns the IDs its
// keys encode.
func collectProposalIDs(offset, count int) []int64 {
	ids := []int64{}
	govGovernance.GetProposals().IterateByOffset(offset, count, func(key string, _ any) bool {
		id, err := strconv.ParseInt(key, 10, 64)
		if err != nil {
			return false
		}

		ids = append(ids, id)

		return false
	})

	return ids
}
