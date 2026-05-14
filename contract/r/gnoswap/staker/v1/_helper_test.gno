package v1

import (
	"math"
	"testing"

	testutils "gno.land/p/nt/testutils/v0"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/mock"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"

	pool_v1 "gno.land/r/gnoswap/pool/v1"
	position_v1 "gno.land/r/gnoswap/position/v1"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/atone"
	"gno.land/r/gnoswap/test_token/btc"
	"gno.land/r/gnoswap/test_token/eth"
	"gno.land/r/gnoswap/test_token/sol"
)

const (
	wugnotPath string = "gno.land/r/gnoland/wugnot"
	gnsPath    string = "gno.land/r/gnoswap/gns"
	atomPath    string = "gno.land/r/gnoswap/test_token/atom"
	atonePath    string = "gno.land/r/gnoswap/test_token/atone"
	btcPath    string = "gno.land/r/gnoswap/test_token/btc"
	ethPath    string = "gno.land/r/gnoswap/test_token/eth"
	solPath    string = "gno.land/r/gnoswap/test_token/sol"

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

	posRealm    = testing.NewCodeRealm("gno.land/r/gnoswap/position")
	rouRealm    = testing.NewCodeRealm("gno.land/r/gnoswap/router")
	stakerRealm = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	// addresses used in tests
	addrUsedInTest = []address{addr01, addr02}

	dummyAddr  = testutils.TestAddress("dummy")
	dummyRealm = testing.NewUserRealm(dummyAddr)

	mockInstance     *stakerV1
	mockGNFTAccessor = newMockNFTAccessor()

	initializedPool     bool
	initializedPosition bool
)

func CreatePool(
	token0 string,
	token1 string,
	fee uint32,
	sqrtPriceX96 string,
	caller address,
) {
	testing.SetRealm(testing.NewUserRealm(caller))
	poolPath := pl.GetPoolPath(token0, token1, fee)
	if !pl.ExistsPoolPath(poolPath) {
		pl.CreatePool(cross, token0, token1, fee, sqrtPriceX96)
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

func CreateSecondPoolWithoutFee(t *testing.T) {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)

	CreatePool(
		atomPath,
		atonePath,
		fee3000,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
		adminAddr,
	)
}

func MakeMintPositionWithoutFee(t *testing.T) (uint64, string, string, string) {
	t.Helper()

	// make actual data to test resetting not only position's state but also pool's state
	testing.SetRealm(adminRealm)

	TokenApprove(t, atomPath, adminAddr, poolAddr, maxApprove)
	TokenApprove(t, atonePath, adminAddr, poolAddr, maxApprove)

	// mint position
	return pn.Mint(
		cross,
		atomPath,
		atonePath,
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

func TokenFaucet(t *testing.T, tokenPath string, to address) {
	t.Helper()
	testing.SetOriginCaller(adminAddr)
	defaultAmount := int64(5_000_000_000)

	switch tokenPath {
	case gnsPath:
		gnsTransfer(t, to, defaultAmount)
	case atomPath:
		atomTransfer(t, to, defaultAmount)
	case atonePath:
		atoneTransfer(t, to, defaultAmount)
	case btcPath:
		btcTransfer(t, to, defaultAmount)
	case ethPath:
		ethTransfer(t, to, defaultAmount)
	case solPath:
		solTransfer(t, to, defaultAmount)
	default:
		panic("token not found")
	}
}

func TokenBalance(t *testing.T, tokenPath string, owner address) int64 {
	t.Helper()
	switch tokenPath {
	case gnsPath:
		return gns.BalanceOf(owner)
	case atomPath:
		return atom.BalanceOf(owner)
	case atonePath:
		return atone.BalanceOf(owner)
	case btcPath:
		return btc.BalanceOf(owner)
	case ethPath:
		return eth.BalanceOf(owner)
	case solPath:
		return sol.BalanceOf(owner)
	default:
		panic("token not found")
	}
}

func TokenAllowance(t *testing.T, tokenPath string, owner, spender address) int64 {
	t.Helper()
	switch tokenPath {
	case gnsPath:
		return gns.Allowance(owner, spender)
	case atomPath:
		return atom.Allowance(owner, spender)
	case atonePath:
		return atone.Allowance(owner, spender)
	case btcPath:
		return btc.Allowance(owner, spender)
	case ethPath:
		return eth.Allowance(owner, spender)
	case solPath:
		return sol.Allowance(owner, spender)
	default:
		panic("token not found")
	}
}

func TokenApprove(t *testing.T, tokenPath string, owner, spender address, amount int64) {
	t.Helper()
	switch tokenPath {
	case gnsPath:
		gnsApprove(t, owner, spender, amount)
	case atomPath:
		atomApprove(t, owner, spender, amount)
	case atonePath:
		atoneApprove(t, owner, spender, amount)
	case btcPath:
		btcApprove(t, owner, spender, amount)
	case ethPath:
		ethApprove(t, owner, spender, amount)
	case solPath:
		solApprove(t, owner, spender, amount)
	default:
		panic("token not found")
	}
}

func MintPosition(t *testing.T,
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
		cross,
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

func gnsApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	gns.Approve(cross, spender, amount)
}

func atomApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	atom.Approve(cross, spender, amount)
}

func atoneApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	atone.Approve(cross, spender, amount)
}

func btcApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	btc.Approve(cross, spender, amount)
}

func ethApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	eth.Approve(cross, spender, amount)
}

func solApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	sol.Approve(cross, spender, amount)
}

func gnsTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, to, amount)
}

func atomTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(adminRealm)
	atom.Transfer(cross, to, amount)
}

func atoneTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(adminRealm)
	atone.Transfer(cross, to, amount)
}

func btcTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(adminRealm)
	btc.Transfer(cross, to, amount)
}

func ethTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(adminRealm)
	eth.Transfer(cross, to, amount)
}

func solTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(adminRealm)
	sol.Transfer(cross, to, amount)
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

func initStakerTest(t *testing.T) {
	t.Helper()

	mockGNFTAccessor = newMockNFTAccessor()

	initPoolTest(t)
	initPositionTest(t)

	mockInstance = &stakerV1{
		store:            newMockStakerStore(),
		poolAccessor:     newMockPoolAccessor(),
		emissionAccessor: newMockEmissionAccessor(),
		nftAccessor:      mockGNFTAccessor,
	}
}

func initPoolTest(t *testing.T) {
	t.Helper()
	const mockPoolPath = "gno.land/r/gnoswap/pool/mock"

	if !initializedPool {
		initializedPool = true
		testing.SetRealm(testing.NewCodeRealm(mockPoolPath))
		pl.RegisterInitializer(cross, func(s pl.IPoolStore) pl.IPool {
			return pool_v1.NewPoolV1(mock.NewMockPoolStore())
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	pl.UpgradeImpl(cross, mockPoolPath)
}

func initPositionTest(t *testing.T) {
	t.Helper()
	const mockPositionPath = "gno.land/r/gnoswap/position/mock"

	if !initializedPosition {
		initializedPosition = true
		testing.SetRealm(testing.NewCodeRealm(mockPositionPath))
		pn.RegisterInitializer(cross, func(s pn.IPositionStore) pn.IPosition {
			return position_v1.NewPositionV1(mock.NewMockPositionStore(), mockGNFTAccessor)
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	pn.UpgradeImpl(cross, mockPositionPath)
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

func mockInstanceSetDepositGnsAmount(amount int64) {
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().SetDepositGnsAmount(amount)
	}(cross)
}

func mockInstanceSetMinimumRewardAmount(amount int64) {
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().SetMinimumRewardAmount(amount)
	}(cross)
}

func mockInstanceStakeToken(positionId uint64, referrer string) {
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().StakeToken(positionId, referrer)
	}(cross)
}

func mockInstanceCollectReward(positionId uint64) {
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().CollectReward(positionId)
	}(cross)
}

func mockInstanceAddToken(tokenPath string) {
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().AddToken(tokenPath)
	}(cross)
}

func mockInstanceRemoveToken(tokenPath string) {
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().RemoveToken(tokenPath)
	}(cross)
}

func mockInstanceSetUnstakingFee(fee uint64) {
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().SetUnStakingFee(fee)
	}(cross)
}

func mockInstanceCreateExternalIncentive(poolPath string, rewardToken string, rewardAmount int64, startTimestamp int64, endTimestamp int64) {
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().CreateExternalIncentive(poolPath, rewardToken, rewardAmount, startTimestamp, endTimestamp)
	}(cross)
}

func mockInstanceSetPoolTier(poolPath string, tier uint64) {
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().SetPoolTier(poolPath, tier)
	}(cross)
}

func mockInstanceSetWarmupPeriod(poolPath string, warmupPeriod int64) {
	// SetWarmUp is a global function that takes percentage and time duration
	// For test purposes, we'll use 30% and the provided warmup period as duration
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().SetWarmUp(30, warmupPeriod)
	}(cross)
}

func mockInstanceUnStakeToken(positionId uint64) string {
	var poolPath string
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		poolPath = getMockInstance().UnStakeToken(positionId)
	}(cross)
	return poolPath
}

func mockInstanceEndExternalIncentive(poolPath string, incentiveId string, refundAddress address) {
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().EndExternalIncentive(poolPath, incentiveId, refundAddress)
	}(cross)
}

func mockInstanceCollectExternalIncentivePenalty(poolPath string, incentiveId string, refundAddress address) int64 {
	var result int64
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		result = getMockInstance().CollectExternalIncentivePenalty(poolPath, incentiveId, refundAddress)
	}(cross)
	return result
}

func getPositionOperator(positionId uint64) address {
	testing.SetRealm(adminRealm)
	return pn.GetPositionOperator(positionId)
}
