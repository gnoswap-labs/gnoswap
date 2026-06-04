package v1

import (
	"math"
	"testing"

	testutils "gno.land/p/nt/testutils/v0"

	"gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/mock"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	sr "gno.land/r/gnoswap/staker"

	pool_v1 "gno.land/r/gnoswap/pool/v1"
	position_v1 "gno.land/r/gnoswap/position/v1"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/obl"
	"gno.land/r/onbloc/qux"
)

const (
	wugnotPath string = "gno.land/r/gnoland/wugnot"
	gnsPath    string = "gno.land/r/gnoswap/gns"
	barPath    string = "gno.land/r/onbloc/bar"
	bazPath    string = "gno.land/r/onbloc/baz"
	fooPath    string = "gno.land/r/onbloc/foo"
	oblPath    string = "gno.land/r/onbloc/obl"
	quxPath    string = "gno.land/r/onbloc/qux"

	fee100      uint32 = 100
	fee500      uint32 = 500
	fee3000     uint32 = 3000
	maxApprove  int64  = 9223372036854775806
	max_timeout int64  = 9999999999

	stakerPackagePath string = "gno.land/r/gnoswap/staker"
)

var (
	// define addresses to use in tests
	addr01 = testutils.TestAddress("addr01")
	addr02 = testutils.TestAddress("addr02")
)

var (
	adminRealm = testing.NewUserRealm(adminAddr)

	alice = testutils.TestAddress("alice")

	govGovernanceAddr = access.MustGetAddress(prbac.ROLE_GOVERNANCE.String())
	poolAddr          = access.MustGetAddress(prbac.ROLE_POOL.String())
	routerAddr        = access.MustGetAddress(prbac.ROLE_ROUTER.String())
	emissionAddr      = access.MustGetAddress(prbac.ROLE_EMISSION.String())
	stakerAddr        = access.MustGetAddress(prbac.ROLE_STAKER.String())
	adminAddr         = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	communityPoolAddr = access.MustGetAddress(prbac.ROLE_COMMUNITY_POOL.String())

	stakerRealm = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	// addresses used in tests
	addrUsedInTest = []address{addr01, addr02}

	mockInstance     *stakerV1
	mockGNFTAccessor = newMockNFTAccessor()

	initializedPool     bool
	initializedPosition bool
)

func CreatePool(
	cur realm,
	token0 string,
	token1 string,
	fee uint32,
	sqrtPriceX96 string,
	caller address,
) {
	testing.SetRealm(testing.NewUserRealm(caller))
	poolPath := pl.GetPoolPath(token0, token1, fee)
	if !pl.ExistsPoolPath(poolPath) {
		pl.CreatePool(cross(cur), token0, token1, fee, sqrtPriceX96)
	}
}

func LPTokenStake(t *testing.T, owner address, positionId uint64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
}

func LPTokenUnStake(t *testing.T, owner address, positionId uint64, unwrap bool) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
}

func CreateSecondPoolWithoutFee(cur realm, t *testing.T) {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross(cur), 0)

	CreatePool(cur,
		barPath,
		bazPath,
		fee3000,
		gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(),
		adminAddr,
	)
}

func MakeMintPositionWithoutFee(cur realm, t *testing.T) (uint64, string, string, string) {
	t.Helper()

	// make actual data to test resetting not only position's state but also pool's state
	testing.SetRealm(adminRealm)

	TokenApprove(cur, t, barPath, adminAddr, poolAddr, maxApprove)
	TokenApprove(cur, t, bazPath, adminAddr, poolAddr, maxApprove)

	// mint position
	return pn.Mint(
		cross(cur),
		barPath,
		bazPath,
		fee3000,
		-887220,
		887220,
		"50000",
		"50000",
		"0",
		"0",
		max_timeout,
		adminAddr,
		"",
	)
}

func TokenFaucet(cur realm, t *testing.T, tokenPath string, to address) {
	t.Helper()
	testing.SetOriginCaller(adminAddr)
	defaultAmount := int64(5_000_000_000)

	switch tokenPath {
	case gnsPath:
		gnsTransfer(cur, t, to, defaultAmount)
	case barPath:
		barTransfer(cur, t, to, defaultAmount)
	case bazPath:
		bazTransfer(cur, t, to, defaultAmount)
	case fooPath:
		fooTransfer(cur, t, to, defaultAmount)
	case oblPath:
		oblTransfer(cur, t, to, defaultAmount)
	case quxPath:
		quxTransfer(cur, t, to, defaultAmount)
	default:
		panic("token not found")
	}
}

func TokenBalance(t *testing.T, tokenPath string, owner address) int64 {
	t.Helper()
	switch tokenPath {
	case gnsPath:
		return gns.BalanceOf(owner)
	case barPath:
		return bar.BalanceOf(owner)
	case bazPath:
		return baz.BalanceOf(owner)
	case fooPath:
		return foo.BalanceOf(owner)
	case oblPath:
		return obl.BalanceOf(owner)
	case quxPath:
		return qux.BalanceOf(owner)
	default:
		panic("token not found")
	}
}

func TokenAllowance(t *testing.T, tokenPath string, owner, spender address) int64 {
	t.Helper()
	switch tokenPath {
	case gnsPath:
		return gns.Allowance(owner, spender)
	case barPath:
		return bar.Allowance(owner, spender)
	case bazPath:
		return baz.Allowance(owner, spender)
	case fooPath:
		return foo.Allowance(owner, spender)
	case oblPath:
		return obl.Allowance(owner, spender)
	case quxPath:
		return qux.Allowance(owner, spender)
	default:
		panic("token not found")
	}
}

func TokenApprove(cur realm, t *testing.T, tokenPath string, owner, spender address, amount int64) {
	t.Helper()
	switch tokenPath {
	case gnsPath:
		gnsApprove(cur, t, owner, spender, amount)
	case barPath:
		barApprove(cur, t, owner, spender, amount)
	case bazPath:
		bazApprove(cur, t, owner, spender, amount)
	case fooPath:
		fooApprove(cur, t, owner, spender, amount)
	case oblPath:
		oblApprove(cur, t, owner, spender, amount)
	case quxPath:
		quxApprove(cur, t, owner, spender, amount)
	default:
		panic("token not found")
	}
}

func MintPosition(
	cur realm,
	t *testing.T,
	token0 string,
	token1 string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	amount0Desired string, // *u256.Uint
	amount1Desired string, // *u256.Uint
	amount0Min string, // *u256.Uint
	amount1Min string, // *u256.Uint
	deadline int64,
	mintTo address,
	caller address,
) (uint64, string, string, string) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(caller))

	return pn.Mint(
		cross(cur),
		token0,
		token1,
		fee,
		tickLower,
		tickUpper,
		amount0Desired,
		amount1Desired,
		amount0Min,
		amount1Min,
		deadline,
		mintTo,
		"",
	)
}

func gnsApprove(cur realm, t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	gns.Approve(cross(cur), spender, amount)
}

func barApprove(cur realm, t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	bar.Approve(cross(cur), spender, amount)
}

func bazApprove(cur realm, t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	baz.Approve(cross(cur), spender, amount)
}

func fooApprove(cur realm, t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	foo.Approve(cross(cur), spender, amount)
}

func oblApprove(cur realm, t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	obl.Approve(cross(cur), spender, amount)
}

func quxApprove(cur realm, t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	qux.Approve(cross(cur), spender, amount)
}

func gnsTransfer(cur realm, t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), to, amount)
}

func barTransfer(cur realm, t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(adminRealm)
	bar.Transfer(cross(cur), to, amount)
}

func bazTransfer(cur realm, t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(adminRealm)
	baz.Transfer(cross(cur), to, amount)
}

func fooTransfer(cur realm, t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(adminRealm)
	foo.Transfer(cross(cur), to, amount)
}

func oblTransfer(cur realm, t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(adminRealm)
	obl.Transfer(cross(cur), to, amount)
}

func quxTransfer(cur realm, t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(adminRealm)
	qux.Transfer(cross(cur), to, amount)
}

type gnsBalanceTracker struct {
	height               int64
	stakerBalance        uint64
	devOpsBalance        uint64
	communityPoolBalance uint64
	govStakerBalance     uint64
	protocolFeeBalance   uint64
	callerBalance        uint64
}

// returns true if actual is within 0.0001% of expected
func isInErrorRange(expected uint64, actual uint64) bool {
	maxSafeValue := uint64(math.MaxUint64 / 100001)
	var lowerBound, upperBound uint64
	if expected > maxSafeValue {
		lowerBound = expected / 100000 * 99999
		upperBound = expected / 100000 * 100001
	} else {
		lowerBound = expected * 99999 / 100000
		upperBound = expected * 100001 / 100000
	}
	return actual >= lowerBound && actual <= upperBound
}

func initStakerTest(cur realm, t *testing.T) {
	t.Helper()

	mockGNFTAccessor = newMockNFTAccessor()

	initPoolTest(cur, t)
	initPositionTest(cur, t)

	mockInstance = &stakerV1{
		store:            newMockStakerStore(),
		poolAccessor:     newMockPoolAccessor(),
		emissionAccessor: newMockEmissionAccessor(),
		nftAccessor:      mockGNFTAccessor,
	}
}

func initPoolTest(cur realm, t *testing.T) {
	t.Helper()
	const mockPoolPath = "gno.land/r/gnoswap/pool/mock"

	if !initializedPool {
		initializedPool = true
		testing.SetRealm(testing.NewCodeRealm(mockPoolPath))
		pl.RegisterInitializer(cross(cur), func(_ int, rlm realm, poolStore pl.IPoolStore) pl.IPool {
			return pool_v1.NewPoolV1(mock.NewMockPoolStore())
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	pl.UpgradeImpl(cross(cur), mockPoolPath)
}

func initPositionTest(cur realm, t *testing.T) {
	t.Helper()
	const mockPositionPath = "gno.land/r/gnoswap/position/mock"

	if !initializedPosition {
		initializedPosition = true
		testing.SetRealm(testing.NewCodeRealm(mockPositionPath))
		pn.RegisterInitializer(cross(cur), func(_ int, rlm realm, positionStore pn.IPositionStore) pn.IPosition {
			return position_v1.NewPositionV1(mock.NewMockPositionStore(), mockGNFTAccessor)
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	pn.UpgradeImpl(cross(cur), mockPositionPath)
}

func getMockInstance() *stakerV1 {
	if mockInstance == nil {
		mockInstance = &stakerV1{
			store:            newMockStakerStore(),
			poolAccessor:     newMockPoolAccessor(),
			emissionAccessor: newMockEmissionAccessor(),
			nftAccessor:      mockGNFTAccessor,
		}
	}

	return mockInstance
}

func mockInstanceSetDepositGnsAmount(cur realm, amount int64) {
	testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
	getMockInstance().SetDepositGnsAmount(0, cur, amount)
}

func mockInstanceSetMinimumRewardAmount(cur realm, amount int64) {
	testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
	getMockInstance().SetMinimumRewardAmount(0, cur, amount)
}

func mockInstanceStakeToken(cur realm, positionId uint64, referrer string) {
	testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
	getMockInstance().StakeToken(0, cur, positionId, referrer)
}

func mockInstanceCollectReward(cur realm, positionId uint64) {
	testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
	getMockInstance().CollectReward(0, cur, positionId)
}

func mockInstanceAddToken(cur realm, tokenPath string) {
	testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
	getMockInstance().AddToken(0, cur, tokenPath)
}

func mockInstanceRemoveToken(cur realm, tokenPath string) {
	testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
	getMockInstance().RemoveToken(0, cur, tokenPath)
}

func mockInstanceSetUnstakingFee(cur realm, fee uint64) {
	testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
	getMockInstance().SetUnStakingFee(0, cur, fee)
}

func mockInstanceCreateExternalIncentive(cur realm, poolPath string, rewardToken string, rewardAmount int64, startTimestamp int64, endTimestamp int64) {
	testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
	getMockInstance().CreateExternalIncentive(0, cur, poolPath, rewardToken, rewardAmount, startTimestamp, endTimestamp)
}

func mockInstanceSetPoolTier(cur realm, poolPath string, tier uint64) {
	testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
	getMockInstance().SetPoolTier(0, cur, poolPath, tier)
}

func mockInstanceSetWarmupPeriod(cur realm, poolPath string, warmupPeriod int64) {
	// SetWarmUp is a global function that takes percentage and time duration
	// For test purposes, we'll use 30% and the provided warmup period as duration
	testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
	getMockInstance().SetWarmUp(0, cur, 30, warmupPeriod)
}

func mockInstanceUnStakeToken(cur realm, positionId uint64) string {
	testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
	return getMockInstance().UnStakeToken(0, cur, positionId)
}

func mockInstanceEndExternalIncentive(cur realm, poolPath string, incentiveId string, refundAddress address) {
	testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
	getMockInstance().EndExternalIncentive(0, cur, poolPath, incentiveId, refundAddress)
}

func mockInstanceCollectExternalIncentivePenalty(cur realm, poolPath string, incentiveId string, refundAddress address) int64 {
	testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
	return getMockInstance().CollectExternalIncentivePenalty(0, cur, poolPath, incentiveId, refundAddress)
}

func mockNFTMint(cur realm, to address, positionId uint64) {
	testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
	getMockInstance().nftAccessor.Mint(0, cur, to, positionIdFrom(positionId))
}

func mockNFTApprove(cur realm, approved address, positionId uint64) {
	testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
	getMockInstance().nftAccessor.Approve(0, cur, approved, positionIdFrom(positionId))
}

func getPositionOperator(positionId uint64) address {
	testing.SetRealm(adminRealm)
	return pn.GetPositionOperator(positionId)
}

// rewardPerSecondFromX128 returns the floored integer reward-per-second
// derived from the Q128-scaled value. Used in tests for expected calculations.
func rewardPerSecondFromX128(incentive *sr.ExternalIncentive) int64 {
	rps := u256.Zero().Rsh(incentive.RewardPerSecondX128(), 128)
	return int64(rps.Uint64())
}
